<p align="center">
  <span href="https://resorption-bidonvilles.dihal.gouv.fr">
    <img src="https://resorption-bidonvilles.dihal.gouv.fr/img/Marianne.d37c6b1e.svg" alt="Résorption-bidonvilles" align="down" height="30">
    <strong><font size="6">Résorption-bidonvilles</font></strong><br/>
    Agir pour résorber les bidonvilles
  </span>

  <h3 align="center"></h3>

  <p align="center">
    [Structure de déploiement]
    <br />
    <a href="https://github.com/MTES-MCT/resorption-bidonvilles-deploy/wiki"><strong>Consulter le wiki »</strong></a>
    <br />
    <br />
    <a href="https://resorption-bidonvilles.dihal.gouv.fr">Voir la plateforme</a>
    ·
    <a href="#-pré-requis">Déployer une instance sur sa machine</a>
    ·
    <a href="#-instance-de-staging--production">Déployer une instance sur un serveur</a>
  </p>
</p>


## 🤓 Préambule

Résorption-bidonvilles est une plateforme publiée sous la forme d'images Docker dans [Docker Hub](https://hub.docker.com/u/resorptionbidonvilles). Il existe une image [pour l'api](https://hub.docker.com/r/resorptionbidonvilles/api), et deux images pour le frontend ([landing](https://hub.docker.com/r/resorptionbidonvilles/www) et [plateforme](https://hub.docker.com/r/resorptionbidonvilles/frontend)).

Ce dépôt fournit une configuration Docker et Docker-compose permettant de monter une instance de dev, staging, ou production de *Résorption-bidonvilles*.

## 🛠 Pré-requis
- make
- docker
- docker-compose
- openssl
- envsubst
- curl
- unzip
- grep
- sed
- timeout

## 👩🏼‍💻 Instance de développement
### 1. Initialiser
Les étapes suivantes sont **obligatoires** :
- sur votre machine, cloner les projets suivants dans des dossiers au même niveau :
  - ce dépôt dans un dossier `resorption-bidonvilles-deploy` 
  - [les sources de la plateforme](https://github.com/MTES-MCT/resorption-bidonvilles) dans un dossier `resorption-bidonvilles`
- créer et remplir un fichier `resorption-bidonvilles-deploy/config/.env` en copiant le fichier `.env.dev.sample` ([voir ici pour une explication complète sur son contenu](#-configuration))
- créer et remplir les fichiers `resorption-bidonvilles/packages/api/.env`, `resorption-bidonvilles/packages/frontend/www/.env`, `resorption-bidonvilles/packages/frontend/webapp/.env` en copiant les fichiers `env.sample` respectifs ([voir ici pour une explication complète sur leur contenu](#-configuration))
- déclarer dans votre fichier `/etc/hosts` les trois domaines locaux suivants :
```
127.0.0.1   resorption-bidonvilles.localhost
127.0.0.1   app.resorption-bidonvilles.localhost
127.0.0.1   api.resorption-bidonvilles.localhost
```
- générer un certificat https auto-signé : `make localcert` (cette commande génère plusieurs certificats dans `data/ssl` qui seront utilisés par le proxy nginx)

Les étapes suivantes sont optionnelles et peuvent être faites plus tard :
- faire autoriser, au niveau de votre système, le certificat d'autorité `data/ssl/RootCA.crt` généré plus haut. Sur MacOS cela revient à rajouter ce certificat au trousseau d'accès système.

### 2. Démarrer l'instance
#### 2.1 Services tiers
Les différents applicatifs de Résorption-bidonvilles dépendent de services tiers (bases de données, notamment). Ces services tiers sont mis à disposition via des containers Docker qui peuvent être démarrés et gérés grâce à docker-compose.

Pour démarrer les services tiers ([voir ici la liste des services montés](#🧩-liste-des-services-montés)) :
```
docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.dev.yml up
```

Pour simplifier l'utilisation, un fichier Makefile met à disposition une target `dev` qui sert d'alias. La commande ci-dessus peut-être réécrite ainsi :
```
make dev up
```

Plus généralement, vous pouvez utiliser cette target pour manipuler les différents services :
- démarrer une session SHELL sur le service database_data : `make dev exec rb_database_data bash`
- forcer un build des images : `make dev build
- etc.

Note : pour passer des options à ces commandes, entourez les de guillemets : `make dev "up --remove-orphans --build"`, autrement, Make retournera une erreur

#### 2.2 Applicatifs
Résorption-bidonvilles fonctionne avec trois applicatifs distincts que vous devez démarrer chacun séparément sur votre machine :
- l'api : `cd resorption-bidonvilles/packages/api && yarn dev`
- la landing (www) : `cd resorption-bidonvilles/packages/frontend/www && yarn dev`
- la plateforme (webapp) : `cd resorption-bidonvilles/packages/frontend/webapp && yarn dev`

<h2 id="deployer">🚀 Instance de staging / production</h2>

### 1. Initialiser
- cloner ce dépôt à l'endroit souhaité (sur une machine Debian, la localisation attendue est le dossier `/srv` : `/srv/resorption-bidonvilles` par exemple)
- créer le fichier `config/.env` en copiant l'un des fichiers d'exemple `config/.env.*.sample`
- faire l'acquisition des certificats https : `make remotecert`
- monter l'instance : `make prod "up -d"`

### 2. Maintenir
- modifier la version attendue de la plateforme dans `config/.env`
- relancer un up : `make prod "up -d"`
- lancer les migrations via le service `rb_api` : `make prod exec rb_api yarn sequelize db:migrate`
- lancer des seeders via le service `rb_api` : `make prod exec rb_api yarn sequelize db:seed --seed db/seeders/...`
- accéder à la base de données : `make prod exec rb_database_data bash`

## 🧩 Liste des services montés

Quel que soit l'environnement choisi, les services suivants seront montés :
- `rb_proxy` : le serveur Nginx qui écoute l'intégralité des requêtes HTTP(S) et redirige vers le service approprié sur la base du nom de domaine
- `rb_database_data` : la base de données PostgreSQL utilisée par l'API
- `rb_database_agenda` : la base de données MongoDB qui sert à planifier des tâches futures via l'outil `agenda`

Sur les environnements de staging/production, les services suivants seront montés :
- `rb_certbot` : un outil permettant le renouvellement automatique des certificats HTTPS
- `rb_www` : le frontend de la landing-page
- `rb_webapp` : le frontend de la plateforme, une SPA développée avec VueJS
- `rb_api` : l'API REST qui alimente la plateforme et landing-page, développée avec NodeJS

## 📒 Configuration
Plusieurs remarques :
- tous les chemins indiqués comme "relatifs" dans cette section sont relatifs à la racine de ce dépôt.
- les variables indiquées `prod-only` ne sont nécessaires que pour la production (pas la dev, ni staging) et inversement pour `dev-only`

### Commune
<table>
    <tbody>
        <tr>
            <td>RB_DEPLOY_VERSION<br/><em>prod-only</em></td>
            <td>Variable utilisée <em>uniquement</em> pour les versions prod/staging. Nom du tag de l'image docker à utiliser (voir les repositories sur <a href="https://hub.docker.com/r/resorptionbidonvilles">Docker Hub</a>). Par défaut, le même numéro de version est utilisé pour frontend et api, mais vous pouvez forcer des versions différentes en modifiant directement RB_DEPLOY_VERSION et RB_FRONTEND_VERSION (voir plus bas).</td>
        </tr>
        <tr>
            <td>RB_DEPLOY_DATA_FOLDER</td>
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
            <td>RB_REMOTEBACKUP_TCHAP_ROOM_ID</td>
            <td>Identifiant Matrix (room ID, de la forme <code>!xxxx:serveur</code>) du salon Tchap qui reçoit les alertes de la sauvegarde cloud (script <code>database/scripts/cloud_backup.sh</code>). L'URL du serveur et le jeton sont ceux de l'API (<code>RB_API_TCHAP_BASE_URL</code> et <code>RB_API_TCHAP_TOKEN</code>). En préproduction : le salon de test.</td>
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
            <td>VUE_APP_API_URL</td>
            <td>URL vers l'API, ne finissant pas par un /. Exemple : https://api.resorption-bidonvilles.localhost</td>
        </tr>
        <tr>
            <td>VUE_APP_MATOMO_ON</td>
            <td>Soit `true`, soit `false. Est-ce que le tracking Matomo doit être activé ou non.</td>
        </tr>
        <tr>
            <td>VUE_APP_SENTRY_ON</td>
            <td>Soit `true`, soit `false. Est-ce que le tracking Sentry doit être activé ou non.</td>
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
            <td>RB_DEPLOY_VERSION</td>
            <td>Variable utilisée <em>uniquement</em> pour les versions prod/staging. Nom du tag de l'image docker à utiliser (voir <a href="https://hub.docker.com/r/resorptionbidonvilles/api/tags">Docker Hub</a>)</td>
        </tr>
        <tr>
            <td>RB_API_BACK_URL</td>
            <td>URL vers l'API, ne finissant pas par un /. Exemple : https://api.resorption-bidonvilles.localhost</td>
        </tr>
        <tr>
            <td>RB_API_FRONT_URL</td>
            <td>URL vers le frontend, sans `/` à la fin. Exemple : https://resorption-bidonvilles.localhost</td>
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
            <td>RB_API_TEST_EMAIL</td>
            <td>Adresse email qui est utilisée pour remplacer certains destinataires d'emails transactionnels. À utiliser en préproduction pour tester les notifications mails à l'ajout de commentaire par exemple.</td>
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
            <td>RB_API_ENV_LABEL</td>
            <td>Étiquette de l'environnement (ex. `PREPROD`). <strong>Vide en production.</strong> Dès qu'elle est renseignée, toutes les notifications Tchap sont redirigées vers le salon de test (<code>RB_API_TCHAP_NOTIF_DEV_TEST</code>), même si <code>NODE_ENV=production</code> : les vrais salons ne sont utilisés que si <code>NODE_ENV=production</code> <em>et</em> que l'étiquette est vide.</td>
        </tr>
        <tr>
            <td>RB_API_TCHAP_BASE_URL</td>
            <td>URL du serveur Tchap (Matrix) qui émet les notifications. <code>https://</code> obligatoire. Une valeur invalide désactive l'envoi (erreur signalée à Sentry).</td>
        </tr>
        <tr>
            <td>RB_API_TCHAP_TOKEN</td>
            <td>Jeton d'accès du compte bot Tchap. Également utilisé par le script de sauvegarde cloud (<code>RB_REMOTEBACKUP_TCHAP_ROOM_ID</code>). Secret : ne jamais le versionner.</td>
        </tr>
        <tr>
            <td>RB_API_TCHAP_NOTIF_*<br/>RB_API_TCHAP_TECH</td>
            <td>Identifiants Matrix (room ID, de la forme <code>!xxxx:serveur</code>) des salons de notification, un par variable : <code>NOTIF_DEV_TEST</code>, <code>NOTIF_INVITATIONS_INTERVENANTS</code>, <code>NOTIF_NETTOYAGE_PIECES_JOINTES</code>, <code>NOTIF_INTERVENANTS_DECLARES</code>, <code>NOTIF_CANICULE</code>, <code>NOTIF_REQUETES_CADASTRE</code>, <code>NOTIF_ACTION_NOUVEAU_COMMENTAIRE</code>, <code>NOTIF_SITE_NOUVEAU_COMMENTAIRE</code>, <code>NOTIF_NOUVEAUX_UTILISATEURS</code>, <code>TECH</code>, <code>NOTIF_AUTO_DESACTIVATIONS</code>, <code>NOTIF_ANONYMISATION</code>, <code>NOTIF_PERSONNES_INVITEES</code>, <code>NOTIF_ABSENCE_PILOTE_ACTION</code>, <code>NOTIF_FERMETURE_SITES</code>, <code>NOTIF_REINSTALLATION</code>, <code>NOTIF_OUVERTURE_SITES</code>. Un alias (<code>#salon:serveur</code>) ou une URL est refusé. <strong>En préproduction, toutes ces variables doivent pointer vers le salon de test</strong> : ne jamais y copier les identifiants des salons de production.</td>
        </tr>
        <tr>
            <td>RB_API_SENTRY_DSN<br/><em>prod-only</em></td>
            <td>DSN du projet Sentry API</td>
        </tr>
        <tr>
            <td>RB_API_SOLIGUIDE_KEY</td>
            <td>Clé privé de communication avec l'API soliguide</td>
        </tr>
        <tr>
            <td>RB_API_EMAIL_BLACKLIST</td>
            <td>Une liste d'id utilisateurs, séparés par des virgules (sans espaces !), qui doivent être exclus des notifications mail d'ouverture et fermeture de site. Exemple : `1,2,3,4`</td>
        </tr>
        <tr>
            <td>RB_API_SEND_ACTIVITY_SUMMARY</td>
            <td>Un booléen (0 ou 1), qui indique à l'API si elle doit programmer l'envoi automatique de résumé d'activités par mail. Théoriquement à 1 uniquement en production</td>
        </tr>
    </tbody>
</table>

## 🙇🏼 Contributeur(ices)

| <img src="https://avatars3.githubusercontent.com/u/1801091?v=3" width="120px;"/><br /><sub><b>Anis Safine Laget</b></sub> | <img src="https://avatars3.githubusercontent.com/u/50863659?v=3" width="120px;"/><br /><sub><b>Christophe Bénard</b></sub> | <img src="https://avatars.githubusercontent.com/u/34971399?v=4" width="120px;"/><br /><sub><b>⠀⠀Gilles Cognin</b></sub> | <img src="https://avatars3.githubusercontent.com/u/5053593?v=3" width="120px;"/><br /><sub><b>⠀⠀Gaël Destrem</b></sub> | <img src="https://avatars3.githubusercontent.com/u/94321132?v=3" width="120px;"/><br /><sub><b>⠀Grégoire Thomazeau</b></sub> |
| --- | --- | --- | --- | --- |

## 📝 Licence
Ce projet est distribué sous license [AGPL-3.0](LICENSE).