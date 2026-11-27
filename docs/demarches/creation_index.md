# Index de la base UrbanWatt

Ce document recense tous les index de la base `UrbanWatt` (schéma `urbanwatt`) et explique pourquoi chacun est présent.

- [Contexte](#contexte)
- [1. Index créés automatiquement](#1-index-créés-automatiquement)
- [2. Index ajoutés](#2-index-ajoutés)
- [3. Index volontairement non créés](#3-index-volontairement-non-créés)
- [4. Coût des index](#4-coût-des-index)
- [5. Vérification et suivi](#5-vérification-et-suivi)
- [6. Script de création](#6-script-de-création)

---

## Contexte

### Volumétrie

| Table               | Lignes  |
|---------------------|--------:|
| `sessions_recharge` | 250 000 |
| `paiements`         | 217 300 |
| `vehicules`         |  18 000 |
| `clients`           |  15 000 |
| `incidents`         |   5 000 |
| `interventions`     |   4 162 |
| `bornes`            |     600 |
| `stations`          |     120 |
| `techniciens`       |     120 |

Seules `sessions_recharge` et `paiements` sont volumineuses, et ce sont aussi elles qui grossissent : depuis avril 2026, environ **34 000 sessions** et **29 500 paiements** sont ajoutés chaque mois, soit environ 1 100 sessions par jour. Ce chiffre correspond au rythme observé dans le jeu de données du projet.

### Principe retenu

Sans index, PostgreSQL lit toute la table pour chaque recherche (*Seq Scan*), et ce temps augmente avec le volume. Avec un index B-tree, le temps de recherche reste quasiment constant.

Un index n'est créé que s'il remplit trois conditions :

1. il répond à une **requête métier identifiée** ;
2. il porte sur une **table volumineuse** ;
3. la requête ne garde qu'une **petite partie des lignes**, sinon PostgreSQL préfère lire toute la table.

Chaque index a en effet un coût : il occupe de l'espace disque et doit être mis à jour à chaque insertion.

---

## 1. Index créés automatiquement

PostgreSQL crée un index pour chaque clé primaire (`PRIMARY KEY`) et chaque contrainte d'unicité (`UNIQUE`) déclarée dans le schéma. **Ces index ne doivent jamais être supprimés**, même si leur compteur d'utilisation reste à 0. Ils garantissent l'intégrité des données.

### Clés primaires

| Index                     | Table               | Colonne           |
|---------------------------|---------------------|-------------------|
| `stations_pkey`           | `stations`          | `id_station`      |
| `bornes_pkey`             | `bornes`            | `id_borne`        |
| `clients_pkey`            | `clients`           | `id_client`       |
| `vehicules_pkey`          | `vehicules`         | `id_vehicule`     |
| `sessions_recharge_pkey`  | `sessions_recharge` | `id_session`      |
| `paiements_pkey`          | `paiements`         | `id_paiement`     |
| `incidents_pkey`          | `incidents`         | `id_incident`     |
| `techniciens_pkey`        | `techniciens`       | `id_technicien`   |
| `interventions_pkey`      | `interventions`     | `id_intervention` |

**Rôle :**
- garantir qu'un identifiant n'existe qu'une seule fois ;
- accélérer les jointures sur ces identifiants ;
- vérifier les clés étrangères à chaque insertion. Par exemple, insérer une session vérifie que la borne existe, grâce à `bornes_pkey`.

### Contraintes d'unicité

| Index                           | Table       | Colonne           | Rôle |
|---------------------------------|-------------|-------------------|------|
| `stations_code_station_key`     | `stations`  | `code_station`    | Une station a un code unique, et on peut la retrouver directement par ce code. |
| `bornes_code_borne_key`         | `bornes`    | `code_borne`      | Une borne a un code unique, et on peut la retrouver directement par ce code (identification sur le terrain). |
| `vehicules_immatriculation_key` | `vehicules` | `immatriculation` | Une immatriculation ne peut pas être enregistrée deux fois, et on peut retrouver un véhicule par sa plaque. |

---

## 2. Index ajoutés

### Synthèse

| # | Index | Table (colonnes) | Besoin couvert | Avant | Après |
|---|-------|------------------|----------------|------:|------:|
| 1 | `idx_sessions_vehicule_debut` | `sessions_recharge (id_vehicule, debut_session)` | Historique d'un véhicule | 15,7 ms | 0,13 ms |
| 2 | `idx_sessions_borne_debut` | `sessions_recharge (id_borne, debut_session)` | Activité d'une borne sur une période | 18,2 ms | 0,07 ms |
| 3 | `idx_sessions_debut` | `sessions_recharge (debut_session)` | Sessions d'une période (tableaux de bord) | 17,8 ms | 1,9 ms |
| 4 | `paiements_id_session_key` | `paiements (id_session)`, contrainte `UNIQUE` | Paiement d'une session et intégrité | 16,3 ms | 0,06 ms |
| 5 | `idx_vehicules_client` | `vehicules (id_client)` | Historique complet d'un client | 50,1 ms | 0,24 ms |
| 6 | `idx_paiements_en_attente` | `paiements (date_paiement)`, index partiel | Suivi des paiements en attente | 15,6 ms | 0,20 ms |

> Les temps ont été mesurés avec `EXPLAIN ANALYZE` (médiane de 5 exécutions) sur le jeu de données du projet. Ils sont indicatifs. Relancer `test_index_urbanwatt.sql` (voir [section 5](#5-vérification-et-suivi)) pour obtenir les valeurs sur votre instance.

### 1. `idx_sessions_vehicule_debut`

```sql
CREATE INDEX idx_sessions_vehicule_debut ON urbanwatt.sessions_recharge (id_vehicule, debut_session);
```

- **Besoin métier :** afficher l'historique des recharges d'un véhicule. C'est la requête la plus fréquente de l'application : elle sert à l'espace client et au support, par exemple quand un client conteste une facture.
- **Choix technique :**
  - `id_vehicule` est une clé étrangère, et PostgreSQL n'indexe jamais automatiquement les clés étrangères.
  - La colonne testée par égalité (`id_vehicule`) est placée en premier, la date en second. Le même index sert donc aussi au tri chronologique (`ORDER BY debut_session DESC`) et au filtrage par période, sans étape de tri supplémentaire.
  - L'index accélère aussi la vérification de la clé étrangère quand un véhicule est supprimé.
- **Gain :** sans index, PostgreSQL lisait 250 000 lignes pour en renvoyer 7.

### 2. `idx_sessions_borne_debut`

```sql
CREATE INDEX idx_sessions_borne_debut ON urbanwatt.sessions_recharge (id_borne, debut_session);
```

- **Besoin métier :** la supervision du parc. On analyse l'activité d'une borne sur une période pour calculer son taux d'utilisation, ou pour comprendre ce qui s'est passé avant un incident, avant d'envoyer un technicien.
- **Choix technique :** même logique que l'index 1. La clé étrangère `id_borne` vient en premier (égalité), la date ensuite (plage de dates).

### 3. `idx_sessions_debut`

```sql
CREATE INDEX idx_sessions_debut ON urbanwatt.sessions_recharge (debut_session);
```

- **Besoin métier :** les tableaux de bord d'exploitation (sessions du jour, de la semaine) et les extractions mensuelles pour la comptabilité.
- **Choix technique :** ces requêtes filtrent sur la date seule, sans borne ni véhicule. Les index 1 et 2 commencent par une autre colonne, donc ils ne permettent pas une recherche efficace sur la date seule.
- **Gain :** plus faible que pour les autres index (×9), parce qu'une journée renvoie environ 1 100 lignes. Il reste significatif pour des écrans consultés en permanence.

### 4. `paiements_id_session_key` (contrainte `UNIQUE`)

```sql
ALTER TABLE urbanwatt.paiements ADD CONSTRAINT paiements_id_session_key UNIQUE (id_session);
```

- **Besoin métier :** retrouver le paiement d'une session (facturation, réclamations, rapprochement comptable). La jointure sessions ↔ paiements est présente dans tous les rapports financiers.
- **Choix technique :**
  - La règle métier « une session = un paiement » est vérifiée dans les données : 217 300 paiements pour 217 300 sessions distinctes.
  - Une contrainte `UNIQUE` empêche de facturer deux fois la même session, et PostgreSQL crée automatiquement l'index qui l'accompagne.
  - On obtient donc à la fois un gain de performance et une garantie d'intégrité.

### 5. `idx_vehicules_client`

```sql
CREATE INDEX idx_vehicules_client ON urbanwatt.vehicules (id_client);
```

- **Besoin métier :** retrouver les véhicules d'un client. C'est le point d'entrée de tout parcours client : connexion, historique, facturation par client.
- **Choix technique :** `id_client` est une clé étrangère non indexée. La table est plus petite (18 000 lignes), mais elle est le premier maillon de la chaîne client → véhicules → sessions → paiements. Sans cet index, toute la chaîne commence par un parcours complet de la table.
- **Gain :** mesuré sur la requête « historique complet d'un client », qui utilise cet index avec les index 1 et 4.

### 6. `idx_paiements_en_attente` (index partiel)

```sql
CREATE INDEX idx_paiements_en_attente ON urbanwatt.paiements (date_paiement) WHERE statut = 'en_attente';
```

- **Besoin métier :** le suivi des paiements non finalisés par le service comptable (relances, alertes, écran de back-office).
- **Choix technique :**
  - Seuls 3 % des paiements sont en attente (6 524 sur 217 300).
  - Un index partiel ne contient que ces lignes. Il pèse 160 Ko, contre environ 5 Mo pour un index sur toute la table, et il n'est mis à jour que pour ces lignes.
  - Le tri par date permet de traiter les paiements les plus anciens en priorité.

---

## 3. Index volontairement non créés

| Candidat | Raison du refus |
|----------|-----------------|
| `sessions_recharge (statut)` | 87 % des sessions sont `terminee`. Un test montre que PostgreSQL ignore cet index : lire toute la table coûte moins cher qu'utiliser un index aussi peu sélectif. |
| `bornes (id_station)` | 600 lignes : un parcours complet prend moins d'1 ms. |
| `incidents (id_borne)` | 5 000 lignes : un parcours complet prend moins d'1 ms. |
| `interventions (id_incident)`, `interventions (id_technicien)` | 4 162 lignes : un parcours complet prend moins d'1 ms. |
| Index pour les agrégats globaux (ex. chiffre d'affaires par station et par mois) | Ces requêtes lisent toute la table, donc aucun index ne les accélère (mesuré : pas de gain). Si elles devenaient trop lentes, la bonne solution serait une vue matérialisée. |

Les index sur les clés étrangères des petites tables seront à réévaluer si ces tables grossissent.

---

## 4. Coût des index

| Index | Taille |
|-------|-------:|
| `idx_sessions_vehicule_debut` | 7,7 Mo |
| `idx_sessions_borne_debut` | 7,7 Mo |
| `paiements_id_session_key` | 4,8 Mo |
| `idx_sessions_debut` | 2,7 Mo |
| `idx_vehicules_client` | 0,35 Mo |
| `idx_paiements_en_attente` | 0,16 Mo |
| **Total** | **≈ 23 Mo** |

Chaque insertion dans `sessions_recharge` met à jour 4 index (la clé primaire et les index 1 à 3). Ce coût est acceptable : une nouvelle session arrive environ toutes les 80 secondes, alors que les lectures sont bien plus fréquentes.

---

## 5. Vérification et suivi

### Lister les index du schéma

```sql
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'urbanwatt'
ORDER BY tablename, indexname;
```

### Vérifier qu'une requête utilise bien son index

```sql
EXPLAIN ANALYZE
SELECT * FROM urbanwatt.sessions_recharge WHERE id_vehicule = 1234;
```

Le plan doit afficher `Index Scan` ou `Bitmap Index Scan on idx_sessions_vehicule_debut`, et non `Seq Scan`.

### Tester tous les index d'un coup

Le script `test_index_urbanwatt.sql` exécute 9 requêtes types. Pour chacune, il indique l'index réellement utilisé et le temps d'exécution avec et sans index. Les tests 8 et 9 sont des contrôles : ils ne doivent utiliser aucun index.

### Suivre l'utilisation en production

```sql
SELECT relname AS table_name, indexrelname AS index_name, idx_scan
FROM pg_stat_user_indexes
WHERE schemaname = 'urbanwatt'
ORDER BY idx_scan;
```

`idx_scan` compte le nombre d'utilisations de chaque index depuis sa création. Si un index ajouté (`idx_...`) reste à 0 après une période d'exploitation représentative, il pourra être supprimé. Les index `_pkey` et `_key` doivent toujours être conservés, car ils portent des contraintes.

---

## 6. Script de création

```sql
CREATE INDEX IF NOT EXISTS idx_sessions_vehicule_debut ON urbanwatt.sessions_recharge (id_vehicule, debut_session);
CREATE INDEX IF NOT EXISTS idx_sessions_borne_debut    ON urbanwatt.sessions_recharge (id_borne, debut_session);
CREATE INDEX IF NOT EXISTS idx_sessions_debut          ON urbanwatt.sessions_recharge (debut_session);
ALTER TABLE urbanwatt.paiements ADD CONSTRAINT paiements_id_session_key UNIQUE (id_session);
CREATE INDEX IF NOT EXISTS idx_vehicules_client        ON urbanwatt.vehicules (id_client);
CREATE INDEX IF NOT EXISTS idx_paiements_en_attente    ON urbanwatt.paiements (date_paiement) WHERE statut = 'en_attente';
ANALYZE;
```

`ANALYZE` met à jour les statistiques, ce qui permet à PostgreSQL de choisir les nouveaux index dès les requêtes suivantes.
