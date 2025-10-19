FROM openresty/openresty:1.21.4.1-0-alpine

RUN apk add --no-cache perl curl
RUN opm get ledgetech/lua-resty-http

RUN apk del perl curl

RUN mkdir -p /var/app/www \
    && chmod 777 -R /var/app/www \
    && mkdir -p /var/logs/openresty \
    && ln -sf /dev/stdout /var/logs/openresty/error.log \
    && ln -sf /dev/stderr /var/logs/openresty/access.log

ENV WWW_DIR=/var/app/www


COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY src /opt/app/src

EXPOSE 8000
