FROM ubuntu:latest

# RUN apt update && apt install -y libpcre3-dev libssl-dev libxml2-dev libxslt-dev libgd-dev libgeoip-dev libperl-dev wget build-essential git gettext-base
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gettext-base \
    git \
    libgd-dev \
    libgeoip-dev \
    libpcre2-dev \
    libperl-dev \
    libssl-dev \
    libxml2-dev \
    libxslt-dev \
    wget && \
    rm -rf /var/lib/apt/lists/*

COPY scripts/* common/nginx.conf naxsi/*  /tmp/

RUN chmod +x /tmp/*.sh && /tmp/create_naxsi-nginx.sh

CMD ["/tmp/process_templates.sh"]