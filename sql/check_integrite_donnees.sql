-- =====================================================================
-- UrbanWatt : contrôle d'intégrité des données
--
-- Utilisation : dans pgAdmin, ouvre un Query Tool sur la base UrbanWatt,
-- colle tout le fichier et exécute-le (F5). Tu obtiens UN tableau de
-- résultats, une ligne par règle :
--
--   niveau       : type de contrôle (domaine, temporel, métier, doublons…)
--   regle        : ce qui est vérifié
--   nb_anomalies : nombre de lignes qui ne respectent pas la règle
--   verdict      : OK si 0 anomalie, ANOMALIE sinon
--
-- Le script est en lecture seule : il ne modifie rien.
-- Pour voir les lignes en cause d'une règle, copie la sous-requête
-- correspondante (repérée par son numéro dans ce fichier), retire
-- les parenthèses qui l'entourent et remplace « SELECT count(*) »
-- par « SELECT * ». Exécute-la seule dans un nouvel onglet.
--
-- Les contrôles de structure (clés primaires, clés étrangères, NOT NULL,
-- UNIQUE) ne sont pas repris ici : PostgreSQL les garantit déjà en
-- refusant toute ligne qui les viole. La règle 0 vérifie seulement
-- que toutes ces contraintes sont bien actives et validées.
-- =====================================================================

