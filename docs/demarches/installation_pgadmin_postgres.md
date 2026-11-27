# Installation de PostgreSQL et pgAdmin avec Docker

La base UrbanWatt et pgAdmin se lancent avec une seule commande. Au premier démarrage, la base est créée et remplie automatiquement à partir des fichiers du dépôt.

## Prérequis

Docker Desktop installé et démarré (« Engine running » en bas à gauche de la fenêtre).

## Premier lancement

1. **Créer le fichier de configuration.** Dans le dossier `infra`, copiez `.env.example` en `.env`, puis remplacez les deux mots de passe `changez-moi`. Le fichier `.env` est ignoré par Git.

   ```powershell
   cd infra
   copy .env.example .env
   ```

2. **Libérer les ports si besoin.** Si d'anciens conteneurs PostgreSQL ou pgAdmin tournent déjà (créés avec `docker run`), arrêtez-les pour libérer les ports 5432 et 5050. Leurs données ne sont pas supprimées.

   ```powershell
   docker ps
   docker stop <nom_du_conteneur>
   ```

3. **Lancer**, toujours depuis le dossier `infra` :

   ```powershell
   docker compose up -d
   ```

Au premier démarrage, PostgreSQL exécute les scripts de `sql/init`, dans l'ordre de leur nom :

| Script | Rôle |
|---|---|
| `01_UrbanWatt.sql` | Crée le schéma `urbanwatt`, en fait le schéma par défaut de la base, puis crée les 9 tables et leurs clés étrangères |
| `02_charger_csv_postgresql.sql` | Charge les 9 fichiers CSV de `sql/data` et recale les compteurs d'identifiants |
| `03_index.sql` | Crée les index décrits dans `creation_index.md` |

pgAdmin attend la fin de ces scripts avant de démarrer. Comptez environ une minute.

## Se connecter

**pgAdmin** : ouvrez http://localhost:5050 et connectez-vous avec `PGADMIN_EMAIL` et `PGADMIN_PASSWORD` (valeurs de `.env`).

### Enregistrer le serveur dans pgAdmin

Le serveur **UrbanWatt** est normalement déjà présent dans le panneau de gauche, sous **Servers** : il est déclaré dans `infra/pgadmin/servers.json`. Au premier clic, pgAdmin demande le mot de passe `POSTGRES_PASSWORD` ; cochez « Save password » pour ne plus le saisir.

pgAdmin ne lit ce fichier qu'à son tout premier démarrage. Si le serveur n'apparaît pas, enregistrez-le à la main : clic droit sur **Servers** > **Register** > **Server**. Remplissez les deux onglets ci-dessous et laissez les autres tels quels.

**Onglet General**

| Champ | Valeur |
|---|---|
| Name | `UrbanWatt` (nom affiché dans pgAdmin, au choix) |

**Onglet Connection**

| Champ | Valeur |
|---|---|
| Host name/address | `postgres` |
| Port | `5432` |
| Maintenance database | `UrbanWatt` (valeur de `POSTGRES_DB`, majuscules comprises) |
| Username | `postgres` (valeur de `POSTGRES_USER`) |
| Password | valeur de `POSTGRES_PASSWORD` dans `infra/.env` |
| Save password? | activé |

Cliquez sur **Save**. Les tables se trouvent dans **Databases** > **UrbanWatt** > **Schemas** > **urbanwatt** > **Tables**.

> **Host n'est pas le nom du serveur.** Ce champ attend l'adresse de PostgreSQL dans le réseau Docker, c'est-à-dire le nom du service dans `docker-compose.yaml` : `postgres`. Le nom du conteneur, `UrbanWatt-Postgres`, fonctionne aussi. `localhost` ne fonctionne pas ici : pgAdmin tourne lui-même dans un conteneur, et pour lui `localhost` désigne son propre conteneur.

### Exécuter des requêtes

