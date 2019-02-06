FROM ubuntu:xenial
SHELL ["/bin/bash", "-c"]

ARG NGINX_VER
ARG MODSECURITY_VER

## Set Packages to add
ENV PACKAGES_BUILD="\
	git-core \
	build-essential \
	zlib1g-dev \
	libpcre3-dev \
	unzip \
	wget \
	libssl-dev \
	automake \
	autoconf \
	libtool \
	libgeoip-dev \
	libxml2-dev \
	libcurl4-openssl-dev \
	libyajl-dev \
	liblmdb0 \
	liblmdb-dev \
	ca-certificates \
	curl \
	gperf \
	uuid-dev \
	libuuid1 \
	lsb-release \
	python \
	lynx"

ENV NGINX_CONFIG="\
	--prefix=/usr \
	--conf-path=/etc/nginx/nginx.conf \
	--http-log-path=/var/log/nginx/access.log \
	--error-log-path=/var/log/nginx/error.log \
	--lock-path=/var/lock/nginx.lock \
	--pid-path=/run/nginx.pid \
	--modules-path=/usr/lib/nginx/modules \
	--http-client-body-temp-path=/var/lib/nginx/body \
	--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
	--http-proxy-temp-path=/var/lib/nginx/proxy \
	--http-scgi-temp-path=/var/lib/nginx/scgi \
	--http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
	--with-pcre-jit \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--with-http_auth_request_module \
	--with-http_v2_module \
	--with-http_dav_module \
	--with-http_slice_module \
	--with-threads \
	--with-http_gzip_static_module \
	--without-http_split_clients_module \
	--without-http_userid_module \
	--add-module=modules/ngx_testcookie \
	--add-module=modules/ngx_pagespeed \
	--add-module=modules/ngx_modsecurity \
	--user=www-data \
	--group=www-data"

## Create Folders
RUN mkdir -p /docker/build

## Add Additional Source Files
ADD src /docker/src

## Set Workdir
WORKDIR /docker/build

## Install Packages
RUN apt-get update && apt-get -y install --no-install-recommends $PACKAGES_BUILD \
&& rm -rf /var/lib/apt/lists/*

## Set Git config
RUN git config --global http.postBuffer 1048576000

## Build Pagespeed
RUN git clone -b latest-beta https://github.com/apache/incubator-pagespeed-ngx.git ngx_pagespeed \
&& cd ngx_pagespeed \
&& wget $(scripts/format_binary_url.sh PSOL_BINARY_URL) \
&& tar -xzvf *.tar.gz

## Build ModSecurity
RUN git clone https://github.com/SpiderLabs/ModSecurity \
&& cd ModSecurity \
&& git checkout v${MODSECURITY_VER} \
&& git submodule init \
&& git submodule update \
&& ./build.sh \
&& ./configure --prefix=/usr \
&& make -j$(nproc) \
&& make install

## Build NGINX
RUN wget http://nginx.org/download/nginx-${NGINX_VER}.tar.gz \
&& tar xf nginx-*.tar.gz && rm nginx-*.tar.gz && mv nginx-* nginx \
&& cd nginx \
&& mkdir modules \
&& git clone https://github.com/kyprizel/testcookie-nginx-module.git modules/ngx_testcookie \
&& git clone https://github.com/SpiderLabs/ModSecurity-nginx.git modules/ngx_modsecurity \
&& mv /docker/build/ngx_pagespeed/ modules/ngx_pagespeed/ \
&& ./configure $NGINX_CONFIG \
&& make -j$(nproc) \
&& make install \
&& mkdir -p /var/lib/nginx/body && chown -R www-data:www-data /var/lib/nginx \
&& strip /usr/sbin/nginx \
&& strip /usr/lib/libmodsecurity.so.${MODSECURITY_VER}

FROM ubuntu:xenial

ARG NGINX_VER
ARG MODSECURITY_VER
LABEL org.label-schema.name="nginxgw" \
      org.label-schema.description="A Custom NGINX build suitable for use as a front-end proxy" \
      org.label-schema.url="https://hub.docker.com/r/catdeployed/nginxgw/" \
      org.label-schema.vcs-url="https://github.com/CatDeployed/docker-nginxgw/" \
      org.label-schema.vendor="CatDeployed" \
      org.label-schema.version=$NGINX_VER \
      org.label-schema.schema-version="1.0"

ENV PACKAGES_REQUIRED="\
        libssl1.0.0 \
        libcurl3 \
        libgeoip1 \
        libyajl2 \
        libxml2"

## Copy Over from other container
COPY --from=0 /usr/sbin/nginx /usr/sbin/nginx
COPY --from=0 /etc/nginx /etc/nginx
COPY --from=0 /var/log/nginx /var/log/nginx
COPY --from=0 /var/lib/nginx /var/lib/nginx
COPY --from=0 /usr/html /var/www/html
COPY --from=0 /usr/lib/libmodsecurity.so.$MODSECURITY_VER /usr/lib/libmodsecurity.so.$MODSECURITY_VER
COPY --from=0 /docker/src/nginx/conf/nginx.conf /etc/nginx/nginx.conf
COPY --from=0 /docker/src/nginx/conf/default.conf /etc/nginx/conf.d/default.conf

## Create Symlinks
RUN cd /usr/lib \
&& ln -s libmodsecurity.so.${MODSECURITY_VER} libmodsecurity.so.3

RUN apt-get update && apt-get -y install --no-install-recommends \
        $PACKAGES_REQUIRED \
&& rm -rf /var/lib/apt/lists/*

## Expose
EXPOSE 80
EXPOSE 443

ENTRYPOINT ["/usr/sbin/nginx"]
CMD [ "-g", "daemon off;"]
