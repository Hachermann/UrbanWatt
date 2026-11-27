-- =====================================================================
-- UrbanWatt : contraintes d'intégrité (prévention)
--
-- Ce script MODIFIE le schéma : il ajoute des contraintes pour que
-- PostgreSQL refuse désormais les données incohérentes, au lieu de
-- les détecter après coup.
--
-- Utilisation : dans pgAdmin, Query Tool sur UrbanWatt, connecté en
-- tant que propriétaire des tables (postgres), puis F5.
-- Exécuté d'un bloc, le script est « tout ou rien » : si une seule
-- contrainte échoue, aucune n'est ajoutée.
--
-- Une contrainte ne peut être ajoutée que si les données existantes la
-- respectent. Les règles qui ont encore des anomalies dans les données
-- (voir controle_integrite_urbanwatt.sql) sont traitées à part, en bas
-- du fichier.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Domaine : listes de valeurs autorisées et valeurs positives
-- ---------------------------------------------------------------------
ALTER TABLE urbanwatt.bornes
  ADD CONSTRAINT chk_bornes_etat       CHECK (etat IN ('disponible', 'maintenance', 'hors_service')),
  ADD CONSTRAINT chk_bornes_connecteur CHECK (connecteur IN ('Type2', 'CCS')),
  ADD CONSTRAINT chk_bornes_puissance  CHECK (puissance_kw > 0);

ALTER TABLE urbanwatt.sessions_recharge
  ADD CONSTRAINT chk_sessions_statut   CHECK (statut IN ('terminee', 'interrompue', 'annulee')),
  ADD CONSTRAINT chk_sessions_energie  CHECK (energie_kwh >= 0),
  ADD CONSTRAINT chk_sessions_cout     CHECK (cout_eur >= 0);

ALTER TABLE urbanwatt.paiements
  ADD CONSTRAINT chk_paiements_statut  CHECK (statut IN ('accepte', 'refuse', 'en_attente')),
  ADD CONSTRAINT chk_paiements_mode    CHECK (mode_paiement IN ('carte', 'application', 'abonnement')),
  ADD CONSTRAINT chk_paiements_montant CHECK (montant_eur > 0);

ALTER TABLE urbanwatt.incidents
  ADD CONSTRAINT chk_incidents_statut  CHECK (statut IN ('ouvert', 'resolu')),
  ADD CONSTRAINT chk_incidents_gravite CHECK (gravite IN ('faible', 'moyenne', 'haute'));

ALTER TABLE urbanwatt.interventions
  ADD CONSTRAINT chk_interventions_statut CHECK (statut IN ('en_cours', 'terminee'));

ALTER TABLE urbanwatt.vehicules
  ADD CONSTRAINT chk_vehicules_capacite CHECK (capacite_batterie_kwh > 0);

ALTER TABLE urbanwatt.clients
  ADD CONSTRAINT chk_clients_email CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$');

ALTER TABLE urbanwatt.techniciens
  ADD CONSTRAINT chk_techniciens_email CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$');

