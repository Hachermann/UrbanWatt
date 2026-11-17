-- =====================================================================
-- Chargement des CSV dans des tables DÉJÀ CRÉÉES — PostgreSQL (via psql)
-- Aucune table n'est supprimée ni recréée.
--
-- Utilisation : se placer dans le dossier qui contient les 9 CSV, puis
--   psql -U postgres -d NOM_DE_TA_BASE -f charger_csv_postgresql.sql
--
-- Les colonnes sont désignées par leur nom (celui de l'en-tête du CSV) :
-- l'ordre des colonnes dans tes tables n'a pas d'importance, mais si une
-- colonne porte un autre nom chez toi, corrige-le dans la liste entre ( ).
--
-- \copy est une commande de psql (ne marche pas dans pgAdmin).
-- Tout est dans une transaction : en cas d'erreur, rien n'est gardé.
-- =====================================================================

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';

BEGIN;

-- ---------------------------------------------------------------
-- (Optionnel) vider les tables avant de recharger : décommente la ligne
-- ---------------------------------------------------------------
-- TRUNCATE interventions, incidents, techniciens, paiements, sessions_recharge, vehicules, clients, bornes, stations;

-- ---------------------------------------------------------------
-- Chargement (séparateur ';', 1 ligne d'en-tête,
-- en format CSV une case vide est lue comme NULL)
-- ---------------------------------------------------------------
\copy stations (id_station, code_station, nom_station, ville, adresse, date_ouverture) FROM 'stations.csv' WITH (FORMAT csv, DELIMITER ';', HEADER true, ENCODING 'UTF8')
\copy bornes (id_borne, id_station, code_borne, puissance_kw, connecteur, etat) FROM 'bornes.csv' WITH (FORMAT csv, DELIMITER ';', HEADER true, ENCODING 'UTF8')
\copy clients (id_client, prenom, nom, email, ville, date_inscription) FROM 'clients.csv' WITH (FORMAT csv, DELIMITER ';', HEADER true, ENCODING 'UTF8')
\copy vehicules (id_vehicule, id_client, immatriculation, marque, modele, capacite_batterie_kwh) FROM 'vehicules.csv' WITH (FORMAT csv, DELIMITER ';', HEADER true, ENCODING 'UTF8')
\copy sessions_recharge (id_session, id_borne, id_vehicule, debut_session, fin_session, energie_kwh, cout_eur, statut) FROM 'sessions_recharge.csv' WITH (FORMAT csv, DELIMITER ';', HEADER true, ENCODING 'UTF8')
\copy paiements (id_paiement, id_session, date_paiement, montant_eur, mode_paiement, statut) FROM 'paiements.csv' WITH (FORMAT csv, DELIMITER ';', HEADER true, ENCODING 'UTF8')
\copy techniciens (id_technicien, prenom, nom, email) FROM 'techniciens.csv' WITH (FORMAT csv, DELIMITER ';', HEADER true, ENCODING 'UTF8')
\copy incidents (id_incident, id_borne, date_signalement, date_resolution, categorie, gravite, statut, description) FROM 'incidents.csv' WITH (FORMAT csv, DELIMITER ';', HEADER true, ENCODING 'UTF8')
\copy interventions (id_intervention, id_incident, id_technicien, date_debut, date_fin, statut, compte_rendu) FROM 'interventions.csv' WITH (FORMAT csv, DELIMITER ';', HEADER true, ENCODING 'UTF8')

-- ---------------------------------------------------------------
-- Si tes id sont en SERIAL / IDENTITY : recaler les compteurs sur le
-- plus grand id chargé (sinon le prochain INSERT sans id planterait).
-- Sans effet pour les colonnes qui n'ont pas de compteur.
-- ---------------------------------------------------------------
DO $$
DECLARE
    t text; c text; s text;
BEGIN
    FOR t, c IN SELECT * FROM (VALUES
        ('stations', 'id_station'),
        ('bornes', 'id_borne'),
        ('clients', 'id_client'),
        ('vehicules', 'id_vehicule'),
        ('sessions_recharge', 'id_session'),
        ('paiements', 'id_paiement'),
        ('techniciens', 'id_technicien'),
        ('incidents', 'id_incident'),
        ('interventions', 'id_intervention')
    ) AS v(tbl, col) LOOP
        s := pg_get_serial_sequence(t, c);
        IF s IS NOT NULL THEN
            EXECUTE format('SELECT setval(%L, MAX(%I)) FROM %I', s, c, t);
        END IF;
    END LOOP;
END $$;

COMMIT;

ANALYZE;

-- Contrôle : nombre de lignes par table
SELECT 'stations' AS table_name, COUNT(*) AS nb FROM stations
UNION ALL SELECT 'bornes' AS table_name, COUNT(*) AS nb FROM bornes
UNION ALL SELECT 'clients' AS table_name, COUNT(*) AS nb FROM clients
UNION ALL SELECT 'vehicules' AS table_name, COUNT(*) AS nb FROM vehicules
UNION ALL SELECT 'sessions_recharge' AS table_name, COUNT(*) AS nb FROM sessions_recharge
UNION ALL SELECT 'paiements' AS table_name, COUNT(*) AS nb FROM paiements
UNION ALL SELECT 'techniciens' AS table_name, COUNT(*) AS nb FROM techniciens
UNION ALL SELECT 'incidents' AS table_name, COUNT(*) AS nb FROM incidents
UNION ALL SELECT 'interventions' AS table_name, COUNT(*) AS nb FROM interventions;
