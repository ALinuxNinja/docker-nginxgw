FROM ubuntu:xenial
SHELL ["/bin/bash", "-c"]

ARG NGINX_VER

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
	python"

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

## Build PSOL
RUN git clone -b master --recursive https://github.com/pagespeed/mod_pagespeed.git \
&& cd mod_pagespeed \
&& python build/gyp_chromium --depth=. \
&& make BUILDTYPE=Release mod_pagespeed_test pagespeed_automatic_test \
&& make AR.host=`pwd`/build/wrappers/ar.sh AR.target=`pwd`/build/wrappers/ar.sh BUILDTYPE=Release

## Build ModSecurity
RUN git clone https://github.com/SpiderLabs/ModSecurity \
&& cd ModSecurity \
&& git checkout v3/master \
&& git submodule init \
&& git submodule update \
&& ./build.sh \
&& ./configure --prefix=/usr \
&& make -j$(nproc) \
&& make install

## Build NGINX
RUN export NGINX_VER=${NGINX_MAINLINE_VER}$(lynx -dump -hiddenlinks=listonly http://nginx.org/download/ | awk '/http/{print $2}' | sed -n "s/^.*nginx-${NGINX_MAINLINE_VER}\.\(.*\)\.tar\.gz$/\1/p" | sort -V | tail -n1) \
&& wget http://nginx.org/download/nginx-${NGINX_VER}.tar.gz \
&& tar xf nginx-*.tar.gz && rm nginx-*.tar.gz && mv nginx-* nginx \
&& mkdir -p /docker/build/nginx/modules \
&& cd /docker/build/nginx/modules \
&& git clone https://github.com/kyprizel/testcookie-nginx-module.git ngx_testcookie \
&& git clone https://github.com/pagespeed/ngx_pagespeed.git \
&& cd /docker/build/nginx/modules/ngx_pagespeed \
&& wget $(scripts/format_binary_url.sh PSOL_BINARY_URL) \
&& tar -zxvf *.tar.gz \
&& cd /docker/build/nginx/modules \
&& git clone https://github.com/SpiderLabs/ModSecurity-nginx.git ngx_modsecurity \
&& ./configure $NGINX_CONFIG \
&& make -j$(nproc) \
&& make install \
&& mkdir -p /var/lib/nginx/body && chown -R www-data:www-data /var/lib/nginx \
&& strip /usr/sbin/nginx \
&& strip /usr/lib/libmodsecurity.so.3.0.0

FROM ubuntu:xenial

ARG BUILD_DATE
ARG VCS_REF
ARG NGINX_VER
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="nginxgw" \
      org.label-schema.description="A Custom NGINX build suitable for use as a front-end proxy" \
      org.label-schema.url="https://hub.docker.com/r/alinuxninja/nginxgw/" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/ALinuxNinja/docker-nginxgw/" \
      org.label-schema.vendor="ALinuxNinja" \
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
COPY --from=0 /usr/lib/libmodsecurity.so.3.0.0 /usr/lib/libmodsecurity.so.3.0.0

## Create Symlinks
RUN cd /usr/lib \
&& ln -s libmodsecurity.so.3.0.0 libmodsecurity.so.3

RUN apt-get update && apt-get -y install --no-install-recommends \
        $PACKAGES_REQUIRED \
&& rm -rf /var/lib/apt/lists/*

## Copy Config
RUN cp /docker/src/nginx/conf/nginx.conf /etc/nginx/nginx.conf \
&& cp /docker/src/nginx/conf/default.conf /etc/nginx/conf.d/default.conf

## Expose
EXPOSE 80
EXPOSE 443

ENTRYPOINT ["/usr/sbin/nginx"]
CMD [ "-g", "daemon off;"]
