<p align="center"><img src="https://resorption-bidonvilles.beta.gouv.fr/img/Marianne.d37c6b1e.svg" height="30" align="center" /> <strong>Résorption-bidonvilles</strong></p>
<h1 align="center">Infrastructure de <em>Résorption-bidonvilles</em></h1>

`resorption-bidonvilles-deploy` fournit une configuration Docker et Docker-compose complète permettant de monter une instance locale de *Résorption-bidonvilles*.

## 🛠 Pré-requis
- make
- docker
- docker-compose
- openssl
- envsubst
- curl

## 👩🏼‍💻 Instance de développement
### 1. Initialiser
Les étapes suivantes sont **obligatoires** :
- sur votre machine, cloner les projets suivants dans des dossiers au même niveau :
  - ce dépôt dans un dossier `resorption-bidonvilles-deploy` 
  - [le dépôt du frontend](https://github.com/MTES-MCT/action-bidonvilles) dans un dossier `resorption-bidonvilles-frontend`
  - [le dépôt de l'API](https://github.com/MTES-MCT/action-bidonvilles-api) dans un dossier `resorption-bidonvilles-api`
- créer et remplir un fichier `config/.env` en copiant le fichier `config/.env.dev.sample` ([voir ici pour une explication complète sur ce fichier](#configuration))
- déclarer dans votre fichier `/etc/hosts` les deux domaines locaux suivants :
```
127.0.0.1   resorption-bidonvilles.localhost
127.0.0.1   api.resorption-bidonvilles.localhost
```
- générer un certificat https auto-signé : `make localcert` (cette commande génère plusieurs certificats dans `data/ssl` qui seront utilisés par le proxy nginx)

Les étapes suivantes sont optionnelles et peuvent être faites plus tard :
- faire autoriser, au niveau de votre système, le certificat d'autorité `data/ssl/RootCA.crt` généré plus haut. Sur MacOS cela revient à rajouter ce certificat au trousseau d'accès système.

### 2. Utiliser
Le fichier Makefile fournit une target `dev` qui peut être utilisée comme un alias de docker-compose :
- démarrer l'instance locale : `make dev up`
- exécuter une commande dans le service api : `make dev exec rb_api yarn sequelize db:migrate`
- démarrer une session SHELL sur le service api : `make dev exec rb_api bash`
- forcer un build des images : `make dev build`
- etc.

Note : pour passer des options à ces commandes, entourez les de guillemets : `make dev "up --remove-orphans --build"`

## 🚀 Instance de staging / production
### 1. Initialiser
- cloner ce dépôt à l'endroit souhaité (sur une machine Debian, la localisation attendue est le dossier `/srv` : `/srv/resorption-bidonvilles` par exemple)
- créer le fichier `config/.env` en copiant l'un des fichiers d'exemple `config/.env.*.sample`
- faire l'acquisition des certificats https : `make remotecert`
- monter l'instance en passant en paramètre les versions attendues du front et de l'api : `RB_FRONTEND_VERSION=0.13.1 RB_API_VERSION=0.0.14 make prod "up -d"`

### 2. Maintenir
- relancer un up avec les bons numéros de version `RB_FRONTEND_VERSION=0.14.0 RB_API_VERSION=0.1.0 make prod "up -d"`
- lancer les migrations via le service `rb_api` : `make prod exec rb_api yarn sequelize db:migrate`
- lancer des seeders via le service `rb_api` : `make prod exec rb_api yarn sequelize db:seed --seed db/seeders/...`
- accéder à la base de données : `make prod exec rb_database_data bash`

<h2 id="configuration">📒 Configuration</h2>
Plusieurs remarques :
- tous les chemins indiqués comme "relatifs" dans cette section sont relatifs à la racine de ce dépôt.
- les variables indiquées `prod-only` ne sont nécessaires que pour la production (pas la dev, ni staging)

### Commune
<table>
    <tbody>
        <tr>
            <td>RB_DATA_FOLDER</td>
            <td>Chemin relatif ou absolu vers le dossier `data` qui doit être créé pour stocker par défaut les données locales (certificats https, base de données ,etc.)</td>
        </tr>
    </tbody>
</table>

### Proxy
<table>
    <tbody>
        <tr>
            <td>RB_PROXY_CONFIG_FOLDER</td>
            <td>Chemin relatif ou absolu vers le dossier de configuration du proxy Nginx.</td>
        </tr>
        <tr>
            <td>RB_PROXY_FRONTEND_HOST</td>
            <td>Adresse de l'hôte pour le frontend (nom de domaine uniquement, pas d'IP). Exemple : `resorption-bidonvilles.localhost`</td>
        </tr>
        <tr>
            <td>RB_PROXY_API_HOST</td>
            <td>Adresse de l'hôte pour l'api (nom de domaine uniquement, pas d'IP). Obligatoirement un sous-domaine du frontend. Exemple : `api.resorption-bidonvilles.localhost`</td>
        </tr>
        <tr>
            <td>RB_PROXY_CERTIFICATE_PATH</td>
            <td>Chemin relatif ou absolu vers le certificat https, utilisé par Nginx pour le chiffrage.</td>
        </tr>
        <tr>
            <td>RB_PROXY_CERTIFICATE_KEY_PATH</td>
            <td>Chemin relatif ou absolu vers la clé du certificat https, utilisé par Nginx pour le chiffrage.</td>
        </tr>
        <tr>
            <td>RB_PROXY_TRUSTED_CERTIFICATE_PATH</td>
            <td>Chemin relatif ou absolu vers le certificat d'autorité https, utilisé par Nginx pour le chiffrage.</td>
        </tr>
        <tr>
            <td>RB_PROXY_TEMPLATE</td>
            <td>Soit `full`, soit `certonly`. Cette variable est configurée automatiquement via make. La version `certonly` met en place la configuration nginx minimale nécessaire à l'acquisition d'un premier certificat https. La version `full` met en place la configuration complète qui pré-suppose l'existence du certificat (et rendrait une erreur s'il n'existe pas).</td>
        </tr>
    </tbody>
</table>

### Base de données (données)
<table>
    <tbody>
        <tr>
            <td>RB_DATABASE_DATA_FOLDER</td>
            <td>Chemin relatif ou absolu vers le dossier de l'hôte auquel doit être bindée cette base de données.</td>
        </tr>
        <tr>
            <td>RB_DATABASE_EXTERNAL_PORT</td>
            <td>Port de l'hôte qui doit être bindé à celui de la base de données.</td>
        </tr>
        <tr>
            <td>RB_DATABASE_LOCALBACKUP_FOLDER</td>
            <td>Chemin absolu du dossier du conteneur dans lequel seront générés les fichiers de backup</td>
        </tr>
        <tr>
            <td>RB_DATABASE_REMOTEBACKUP_KEY_ID<br/><em>prod-only</em></td>
            <td rowspan="6" align="center">Voir la page du wiki <a href="https://github.com/MTES-MCT/resorption-bidonvilles-deploy/wiki/Backup-%7C-Mise-en-place-de-la-backup-cloud#-configuration-de-rclone">Mise en place de la backup cloud</a></td>
        </tr>
        <tr>
            <td>RB_DATABASE_REMOTEBACKUP_KEY_SECRET<br/><em>prod-only</em></td>
        </tr>
        <tr>
            <td>RB_DATABASE_REMOTEBACKUP_BUCKET_ENDPOINT<br/><em>prod-only</em></td>
        </tr>
        <tr>
            <td>RB_DATABASE_REMOTEBACKUP_BUCKET_NAME<br/><em>prod-only</em></td>
        </tr>
        <tr>
            <td>RB_DATABASE_REMOTEBACKUP_BUCKET_PASSWORD<br/><em>prod-only</em></td>
        </tr>
        <tr>
            <td>RB_DATABASE_REMOTEBACKUP_SLACK_WEBHOOK<br/><em>prod-only</em></td>
        </tr>
        <tr>
            <td>POSTGRES_DB</td>
            <td>Nom de la base de données</td>
        </tr>
        <tr>
            <td>POSTGRES_USER</td>
            <td>Nom de l'utilisateur PostgreSQL propriétaire de la base de données</td>
        </tr>
        <tr>
            <td>POSTGRES_PASSWORD</td>
            <td>Mot de passe de l'utilisateur PostgreSQL</td>
        </tr>
    </tbody>
</table>

### Base de données (agenda)
<table>
    <tbody>
        <tr>
            <td>RB_AGENDA_MONGO_VERSION</td>
            <td>Tag d'image docker Mongo à utiliser (voir <a href="https://hub.docker.com/_/mongo">Docker Hub</a>)</td>
        </tr>
        <tr>
            <td>RB_AGENDA_DATA_FOLDER</td>
            <td>Chemin relatif ou absolu vers le dossier de l'hôte auquel doit être bindée cette base de données.</td>
        </tr>
        <tr>
            <td>MONGO_INITDB_ROOT_USERNAME</td>
            <td>Nom de l'utilisateur MongoDB</td>
        </tr>
        <tr>
            <td>MONGO_INITDB_ROOT_PASSWORD</td>
            <td>Mot de passe de l'utilisateur MongoDB</td>
        </tr>
    </tbody>
</table>

### Frontend
<table>
    <tbody>
        <tr>
            <td>RB_FRONTEND_VERSION</td>
            <td>Variable utilisée <em>uniquement</em> pour les versions prod/staging. Nom du tag de l'image docker à utiliser (voir <a href="https://hub.docker.com/r/resorptionbidonvilles/frontend/tags">Docker Hub</a>)</td>
        </tr>
        <tr>
            <td>RB_FRONTEND_FOLDER</td>
            <td>Variable utilisée <em>uniquement</em> pour la version dev. Chemin relatif ou absolu vers la racine du dépôt `action-bidonvilles`.</td>
        </tr>
        <tr>
            <td>VUE_APP_API_URL</td>
            <td>URL vers l'API, ne finissant pas par un /. Exemple : https://api.resorption-bidonvilles.localhost</td>
        </tr>
        <tr>
            <td>VUE_APP_MATOMO_ON</td>
            <td>Soit `true`, soit `false. Est-ce que le tracking Matomo doit être activé ou non.</td>
        </tr>
        <tr>
            <td>VUE_APP_SENTRY_SOURCEMAP_AUTHKEY<br/><em>prod-only</em></td>
            <td>Authkey pour communication avec le projet Sentry</td>
        </tr>
        <tr>
            <td>VUE_APP_SENTRY<br/><em>prod-only</em></td>
            <td>DSN du projet Sentry frontend</td>
        </tr>
    </tbody>
</table>

### API
<table>
    <tbody>
        <tr>
            <td>RB_API_VERSION</td>
            <td>Variable utilisée <em>uniquement</em> pour les versions prod/staging. Nom du tag de l'image docker à utiliser (voir <a href="https://hub.docker.com/r/resorptionbidonvilles/api/tags">Docker Hub</a>)</td>
        </tr>
        <tr>
            <td>RB_API_FOLDER</td>
            <td>Variable utilisée <em>uniquement</em> pour la version dev. Chemin relatif ou absolu vers la racine du dépôt `action-bidonvilles-api`.</td>
        </tr>
        <tr>
            <td>RB_API_BACK_URL</td>
            <td>URL vers l'API, ne finissant pas par un /. Exemple : https://api.resorption-bidonvilles.localhost</td>
        </tr>
        <tr>
            <td>RB_API_FRONT_URL</td>
            <td>URL vers le frontend, finissant par un `/#`. Exemple : https://resorption-bidonvilles.localhost/#</td>
        </tr>
        <tr>
            <td>RB_API_AUTH_SECRET</td>
            <td>Chaîne secrète servant à chiffrer les tokens de l'API. Utiliser une chaîne d'au moins 40 caractères.</td>
        </tr>
        <tr>
            <td>RB_API_AUTH_EXPIRES_IN</td>
            <td>Nombre d'heures de validité d'un token d'authentification. Exemple : `24h`.</td>
        </tr>
        <tr>
            <td>RB_API_ACTIVATION_TOKEN_EXPIRES_IN</td>
            <td>Nombre d'heures de validité d'un token d'activation de compte. Exemple : `24h`</td>
        </tr>
        <tr>
            <td>RB_API_PASSWORD_RESET_EXPIRES_IN</td>
            <td>Nombre d'heures de validité d'un token de réinitialisation de mot de passe. Exemple : `24h`</td>
        </tr>
        <tr>
            <td>RB_API_MAILJET_PUBLIC_KEY</td>
            <td>Clé publique de l'API Mailjet</td>
        </tr>
        <tr>
            <td>RB_API_MAILJET_PRIVATE_KEY</td>
            <td>Clé privée de l'API Mailjet</td>
        </tr>
        <tr>
            <td>RB_API_MONGO_USERNAME</td>
            <td>Nom de l'utilisateur pour la connexion à la base de données Agenda</td>
        </tr>
        <tr>
            <td>RB_API_MONGO_PASSWORD</td>
            <td>Mot de passe de l'utilisateur Mongo pour la base de données Agenda</td>
        </tr>
        <tr>
            <td>RB_API_SLACK_WEBHOOK_1<br/>RB_API_SLACK_WEBHOOK_2<br/>...<br/><em>prod-only</em></td>
            <td>Définition de webhooks Slack sous la forme "nom;url" où "nom" est le nom de la clé qui sera définie dans l'objet "slack" de la configuration api, et "url" est l'URL du webhook en question.<br/><br/>Il peut y avoir une infinité de variables "RB_API_SLACK_WEBHOOK_X" tant que la numérotation commence bien par 1 et qu'elle est incrémentée de 1 à chaqure fois.</td>
        </tr>
        <tr>
            <td>RB_API_SENTRY_DSN<br/><em>prod-only</em></td>
            <td>DSN du projet Sentry API</td>
        </tr>
    </tbody>
</table>

## 🙇🏼 Contributeur(ices)

| <img src="https://avatars3.githubusercontent.com/u/1801091?v=3" width="120px;"/><br /><sub><b>Anis Safine Laget</b></sub> | <img src="https://avatars3.githubusercontent.com/u/50863659?v=3" width="120px;"/><br /><sub><b>Christophe Benard</b></sub> | <img src="https://avatars3.githubusercontent.com/u/5053593?v=3" width="120px;"/><br /><sub><b>⠀⠀Gaël Destrem</b></sub> |
| --- | --- | --- |

## 📝 Licence
Ce projet est distribué sous license [AGPL-3.0](LICENSE).