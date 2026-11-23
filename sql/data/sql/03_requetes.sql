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
SELECT clients.id_client, prenom, nom
FROM "Urbanwatt".clients 
WHERE clients.id_client NOT IN (
    SELECT DISTINCT vehicules.id_client
    FROM "Urbanwatt".vehicules 
    JOIN "Urbanwatt".sessions_recharge ON sessions_recharge.id_vehicule = vehicules.id_vehicule
    WHERE sessions_recharge.statut = 'interrompue' 
	or sessions_recharge.statut = 'annulee'
)
ORDER BY clients.id_client;

-- Question 5 : 
-- Afficher les sessions terminées dans la station ST-LYO, triées par
-- énergie délivrée de la plus élevée à la plus faible.

SET search_path TO "Urbanwatt";

SELECT id_session, energie_kwh, sessions_recharge.statut, code_station from sessions_recharge
join bornes on bornes.id_borne = sessions_recharge.id_borne
Join stations on stations.id_station = bornes.id_station 
where stations.code_station = 'ST-LYO' 
AND sessions_recharge.statut = 'terminee'
ORDER BY energie_kwh DESC; 

-- Question 6
-- Présenter, pour le client n° 10, toutes ses sessions avec le véhicule
-- concerné, la station, la date et le statut.
SET search_path TO "Urbanwatt"; 

select clients.id_client, prenom, nom, immatriculation, sessions_recharge.id_session, stations.code_station,
sessions_recharge.debut_session, sessions_recharge.fin_session, sessions_recharge.statut
from clients
join vehicules on vehicules.id_client = clients.id_client
join sessions_recharge on sessions_recharge.id_vehicule = vehicules.id_vehicule
join bornes on bornes.id_borne = sessions_recharge.id_borne 
join stations on stations.id_station = bornes.id_station 

where clients.id_client = 10

-- Question 7
--  Lister les incidents de gravité haute avec le code de la borne, la
-- station, la catégorie, la date de signalement et l’état de résolution.


SET search_path TO "Urbanwatt";

-- Valeurs utilisées dans les données :
--   sessions_recharge.statut : terminee | interrompue | annulee
--   paiements.statut         : accepte | refuse | en_attente
--   incidents.gravite        : faible | moyenne | haute
--   incidents.statut         : ouvert | resolu
--   interventions.statut     : terminee | en_cours
--   bornes.etat              : disponible | maintenance | hors_service



SELECT i.id_incident,
       b.code_borne,
       st.code_station,
       st.nom_station,
       i.categorie,
       i.date_signalement,
       i.statut          AS etat_resolution,
       i.date_resolution
FROM incidents i
JOIN bornes b    ON b.id_borne = i.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE i.gravite = 'haute'
ORDER BY i.date_signalement;


-- Question 8 :
-- Afficher tous les incidents associés à ST-BOR, classés par date
-- décroissante, en indiquant les interventions éventuelles.
-- LEFT JOIN : les incidents sans intervention restent dans le résultat.

SELECT i.id_incident,
       b.code_borne,
       i.date_signalement,
       i.categorie,
       i.gravite,
       i.statut          AS statut_incident,
       it.id_intervention,
       t.prenom || ' ' || t.nom AS technicien,
       it.date_debut,
       it.date_fin,
       it.statut         AS statut_intervention
FROM incidents i
JOIN bornes b    ON b.id_borne = i.id_borne
JOIN stations st ON st.id_station = b.id_station
LEFT JOIN interventions it ON it.id_incident = i.id_incident
LEFT JOIN techniciens t    ON t.id_technicien = it.id_technicien
WHERE st.code_station = 'ST-BOR'
ORDER BY i.date_signalement DESC;


-- Question 9 :
-- Lister les sessions annulées ou interrompues dans ST-NAN, avec le
-- véhicule, la date et le statut.

SELECT s.id_session,
       v.immatriculation,
       v.marque,
       v.modele,
       b.code_borne,
       s.debut_session,
       s.statut
FROM sessions_recharge s
JOIN vehicules v ON v.id_vehicule = s.id_vehicule
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE st.code_station = 'ST-NAN'
  AND s.statut IN ('annulee', 'interrompue')
