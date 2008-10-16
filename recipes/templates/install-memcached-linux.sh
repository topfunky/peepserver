#!/bin/sh

# Install memcached and dependencies.
#
# By Geoffrey Grosenbach http://topfunky.com
#
# USE AT YOUR OWN RISK

wget http://www.monkey.org/~provos/libevent-1.3b.tar.gz
tar xfz libevent-1.3b.tar.gz
cd libevent-1.3b
./configure && make && make verify
sudo make install

echo "You may need to add /usr/local/lib to /etc/ld.so.conf or create a new file in /etc/ld.so.conf.d that references it. You'll also need to run ldconfig if you do either of those."

wget http://danga.com/memcached/dist/memcached-1.2.2.tar.gz
tar xfz memcached-1.2.2.tar.gz
cd memcached-1.2.2
./configure && make && make test
sudo make install

