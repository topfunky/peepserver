#!/bin/sh

##
# Install the runit process launcher.
#
# Should be run as the root user.
#
# Built for CentOS as found at RailsMachine hosting. http://railsmachine.com
#
# Author:   Geoffrey Grosenbach http://peepcode.com
# Original: http://smarden.sunsite.dk/runit/install.html
# See also: http://www.sanityinc.com/articles/init-scripts-considered-harmful

mkdir /package
chmod 1755 /package
cd /package
wget http://smarden.sunsite.dk/runit/runit-2.0.0.tar.gz
tar xfz runit-2.0.0.tar.gz
rm !$
cd admin/runit-2.0.0
./package/install

# Install alongside traditional sysvinit and inittab
install -m0750 /package/admin/runit/etc/2 /sbin/runsvdir-start
mkdir -p /service
mkdir -p /etc/sv

cat >>/etc/inittab <<EOT
SV:123456:respawn:/sbin/runsvdir-start
EOT

init q
