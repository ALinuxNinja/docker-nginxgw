# Nginx Gateway Docker Container

## Usage
```
docker run -d -p 80:80 alinuxninja/nginxgw
```
As NGINX is installed in the standard location, new configuration can simply be mounted at /etc/nginx/nginx.conf as needed.

## About
This container is likely useful to those that are running a web gateway setup where all content is proxied through a frontend server.
The version of NGINX here brings a few features that are likely useful.

Modules:
- [ModSecurity](https://github.com/SpiderLabs/ModSecurity-nginx)
- [testcookie](https://github.com/kyprizel/testcookie-nginx-module)
- [pagespeed](https://github.com/pagespeed/ngx_pagespeed)

NGINX has also been stripped down by a bit to make it more efficient. Only "latest" tag avaliable at the moment due to testing.
