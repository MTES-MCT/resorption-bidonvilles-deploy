include ./config/.env
export

dev:
	docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.dev.yml $(filter-out $@,$(MAKECMDGOALS))

prod:
	docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.prod.yml $(filter-out $@,$(MAKECMDGOALS))

initcertificate:
	docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.prod.yml up -d rb_proxy \
		&& docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.prod.yml run rb_certbot -c 'certbot certonly --webroot --webroot-path=/var/www/certbot --email admin@resorption-bidonvilles.beta.gouv.fr --agree-tos --no-eff-email --force-renewal -d ${RB_PROXY_FRONTEND_HOST},${RB_PROXY_API_HOST}' \
		&& docker-compose --env-file ./config/.env -f docker-compose.yml -f docker-compose.prod.yml down