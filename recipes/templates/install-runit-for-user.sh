#!/bin/sh

##
# Install the runit process launcher for a specific user.
#
# Should be run that user. Will also call sudo for some commands.
#
# Built for CentOS as found at RailsMachine hosting. http://railsmachine.com
#
# Author:   Geoffrey Grosenbach http://peepcode.com
# See also: http://www.sanityinc.com/articles/init-scripts-considered-harmful
# And also: http://smarden.sunsite.dk/runit/install.html

sudo mkdir -p /etc/sv/$USER

mkdir ~/service

cat >/tmp/run <<EOT
#!/bin/sh
exec 2>&1 
exec chpst -u $USER /usr/local/bin/runsvdir $HOME/service 'log: ...........................................................................................................................................................................................................................................................................................................................................................................................................'
EOT
sudo mv /tmp/run /etc/sv/$USER/run
sudo chmod +x !$
