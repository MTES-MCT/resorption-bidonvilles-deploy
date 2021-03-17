## Pré-requis
- make
- docker
- docker-compose
- openssl

## Initialisation
Avant de pouvoir utiliser ce dépôt, vous devez préalablement :
- sur la même machine, où vous le souhaitez, cloner le dépôt [action-bidonvilles](https://github.com/MTES-MCT/action-bidonvilles)
- créer un fichier /config/.env qui servira à décrire l'environnement désiré

### Configuration
Important : tous les chemins relatifs incrits dans la configuration seront interprétés comme relatifs à la racine du projet ("/") et non pas au dossier "/config" !

#### 1. Générale
- RB_DATA_FOLDER : chemin vers le dossier où seront stockées, par défaut, toutes les données du projet

#### 2. De la base de données
Configuration de l'image docker :
- RB_DATABASE_POSTGRES_VERSION : numéro de version de postgres (doit correspondre à un tag Docker)
- RB_DATABASE_DATA_FOLDER : chemin vers le dossier où sera stockée la base de données
- RB_DATABASE_EXTERNAL_PORT : dans le cas d'un environnement dev, port ouvert pour une connexion depuis l'hôte

Configuration de la base elle-même :
- POSTGRES_DB : nom de la base
- POSTGRES_USER
- POSTGRES_PASSWORD=rbadmin

#### 3. Du proxy
Dans le cas d'un environnement de production, c'est un proxy qui est exposé et écoute les ports publics, pour ensuite faire la redirection vers les services appropriés.

La configuration des serveurs est fournie dans le dossier `/nginx`, mais vous pouvez paramétrer les éléments suivants :
- RB_PROXY_HTTP_PORT : port d'écoute du HTTP pour le service frontend
- RB_PROXY_SSL_PORT : port d'écoute du SSL pour le service frontend
- RB_PROXY_CONFIG_FOLDER : chemin vers le dossier contenant les configurations nginx
- RB_PROXY_FRONTEND_HOST : nom de domaine écouté pour le service frontend

Notes importantes :
- le frontend est décrit dans un fichier `default.conf` de façon à surcharger la configuration par défaut
- les fichiers du dossier `/nginx` sont des fichiers en `*.template` afin de profiter de l'injection des variables d'environnement
- justement, il est interdit de surcharger la commande par défaut de l'image nginx : autrement, l'injection des variables ne serait plus active et le proxy ne fonctionnerait plus

#### 4. Du frontend
Configuration de l'image docker :
- RB_FRONTEND_FOLDER : chemin vers le dossier du dépôt frontend
- RB_FRONTEND_EXTERNAL_PORT : dans le cas d'un environnement dev, port depuis lequel le front est accessible

Configuration de l'application frontend :
- VUE_APP_API_URL : url (sans `/` à la fin) vers l'api (exemple : `https://api.resorption-bidonvilles.beta.gouv.fr`)
- VUE_APP_MATOMO_ON : booléen indiquant si le tracking doit être activé ou pas sur cet environnement

## Utilisation
- pour un environnement de développement (ports ouverts, hot reload, etc.) : `make dev up`
- pour un environnement de déploiement : `make prod up`

Note : pour passer des options à ces commandes, entourez les de guillemets et mettez un espace en premier caractère : `make dev up " --remove-orphans --build"`