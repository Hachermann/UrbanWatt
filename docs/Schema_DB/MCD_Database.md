# MCD du réseau de bornes de recharge

Modèle conceptuel (Merise) déduit des 9 tables : 9 entités et 8 associations binaires, toutes de type 1,1 – 0,n ou 1,1 – 1,n. Les cardinalités sont vérifiées sur les données.

Une cardinalité se lit du côté de l'entité : le « 0,n » près de CLIENT signifie qu'un client participe de 0 à n fois à POSSÉDER, donc qu'il possède de 0 à n véhicules. Sur petit écran, le schéma défile horizontalement.

## Règles de gestion : chaque cardinalité justifiée

| Association | Règle | Dans les données |
| --- | --- | --- |
| POSSÉDER | Un client possède de 0 à n véhicules ; un véhicule appartient à un seul client. | 4 479 clients sans véhicule, 7 au maximum |
| EFFECTUER | Un véhicule effectue de 0 à n sessions ; une session est effectuée par un seul véhicule. | 1 véhicule sans session, 39 au maximum |
| ACCUEILLIR | Une borne accueille de 0 à n sessions ; une session a lieu sur une seule borne. | De 246 à 605 sessions par borne |
| RÉGLER | Une session est réglée par 0 à n paiements ; un paiement règle une seule session. | 32 700 sessions sans paiement (annulées ou interrompues), jamais plus d'un |
| COMPORTER | Une station comporte de 1 à n bornes ; une borne appartient à une seule station. | 5 bornes dans chaque station |
| CONCERNER | Une borne connaît de 0 à n incidents ; un incident concerne une seule borne. | De 1 à 18 incidents par borne |
| TRAITER | Un incident est traité par 0 à n interventions ; une intervention traite un seul incident. | 838 incidents sans intervention, jamais plus d'une |
| RÉALISER | Un technicien réalise de 0 à n interventions ; une intervention est réalisée par un seul technicien. | De 22 à 52 interventions par technicien |

**À valider selon ton sujet :** pour RÉGLER et TRAITER, les données ne montrent jamais plus d'un paiement par session ni plus d'une intervention par incident. J'ai gardé 0,n pour permettre un nouveau paiement après un refus, ou une seconde intervention. Si ta règle dit « au plus un », mets 0,1 : le MLD reste le même, avec une contrainte d'unicité sur la clé étrangère.

SESSION_RECHARGE et INTERVENTION sont des entités, pas des associations porteuses : elles ont leur propre identifiant, et PAIEMENT dépend de SESSION_RECHARGE.

## Passage au MLD : on retrouve les 9 tables

Chaque association disparaît : l'identifiant de l'entité côté 0,n ou 1,n devient une clé étrangère (#) dans l'entité côté 1,1.

- **STATION** (id_station, code_station, nom_station, ville, adresse, date_ouverture)
- **BORNE** (id_borne, code_borne, puissance_kw, connecteur, etat, #id_station)
- **CLIENT** (id_client, prenom, nom, email, ville, date_inscription)
- **VEHICULE** (id_vehicule, immatriculation, marque, modele, capacite_batterie_kwh, #id_client)
- **SESSION_RECHARGE** (id_session, debut_session, fin_session, energie_kwh, cout_eur, statut, #id_borne, #id_vehicule)
- **PAIEMENT** (id_paiement, date_paiement, montant_eur, mode_paiement, statut, #id_session)
- **TECHNICIEN** (id_technicien, prenom, nom, email)
- **INCIDENT** (id_incident, date_signalement, date_resolution, categorie, gravite, statut, description, #id_borne)
- **INTERVENTION** (id_intervention, date_debut, date_fin, statut, compte_rendu, #id_incident, #id_technicien)

Identifiant souligné, clé étrangère précédée de #.