Les requêtes s'exécutent sans préfixe ni `SET search_path` : `urbanwatt` est le schéma par défaut de la base. `SELECT * FROM clients;` fonctionne directement.

### Depuis un autre client

DBeaver, psql installé sur la machine, etc. : hôte `localhost`, port `5432`, base `UrbanWatt`, utilisateur et mot de passe de `.env`.

## Commandes utiles

Toutes se lancent depuis le dossier `infra`.

| Commande | Effet |
|---|---|
| `docker compose ps` | État des conteneurs. `UrbanWatt-Postgres` doit être `healthy` |
| `docker compose logs postgres` | Journal de la base, dont le nombre de lignes chargées par table |
| `docker compose down` | Arrête les conteneurs. Les données sont conservées |
| `docker compose down -v` | Arrête et supprime les données. Le prochain `up` recrée tout depuis les CSV |

## Points d'attention

- **Les scripts de `sql/init` ne s'exécutent que si la base est vide.** Après avoir modifié un script ou un CSV, repartez de zéro : `docker compose down -v`, puis `docker compose up -d`.
- **Pour la même raison, changer un mot de passe dans `.env` après le premier lancement n'a aucun effet** sur la base existante. Il faut repartir de zéro, ou changer le mot de passe dans PostgreSQL (`ALTER USER postgres PASSWORD '...';`).
- **Ne placez pas d'autres fichiers `.sql` dans `sql/init`.** Tout ce qui s'y trouve est exécuté automatiquement, et une erreur interrompt le démarrage. Les requêtes du projet sont dans `sql/request.sql`.
- **« port is already allocated »** : un autre programme ou conteneur utilise déjà le port. Arrêtez-le, ou changez `POSTGRES_PORT` ou `PGADMIN_PORT` dans `.env`.
- **Le conteneur `UrbanWatt-Postgres` s'arrête au premier démarrage** : un script de `sql/init` a échoué. L'erreur est indiquée par `docker compose logs postgres`. Corrigez-la, puis repartez de zéro avec `down -v` et `up -d`.

## Problèmes rencontrés et solutions

### « failed to resolve host 'UrbanWatt' » à l'enregistrement du serveur

**Cause :** le champ Host name/address contenait `UrbanWatt`, le nom donné au serveur. Aucune machine ne porte ce nom dans le réseau Docker, donc pgAdmin ne peut pas la trouver.

**Solution :** mettre `postgres` dans Host name/address (le nom du service PostgreSQL dans `docker-compose.yaml`), et garder `UrbanWatt` uniquement dans le champ Name de l'onglet General.

### Nom de la base différent entre `.env` et `servers.json`

**Cause :** la base a été renommée `UrbanWatt` dans `.env`, alors que `servers.json` indiquait encore `urbanwatt`. Pour PostgreSQL, ce sont deux bases différentes : le nom d'une base respecte les majuscules.

**Solution :** le nom `UrbanWatt` a été reporté partout : `infra/.env.example`, `infra/pgadmin/servers.json` et la valeur par défaut de `POSTGRES_DB` dans `docker-compose.yaml`. Dans pgAdmin, saisir `UrbanWatt` en Maintenance database, avec les majuscules.

Si pgAdmin répond « database "UrbanWatt" does not exist », la base a été créée avant le changement de nom dans `.env` et porte encore l'ancien nom. Mettre `postgres` en Maintenance database pour se connecter, puis lire son nom exact dans **Databases**.

### Le serveur enregistré automatiquement n'a pas pris en compte une modification

**Cause :** pgAdmin ne lit `infra/pgadmin/servers.json` qu'à son tout premier démarrage. Une modification ultérieure du fichier est ignorée.

**Solution :** enregistrer le serveur à la main (voir « Enregistrer le serveur dans pgAdmin »), ou réinitialiser la configuration de pgAdmin. Cette réinitialisation ne touche pas aux données de la base :

```powershell
docker compose down
docker volume rm urbanwatt_pgadmin_data
docker compose up -d
```