ORDER BY s.debut_session;


-- Question 10 :
-- Afficher les clients ayant réalisé au moins une session terminée de
-- plus de 30 kWh, sans doublon.
-- EXISTS évite les doublons sans avoir besoin de DISTINCT.

SELECT c.id_client, c.prenom, c.nom
FROM clients c
WHERE EXISTS (
    SELECT 1
    FROM vehicules v
    JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
    WHERE v.id_client = c.id_client
      AND s.statut = 'terminee'
      AND s.energie_kwh > 30
)
ORDER BY c.id_client;


-- Question 11 :
-- Calculer le nombre de bornes disponibles, en maintenance et hors
-- service pour chaque station.

SELECT st.code_station,
       st.nom_station,
       COUNT(b.id_borne) FILTER (WHERE b.etat = 'disponible')   AS nb_disponibles,
       COUNT(b.id_borne) FILTER (WHERE b.etat = 'maintenance')  AS nb_maintenance,
       COUNT(b.id_borne) FILTER (WHERE b.etat = 'hors_service') AS nb_hors_service
FROM stations st
LEFT JOIN bornes b ON b.id_station = st.id_station
GROUP BY st.id_station, st.code_station, st.nom_station
ORDER BY st.code_station;


-- Question 12 :
-- Trouver, pour la station ST-LIL, la ou les sessions terminées dont
-- l'énergie délivrée est maximale (les ex aequo sont tous affichés).

SELECT s.id_session, b.code_borne, s.debut_session, s.energie_kwh
FROM sessions_recharge s
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE st.code_station = 'ST-LIL'
  AND s.statut = 'terminee'
  AND s.energie_kwh = (
        SELECT MAX(s2.energie_kwh)
        FROM sessions_recharge s2
        JOIN bornes b2    ON b2.id_borne = s2.id_borne
        JOIN stations st2 ON st2.id_station = b2.id_station
        WHERE st2.code_station = 'ST-LIL'
          AND s2.statut = 'terminee'
  );


-- Question 13 :
-- Afficher le nombre de véhicules distincts ayant réalisé au moins une
-- session terminée dans chaque station.
-- La condition sur le statut est dans le ON pour garder les stations à 0.

SELECT st.code_station,
       st.nom_station,
       COUNT(DISTINCT s.id_vehicule) AS nb_vehicules_distincts
FROM stations st
LEFT JOIN bornes b ON b.id_station = st.id_station
LEFT JOIN sessions_recharge s ON s.id_borne = b.id_borne
                             AND s.statut = 'terminee'
GROUP BY st.id_station, st.code_station, st.nom_station
ORDER BY nb_vehicules_distincts DESC, st.code_station;


-- Question 14 :
-- Calculer l'énergie moyenne délivrée par véhicule sur ses sessions
-- terminées, en conservant ceux sans recharge.
-- LEFT JOIN + condition dans le ON : un véhicule sans session terminée
-- apparaît avec 0 session et une moyenne NULL.

SELECT v.id_vehicule,
       v.immatriculation,
       COUNT(s.id_session)          AS nb_sessions_terminees,
       ROUND(AVG(s.energie_kwh), 2) AS energie_moyenne_kwh
FROM vehicules v
LEFT JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
                             AND s.statut = 'terminee'
GROUP BY v.id_vehicule, v.immatriculation
ORDER BY v.id_vehicule;


-- Question 15 :
-- Afficher pour chaque station sa plus grande énergie délivrée en une
-- session terminée et la borne associée.
-- RANK() garde toutes les bornes en cas d'égalité.

WITH classement AS (
    SELECT st.code_station,
           st.nom_station,
           b.code_borne,
           s.id_session,
           s.energie_kwh,
           RANK() OVER (PARTITION BY st.id_station
                        ORDER BY s.energie_kwh DESC) AS rang
    FROM sessions_recharge s
    JOIN bornes b    ON b.id_borne = s.id_borne
    JOIN stations st ON st.id_station = b.id_station
    WHERE s.statut = 'terminee'
)
SELECT code_station, nom_station, energie_kwh AS energie_max_kwh,
       code_borne, id_session
