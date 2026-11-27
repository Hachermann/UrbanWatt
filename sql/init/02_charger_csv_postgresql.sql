-- =====================================================================
-- 02 - Chargement des 9 fichiers CSV
--
-- Exécuté automatiquement par Docker au premier démarrage, après
-- 01_UrbanWatt.sql. Les CSV du dossier sql/data sont montés dans le
-- conteneur sous /data (voir infra/docker-compose.yaml).
--
-- Ordre des imports : tables parentes puis tables enfants, à cause des
-- clés étrangères.
-- =====================================================================

SET search_path TO urbanwatt;

COPY techniciens (id_technicien, prenom, nom, email)
    FROM '/data/techniciens.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

COPY stations (id_station, code_station, nom_station, ville, adresse, date_ouverture)
    FROM '/data/stations.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

COPY clients (id_client, prenom, nom, email, ville, date_inscription)
    FROM '/data/clients.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

COPY bornes (id_borne, id_station, code_borne, puissance_kw, connecteur, etat)
    FROM '/data/bornes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

COPY vehicules (id_vehicule, id_client, immatriculation, marque, modele, capacite_batterie_kwh)
    FROM '/data/vehicules.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

COPY incidents (id_incident, id_borne, date_signalement, date_resolution, categorie, gravite, statut, description)
    FROM '/data/incidents.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

COPY sessions_recharge (id_session, id_borne, id_vehicule, debut_session, fin_session, energie_kwh, cout_eur, statut)
    FROM '/data/sessions_recharge.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

COPY paiements (id_paiement, id_session, date_paiement, montant_eur, mode_paiement, statut)
    FROM '/data/paiements.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

COPY interventions (id_intervention, id_incident, id_technicien, date_debut, date_fin, statut, compte_rendu)
    FROM '/data/interventions.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

-- Les CSV fournissent les identifiants : les compteurs des colonnes
-- IDENTITY sont restés à 1. On les recale sur le plus grand identifiant,
-- sinon le prochain INSERT sans identifiant échouerait (clé déjà prise).
SELECT setval(pg_get_serial_sequence('urbanwatt.techniciens',       'id_technicien'),   (SELECT MAX(id_technicien)   FROM techniciens));
SELECT setval(pg_get_serial_sequence('urbanwatt.stations',          'id_station'),      (SELECT MAX(id_station)      FROM stations));
SELECT setval(pg_get_serial_sequence('urbanwatt.clients',           'id_client'),       (SELECT MAX(id_client)       FROM clients));
SELECT setval(pg_get_serial_sequence('urbanwatt.bornes',            'id_borne'),        (SELECT MAX(id_borne)        FROM bornes));
SELECT setval(pg_get_serial_sequence('urbanwatt.vehicules',         'id_vehicule'),     (SELECT MAX(id_vehicule)     FROM vehicules));
SELECT setval(pg_get_serial_sequence('urbanwatt.incidents',         'id_incident'),     (SELECT MAX(id_incident)     FROM incidents));
SELECT setval(pg_get_serial_sequence('urbanwatt.sessions_recharge', 'id_session'),      (SELECT MAX(id_session)      FROM sessions_recharge));
SELECT setval(pg_get_serial_sequence('urbanwatt.paiements',         'id_paiement'),     (SELECT MAX(id_paiement)     FROM paiements));
SELECT setval(pg_get_serial_sequence('urbanwatt.interventions',     'id_intervention'), (SELECT MAX(id_intervention) FROM interventions));

-- Vérification : nombre de lignes par table
-- (visible avec : docker compose logs postgres)
SELECT 'stations' AS table_name, COUNT(*) AS nb FROM stations
UNION ALL SELECT 'bornes',            COUNT(*) FROM bornes
UNION ALL SELECT 'clients',           COUNT(*) FROM clients
UNION ALL SELECT 'vehicules',         COUNT(*) FROM vehicules
UNION ALL SELECT 'sessions_recharge', COUNT(*) FROM sessions_recharge
UNION ALL SELECT 'paiements',         COUNT(*) FROM paiements
UNION ALL SELECT 'techniciens',       COUNT(*) FROM techniciens
UNION ALL SELECT 'incidents',         COUNT(*) FROM incidents
UNION ALL SELECT 'interventions',     COUNT(*) FROM interventions;
