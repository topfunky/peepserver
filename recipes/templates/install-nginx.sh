#!/bin/sh

# Description: Installs nginx webserver from source. Places in subdirs of /usr/local/nginx.
#
# Author: Geoffrey Grosenbach http://topfunky.com
#
# MIT Licensed. Use at your own risk.

mkdir src
cd src

## http://www.pcre.org/
curl -O ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-7.1.tar.gz
tar xfz pcre-7.1.tar.gz
cd pcre-7.1
./configure --prefix=/usr/local
make
sudo make install
cd ..

## http://nginx.net/
# See also
## http://hiredgnu.co.za/category/nginx/
## http://www.degrunt.net/articles/2006/10/24/using-nginx-and-mongrel-cluster-on-osx

curl -O http://sysoev.ru/nginx/nginx-0.5.31.tar.gz
tar xfz nginx-0.5.31.tar.gz
cd nginx-0.5.31
./configure --with-http_ssl_module --prefix=/usr/local/nginx --with-pcre=../pcre-7.1
make
sudo make install

cd ..

# See also http://brainspl.at/articles/2007/01/03/new-nginx-conf-with-optimizations
echo "See http://topfunky.net/svn/shovel/nginx for config files and start scripts."