FROM classement
WHERE rang = 1
ORDER BY code_station;


-- Question 16 :
-- Présenter toutes les sessions de ESSAI-0007 avec la ville, la station,
-- la borne et la date par ordre chronologique.
-- Égalité stricte : LIKE 'ESSAI-0007%' ramènerait aussi ESSAI-0007000, etc.

SELECT s.id_session,
       st.ville,
       st.code_station,
       st.nom_station,
       b.code_borne,
       s.debut_session,
       s.fin_session,
       s.statut
FROM sessions_recharge s
JOIN vehicules v ON v.id_vehicule = s.id_vehicule
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE v.immatriculation = 'ESSAI-0007'
ORDER BY s.debut_session;


-- Question 17 :
-- Afficher les propriétaires et les véhicules ayant utilisé au moins une
-- fois la borne BR-NAN-01.

SELECT DISTINCT c.id_client,
       c.prenom,
       c.nom,
       v.immatriculation,
       v.marque,
       v.modele
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
JOIN bornes b            ON b.id_borne = s.id_borne
WHERE b.code_borne = 'BR-NAN-01'
ORDER BY c.id_client, v.immatriculation;


-- Question 18 :
-- Lister les bornes ayant connu au moins deux incidents, avec le nombre
-- d'incidents et la date du plus récent.

SELECT b.code_borne,
       st.code_station,
       COUNT(i.id_incident)    AS nb_incidents,
       MAX(i.date_signalement) AS dernier_incident
FROM bornes b
JOIN stations st  ON st.id_station = b.id_station
JOIN incidents i  ON i.id_borne = b.id_borne
GROUP BY b.id_borne, b.code_borne, st.code_station
HAVING COUNT(i.id_incident) >= 2
ORDER BY nb_incidents DESC, dernier_incident DESC;


-- Question 19 :
-- Trouver les clients ayant effectué au moins une session terminée dans
-- chacune des stations du réseau (division relationnelle).
-- Un client est retenu si son nombre de stations distinctes visitées est
-- égal au nombre total de stations.

SELECT c.id_client, c.prenom, c.nom
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
JOIN bornes b            ON b.id_borne = s.id_borne
WHERE s.statut = 'terminee'
GROUP BY c.id_client, c.prenom, c.nom
HAVING COUNT(DISTINCT b.id_station) = (SELECT COUNT(*) FROM stations)
ORDER BY c.id_client;


-- Question 20 :
-- Établir le classement des clients selon l'énergie consommée : client,
-- nombre de sessions, énergie et rang.
-- Énergie consommée = sessions terminées (celles qui sont facturées).
-- Pour inclure aussi l'énergie des sessions interrompues, remplacer la
-- condition du WHERE par : s.statut IN ('terminee', 'interrompue').

SELECT c.id_client,
       c.prenom,
       c.nom,
       COUNT(s.id_session)  AS nb_sessions,
       SUM(s.energie_kwh)   AS energie_totale_kwh,
       RANK() OVER (ORDER BY SUM(s.energie_kwh) DESC) AS rang
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
WHERE s.statut = 'terminee'
GROUP BY c.id_client, c.prenom, c.nom
ORDER BY rang;


-- Question 21 :
-- Afficher les clients ayant subi au moins deux sessions interrompues,
-- avec le nombre total de ces interruptions.

SELECT c.id_client,
       c.prenom,
       c.nom,
       COUNT(s.id_session) AS nb_interruptions
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
WHERE s.statut = 'interrompue'
GROUP BY c.id_client, c.prenom, c.nom
HAVING COUNT(s.id_session) >= 2
ORDER BY nb_interruptions DESC, c.id_client;


-- Question 22 :
-- Calculer, pour chaque station, le chiffre d'affaires encaissé à partir
-- des seuls paiements acceptés, par ordre décroissant.
-- Les conditions sont dans les ON pour garder les stations sans CA (0).

SELECT st.code_station,
       st.nom_station,
       COALESCE(SUM(p.montant_eur), 0) AS chiffre_affaires_eur
