-- Question 1 à 15 : 

-- Question 1 : 
-- Afficher les clients ayant réalisé au moins une session de recharge
-- dans la station ST-LIL, sans doublon, avec leur nom et leur prénom 

SELECT DISTINCT prenom, nom, stations.code_station
	FROM "Urbanwatt".clients
Join "Urbanwatt".vehicules on "Urbanwatt".vehicules.id_client = "Urbanwatt".clients.id_client 	
Join "Urbanwatt".sessions_recharge on "Urbanwatt".sessions_recharge.id_vehicule = "Urbanwatt".vehicules.id_vehicule
Join "Urbanwatt".bornes on "Urbanwatt".bornes.id_borne = "Urbanwatt".sessions_recharge.id_borne
Join "Urbanwatt".stations on "Urbanwatt".stations.id_station = "Urbanwatt".bornes.id_station
Where stations.code_station = 'ST-LIL';

-- Question 2 : 
-- Lister toutes les bornes de la station ST-TOU, avec leur code, leur
-- puissance, leur type de connecteur et leur état, triées par puissance
-- décroissante

SELECT DISTINCT stations.code_station, bornes.code_borne, bornes.puissance_kw, bornes.connecteur, bornes.etat
	FROM "Urbanwatt".bornes
Join "Urbanwatt".stations on "Urbanwatt".stations.id_station = "Urbanwatt".bornes.id_station
Where stations.code_station LIKE 'ST-TOU%'
ORDER BY bornes.puissance_kw DESC;

-- Question 3 : 
-- Afficher l’historique des sessions du véhicule ESSAI-0001 : dates,
-- borne utilisée, énergie, coût et statut, de la plus récente à la plus
-- ancienne 

SELECT vehicules.immatriculation, sessions_recharge.debut_session, sessions_recharge.fin_session, code_borne as borne_utilisee, sessions_recharge.energie_kwh, cout_eur, sessions_recharge.statut
	FROM "Urbanwatt".sessions_recharge
Join "Urbanwatt".vehicules on "Urbanwatt".vehicules.id_vehicule = "Urbanwatt".sessions_recharge.id_vehicule
Join "Urbanwatt".bornes on "Urbanwatt".bornes.id_borne = "Urbanwatt".sessions_recharge.id_borne
Where vehicules.immatriculation = 'ESSAI-0001'
ORDER BY sessions_recharge.debut_session DESC;

-- Question 4 : 
-- Lister les clients n’ayant jamais eu de session annulée ou
-- interrompue, y compris ceux qui n’ont effectué aucune recharge
