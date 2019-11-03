#### Ubuntu Linux Container
[![](https://images.microbadger.com/badges/image/catdeployed/nginxgw:latest.svg)](https://hub.docker.com/r/catdeployed/nginxgw/) [![](https://img.shields.io/microbadger/layers/catdeployed/nginxgw/latest.svg)](https://hub.docker.com/r/catdeployed/nginxgw/)

For this container, use the 'ubuntu' folder.

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
docker build -t catdeployed/nginxgw --build-arg NGINX_VER=1.15.8 --build-arg MODSECURITY_VER=3.0.3  .
```
