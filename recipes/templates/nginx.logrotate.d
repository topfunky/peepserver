# TODO Make erb and use app variables
/var/log/nginx*.log /var/www/apps/nubyonrails.com/shared/log/nginx.*.log {
    daily
    rotate 7
    compress
    missingok
    sharedscripts
    postrotate
        /etc/init.d/nginx relog
    endscript
}
