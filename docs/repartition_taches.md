# Répartition des tâches — Projet BDD UrbanWatt

## Équipe

| Membre | Rôle |
|---|---|
| Pierre Paquet-Deom | Dev |
| Alexis Alzaga | Dev |


---

## Tâches

### T01 · Valider le MCD
- **Responsable :** Pierre
- **Statut :** Terminé
- **Pour le :** 17/11
- **Détails :** relire les 8 associations et trancher 0,n ou 0,1 pour RÉGLER et TRAITER selon l'énoncé.
- [x] Relire les cardinalités
- [x] Exporter le schéma pour le rapport

### T02 · Rédiger le MLD
- **Responsable :** Pierre
- **Statut :** Terminé
- **Pour le :** 17/11
- **Détails :** écrire le schéma relationnel (identifiants soulignés, clés étrangères avec #).
- [x] Écrire les 9 relations
- [x] Vérifier la cohérence avec le MCD

### T03 · Créer les tables
- **Responsable :** Pierre
- **Statut :** Terminé <!-- À faire · En cours · Bloqué · Terminé -->
- **Pour le :** 12/11
- **Détails :** CREATE TABLE des 9 tables avec clés primaires, clés étrangères et contraintes.
- [x] Écrire le script
- [x] L'exécuter sur PostgreSQL (Docker)

### T04 · Importer les données CSV
- **Responsable :** Pierre
- **Statut :** En cours
- **Pour le :** 17/11
- **Détails :** charger les 9 CSV dans l'ordre parents → enfants en utilisant l'interface graphique de pgadmin.
- [x] importer les 9 fichiers csv dans pgadmin
- [x] créer les tables dans l'ordre
- [x] vérifier le nombre de lignes
- [x] créer au moins deux index

### T05 · Écrire les requêtes SQL
- **Responsable :** Alexis
- **Statut :** En cours <!-- À faire · En cours · Bloqué · Terminé -->
- **Pour le :** JJ/MM
- **Détails :** requêtes demandées par l'énoncé (jointures, agrégats, sous-requêtes…).
- [x] 1-15 : requêtes obligatoire
- [x] 16-24 : 5 questions au choix a traiter obligatoirement
- [x] 25-31 : Facultatif => approfondissement

### T06 · Vérifier l'intégrité des données
- **Responsable :** Pierre
- **Statut :** À faire <!-- À faire · En cours · Bloqué · Terminé -->
- **Pour le :** JJ/MM
- **Détails :** contrôler les comptes, les valeurs NULL et les dates incohérentes.
- [ ] Comptes par table
- [ ] Sessions annulées sans paiement

### T07 · Vérifier l'intégrité des données
- **Responsable :** Pierre
- **Statut :** À faire <!-- À faire · En cours · Bloqué · Terminé -->
- **Pour le :** JJ/MM
- **Détails :** contrôler les comptes, les valeurs NULL et les dates incohérentes.
- [ ] Comptes par table
- [ ] Sessions annulées sans paiement

### T08 · Sécurités et Sauvegardes
- **Responsable :** Alexis
- **Statut :** À faire <!-- À faire · En cours · Bloqué · Terminé -->
- **Pour le :** JJ/MM
- **Détails :** Les secrets restent hors de Git et vous fournissez un .env.example . Faire une sauvegarde avec pg_dump , la
restaurer dans une base de test séparée, puis comparer le nombre de lignes avant et après.
- [ ] Comptes par table
- [ ] Sessions annulées sans paiement

### T09 · Rédiger le rapport
- **Responsable :** Pierre, ALexis ?
- **Statut :** À faire <!-- À faire · En cours · Bloqué · Terminé -->
- **Pour le :** JJ/MM
- **Détails :** présenter le MCD, le MLD, les choix de conception et les requêtes.
- [ ] Plan
- [ ] Relecture

### T10 · Préparer la soutenance
- **Responsable :** Pierre, Alexis
- **Statut :** À faire <!-- À faire · En cours · Bloqué · Terminé -->
- **Pour le :** JJ/MM
- **Détails :** support de présentation et démo des requêtes.
- [ ] Slides
- [ ] Répétition
