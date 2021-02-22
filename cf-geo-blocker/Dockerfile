FROM alpine:3

ENV LIBMAXMINDDB_VERSION=${LIBMAXMINDDB_VERSION:-1.5.0}
ENV NGINX_VERSION=${NGINX_VERSION:-1.19.6}
ENV NGX_HTTP_GEOIP2_MODULE_VERSION=${NGX_HTTP_GEOIP2_MODULE_VERSION:-3.3}
ENV GEOIP_UPDATE_VERSION=${GEOIP_UPDATE_VERSION:-4.6.0}

RUN addgroup -g 101 -S nginx && \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx

RUN mkdir -p /var/log/nginx && \
    touch /var/log/nginx/access.log && \
    chown nginx:nginx /var/log/nginx/access.log && \
    touch /var/log/nginx/error.log && \
    chown nginx:nginx /var/log/nginx/error.log
RUN mkdir -p /var/log/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    chown nginx:nginx /var/log/nginx/access.log && \
    chown nginx:nginx /var/log/nginx/error.log

WORKDIR /usr/share

COPY pkgs.lst .
#RUN while read pkg; do echo $pkg | xargs apk add --no-cache -q && echo "Installing: ${pkg}"; done < pkgs.lst
RUN while read pkg; do echo $pkg | xargs apk add --no-cache -q; done < pkgs.lst

# Download and install the required MaxMind tool
RUN echo "Downloading and Installing libmaxminddb: ${LIBMAXMINDDB_VERSION}" && \
    curl -sLO "https://github.com/maxmind/libmaxminddb/releases/download/${LIBMAXMINDDB_VERSION}/libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz" && \
    mkdir -p libmaxminddb && \
    tar -xf libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz -C libmaxminddb --strip-components 1 && \
    cd libmaxminddb && \
    ./configure -q && \
    make && \
    make install && \
    ln -s /usr/local/bin/mmdblookup /usr/bin/mmdblookup

# Download the ngx_http_geoip2_module for nginx
RUN echo "Downloading and Installing ngx_http_geoip2_module: ${NGX_HTTP_GEOIP2_MODULE_VERSION}" && \
    curl -sLO "https://github.com/leev/ngx_http_geoip2_module/archive/${NGX_HTTP_GEOIP2_MODULE_VERSION}.tar.gz" && \
    mkdir -p ngx_http_geoip2_module && \
    tar -xf "${NGX_HTTP_GEOIP2_MODULE_VERSION}.tar.gz" -C ngx_http_geoip2_module --strip-components 1

# Download the geoipupdate utility
    RUN echo "Downloading and Installing geoipupdate: ${GEOIP_UPDATE_VERSION}" && \
        env GO111MODULE=on go get -u github.com/maxmind/geoipupdate/v4/cmd/geoipupdate && \
        ln -s /root/go/bin/geoipupdate /usr/bin/geoipupdate

RUN echo "Downloading and Installing nginx: ${NGINX_VERSION}" && \
    curl -sLO "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" && \
    mkdir -p /etc/nginx && \
    tar -xf nginx-${NGINX_VERSION}.tar.gz -C /etc/nginx --strip-components 1

WORKDIR /etc/nginx
RUN ./configure \
    --pid-path=/var/run/nginx.pid \
    --add-dynamic-module=/usr/share/ngx_http_geoip2_module \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin \
    --conf-path=/etc/nginx \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-http_geoip_module=dynamic \
    --with-stream=dynamic && \
    make && \
    make install && \
    ln -s /usr/sbin/nginx /bin/nginx

# Tidying up
RUN rm -rf /usr/share/nginx/* \
    /etc/nginx/CHANGES* \
    /etc/nginx/Makefile* \
    /etc/nginx/README \
    /etc/nginx/src \
    /etc/nginx/configure

EXPOSE 80
RUN chown -R nginx:nginx /etc/nginx
COPY entrypoint.sh /etc/nginx
COPY GeoIP.conf.tmpl /usr/local/share/
COPY nginx.conf /etc/nginx/
COPY proxy.conf /etc/nginx/
COPY update_geoip_dbs.sh /etc/periodic/weekly/
COPY update_geoip_dbs.sh /etc/periodic/15min/


RUN chmod +x /etc/nginx/entrypoint.sh && \
    chmod +x /etc/periodic/15min/update_geoip_dbs.sh
ENTRYPOINT ["/etc/nginx/entrypoint.sh"]

STOPSIGNAL SIGQUIT

CMD ["/usr/sbin/nginx", "-c", "/etc/nginx/nginx.conf", "-g", "daemon off;"]
