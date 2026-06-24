# syntax=docker/dockerfile:1.7.0

# ==========================================
# Stage 1 : Compilation native sur Alpine
# ==========================================
FROM alpine:3.21 AS builder
LABEL stage=builder

ARG NGINX_VERSION=1.26.2
# NAXSI maintenu (fork wargio/libnaxsi), compatible PCRE2 et nginx récent.
# Figé sur un tag : cloner la branche par défaut récupèrerait un HEAD instable.
ARG NAXSI_VERSION=1.7

RUN apk add --no-cache \
    build-base \
    gd-dev \
    geoip-dev \
    gettext \
    git \
    libxslt-dev \
    linux-headers \
    openssl-dev \
    pcre2-dev \
    wget

WORKDIR /tmp

RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -zxf nginx-${NGINX_VERSION}.tar.gz && \
    git clone --depth 1 --branch "${NAXSI_VERSION}" --recurse-submodules https://github.com/wargio/naxsi.git

WORKDIR /tmp/nginx-${NGINX_VERSION}

RUN ./configure \
    --prefix=/usr/local/nginx \
    --sbin-path=/usr/local/nginx/sbin/nginx \
    --conf-path=/usr/local/nginx/conf/nginx.conf \
    --pid-path=/tmp/nginx.pid \
    --lock-path=/tmp/nginx.lock \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_xslt_module \
    --with-http_geoip_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_degradation_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-stream_geoip_module \
    --add-module=/tmp/naxsi/naxsi_src \
    --with-threads \
    --with-compat

RUN make -j$(nproc) && make install
RUN cp /tmp/naxsi/naxsi_rules/naxsi_core.rules /usr/local/nginx/conf/

# ==========================================
# Stage 2 : Runtime (Image finale durcie)
# ==========================================
FROM alpine:3.21
LABEL maintainer="your-team@example.com" \
      description="NGINX with NAXSI WAF - Native Alpine Build"

RUN apk add --no-cache \
    ca-certificates \
    gd \
    geoip \
    gettext \
    libxslt \
    openssl \
    pcre2 \
    tzdata

RUN addgroup -g 101 -S nginx && \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -g "nginx" nginx

COPY --from=builder --chown=root:root /usr/local/nginx /usr/local/nginx
RUN chmod -R go-w /usr/local/nginx

COPY common/ /usr/local/nginx/conf/
COPY http.conf /usr/local/nginx/conf/http.conf
COPY naxsi/ /usr/local/nginx/conf/naxsi/

# Les includes des vhosts et de http.conf sont relatifs au préfixe /usr/local/nginx/conf
RUN mkdir -p /usr/local/nginx/conf/conf.d /usr/local/nginx/conf/templates && \
    chown -R nginx:nginx /usr/local/nginx/conf

COPY scripts/process_templates.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/process_templates.sh

RUN mkdir -p /var/cache/nginx /var/log/nginx /var/lib/nginx/tmp && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx /var/lib/nginx

USER nginx:nginx
EXPOSE 8080 8443

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
    CMD /usr/local/nginx/sbin/nginx -t || exit 1

ENTRYPOINT ["/usr/local/bin/process_templates.sh"]