WITH controles(num, niveau, regle, nb_anomalies) AS (

-- ---------------------------------------------------------------------
-- 0. Structure : contraintes déclarées et validées
-- ---------------------------------------------------------------------
SELECT 0, '0. Structure', 'Contraintes PK / FK / UNIQUE non validées',
  (SELECT count(*) FROM pg_constraint c
     JOIN pg_namespace n ON n.oid = c.connamespace
    WHERE n.nspname = 'urbanwatt' AND NOT c.convalidated)

-- ---------------------------------------------------------------------
-- 1. Domaine : valeurs autorisées et valeurs numériques plausibles
-- ---------------------------------------------------------------------
UNION ALL SELECT 1, '1. Domaine', 'bornes.etat hors liste (disponible, maintenance, hors_service)',
  (SELECT count(*) FROM urbanwatt.bornes WHERE etat NOT IN ('disponible', 'maintenance', 'hors_service'))
UNION ALL SELECT 2, '1. Domaine', 'bornes.connecteur hors liste (Type2, CCS)',
  (SELECT count(*) FROM urbanwatt.bornes WHERE connecteur NOT IN ('Type2', 'CCS'))
UNION ALL SELECT 3, '1. Domaine', 'bornes.puissance_kw <= 0 ou > 350',
  (SELECT count(*) FROM urbanwatt.bornes WHERE puissance_kw <= 0 OR puissance_kw > 350)
UNION ALL SELECT 4, '1. Domaine', 'sessions_recharge.statut hors liste (terminee, interrompue, annulee)',
  (SELECT count(*) FROM urbanwatt.sessions_recharge WHERE statut NOT IN ('terminee', 'interrompue', 'annulee'))
UNION ALL SELECT 5, '1. Domaine', 'sessions_recharge : energie_kwh ou cout_eur négatif',
  (SELECT count(*) FROM urbanwatt.sessions_recharge WHERE energie_kwh < 0 OR cout_eur < 0)
UNION ALL SELECT 6, '1. Domaine', 'paiements.statut hors liste (accepte, refuse, en_attente)',
  (SELECT count(*) FROM urbanwatt.paiements WHERE statut NOT IN ('accepte', 'refuse', 'en_attente'))
UNION ALL SELECT 7, '1. Domaine', 'paiements.mode_paiement hors liste (carte, application, abonnement)',
  (SELECT count(*) FROM urbanwatt.paiements WHERE mode_paiement NOT IN ('carte', 'application', 'abonnement'))
UNION ALL SELECT 8, '1. Domaine', 'paiements.montant_eur <= 0',
  (SELECT count(*) FROM urbanwatt.paiements WHERE montant_eur <= 0)
UNION ALL SELECT 9, '1. Domaine', 'incidents : statut ou gravite hors liste',
  (SELECT count(*) FROM urbanwatt.incidents
    WHERE statut NOT IN ('ouvert', 'resolu') OR gravite NOT IN ('faible', 'moyenne', 'haute'))
UNION ALL SELECT 10, '1. Domaine', 'interventions.statut hors liste (en_cours, terminee)',
  (SELECT count(*) FROM urbanwatt.interventions WHERE statut NOT IN ('en_cours', 'terminee'))
UNION ALL SELECT 11, '1. Domaine', 'vehicules.capacite_batterie_kwh <= 0 ou > 200',
  (SELECT count(*) FROM urbanwatt.vehicules WHERE capacite_batterie_kwh <= 0 OR capacite_batterie_kwh > 200)
UNION ALL SELECT 12, '1. Domaine', 'Email client au format invalide',
  (SELECT count(*) FROM urbanwatt.clients WHERE email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')
UNION ALL SELECT 13, '1. Domaine', 'Email technicien au format invalide',
  (SELECT count(*) FROM urbanwatt.techniciens WHERE email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')

-- ---------------------------------------------------------------------
-- 2. Cohérence temporelle : l'ordre des dates est logique
-- ---------------------------------------------------------------------
UNION ALL SELECT 20, '2. Temporel', 'Session : fin_session <= debut_session',
  (SELECT count(*) FROM urbanwatt.sessions_recharge WHERE fin_session <= debut_session)
UNION ALL SELECT 21, '2. Temporel', 'Session commencée avant l''ouverture de la station',
  (SELECT count(*) FROM urbanwatt.sessions_recharge s
     JOIN urbanwatt.bornes b   ON b.id_borne = s.id_borne
     JOIN urbanwatt.stations st ON st.id_station = b.id_station
    WHERE s.debut_session < st.date_ouverture)
UNION ALL SELECT 22, '2. Temporel', 'Session commencée avant l''inscription du client',
  (SELECT count(*) FROM urbanwatt.sessions_recharge s
     JOIN urbanwatt.vehicules v ON v.id_vehicule = s.id_vehicule
     JOIN urbanwatt.clients c   ON c.id_client = v.id_client
    WHERE s.debut_session < c.date_inscription)
UNION ALL SELECT 23, '2. Temporel', 'Paiement daté avant la fin de la session',
  (SELECT count(*) FROM urbanwatt.paiements p
     JOIN urbanwatt.sessions_recharge s ON s.id_session = p.id_session
    WHERE p.date_paiement < s.fin_session)
UNION ALL SELECT 24, '2. Temporel', 'Incident : date_resolution < date_signalement',
  (SELECT count(*) FROM urbanwatt.incidents WHERE date_resolution < date_signalement)
UNION ALL SELECT 25, '2. Temporel', 'Incident signalé avant l''ouverture de la station',
  (SELECT count(*) FROM urbanwatt.incidents i
     JOIN urbanwatt.bornes b   ON b.id_borne = i.id_borne
     JOIN urbanwatt.stations st ON st.id_station = b.id_station
    WHERE i.date_signalement < st.date_ouverture)
UNION ALL SELECT 26, '2. Temporel', 'Intervention : date_fin < date_debut',
  (SELECT count(*) FROM urbanwatt.interventions WHERE date_fin < date_debut)
UNION ALL SELECT 27, '2. Temporel', 'Intervention commencée avant le signalement de l''incident',
  (SELECT count(*) FROM urbanwatt.interventions it
     JOIN urbanwatt.incidents i ON i.id_incident = it.id_incident
    WHERE it.date_debut < i.date_signalement)
UNION ALL SELECT 28, '2. Temporel', 'Date dans le futur (sessions, paiements, incidents, inscriptions)',
  (SELECT (SELECT count(*) FROM urbanwatt.sessions_recharge WHERE debut_session > now())
        + (SELECT count(*) FROM urbanwatt.paiements        WHERE date_paiement > now())
        + (SELECT count(*) FROM urbanwatt.incidents        WHERE date_signalement > now())
        + (SELECT count(*) FROM urbanwatt.clients          WHERE date_inscription > current_date))

-- ---------------------------------------------------------------------
-- 3. Cohérence métier : le statut correspond aux données
-- ---------------------------------------------------------------------
UNION ALL SELECT 30, '3. Métier', 'Session terminee sans fin, énergie ou coût',
  (SELECT count(*) FROM urbanwatt.sessions_recharge
    WHERE statut = 'terminee' AND (fin_session IS NULL OR energie_kwh IS NULL OR cout_eur IS NULL))
UNION ALL SELECT 31, '3. Métier', 'Session annulee avec énergie ou coût > 0',
  (SELECT count(*) FROM urbanwatt.sessions_recharge
    WHERE statut = 'annulee' AND (coalesce(energie_kwh, 0) > 0 OR coalesce(cout_eur, 0) > 0))
UNION ALL SELECT 32, '3. Métier', 'Énergie rechargée > capacité de la batterie du véhicule',
  (SELECT count(*) FROM urbanwatt.sessions_recharge s
     JOIN urbanwatt.vehicules v ON v.id_vehicule = s.id_vehicule
    WHERE s.energie_kwh > v.capacite_batterie_kwh)
UNION ALL SELECT 33, '3. Métier', 'Énergie > puissance de la borne × durée (physiquement impossible)',
  (SELECT count(*) FROM urbanwatt.sessions_recharge s
     JOIN urbanwatt.bornes b ON b.id_borne = s.id_borne
    WHERE s.energie_kwh > b.puissance_kw * extract(epoch FROM s.fin_session - s.debut_session) / 3600)
UNION ALL SELECT 34, '3. Métier', 'Borne Type2 (courant alternatif) annoncée à plus de 43 kW',
  (SELECT count(*) FROM urbanwatt.bornes WHERE connecteur = 'Type2' AND puissance_kw > 43)
UNION ALL SELECT 35, '3. Métier', 'Code borne qui ne correspond pas à la ville de sa station',
  (SELECT count(*) FROM urbanwatt.bornes b
     JOIN urbanwatt.stations st ON st.id_station = b.id_station
    WHERE split_part(b.code_borne, '-', 2) <> split_part(st.code_station, '-', 2))
UNION ALL SELECT 36, '3. Métier', 'Paiement pour une session non terminee',
  (SELECT count(*) FROM urbanwatt.paiements p
     JOIN urbanwatt.sessions_recharge s ON s.id_session = p.id_session
    WHERE s.statut <> 'terminee')
UNION ALL SELECT 37, '3. Métier', 'Session terminee sans paiement',
  (SELECT count(*) FROM urbanwatt.sessions_recharge s
    WHERE s.statut = 'terminee'
      AND NOT EXISTS (SELECT 1 FROM urbanwatt.paiements p WHERE p.id_session = s.id_session))
UNION ALL SELECT 38, '3. Métier', 'Montant payé différent du coût de la session',
  (SELECT count(*) FROM urbanwatt.paiements p
     JOIN urbanwatt.sessions_recharge s ON s.id_session = p.id_session
    WHERE p.montant_eur <> s.cout_eur)
UNION ALL SELECT 39, '3. Métier', 'Incident resolu sans date de résolution (ou ouvert avec)',
  (SELECT count(*) FROM urbanwatt.incidents
    WHERE (statut = 'resolu' AND date_resolution IS NULL)
       OR (statut = 'ouvert' AND date_resolution IS NOT NULL))
UNION ALL SELECT 40, '3. Métier', 'Intervention terminee sans date de fin (ou en_cours avec)',
  (SELECT count(*) FROM urbanwatt.interventions
    WHERE (statut = 'terminee' AND date_fin IS NULL)
       OR (statut = 'en_cours' AND date_fin IS NOT NULL))

-- ---------------------------------------------------------------------
-- 4. Chevauchements : une ressource utilisée deux fois en même temps
-- ---------------------------------------------------------------------
UNION ALL SELECT 50, '4. Chevauchement', 'Session qui commence sur une borne encore occupée',
  (SELECT count(*) FROM (
     SELECT id_session, id_borne, id_vehicule, debut_session, fin_session,
            max(fin_session) OVER (PARTITION BY id_borne ORDER BY debut_session, id_session
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS fin_precedente
       FROM urbanwatt.sessions_recharge
      WHERE fin_session IS NOT NULL) w
    WHERE debut_session < fin_precedente)
UNION ALL SELECT 51, '4. Chevauchement', 'Véhicule qui commence une session alors qu''il est déjà en charge',
  (SELECT count(*) FROM (
     SELECT id_session, id_borne, id_vehicule, debut_session, fin_session,
            max(fin_session) OVER (PARTITION BY id_vehicule ORDER BY debut_session, id_session
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS fin_precedente
       FROM urbanwatt.sessions_recharge
      WHERE fin_session IS NOT NULL) w
    WHERE debut_session < fin_precedente)

-- ---------------------------------------------------------------------
-- 5. Doublons métier (non protégés par une contrainte UNIQUE)
-- ---------------------------------------------------------------------
UNION ALL SELECT 60, '5. Doublons', 'Clients partageant le même email',
  (SELECT coalesce(sum(n), 0) FROM (SELECT count(*) n FROM urbanwatt.clients
                                     GROUP BY lower(email) HAVING count(*) > 1) d)
UNION ALL SELECT 61, '5. Doublons', 'Techniciens partageant le même email',
  (SELECT coalesce(sum(n), 0) FROM (SELECT count(*) n FROM urbanwatt.techniciens
                                     GROUP BY lower(email) HAVING count(*) > 1) d)
)
SELECT num, niveau, regle, nb_anomalies,
       CASE WHEN nb_anomalies = 0 THEN 'OK' ELSE 'ANOMALIE' END AS verdict
FROM controles
ORDER BY num;