FROM stations st
LEFT JOIN bornes b            ON b.id_station = st.id_station
LEFT JOIN sessions_recharge s ON s.id_borne = b.id_borne
LEFT JOIN paiements p         ON p.id_session = s.id_session
                             AND p.statut = 'accepte'
GROUP BY st.id_station, st.code_station, st.nom_station
ORDER BY chiffre_affaires_eur DESC;


-- Question 23 :
-- Vérifier par une requête renvoyant vrai/faux si ESSAI-0007 a déjà
-- terminé une session dans la station ST-BOR.

SELECT EXISTS (
    SELECT 1
    FROM sessions_recharge s
    JOIN vehicules v ON v.id_vehicule = s.id_vehicule
    JOIN bornes b    ON b.id_borne = s.id_borne
    JOIN stations st ON st.id_station = b.id_station
    WHERE v.immatriculation = 'ESSAI-0007'
      AND st.code_station = 'ST-BOR'
      AND s.statut = 'terminee'
) AS a_termine_une_session_st_bor;


-- Question 24 :
-- Lister les 10 sessions ayant donné lieu aux montants de paiement
-- accepté les plus élevés, avec client, véhicule et station.

SELECT s.id_session,
       p.montant_eur,
       c.prenom || ' ' || c.nom AS client,
       v.immatriculation,
       st.code_station,
       st.nom_station
FROM paiements p
JOIN sessions_recharge s ON s.id_session = p.id_session
JOIN vehicules v         ON v.id_vehicule = s.id_vehicule
JOIN clients c           ON c.id_client = v.id_client
JOIN bornes b            ON b.id_borne = s.id_borne
JOIN stations st         ON st.id_station = b.id_station
WHERE p.statut = 'accepte'
ORDER BY p.montant_eur DESC
LIMIT 10;


-- Question 25 :
-- Lister toutes les bornes n'ayant jamais eu d'incident signalé, y
-- compris celles qui ont enregistré des recharges.
-- Le filtre porte uniquement sur les incidents ; le nombre de sessions
-- est affiché pour montrer que les bornes utilisées sont bien incluses.

SELECT b.code_borne,
       st.code_station,
       b.etat,
       (SELECT COUNT(*)
        FROM sessions_recharge s
        WHERE s.id_borne = b.id_borne) AS nb_sessions
FROM bornes b
JOIN stations st ON st.id_station = b.id_station
WHERE NOT EXISTS (
    SELECT 1 FROM incidents i WHERE i.id_borne = b.id_borne
)
ORDER BY b.code_borne;


-- Question 26 :
-- Pour chaque véhicule, afficher sa ou ses sessions terminées dont
-- l'énergie délivrée est la plus élevée.

WITH classement AS (
    SELECT v.id_vehicule,
           v.immatriculation,
           s.id_session,
           s.debut_session,
           s.energie_kwh,
           RANK() OVER (PARTITION BY s.id_vehicule
                        ORDER BY s.energie_kwh DESC) AS rang
    FROM sessions_recharge s
    JOIN vehicules v ON v.id_vehicule = s.id_vehicule
    WHERE s.statut = 'terminee'
)
SELECT immatriculation, id_session, debut_session, energie_kwh
FROM classement
WHERE rang = 1
ORDER BY id_vehicule;


-- Question 27 :
-- Afficher pour chaque station le nombre de bornes, la puissance totale
-- installée et l'énergie moyenne par session terminée, sans double
-- comptage.
-- Piège : joindre bornes et sessions puis faire SUM(puissance_kw)
-- additionnerait la puissance d'une borne autant de fois qu'elle a de
-- sessions. On calcule donc chaque agrégat séparément, puis on assemble.

WITH bornes_station AS (
    SELECT id_station,
           COUNT(*)          AS nb_bornes,
           SUM(puissance_kw) AS puissance_totale_kw
    FROM bornes
    GROUP BY id_station
),
energie_station AS (
    SELECT b.id_station,
           ROUND(AVG(s.energie_kwh), 2) AS energie_moyenne_kwh
    FROM sessions_recharge s
    JOIN bornes b ON b.id_borne = s.id_borne
    WHERE s.statut = 'terminee'
    GROUP BY b.id_station
)
SELECT st.code_station,
       st.nom_station,
       COALESCE(bs.nb_bornes, 0)           AS nb_bornes,
       COALESCE(bs.puissance_totale_kw, 0) AS puissance_totale_kw,
       es.energie_moyenne_kwh
