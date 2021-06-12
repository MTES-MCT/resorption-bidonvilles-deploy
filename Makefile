include ./config/.env
export

dev:
	docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.dev.yml $(filter-out $@,$(MAKECMDGOALS))

prod:
	docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.prod.yml $(filter-out $@,$(MAKECMDGOALS))

exec:
	docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.prod.yml exec -T $(filter-out $@,$(MAKECMDGOALS))

localcert:
	envsubst < config/domains.ext.sample > config/domains.ext
	mkdir -p data/ssl
	openssl req -x509 -nodes -new -sha256 -days 360 -newkey rsa:2048 -keyout data/ssl/RootCA.key -out data/ssl/RootCA.pem -subj "/CN=RootCA"
	openssl x509 -outform pem -in data/ssl/RootCA.pem -out data/ssl/RootCA.crt
	openssl req -new -nodes -newkey rsa:2048 -keyout data/ssl/localhost.key -out data/ssl/localhost.csr -subj "/CN=localhost"
	openssl x509 -req -sha256 -days 360 -in data/ssl/localhost.csr -CA data/ssl/RootCA.pem -CAkey data/ssl/RootCA.key -CAcreateserial -extfile config/domains.ext -out data/ssl/localhost.crt

remotecert:
	mkdir -p data/ssl && openssl dhparam -out data/ssl/dhparam.pem 2048
	RB_PROXY_TEMPLATE=certonly \
	docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.prod.yml up -d rb_proxy \
		&& docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.prod.yml run rb_certbot -c 'certbot certonly --webroot --webroot-path=/var/www/certbot --email admin@resorption-bidonvilles.beta.gouv.fr --agree-tos --no-eff-email --force-renewal -d ${RB_PROXY_FRONTEND_HOST},${RB_PROXY_API_HOST}' \
		&& docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.prod.yml down

local_backup:
	docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.prod.yml exec -T rb_database_data local_backup

cloud_backup:
	./database/scripts/cloud_backup.sh