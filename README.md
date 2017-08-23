[![Build Status](https://semaphoreci.com/api/v1/alinuxninja/docker-nginxgw/branches/stable/badge.svg)](https://semaphoreci.com/alinuxninja/docker-nginxgw) [![](https://images.microbadger.com/badges/image/alinuxninja/nginxgw.svg)](https://microbadger.com/images/alinuxninja/nginxgw) [![](https://images.microbadger.com/badges/version/alinuxninja/nginxgw.svg)](https://hub.docker.com/r/alinuxninja/nginxgw/ )

## About
This container is a stripped down version of NGINX optimized for usage as a frontend proxy.

Additional Modules:
- Modsecurity (v3)
- testcookie
- pagespeed

## Building
When building, specify the correct NGINX version to build. Automatic version builds are avaliable at Docker Hub, which can be accessed from the badges.

For example:
```
docker build --build-arg NGINX_VER=1.13.0 -t alinuxninja/nginxgw:latest .
```