FROM stations st
LEFT JOIN bornes_station bs  ON bs.id_station = st.id_station
LEFT JOIN energie_station es ON es.id_station = st.id_station
ORDER BY st.code_station;


-- Question 28 :
-- Lister les techniciens avec le nombre d'interventions terminées et la
-- durée totale passée en intervention, y compris ceux sans intervention
-- terminée.

SELECT t.id_technicien,
       t.prenom,
       t.nom,
       COUNT(it.id_intervention) AS nb_interventions_terminees,
       COALESCE(SUM(it.date_fin - it.date_debut), INTERVAL '0') AS duree_totale,
       ROUND(COALESCE(EXTRACT(EPOCH FROM SUM(it.date_fin - it.date_debut)), 0)
             / 3600, 1) AS duree_totale_heures
FROM techniciens t
LEFT JOIN interventions it ON it.id_technicien = t.id_technicien
                          AND it.statut = 'terminee'
GROUP BY t.id_technicien, t.prenom, t.nom
ORDER BY nb_interventions_terminees DESC, t.id_technicien;


-- Question 29 :
-- Trouver le ou les jours ayant enregistré le plus grand nombre de
-- sessions terminées sur l'ensemble du réseau.

WITH par_jour AS (
    SELECT CAST(debut_session AS date) AS jour,
           COUNT(*)                    AS nb_sessions_terminees
    FROM sessions_recharge
    WHERE statut = 'terminee'
    GROUP BY CAST(debut_session AS date)
)
SELECT jour, nb_sessions_terminees
FROM par_jour
WHERE nb_sessions_terminees = (SELECT MAX(nb_sessions_terminees) FROM par_jour)
ORDER BY jour;


-- Question 30 :
-- Afficher les cinq bornes présentant le plus grand nombre de sessions
-- interrompues, avec leur nombre total de sessions et leur taux
-- d'interruption.

SELECT b.code_borne,
       st.code_station,
       COUNT(*) FILTER (WHERE s.statut = 'interrompue') AS nb_interrompues,
       COUNT(*)                                         AS nb_sessions_total,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.statut = 'interrompue')
             / COUNT(*), 2)                             AS taux_interruption_pct
FROM bornes b
JOIN stations st         ON st.id_station = b.id_station
JOIN sessions_recharge s ON s.id_borne = b.id_borne
GROUP BY b.id_borne, b.code_borne, st.code_station
ORDER BY nb_interrompues DESC, taux_interruption_pct DESC
LIMIT 5;


-- Question 31 :
-- Pour chaque véhicule, trouver les sessions terminées dont l'énergie
-- délivrée est supérieure à celle de sa session terminée précédente ;
-- afficher les deux valeurs et les deux dates.
-- LAG() récupère la session terminée précédente du même véhicule. Le
-- filtre sur 'terminee' est fait AVANT la fonction de fenêtre, pour que
-- la "précédente" soit bien une session terminée.

WITH terminees AS (
    SELECT s.id_vehicule,
           s.id_session,
           s.debut_session,
           s.energie_kwh,
           LAG(s.debut_session) OVER w AS debut_precedente,
           LAG(s.energie_kwh)   OVER w AS energie_precedente
    FROM sessions_recharge s
    WHERE s.statut = 'terminee'
    WINDOW w AS (PARTITION BY s.id_vehicule ORDER BY s.debut_session)
)
SELECT v.immatriculation,
       t.debut_precedente,
       t.energie_precedente,
       t.debut_session  AS debut_session,
       t.energie_kwh    AS energie_session
FROM terminees t
JOIN vehicules v ON v.id_vehicule = t.id_vehicule
WHERE t.energie_kwh > t.energie_precedente
ORDER BY v.id_vehicule, t.debut_session;