-- ---------------------------------------------------------------------
-- 2. Cohérence temporelle (dates d'une même ligne)
-- ---------------------------------------------------------------------
ALTER TABLE urbanwatt.sessions_recharge
  ADD CONSTRAINT chk_sessions_dates      CHECK (fin_session > debut_session);
ALTER TABLE urbanwatt.incidents
  ADD CONSTRAINT chk_incidents_dates     CHECK (date_resolution >= date_signalement);
ALTER TABLE urbanwatt.interventions
  ADD CONSTRAINT chk_interventions_dates CHECK (date_fin >= date_debut);

-- ---------------------------------------------------------------------
-- 3. Cohérence entre le statut et les autres colonnes
-- ---------------------------------------------------------------------
ALTER TABLE urbanwatt.sessions_recharge
  -- une session terminée a forcément une fin, une énergie et un coût
  ADD CONSTRAINT chk_sessions_terminee CHECK (
    statut <> 'terminee'
    OR (fin_session IS NOT NULL AND energie_kwh IS NOT NULL AND cout_eur IS NOT NULL)),
  -- une session annulée n'a rien consommé
  ADD CONSTRAINT chk_sessions_annulee CHECK (
    statut <> 'annulee'
    OR (coalesce(energie_kwh, 0) = 0 AND coalesce(cout_eur, 0) = 0));

ALTER TABLE urbanwatt.incidents
  -- résolu <=> date de résolution renseignée
  ADD CONSTRAINT chk_incidents_resolution CHECK ((statut = 'resolu') = (date_resolution IS NOT NULL));

ALTER TABLE urbanwatt.interventions
  -- terminée <=> date de fin renseignée
  ADD CONSTRAINT chk_interventions_fin CHECK ((statut = 'terminee') = (date_fin IS NOT NULL));

-- ---------------------------------------------------------------------
-- 4. Doublons : un email ne correspond qu'à une seule personne
-- ---------------------------------------------------------------------
ALTER TABLE urbanwatt.clients     ADD CONSTRAINT uq_clients_email     UNIQUE (email);
ALTER TABLE urbanwatt.techniciens ADD CONSTRAINT uq_techniciens_email UNIQUE (email);

-- ---------------------------------------------------------------------
-- 5. Chevauchement : une borne ne sert qu'une session à la fois
--    Contrainte d'exclusion : PostgreSQL refuse toute session dont la
--    période recouvre celle d'une autre session sur la même borne.
--    Les sessions annulées n'ont pas de fin_session (période sans fin) :
--    elles sont exclues de la règle par la clause WHERE.
--    btree_gist est une extension fournie avec PostgreSQL.
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE urbanwatt.sessions_recharge
  ADD CONSTRAINT excl_sessions_borne_occupee
  EXCLUDE USING gist (id_borne WITH =, tsrange(debut_session, fin_session) WITH &&)
  WHERE (fin_session IS NOT NULL);

-- ---------------------------------------------------------------------
-- 6. Règles qui ont encore des anomalies dans les données
-- ---------------------------------------------------------------------

-- 6a. Une borne Type2 (courant alternatif) ne dépasse pas 43 kW
--     (maximum en triphasé ; au-delà, la recharge rapide se fait en
--     courant continu, avec un connecteur CCS).
--     5 bornes existantes ne respectent pas la règle. NOT VALID applique
--     la contrainte aux nouvelles lignes et aux modifications, sans
--     vérifier l'existant. Après correction des 5 bornes, lancer :
--       ALTER TABLE urbanwatt.bornes VALIDATE CONSTRAINT chk_bornes_type2_puissance;
ALTER TABLE urbanwatt.bornes
  ADD CONSTRAINT chk_bornes_type2_puissance
  CHECK (connecteur <> 'Type2' OR puissance_kw <= 43) NOT VALID;

-- 6b. Un véhicule ne recharge qu'à un seul endroit à la fois.
--     1 388 sessions existantes se chevauchent : à corriger d'abord.
--     Une contrainte d'exclusion ne peut pas être NOT VALID, elle est
--     donc laissée en commentaire jusqu'à la correction des données.
-- ALTER TABLE urbanwatt.sessions_recharge
--   ADD CONSTRAINT excl_sessions_vehicule_occupe
--   EXCLUDE USING gist (id_vehicule WITH =, tsrange(debut_session, fin_session) WITH &&)
--   WHERE (fin_session IS NOT NULL);

-- 6c. Règles qui portent sur plusieurs tables (session avant
--     l'inscription du client, énergie > puissance × durée, montant payé
--     différent du coût) : une contrainte CHECK ne peut pas lire une
--     autre table. Elles restent vérifiées par le script de contrôle,
--     à lancer régulièrement, ou par des triggers si l'application
--     l'exige.
