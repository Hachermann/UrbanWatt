# Projet Urbanwatt — Documentation des requêtes SQL

Base PostgreSQL d'un réseau de bornes de recharge pour véhicules électriques. Ce document explique les 31 requêtes du projet, de la sélection simple aux fonctions de fenêtre. La section 2 détaille les fonctions SQL utilisées, et chaque requête y renvoie.

Les résultats indiqués (nombre de lignes, valeurs) ont été obtenus en exécutant les requêtes sur le jeu de données CSV fourni, sous PostgreSQL 16.

## Sommaire

1. Contexte et modèle de données
2. Fiche mémo : les notions SQL utilisées
3. Requêtes 1 à 10 : sélections et jointures
4. Requêtes 11 à 20 : agrégations et calculs
5. Requêtes 21 à 25 : analyses avancées
6. Requêtes 26 à 31 : requêtes de synthèse
7. Récapitulatif des pièges

---

## 1. Contexte et modèle de données

### 1.1 Exécution

Les tables sont dans le schéma `urbanwatt`, qui est le schéma par défaut de la base `UrbanWatt` : ce réglage est fait par `sql/init/01_UrbanWatt.sql` au premier démarrage Docker (voir `installation_pgadmin_postgres.md`). Dans le Query Tool de pgAdmin, les requêtes s'exécutent donc telles quelles.

Sur une base où ce réglage n'existe pas, exécutez d'abord cette ligne :

```sql
SET search_path TO urbanwatt;
```

Sans elle, il faut préfixer chaque table (`urbanwatt.clients`). Le nom est en minuscules, il n'a donc pas besoin de guillemets.

### 1.2 Tables et volumes

| Table | Lignes | Contenu |
|---|---:|---|
| `stations` | 120 | Lieux de recharge, identifiés par un code (`ST-LIL`, `ST-TOU-002`…) |
| `bornes` | 600 | Points de charge, chacun rattaché à une station |
| `clients` | 15 000 | Clients du réseau |
| `vehicules` | 18 000 | Véhicules, chacun rattaché à un client |
| `sessions_recharge` | 250 000 | Une recharge d'un véhicule sur une borne |
| `paiements` | 217 300 | Au plus un paiement par session |
| `incidents` | 5 000 | Pannes signalées sur une borne |
| `interventions` | 4 162 | Réparation d'un incident par un technicien |
| `techniciens` | 120 | Techniciens de maintenance |

### 1.3 Chemins de jointure

```
clients ──< vehicules ──< sessions_recharge >── bornes >── stations
                              │                   │
                              └──< paiements      └──< incidents ──< interventions >── techniciens
```

`A ──< B` signifie : un A possède plusieurs B (la clé étrangère est dans B).

Pour relier un client à une station, il faut toujours traverser la chaîne complète : `clients → vehicules → sessions_recharge → bornes → stations`. Il n'existe pas de lien direct entre un client et une station.

### 1.4 Valeurs des colonnes de statut

| Colonne | Valeurs |
|---|---|
| `sessions_recharge.statut` | `terminee`, `interrompue`, `annulee` |
| `paiements.statut` | `accepte`, `refuse`, `en_attente` |
| `incidents.gravite` | `faible`, `moyenne`, `haute` |
| `incidents.statut` | `ouvert`, `resolu` |
| `interventions.statut` | `terminee`, `en_cours` |
| `bornes.etat` | `disponible`, `maintenance`, `hors_service` |

Les valeurs sont écrites sans accent (`terminee`, pas `terminée`). Une faute de frappe dans une valeur ne provoque pas d'erreur, la requête renvoie simplement 0 ligne.

Les sessions `annulee` n'ont ni date de fin, ni énergie, ni coût : ces colonnes valent `NULL`.

---

## 2. Fiche mémo : les notions SQL utilisées

### 2.1 Ordre d'exécution logique d'une requête

On écrit `SELECT` en premier, mais PostgreSQL évalue les clauses dans cet ordre :

| Étape | Clause | Ce qu'elle fait |
|---:|---|---|
| 1 | `FROM` / `JOIN` | Construit les lignes à partir des tables |
| 2 | `WHERE` | Filtre ligne par ligne, avant tout regroupement |
| 3 | `GROUP BY` | Regroupe les lignes |
| 4 | `HAVING` | Filtre les groupes |
| 5 | Fonctions de fenêtre (`OVER`) | Calculent un rang, une valeur précédente… |
| 6 | `SELECT` | Calcule les colonnes et crée les alias |
| 7 | `DISTINCT` | Supprime les doublons |
| 8 | `ORDER BY` | Trie |
| 9 | `LIMIT` | Garde les n premières lignes |

Cet ordre explique trois règles utilisées partout dans le projet :

