# syntax=docker/dockerfile:1.7.0

# ==========================================
# Stage 1 : Build sécurisé
# ==========================================
FROM alpine:3.21 AS builder
LABEL stage=builder

# Installation des dépendances de compilation et des outils de compatibilité
RUN apk add --no-cache \
    bash \
    build-base \
    dos2unix \
    gd-dev \
    geoip-dev \
    gettext \
    git \
    libxslt-dev \
    openssl-dev \
    pcre2-dev \
    perl-dev \
    wget

WORKDIR /build

# Copie des sources en conservant la structure des répertoires
COPY scripts/ ./scripts/
COPY common/ ./common/
COPY naxsi/ ./naxsi/

# Nettoyage global des variables de build et exécution
RUN dos2unix ./scripts/*.sh && \
    chmod +x ./scripts/*.sh && \
    # On force le script à ignorer les flags Ubuntu en injectant des variables de configuration vierges/propres
    export DEB_BUILD_MAINT_OPTIONS="" && \
    export DEB_CFLAGS_SET="" && \
    export DEB_LDFLAGS_SET="" && \
    # Flags de contournement GCC pour Alpine
    export CFLAGS="-Wno-error=macro-redefined -Wno-error" && \
    export EXTRA_CFLAGS="-Wno-macro-redefined" && \
    ./scripts/create_naxsi-nginx.sh

# ==========================================
# Stage 2 : Runtime (Image finale durcie)
# ==========================================
FROM alpine:3.21
LABEL maintainer="your-team@example.com" \
      description="NGINX with NAXSI WAF"

# Dépendances de runtime pures Alpine
RUN apk add --no-cache \
    ca-certificates \
    gd \
    geoip \
    libxslt \
    openssl \
    pcre2 \
    perl \
    tzdata

# Récupération du binaire Nginx compilé
COPY --from=builder --chown=root:root /usr/local/nginx /usr/local/nginx
RUN chmod -R go-w /usr/local/nginx

# Récupération et préparation du script d'entrypoint
COPY --from=builder /tmp/process_templates.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/process_templates.sh

# Création de l'utilisateur non-privilégié et des dossiers requis par Nginx
RUN addgroup -g 101 -S nginx && \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -g "nginx" nginx && \
    mkdir -p /var/cache/nginx /var/log/nginx /var/lib/nginx/tmp && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx /var/lib/nginx

USER nginx:nginx
EXPOSE 8080

# Healthcheck adapté au démarrage de l'entrypoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
    CMD /usr/local/nginx/sbin/nginx -t || exit 1

ENTRYPOINT ["/usr/local/bin/process_templates.sh"]