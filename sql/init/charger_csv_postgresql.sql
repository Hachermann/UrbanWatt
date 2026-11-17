-- ordre des imports : parents puis enfant -> technicien, station, clients,
-- bornes, vehicules, incidents, sessions_recharge, paiements, interventions

-- fichier example car les imports se sont fait via l'interface graphique de pgadmin

COPY clients(id_client, prenom, nom, email, ville, date_inscription) FROM 'clients.csv' DELIMITER ';' CSV HEADER;
COPY vehicules(id_vehicule, id_client, immatriculation, marque, modele, capacite_batterie_kwh) FROM 'vehicules.csv' DELIMITER ';' CSV HEADER;
COPY techniciens(id_technicien, prenom, nom, email) FROM 'techniciens.csv' DELIMITER ';' CSV HEADER;
COPY stations(id_station, code_station, nom_station, ville, adresse, date_ouverture) FROM 'stations.csv' DELIMITER ';' CSV HEADER;
COPY bornes(id_borne, id_station, code_borne, puissance_kw, connecteur, etat) FROM 'bornes.csv' DELIMITER ';' CSV HEADER;
COPY incidents(id_incident, id_borne, date_signalement, date_resolution, categorie, gravite, statut, description) FROM 'incidents.csv' DELIMITER ';' CSV HEADER;
COPY interventions(id_intervention, id_incident, id_technicien, date_debut, date_fin, statut, compte_rendu) FROM 'interventions.csv' DELIMITER ';' CSV HEADER;
COPY sessions_recharge(id_session, id_borne, id_vehicule, debut_session, fin_session, energie_kwh, cout_eur, statut) FROM 'sessions_recharge.csv' DELIMITER ';' CSV HEADER;
COPY paiements(id_paiement, id_session, date_paiement, montant_eur, mode_paiement, statut) FROM 'paiements.csv' DELIMITER ';' CSV HEADER;

SELECT 'stations' AS table_name, COUNT(*) AS nb FROM stations
UNION ALL SELECT 'bornes' AS table_name, COUNT(*) AS nb FROM bornes
UNION ALL SELECT 'clients' AS table_name, COUNT(*) AS nb FROM clients
UNION ALL SELECT 'vehicules' AS table_name, COUNT(*) AS nb FROM vehicules
UNION ALL SELECT 'sessions_recharge' AS table_name, COUNT(*) AS nb FROM sessions_recharge
UNION ALL SELECT 'paiements' AS table_name, COUNT(*) AS nb FROM paiements
UNION ALL SELECT 'techniciens' AS table_name, COUNT(*) AS nb FROM techniciens
UNION ALL SELECT 'incidents' AS table_name, COUNT(*) AS nb FROM incidents
UNION ALL SELECT 'interventions' AS table_name, COUNT(*) AS nb FROM interventions;