- Un alias défini dans le `SELECT` ne peut pas servir dans le `WHERE` (il n'existe pas encore), mais il peut servir dans l'`ORDER BY`.
- Un agrégat (`COUNT`, `SUM`…) ne peut pas être filtré dans le `WHERE`, il faut le filtrer dans le `HAVING`.
- Le résultat d'une fonction de fenêtre ne peut être filtré ni dans le `WHERE` ni dans le `HAVING`. Il faut calculer la fenêtre dans une CTE (§2.12), puis filtrer dans la requête qui l'utilise (Q15, Q26, Q31).

### 2.2 Jointures : `JOIN` et `LEFT JOIN`

- `JOIN` (ou `INNER JOIN`) ne garde une ligne que si elle a une correspondance des deux côtés.
- `LEFT JOIN` garde toutes les lignes de la table de gauche. Quand il n'y a pas de correspondance, les colonnes de la table de droite valent `NULL`.

On utilise `LEFT JOIN` dès que l'énoncé dit « y compris ceux qui n'ont pas… » ou « en conservant… » : véhicules sans recharge (Q14), techniciens sans intervention (Q28), incidents sans intervention (Q8).

**Piège : la condition dans le `ON` ou dans le `WHERE`.** Avec un `LEFT JOIN`, une condition sur la table de droite change de sens selon l'endroit où elle est placée.

```sql
-- Correct : la condition fait partie de la jointure.
-- Un véhicule sans session terminée est gardé, avec des NULL à droite.
FROM vehicules v
LEFT JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
                             AND s.statut = 'terminee'

-- Incorrect : le WHERE s'applique après la jointure.
-- Pour un véhicule sans session terminée, s.statut vaut NULL,
-- la condition est fausse et la ligne disparaît.
FROM vehicules v
LEFT JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
WHERE s.statut = 'terminee'
```

Sur nos données, la première version renvoie 18 000 véhicules, la seconde 17 995 : les 5 véhicules sans session terminée disparaissent, et le `LEFT JOIN` se comporte comme un `JOIN` ordinaire.

Règle à retenir : une condition sur la table de droite d'un `LEFT JOIN` se place dans le `ON`. Requêtes concernées : Q13, Q14, Q22, Q28.

### 2.3 Alias de tables

```sql
FROM sessions_recharge s
JOIN bornes b ON b.id_borne = s.id_borne
```

`s` et `b` sont des alias : des noms courts qui remplacent le nom complet de la table dans le reste de la requête. Ils rendent les requêtes plus lisibles et deviennent obligatoires quand une même table apparaît deux fois (sous-requête de Q12, avec `s2`, `b2`, `st2`).

### 2.4 `DISTINCT`

`SELECT DISTINCT` supprime les lignes identiques sur l'ensemble des colonnes sélectionnées. Il sert quand une jointure multiplie les lignes : un client qui a rechargé 30 fois dans une station apparaît 30 fois après la jointure avec `sessions_recharge`.

**Piège : les homonymes.** `SELECT DISTINCT prenom, nom` fusionne deux clients différents qui portent le même nom. Il faut toujours inclure l'identifiant (`id_client`) dans un `DISTINCT` (Q1, Q17).

### 2.5 `IN`, `NOT IN` et le piège des `NULL`

`s.statut IN ('annulee', 'interrompue')` équivaut à `s.statut = 'annulee' OR s.statut = 'interrompue'`, en plus court (Q4, Q9).

`NOT IN (sous-requête)` garde les lignes absentes de la liste. Attention : si la sous-requête renvoie une seule valeur `NULL`, `NOT IN` ne renvoie plus aucune ligne, car la comparaison avec `NULL` n'est ni vraie ni fausse. Dans Q4, la colonne `vehicules.id_client` est déclarée `NOT NULL`, donc le risque n'existe pas. En règle générale, `NOT EXISTS` (§2.6) est plus sûr.

### 2.6 `EXISTS` et `NOT EXISTS`

```sql
WHERE EXISTS (
    SELECT 1
    FROM vehicules v
    JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
    WHERE v.id_client = c.id_client     -- lien avec la requête principale
      AND s.statut = 'terminee'
)
```

`EXISTS` vaut vrai si la sous-requête renvoie au moins une ligne. Ce qui est sélectionné n'a pas d'importance, d'où la convention `SELECT 1`. PostgreSQL s'arrête dès la première ligne trouvée.

La sous-requête est dite **corrélée** : elle fait référence à une colonne de la requête principale (`c.id_client`) et elle est évaluée pour chaque client.

Avantages par rapport à `JOIN` + `DISTINCT` : pas de doublons à supprimer, puisque chaque client n'est évalué qu'une fois ; et pas de piège avec les `NULL`, contrairement à `NOT IN`.

`SELECT EXISTS (...)` renvoie directement un booléen `true` / `false` (Q23).

Requêtes concernées : Q10, Q23, Q25.

### 2.7 Fonctions d'agrégat, `GROUP BY` et `HAVING`

| Fonction | Ce qu'elle renvoie |
|---|---|
| `COUNT(*)` | Le nombre de lignes du groupe, `NULL` compris |
| `COUNT(colonne)` | Le nombre de valeurs non `NULL` |
| `COUNT(DISTINCT colonne)` | Le nombre de valeurs distinctes non `NULL` |
| `SUM`, `AVG` | La somme ou la moyenne. Ignorent les `NULL`, renvoient `NULL` si le groupe n'a aucune valeur |
| `MAX`, `MIN` | La plus grande ou la plus petite valeur. Fonctionnent aussi sur les dates |

**`GROUP BY`** : toute colonne du `SELECT` qui n'est pas dans un agrégat doit figurer dans le `GROUP BY`. On y met aussi l'identifiant (`c.id_client`) pour ne pas regrouper deux clients homonymes.

**`COUNT(*)` contre `COUNT(colonne)` après un `LEFT JOIN`** : un véhicule sans session produit une ligne dont les colonnes de `sessions_recharge` sont à `NULL`. `COUNT(*)` compte cette ligne et renvoie 1, alors que `COUNT(s.id_session)` renvoie 0, ce qui est la bonne réponse (Q14, Q28).

**`WHERE` contre `HAVING`** : `WHERE` filtre les lignes avant le regroupement, `HAVING` filtre les groupes après. Dans Q21, `WHERE s.statut = 'interrompue'` ne garde que les sessions interrompues, puis `HAVING COUNT(...) >= 2` ne garde que les clients qui en ont au moins deux.

### 2.8 Agrégat conditionnel : `FILTER`

```sql
COUNT(b.id_borne) FILTER (WHERE b.etat = 'maintenance') AS nb_maintenance
```

`FILTER (WHERE ...)` applique l'agrégat uniquement aux lignes qui respectent la condition. On obtient plusieurs comptages différents sur le même groupe, en une seule lecture de la table (Q11 : disponibles, en maintenance et hors service ; Q30 : sessions interrompues et sessions totales).

`FILTER` fait partie du standard SQL, mais n'est pas disponible partout (MySQL ne le connaît pas). L'équivalent portable est :

```sql
SUM(CASE WHEN b.etat = 'maintenance' THEN 1 ELSE 0 END) AS nb_maintenance
```

### 2.9 `COALESCE`

`COALESCE(a, b, ...)` renvoie la première valeur non `NULL`. On l'utilise pour remplacer un résultat vide par une valeur lisible :

```sql
COALESCE(SUM(p.montant_eur), 0)   -- 0 au lieu de NULL pour une station sans paiement
```

Requêtes concernées : Q22, Q27, Q28.

### 2.10 Calculs : `ROUND` et division entière

`ROUND(valeur, 2)` arrondit à deux décimales (Q14, Q27, Q30).

**Piège de la division entière** : en PostgreSQL, un entier divisé par un entier donne un entier. `69 / 568` vaut `0`, pas `0,12`. Comme `COUNT` renvoie un entier, un taux calculé par `COUNT(...) / COUNT(*)` vaudrait toujours 0. On multiplie donc d'abord par `100.0` (un nombre décimal), ce qui force un calcul décimal : `100.0 * 69 / 568` vaut `12,15` (Q30).

### 2.11 Sous-requêtes

| Type | Exemple | Requêtes |
|---|---|---|
| Scalaire : renvoie une seule valeur | `WHERE energie_kwh = (SELECT MAX(...) ...)` | Q12, Q19, Q29 |
| Liste : renvoie une colonne de valeurs | `WHERE id_client NOT IN (SELECT ...)` | Q4 |
| Corrélée : utilise une colonne de la requête principale | `(SELECT COUNT(*) ... WHERE s.id_borne = b.id_borne)` | Q10, Q25 |

Une sous-requête scalaire peut se placer dans le `WHERE`, le `HAVING` (Q19) ou le `SELECT` (Q25).

### 2.12 CTE : la clause `WITH`

```sql
WITH classement AS (
    SELECT ...           -- requête intermédiaire nommée
)
SELECT ... FROM classement WHERE rang = 1;
```

Une CTE (*Common Table Expression*) donne un nom à un résultat intermédiaire, qu'on interroge ensuite comme une table. On peut en enchaîner plusieurs, séparées par des virgules (Q27). Elle sert à :

- filtrer sur le résultat d'une fonction de fenêtre, impossible directement (§2.1) : Q15, Q26, Q31 ;
- réutiliser un même résultat deux fois : Q29 utilise `par_jour` pour la liste et pour le maximum ;
- calculer des agrégats séparément avant de les assembler, pour éviter le double comptage : Q27 ;
- rendre une requête longue lisible, étape par étape.

### 2.13 Fonctions de fenêtre (`OVER`)

Un agrégat avec `GROUP BY` réduit plusieurs lignes à une seule. Une fonction de fenêtre **garde toutes les lignes** et ajoute à chacune une valeur calculée sur un ensemble de lignes voisines (la « fenêtre »).

```sql
RANK() OVER (PARTITION BY st.id_station ORDER BY s.energie_kwh DESC)
```

- `PARTITION BY` découpe les lignes en groupes indépendants : ici, un classement par station. Sans `PARTITION BY`, la fenêtre couvre tout le résultat (Q20).
- `ORDER BY` fixe l'ordre des lignes dans chaque groupe : ici, de la plus forte énergie à la plus faible.

#### Les fonctions de rang : `RANK`, `DENSE_RANK`, `ROW_NUMBER`

Elles diffèrent seulement par leur traitement des égalités. Exemple sur quatre énergies triées :

| energie_kwh | `ROW_NUMBER()` | `RANK()` | `DENSE_RANK()` |
|---:|:---:|:---:|:---:|
| 60,9 | 1 | 1 | 1 |
| 60,9 | 2 | 1 | 1 |
| 55,0 | 3 | 3 | 2 |
| 50,2 | 4 | 4 | 3 |

- `ROW_NUMBER` numérote sans jamais d'égalité : entre deux ex aequo, le choix est arbitraire.
- `RANK` donne le même rang aux ex aequo, puis saute des rangs (1, 1, 3).
- `DENSE_RANK` donne le même rang aux ex aequo, sans saut (1, 1, 2).

Quand l'énoncé dit « la **ou les** sessions », on garde `rang = 1` avec `RANK()` : tous les ex aequo sont conservés. Avec `ROW_NUMBER()`, un seul serait gardé au hasard (Q15, Q26). Pour un classement (Q20), `RANK()` correspond au classement « sportif » : deux premiers ex aequo, puis un troisième.

#### `LAG` et `LEAD` : la ligne précédente ou suivante

`LAG(colonne)` renvoie la valeur de la ligne précédente dans la partition, selon l'ordre de l'`ORDER BY`. `LEAD(colonne)` renvoie celle de la ligne suivante. Pour la première ligne, `LAG` renvoie `NULL`.

Exemple fictif pour un véhicule, avec `LAG(energie_kwh) OVER (PARTITION BY id_vehicule ORDER BY debut_session)` :

| debut_session | energie_kwh | LAG(energie_kwh) | Énergie en hausse ? |
|---|---:|---:|:---:|
| 2026-04-11 12:55 | 23,56 | `NULL` | non (pas de précédente) |
| 2026-04-21 10:50 | 24,59 | 23,56 | oui |
| 2026-04-24 18:50 | 18,10 | 24,59 | non |

`LAG` accepte aussi un décalage et une valeur par défaut : `LAG(energie_kwh, 2, 0)` renvoie l'énergie d'il y a deux sessions, ou 0 s'il n'y en a pas. Utilisé dans Q31.

#### La clause `WINDOW`

Quand plusieurs fonctions utilisent la même fenêtre, on la nomme une fois pour ne pas la répéter :

```sql
LAG(s.debut_session) OVER w AS debut_precedente,
LAG(s.energie_kwh)   OVER w AS energie_precedente
...
WINDOW w AS (PARTITION BY s.id_vehicule ORDER BY s.debut_session)
```

#### Fenêtre calculée après un `GROUP BY`

Les fonctions de fenêtre sont calculées après le regroupement (§2.1). On peut donc classer des agrégats : `RANK() OVER (ORDER BY SUM(s.energie_kwh) DESC)` classe les clients selon leur énergie totale (Q20).

### 2.14 Dates et durées

| Expression | Résultat | Requête |
|---|---|---|
| `CAST(debut_session AS date)` ou `debut_session::date` | Garde le jour, supprime l'heure : `2026-08-07 14:35` devient `2026-08-07` | Q29 |
| `date_fin - date_debut` | Une durée (`interval`) : `1 day 05:00:00` | Q28 |
| `SUM(date_fin - date_debut)` | Une somme de durées | Q28 |
| `EXTRACT(EPOCH FROM duree)` | La durée convertie en secondes | Q28 |

**Particularité de la somme de durées** : PostgreSQL additionne les jours et les heures séparément, sans convertir les heures en jours. Le résultat peut donc ressembler à `74 days 523:23:00` (74 jours et 523 heures). `justify_hours(...)` normalise l'affichage en `95 days 19:23:00`. Pour obtenir un total exploitable, Q28 convertit la durée en heures : `EXTRACT(EPOCH FROM ...) / 3600`.

### 2.15 Texte : concaténation et `LIKE`

`t.prenom || ' ' || t.nom` concatène les chaînes en une seule colonne (`Emma Petit`). Attention : si un élément vaut `NULL`, le résultat entier vaut `NULL`. Dans Q8, la colonne `technicien` est donc vide pour un incident sans intervention, ce qui est le comportement voulu. `concat_ws(' ', prenom, nom)` ignorerait les `NULL`.

`LIKE` compare avec un motif : `%` remplace n'importe quelle suite de caractères. `code_station LIKE 'ST-TOU%'` correspond à `ST-TOU`, mais aussi à `ST-TOU-002`, `ST-TOU-003`, etc. Pour un code précis, on utilise l'égalité stricte `=` (Q2, Q16, Q23).

### 2.16 Tri et limitation : `ORDER BY`, `LIMIT` et les ex aequo

`ORDER BY colonne DESC` trie du plus grand au plus petit ; `LIMIT 10` garde les 10 premières lignes (Q24, Q30).

Si plusieurs lignes sont à égalité à la limite (par exemple la 10e et la 11e ont le même montant), `LIMIT` en coupe une arbitrairement. PostgreSQL 13 et suivants proposent `FETCH FIRST 10 ROWS WITH TIES`, qui garde tous les ex aequo de la dernière place. Sur nos données, il n'y a pas d'égalité à la limite pour Q24 et Q30, les deux écritures donnent donc le même résultat.

### 2.17 Division relationnelle (« dans chacune des… »)

Une question de la forme « les clients qui ont fait X dans **toutes** les stations » est appelée division relationnelle. SQL n'a pas d'opérateur « pour tout », on le reformule de deux façons (Q19) :

- **Par comptage** : le client a visité autant de stations distinctes qu'il en existe au total. `HAVING COUNT(DISTINCT b.id_station) = (SELECT COUNT(*) FROM stations)`.
- **Par double négation** : il n'existe aucune station dans laquelle le client n'a pas de session terminée. `NOT EXISTS (... NOT EXISTS (...))`.

---

## 3. Requêtes 1 à 10 : sélections et jointures

### Q1 — Clients ayant rechargé à ST-LIL

> Afficher les clients ayant réalisé au moins une session de recharge dans la station ST-LIL, sans doublon, avec leur nom et leur prénom.

```sql
SELECT DISTINCT c.id_client, c.prenom, c.nom
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
JOIN bornes b            ON b.id_borne = s.id_borne
JOIN stations st         ON st.id_station = b.id_station
WHERE st.code_station = 'ST-LIL'
ORDER BY c.id_client;
```

**Fonctionnement.** La requête parcourt toute la chaîne client → véhicule → session → borne → station, puis ne garde que les lignes de ST-LIL. Un client qui a rechargé plusieurs fois apparaît une fois par session : `DISTINCT` supprime ces répétitions.

**Notions :** jointures (§2.2), `DISTINCT` (§2.4).

**Résultat :** 1 011 clients.

> **Correction par rapport à la version initiale.** La première version faisait `SELECT DISTINCT prenom, nom`, sans l'identifiant. Elle renvoyait 683 lignes au lieu de 1 011 : 328 clients ont disparu, fusionnés avec un homonyme. Ajouter `c.id_client` garantit qu'on compte des personnes, pas des noms.

### Q2 — Bornes de la station ST-TOU

> Lister toutes les bornes de la station ST-TOU, avec leur code, leur puissance, leur type de connecteur et leur état, triées par puissance décroissante.

```sql
SELECT st.code_station, b.code_borne, b.puissance_kw, b.connecteur, b.etat
FROM bornes b
JOIN stations st ON st.id_station = b.id_station
WHERE st.code_station = 'ST-TOU'
ORDER BY b.puissance_kw DESC;
```

**Fonctionnement.** Une seule jointure suffit, puisque la borne contient la clé de sa station. `ORDER BY ... DESC` trie de la plus puissante à la moins puissante.

**Notions :** jointure (§2.2), `LIKE` contre `=` (§2.15).

**Résultat :** 5 bornes.

> **Correction par rapport à la version initiale.** La première version utilisait `LIKE 'ST-TOU%'`, qui correspond aussi aux stations ST-TOU-002 à ST-TOU-006. Elle renvoyait 30 bornes réparties sur 6 stations, au lieu des 5 bornes de ST-TOU. Le `DISTINCT` a aussi été retiré : `code_borne` est unique, aucun doublon n'est possible.

### Q3 — Historique du véhicule ESSAI-0001

> Afficher l'historique des sessions du véhicule ESSAI-0001 : dates, borne utilisée, énergie, coût et statut, de la plus récente à la plus ancienne.

```sql
SELECT v.immatriculation,
       s.debut_session,
       s.fin_session,
       b.code_borne AS borne_utilisee,
       s.energie_kwh,
       s.cout_eur,
       s.statut
FROM sessions_recharge s
JOIN vehicules v ON v.id_vehicule = s.id_vehicule
JOIN bornes b    ON b.id_borne = s.id_borne
WHERE v.immatriculation = 'ESSAI-0001'
ORDER BY s.debut_session DESC;
```

**Fonctionnement.** La requête part des sessions et récupère l'immatriculation et le code de la borne par jointure. `AS borne_utilisee` renomme la colonne dans le résultat. Le tri `DESC` sur la date de début place la session la plus récente en premier.

**Notions :** jointures (§2.2), alias de colonne.

**Résultat :** 29 sessions. Les sessions annulées affichent `NULL` pour la fin, l'énergie et le coût, ce qui est normal (§1.4).

### Q4 — Clients sans session annulée ni interrompue

> Lister les clients n'ayant jamais eu de session annulée ou interrompue, y compris ceux qui n'ont effectué aucune recharge.

```sql
SELECT c.id_client, c.prenom, c.nom
FROM clients c
WHERE c.id_client NOT IN (
    SELECT DISTINCT v.id_client
    FROM vehicules v
    JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
    WHERE s.statut IN ('interrompue', 'annulee')
)
ORDER BY c.id_client;
```

**Fonctionnement.** La sous-requête construit la liste des clients qui ont eu au moins une session annulée ou interrompue. La requête principale garde tous les clients absents de cette liste. Un client qui n'a jamais rechargé n'est pas dans la liste : il est donc bien inclus, comme le demande l'énoncé, sans traitement particulier.

**Notions :** `IN` / `NOT IN` (§2.5), sous-requête liste (§2.11).

**Résultat :** 5 611 clients, dont 4 479 qui n'ont jamais rechargé.

**Variante équivalente**, sans le risque lié aux `NULL` :

```sql
SELECT c.id_client, c.prenom, c.nom
FROM clients c
WHERE NOT EXISTS (
    SELECT 1
    FROM vehicules v
    JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
    WHERE v.id_client = c.id_client
      AND s.statut IN ('interrompue', 'annulee')
)
ORDER BY c.id_client;
```

### Q5 — Sessions terminées à ST-LYO

> Afficher les sessions terminées dans la station ST-LYO, triées par énergie délivrée de la plus élevée à la plus faible.

```sql
SELECT s.id_session, s.energie_kwh, s.statut, st.code_station
FROM sessions_recharge s
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE st.code_station = 'ST-LYO'
  AND s.statut = 'terminee'
ORDER BY s.energie_kwh DESC;
```

**Fonctionnement.** Deux conditions combinées par `AND` : la station et le statut. Les sessions terminées ont toujours une énergie renseignée, le tri ne rencontre donc pas de `NULL`.

**Notions :** jointures (§2.2).

**Résultat :** 2 064 sessions.

### Q6 — Sessions du client n° 10

> Présenter, pour le client n° 10, toutes ses sessions avec le véhicule concerné, la station, la date et le statut.

```sql
SELECT c.id_client, c.prenom, c.nom,
       v.immatriculation,
       s.id_session,
       st.code_station,
       s.debut_session,
       s.fin_session,
       s.statut
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
JOIN bornes b            ON b.id_borne = s.id_borne
JOIN stations st         ON st.id_station = b.id_station
WHERE c.id_client = 10
ORDER BY s.debut_session;
```

**Fonctionnement.** Toute la chaîne de jointures, filtrée sur l'identifiant du client. Si le client possède plusieurs véhicules, les sessions de chacun apparaissent, avec l'immatriculation pour les distinguer.

**Notions :** jointures (§2.2).

**Résultat :** 70 sessions.

> **Correction par rapport à la version initiale.** Ajout d'un `ORDER BY` : sans lui, PostgreSQL ne garantit aucun ordre, et les sessions peuvent sortir mélangées.

### Q7 — Incidents de gravité haute

> Lister les incidents de gravité haute avec le code de la borne, la station, la catégorie, la date de signalement et l'état de résolution.

```sql
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
```

**Fonctionnement.** L'incident est rattaché à une borne, elle-même rattachée à une station. Le filtre porte sur la gravité. L'état de résolution est la colonne `statut` (`ouvert` ou `resolu`), renommée pour coller à l'énoncé ; la date de résolution est affichée en complément et vaut `NULL` pour un incident encore ouvert.

**Notions :** jointures (§2.2).

**Résultat :** 997 incidents.

### Q8 — Incidents de ST-BOR et interventions éventuelles

> Afficher tous les incidents associés à ST-BOR, classés par date décroissante, en indiquant les interventions éventuelles.

```sql
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
```

**Fonctionnement.** Le mot « éventuelles » impose un `LEFT JOIN` : un incident sans intervention doit rester dans le résultat. Les deux `LEFT JOIN` s'enchaînent (intervention, puis technicien). Le filtre du `WHERE` porte sur la station, qui est jointe par un `JOIN` ordinaire : il ne casse donc pas le `LEFT JOIN`. La concaténation `||` produit le nom complet du technicien, et donne `NULL` quand il n'y a pas d'intervention.

**Notions :** `LEFT JOIN` (§2.2), concaténation (§2.15).

**Résultat :** 55 incidents, dont 9 sans intervention (colonnes d'intervention à `NULL`).

### Q9 — Sessions annulées ou interrompues à ST-NAN

> Lister les sessions annulées ou interrompues dans ST-NAN, avec le véhicule, la date et le statut.

```sql
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
```

**Fonctionnement.** `IN` remplace deux conditions `OR`. C'est aussi plus sûr : écrire `station = 'ST-NAN' AND statut = 'annulee' OR statut = 'interrompue'` sans parenthèses serait faux, car `AND` est prioritaire sur `OR`, et toutes les sessions interrompues du réseau seraient ramenées.

**Notions :** `IN` (§2.5), jointures (§2.2).

**Résultat :** 252 sessions.

### Q10 — Clients avec une session terminée de plus de 30 kWh

> Afficher les clients ayant réalisé au moins une session terminée de plus de 30 kWh, sans doublon.

```sql
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
```

**Fonctionnement.** Pour chaque client, la sous-requête corrélée cherche au moins une session qui remplit les deux conditions. `EXISTS` répond oui ou non : chaque client n'apparaît qu'une fois, sans `DISTINCT`. La version avec `JOIN` + `DISTINCT` donnerait le même résultat, mais en construisant d'abord toutes les lignes client-session, puis en supprimant les doublons.

**Notions :** `EXISTS` et sous-requête corrélée (§2.6).

**Résultat :** 9 790 clients.

---

## 4. Requêtes 11 à 20 : agrégations et calculs

### Q11 — États des bornes par station

> Calculer le nombre de bornes disponibles, en maintenance et hors service pour chaque station.

```sql
SELECT st.code_station,
       st.nom_station,
       COUNT(b.id_borne) FILTER (WHERE b.etat = 'disponible')   AS nb_disponibles,
       COUNT(b.id_borne) FILTER (WHERE b.etat = 'maintenance')  AS nb_maintenance,
       COUNT(b.id_borne) FILTER (WHERE b.etat = 'hors_service') AS nb_hors_service
FROM stations st
LEFT JOIN bornes b ON b.id_station = st.id_station
GROUP BY st.id_station, st.code_station, st.nom_station
ORDER BY st.code_station;
```

**Fonctionnement.** On regroupe par station, puis trois `COUNT` comptent chacun un état grâce à `FILTER`. On obtient un tableau croisé (une ligne par station, une colonne par état) en une seule lecture des bornes. Sans `FILTER`, il faudrait trois requêtes, ou un `GROUP BY station, etat` qui donnerait une ligne par couple station-état. Le `LEFT JOIN` garde une station sans borne (elle afficherait trois zéros).

**Notions :** `GROUP BY` (§2.7), `FILTER` (§2.8), `LEFT JOIN` (§2.2).

**Résultat :** 120 stations.

### Q12 — Session(s) d'énergie maximale à ST-LIL

> Trouver, pour la station ST-LIL, la ou les sessions terminées dont l'énergie délivrée est maximale.

```sql
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
```

**Fonctionnement.** La sous-requête scalaire calcule l'énergie maximale à ST-LIL. La requête principale renvoie toutes les sessions qui atteignent cette valeur. La sous-requête doit répéter les mêmes filtres (station et statut) : sans eux, elle renverrait le maximum de tout le réseau. Les tables y sont réutilisées, d'où les alias `s2`, `b2`, `st2`.

Pourquoi pas `ORDER BY energie_kwh DESC LIMIT 1` ? Parce que cette écriture ne garde qu'une session, même si plusieurs sont à égalité. L'énoncé dit « la **ou les** sessions ».

**Notions :** sous-requête scalaire (§2.11), `MAX` (§2.7).

**Résultat :** 1 session (n° 1285, borne BR-LIL-02, 60,87 kWh).

### Q13 — Véhicules distincts par station

> Afficher le nombre de véhicules distincts ayant réalisé au moins une session terminée dans chaque station.

```sql
SELECT st.code_station,
       st.nom_station,
       COUNT(DISTINCT s.id_vehicule) AS nb_vehicules_distincts
FROM stations st
LEFT JOIN bornes b ON b.id_station = st.id_station
LEFT JOIN sessions_recharge s ON s.id_borne = b.id_borne
                             AND s.statut = 'terminee'
GROUP BY st.id_station, st.code_station, st.nom_station
ORDER BY nb_vehicules_distincts DESC, st.code_station;
```

**Fonctionnement.** Un même véhicule peut recharger plusieurs fois dans une station : `COUNT(DISTINCT s.id_vehicule)` ne le compte qu'une fois. `COUNT(s.id_session)` donnerait le nombre de sessions, pas de véhicules. La condition sur le statut est dans le `ON` pour qu'une station sans session terminée reste affichée avec 0.

**Notions :** `COUNT(DISTINCT)` (§2.7), condition dans le `ON` (§2.2).

**Résultat :** 120 stations. ST-NCY-004 arrive en tête avec 1 220 véhicules distincts.

### Q14 — Énergie moyenne par véhicule

> Calculer l'énergie moyenne délivrée par véhicule sur ses sessions terminées, en conservant ceux sans recharge.

```sql
SELECT v.id_vehicule,
       v.immatriculation,
       COUNT(s.id_session)          AS nb_sessions_terminees,
       ROUND(AVG(s.energie_kwh), 2) AS energie_moyenne_kwh
FROM vehicules v
LEFT JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
                             AND s.statut = 'terminee'
GROUP BY v.id_vehicule, v.immatriculation
ORDER BY v.id_vehicule;
```

**Fonctionnement.** « En conservant ceux sans recharge » impose le `LEFT JOIN`, avec la condition sur le statut dans le `ON`. Un véhicule sans session terminée apparaît avec 0 session et une moyenne `NULL`, puisqu'il n'a aucune valeur à moyenner. `COUNT(s.id_session)` donne bien 0 pour ce véhicule, alors que `COUNT(*)` donnerait 1.

**Notions :** condition dans le `ON` (§2.2), `COUNT(colonne)` contre `COUNT(*)` (§2.7), `ROUND` (§2.10).

**Résultat :** 18 000 véhicules, dont 5 sans session terminée. Avec la condition dans le `WHERE`, on n'en obtiendrait que 17 995.

### Q15 — Énergie maximale et borne associée, par station

> Afficher pour chaque station sa plus grande énergie délivrée en une session terminée et la borne associée.

```sql
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
```

**Fonctionnement.** Un simple `GROUP BY station` avec `MAX(energie_kwh)` donnerait l'énergie maximale, mais pas la borne : on ne peut pas afficher `code_borne` sans le regrouper aussi, ce qui donnerait un maximum par borne. La fonction de fenêtre résout le problème :

1. `PARTITION BY st.id_station` fait un classement séparé pour chaque station.
2. `ORDER BY s.energie_kwh DESC` classe les sessions de la plus forte à la plus faible.
3. `RANK()` donne le rang 1 à la ou aux sessions maximales de chaque station.
4. La CTE est nécessaire, car on ne peut pas écrire `WHERE rang = 1` dans la requête qui calcule le rang (§2.1).

**Notions :** fonctions de fenêtre et `RANK` (§2.13), CTE (§2.12).

**Résultat :** 121 lignes pour 120 stations : à ST-NIC-001, deux sessions sont ex aequo, et `RANK()` les garde toutes les deux.

### Q16 — Sessions du véhicule ESSAI-0007

> Présenter toutes les sessions de ESSAI-0007 avec la ville, la station, la borne et la date par ordre chronologique.

```sql
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
```

**Fonctionnement.** « Ordre chronologique » signifie du plus ancien au plus récent, soit un tri croissant (`ASC`, par défaut). L'égalité stricte est indispensable : les immatriculations `ESSAI-0007000` à `ESSAI-0007999` existent aussi, et `LIKE 'ESSAI-0007%'` les ramènerait.

**Notions :** jointures (§2.2), `LIKE` contre `=` (§2.15).

**Résultat :** 32 sessions.

### Q17 — Utilisateurs de la borne BR-NAN-01

> Afficher les propriétaires et les véhicules ayant utilisé au moins une fois la borne BR-NAN-01.

```sql
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
```

**Fonctionnement.** Un véhicule qui a utilisé la borne plusieurs fois apparaît une fois par session : `DISTINCT` garde un seul couple propriétaire-véhicule. Un client avec deux véhicules ayant utilisé la borne apparaît sur deux lignes, une par véhicule, ce qui répond à l'énoncé.

**Notions :** jointures (§2.2), `DISTINCT` (§2.4).

**Résultat :** 312 couples propriétaire-véhicule.

### Q18 — Bornes avec au moins deux incidents

> Lister les bornes ayant connu au moins deux incidents, avec le nombre d'incidents et la date du plus récent.

```sql
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
```

**Fonctionnement.** On regroupe les incidents par borne. `MAX` sur une date renvoie la plus récente. La condition « au moins deux » porte sur un agrégat : elle se place dans le `HAVING`, pas dans le `WHERE`.

**Notions :** `GROUP BY` et `HAVING` (§2.7), `MAX` sur une date.

**Résultat :** 599 bornes sur 600 (une seule borne n'a eu qu'un incident). BR-BOR-01 est en tête avec 18 incidents.

### Q19 — Clients présents dans toutes les stations

> Trouver les clients ayant effectué au moins une session terminée dans chacune des stations du réseau.

```sql
SELECT c.id_client, c.prenom, c.nom
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
JOIN bornes b            ON b.id_borne = s.id_borne
WHERE s.statut = 'terminee'
GROUP BY c.id_client, c.prenom, c.nom
HAVING COUNT(DISTINCT b.id_station) = (SELECT COUNT(*) FROM stations)
ORDER BY c.id_client;
```

**Fonctionnement.** C'est une division relationnelle. Pour chaque client, on compte les stations distinctes où il a terminé une session. Il est retenu si ce nombre est égal au nombre total de stations, calculé par la sous-requête scalaire du `HAVING`. Le `DISTINCT` est indispensable : sans lui, on compterait les sessions, et un client ayant fait 120 sessions dans une seule station serait retenu.

Variante par double négation, qui donne le même résultat :

```sql
SELECT c.id_client, c.prenom, c.nom
FROM clients c
WHERE NOT EXISTS (
    SELECT 1 FROM stations st
    WHERE NOT EXISTS (
        SELECT 1
        FROM vehicules v
        JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
        JOIN bornes b            ON b.id_borne = s.id_borne
        WHERE v.id_client = c.id_client
          AND b.id_station = st.id_station
          AND s.statut = 'terminee'
    )
);
```

Elle se lit : « les clients pour lesquels il n'existe aucune station où ils n'ont pas de session terminée ».

**Notions :** division relationnelle (§2.17), `COUNT(DISTINCT)` et `HAVING` (§2.7), sous-requête scalaire (§2.11).

**Résultat :** 0 client. La requête est correcte : le client le plus mobile a terminé des sessions dans 29 stations sur 120.

### Q20 — Classement des clients par énergie consommée

> Établir le classement des clients selon l'énergie consommée : client, nombre de sessions, énergie et rang.

```sql
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
```

**Fonctionnement.** Le `GROUP BY` calcule le nombre de sessions et l'énergie totale par client. La fonction de fenêtre est évaluée après le regroupement (§2.1) : elle peut donc classer selon `SUM(s.energie_kwh)`. Il n'y a pas de `PARTITION BY`, car le classement porte sur l'ensemble des clients. Deux clients à égalité reçoivent le même rang.

On compte l'énergie des sessions terminées, celles qui sont facturées. Pour y ajouter l'énergie délivrée avant une interruption, remplacez la condition par `s.statut IN ('terminee', 'interrompue')`.

**Notions :** fenêtre après `GROUP BY` et `RANK` (§2.13), agrégats (§2.7).

**Résultat :** 10 520 clients classés. Les 4 480 clients sans session terminée n'apparaissent pas, car la jointure est un `JOIN` ordinaire. Emma Fontaine (n° 11639) est première avec 115 sessions et 2 809,26 kWh.

---

## 5. Requêtes 21 à 25 : analyses avancées

### Q21 — Clients avec au moins deux sessions interrompues

> Afficher les clients ayant subi au moins deux sessions interrompues, avec le nombre total de ces interruptions.

```sql
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
```

**Fonctionnement.** C'est l'exemple type de la différence entre `WHERE` et `HAVING` : le `WHERE` garde d'abord les seules sessions interrompues ; le `GROUP BY` les compte par client ; le `HAVING` garde ensuite les clients qui en ont au moins deux. Le comptage se fait par client, toutes ses voitures confondues.

**Notions :** `WHERE` contre `HAVING` (§2.7).

**Résultat :** 5 340 clients. Le maximum est de 14 interruptions pour un même client.

### Q22 — Chiffre d'affaires encaissé par station

> Calculer, pour chaque station, le chiffre d'affaires encaissé à partir des seuls paiements acceptés, par ordre décroissant.

```sql
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
```

**Fonctionnement.** On remonte de la station jusqu'aux paiements, en ne gardant que les paiements acceptés (« encaissé » exclut les paiements refusés ou en attente). Les trois `LEFT JOIN`, avec la condition de statut dans le `ON`, garantissent qu'une station sans paiement accepté reste affichée ; `COALESCE` remplace alors la somme `NULL` par 0.

Le risque de double comptage est écarté : il y a au plus un paiement par session (217 300 paiements pour 217 300 sessions distinctes).

**Notions :** `LEFT JOIN` et condition dans le `ON` (§2.2), `SUM` (§2.7), `COALESCE` (§2.9).

**Résultat :** 120 stations. ST-REN-007 est en tête avec 24 118,72 € ; la plus faible encaisse 12 581,64 €. Toutes les stations ont donc un chiffre d'affaires, mais la requête resterait juste si l'une d'elles n'en avait aucun.

### Q23 — ESSAI-0007 a-t-il terminé une session à ST-BOR ?

> Vérifier par une requête renvoyant vrai/faux si ESSAI-0007 a déjà terminé une session dans la station ST-BOR.

```sql
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
```

**Fonctionnement.** `EXISTS` placé directement dans le `SELECT` renvoie une seule ligne avec un booléen. La sous-requête n'est pas corrélée : elle ne dépend d'aucune table extérieure. PostgreSQL s'arrête dès qu'il trouve une session correspondante.

Une alternative serait `SELECT COUNT(*) > 0 FROM ...`, mais elle compte toutes les sessions avant de répondre, alors que `EXISTS` s'arrête à la première.

**Notions :** `EXISTS` (§2.6).

**Résultat :** `true` (pgAdmin affiche `true` ; psql affiche `t`).

### Q24 — Les 10 paiements acceptés les plus élevés

> Lister les 10 sessions ayant donné lieu aux montants de paiement accepté les plus élevés, avec client, véhicule et station.

```sql
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
```

**Fonctionnement.** La requête part des paiements, ne garde que les acceptés, les trie du plus élevé au plus faible et garde les 10 premiers. La session fait le lien vers deux branches : le véhicule et son propriétaire d'un côté, la borne et sa station de l'autre.

**Notions :** `ORDER BY` + `LIMIT` (§2.16), concaténation (§2.15).

**Résultat :** 10 sessions, de 37,40 € à 36,76 €. Le 11e montant (36,66 €) est différent du 10e, il n'y a donc pas d'ex aequo coupé par le `LIMIT`. Pour gérer ce cas dans l'absolu, on peut remplacer `LIMIT 10` par `FETCH FIRST 10 ROWS WITH TIES`.

### Q25 — Bornes sans aucun incident

> Lister toutes les bornes n'ayant jamais eu d'incident signalé, y compris celles qui ont enregistré des recharges.

```sql
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
```

**Fonctionnement.** `NOT EXISTS` garde les bornes pour lesquelles aucun incident n'existe. La précision « y compris celles qui ont enregistré des recharges » signifie que l'utilisation de la borne ne doit pas intervenir dans le filtre : on ne joint donc pas `sessions_recharge` dans le `WHERE`. Pour le rendre visible, une sous-requête corrélée placée dans le `SELECT` affiche le nombre de sessions de chaque borne, sans multiplier les lignes comme le ferait une jointure.

Écriture équivalente avec `LEFT JOIN` : `LEFT JOIN incidents i ON i.id_borne = b.id_borne WHERE i.id_incident IS NULL`.

**Notions :** `NOT EXISTS` (§2.6), sous-requête corrélée dans le `SELECT` (§2.11).

**Résultat :** 0 borne. La requête est correcte : les 600 bornes ont toutes eu au moins un incident. Pour le vérifier : `SELECT COUNT(DISTINCT id_borne) FROM incidents;` renvoie 600.

---

## 6. Requêtes 26 à 31 : requêtes de synthèse

### Q26 — Meilleure session de chaque véhicule

> Pour chaque véhicule, afficher sa ou ses sessions terminées dont l'énergie délivrée est la plus élevée.

```sql
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
```

**Fonctionnement.** Même principe que Q15, mais avec une partition par véhicule au lieu d'une partition par station. `RANK()` garde toutes les sessions ex aequo au rang 1, ce que demande « sa **ou ses** sessions ».

Le tri final se fait sur `id_vehicule` plutôt que sur l'immatriculation. Les véhicules 1 à 64 ont une immatriculation courte (`ESSAI-0001`), les suivants une longue (`ESSAI-0000065`). Un tri alphabétique placerait `ESSAI-0000065` avant `ESSAI-0001`, donc le véhicule 65 avant le véhicule 1.

**Notions :** fonctions de fenêtre et `RANK` (§2.13), CTE (§2.12).

**Résultat :** 18 017 lignes pour 17 995 véhicules ayant au moins une session terminée : 22 lignes supplémentaires correspondent à des ex aequo.

### Q27 — Synthèse par station sans double comptage

> Afficher pour chaque station le nombre de bornes, la puissance totale installée et l'énergie moyenne par session terminée, sans double comptage.

```sql
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
```

**Le piège.** La tentation est d'écrire une seule requête :

```sql
-- FAUX : la puissance de chaque borne est additionnée une fois par session
SELECT st.code_station, COUNT(b.id_borne), SUM(b.puissance_kw), AVG(s.energie_kwh)
FROM stations st
JOIN bornes b            ON b.id_station = st.id_station
JOIN sessions_recharge s ON s.id_borne = b.id_borne AND s.statut = 'terminee'
GROUP BY st.code_station;
```

Après la jointure avec les sessions, chaque borne apparaît autant de fois qu'elle a de sessions. Pour ST-LIL, la puissance installée réelle est de 372 kW, mais cette requête renvoie 165 716 kW. `COUNT(b.id_borne)` est faux pour la même raison. `SUM(DISTINCT b.puissance_kw)` ne corrige rien : deux bornes de même puissance ne seraient comptées qu'une fois.

**La solution.** Chaque agrégat est calculé à son propre niveau, dans une CTE séparée : la puissance au niveau des bornes, l'énergie moyenne au niveau des sessions. On obtient une ligne par station dans chaque CTE, et la jointure finale (une ligne contre une ligne) ne peut plus rien multiplier. Les `LEFT JOIN` et `COALESCE` gardent les stations sans borne ou sans session terminée.

**Notions :** CTE multiples (§2.12), agrégats (§2.7), `COALESCE` (§2.9).

**Résultat :** 120 stations.

### Q28 — Activité des techniciens

> Lister les techniciens avec le nombre d'interventions terminées et la durée totale passée en intervention, y compris ceux sans intervention terminée.

```sql
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
```

**Fonctionnement.**

- `LEFT JOIN` avec le statut dans le `ON` : un technicien sans intervention terminée reste listé, avec 0.
- `it.date_fin - it.date_debut` : soustraire deux `timestamp` donne une durée (`interval`). Seules les interventions terminées sont prises en compte, ce qui écarte les 428 interventions `en_cours`, dont la date de fin est vide.
- `SUM(...)` additionne ces durées. Comme PostgreSQL ne convertit pas les heures en jours, l'affichage brut ressemble à `74 days 523:23:00` (§2.14).
- `EXTRACT(EPOCH FROM ...)` convertit la durée totale en secondes, `/ 3600` en heures, et `ROUND(..., 1)` arrondit au dixième. Cette colonne est plus simple à lire et à comparer.
- `COALESCE(..., INTERVAL '0')` et `COALESCE(..., 0)` affichent 0 au lieu de `NULL` pour un technicien sans intervention.

**Notions :** dates et durées (§2.14), `LEFT JOIN` (§2.2), `COALESCE` (§2.9), `COUNT(colonne)` (§2.7).

**Résultat :** 120 techniciens. Tous ont au moins 20 interventions terminées, mais la requête garderait ceux qui n'en ont aucune. Raphaël Faure (n° 82) est en tête avec 51 interventions.

### Q29 — Jour(s) record de sessions terminées

> Trouver le ou les jours ayant enregistré le plus grand nombre de sessions terminées sur l'ensemble du réseau.

```sql
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
```

**Fonctionnement.**

1. `CAST(debut_session AS date)` supprime l'heure, pour regrouper toutes les sessions d'une même journée. Regrouper sur `debut_session` directement donnerait un groupe par minute.
2. La CTE `par_jour` compte les sessions terminées pour chaque jour.
3. La sous-requête calcule le maximum de ces comptages, et la requête principale garde tous les jours qui l'atteignent.

La CTE est utilisée deux fois (dans le `FROM` et dans la sous-requête) : sans elle, il faudrait écrire deux fois le même regroupement. L'écriture `debut_session::date` est un raccourci PostgreSQL équivalent à `CAST`.

**Notions :** conversion en date (§2.14), CTE (§2.12), sous-requête scalaire (§2.11).

**Résultat :** 2 jours ex aequo, le 7 août et le 20 septembre 2026, avec 1 081 sessions terminées chacun. Un `ORDER BY ... LIMIT 1` n'en aurait gardé qu'un.

### Q30 — Bornes les plus interrompues

> Afficher les cinq bornes présentant le plus grand nombre de sessions interrompues, avec leur nombre total de sessions et leur taux d'interruption.

```sql
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
```

**Fonctionnement.**

- Il faut deux comptages sur des ensembles différents : les sessions interrompues et toutes les sessions. Un `WHERE s.statut = 'interrompue'` ferait perdre le total. `FILTER` permet de compter les deux dans le même groupe (§2.8).
- Le taux est calculé en pourcentage. `100.0` force un calcul décimal : sans lui, la division de deux entiers donnerait 0 (§2.10).
- Le tri principal porte sur le nombre d'interruptions, comme le demande l'énoncé. Le taux sert à départager les égalités.

**Notions :** `FILTER` (§2.8), division entière et `ROUND` (§2.10), `LIMIT` (§2.16).

**Résultat :** 5 bornes. BR-LIL-00312 (ST-LIL-002) est en tête avec 69 sessions interrompues sur 568, soit 12,15 %.

### Q31 — Sessions en hausse par rapport à la précédente

> Pour chaque véhicule, trouver les sessions terminées dont l'énergie délivrée est supérieure à celle de sa session terminée précédente ; afficher les deux valeurs et les deux dates.

```sql
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
```

**Fonctionnement.** C'est la requête la plus technique du projet.

1. **`LAG`** récupère, sur chaque ligne, la valeur de la session précédente du même véhicule. `PARTITION BY s.id_vehicule` empêche de comparer deux véhicules différents ; `ORDER BY s.debut_session` définit ce qu'est la « précédente » (la plus récente avant celle-ci).
2. **`WINDOW w`** nomme la fenêtre une fois, pour les deux appels à `LAG` (la date et l'énergie précédentes).
3. **Le filtre sur `terminee` est placé dans la CTE, avant le calcul de `LAG`.** C'est le point essentiel : la fenêtre ne voit que des sessions terminées, et la « précédente » est donc bien la session terminée précédente. Si on filtrait après, la précédente pourrait être une session annulée, dont l'énergie vaut `NULL`, et la comparaison serait faussée.
4. **La comparaison se fait dans la requête principale**, car on ne peut pas filtrer sur `LAG` dans la requête qui le calcule (§2.1).
5. **La première session de chaque véhicule** a une énergie précédente `NULL`. `energie_kwh > NULL` n'est pas vrai, la ligne est donc écartée naturellement, ce qui est correct : il n'y a rien à comparer.

**Notions :** `LAG` et clause `WINDOW` (§2.13), CTE (§2.12), ordre d'exécution (§2.1).

**Résultat :** 99 465 sessions en hausse par rapport à la session terminée précédente du même véhicule.

---

## 7. Récapitulatif des pièges

| Piège | Symptôme | Solution | Requêtes |
|---|---|---|---|
| `LIKE` au lieu de `=` sur un code | Des lignes en trop (ST-TOU-002, ESSAI-0007000…) | Égalité stricte `=` | Q2, Q16, Q23 |
| `DISTINCT` sans identifiant | Des homonymes fusionnés, des lignes en moins | Ajouter `id_client` au `SELECT` | Q1, Q17 |
| Condition sur la table de droite d'un `LEFT JOIN` placée dans le `WHERE` | Les lignes sans correspondance disparaissent | Placer la condition dans le `ON` | Q13, Q14, Q22, Q28 |
| `COUNT(*)` après un `LEFT JOIN` | 1 au lieu de 0 pour une ligne sans correspondance | `COUNT(colonne_de_droite)` | Q14, Q28 |
| Agrégat filtré dans le `WHERE` | Erreur SQL | Filtrer dans le `HAVING` | Q18, Q19, Q21 |
| Filtre sur une fonction de fenêtre dans la même requête | Erreur SQL | Calculer dans une CTE, filtrer ensuite | Q15, Q26, Q31 |
| `LIMIT 1` ou `ROW_NUMBER` pour « la ou les » | Un seul ex aequo gardé au hasard | Sous-requête `MAX` ou `RANK()` | Q12, Q15, Q26, Q29 |
| Jointure de plusieurs tables filles avant un `SUM` | Valeurs multipliées (165 716 kW au lieu de 372 kW) | Agréger chaque niveau dans sa propre CTE | Q27 |
| Division de deux entiers | Taux toujours égal à 0 | Multiplier d'abord par `100.0` | Q30 |
| `NOT IN` avec une sous-requête pouvant contenir `NULL` | Aucune ligne renvoyée | `NOT EXISTS` | Q4 |
| Filtre appliqué après `LAG` | La « précédente » peut être une session annulée | Filtrer avant le calcul de la fenêtre | Q31 |
| Absence d'`ORDER BY` | Ordre des lignes imprévisible | Toujours trier explicitement | Q6 |
| Valeur de statut mal orthographiée (`terminée`) | 0 ligne, sans erreur | Vérifier les valeurs avec `SELECT DISTINCT statut FROM ...` | Toutes |
