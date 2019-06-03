#!/bin/bash
# Demyx
# https://demyx.sh

DEMYX_DOCKER_CHECK=$(which docker)
DEMYX_SUDO_CHECK=$(id -u)
DEMYX_BASH_CHECK=$(which bash)

if [[ -z "$DEMYX_BASH_CHECK" ]]; then
    echo -e "\e[31m[CRITICAL]\e[39m Please install bash"
    exit 1
fi

if [[ "$DEMYX_SUDO_CHECK" != 0 ]]; then
    echo -e "\e[31m[CRITICAL]\e[39m Must be ran as root or sudo"
    exit 1
fi

if [[ -z "$DEMYX_DOCKER_CHECK" ]]; then
    echo -e "\e[31m[CRITICAL]\e[39m Docker must be installed"
    exit 1
fi

docker pull demyx/demyx
docker pull demyx/browsersync
docker pull demyx/docker-compose
docker pull demyx/logrotate
docker pull demyx/mariadb
docker pull demyx/nginx-php-wordpress
docker pull demyx/ssh
docker pull demyx/utilities
docker pull wordpress:cli
docker pull phpmyadmin/phpmyadmin
docker pull pyouroboros/ouroboros
docker pull quay.io/vektorlab/ctop
docker network create demyx

demyx stack --down

if [ -f /usr/local/bin/demyx ]; then
    rm /usr/local/bin/demyx
fi

wget demyx.sh/chroot -qO /usr/local/bin/demyx
chmod +x /usr/local/bin/demyx

demyx --dev --nc

echo -e "\e[34m[INFO]\e[39m Waiting for demyx container to initialize"
sleep 5

docker cp "$HOME"/.ssh/authorized_keys demyx:/home/demyx/.ssh
demyx --dev --nc

source /srv/demyx/etc/.env
cat > /srv/demyx/etc/.env <<-EOF
# AUTO GENERATED
DEMYX_STACK_DOMAIN=$PRIMARY_DOMAIN
DEMYX_STACK_AUTH=$BASIC_AUTH_USER:$(grep -s BASIC_AUTH_PASSWORD /srv/demyx/etc/.env | awk -F '[=]' '{print $2}' || true)
DEMYX_STACK_RECENT_ERRORS=100
DEMYX_STACK_DOCKER_WATCH=true
DEMYX_STACK_DOCKER_EXPOSED_BY_DEFAULT=false
DEMYX_STACK_ENTRYPOINT_DEFAULTENTRYPOINTS=http,https
DEMYX_STACK_ACME_ONHOSTRULE=true
DEMYX_STACK_ACME_EMAIL=info@$PRIMARY_DOMAIN
DEMYX_STACK_ACME_STORAGE=/demyx/acme.json
DEMYX_STACK_ACME_ENTRYPOINT=https
DEMYX_STACK_ACME_HTTPCHALLENGE_ENTRYPOINT=http
DEMYX_STACK_LOG_LEVEL=INFO
DEMYX_STACK_LOG_ACCESS=/var/log/demyx/access.log
DEMYX_STACK_LOG_ERROR=/var/log/demyx/error.log
DEMYX_FORCE_STS_HEADER=true
DEMYX_STS_SECONDS=315360000
DEMYX_STS_INCLUDE_SUBDOMAINS=true
DEMYX_STS_PRELOAD=true
EOF

echo -e "\e[34m[INFO]\e[39m Configuring Traefik"

docker run -dt --rm \
--name demyx_traefik \
-v demyx_traefik:/demyx \
demyx/utilities bash

docker cp /srv/demyx/etc/traefik/acme.json demyx_traefik:/demyx
docker cp /srv/demyx/etc/.env demyx:/demyx/app/stack
docker exec -t demyx_traefik chmod 600 /demyx/acme.json
docker stop demyx_traefik
docker exec -t demyx demyx update

cd /srv/demyx/apps

for i in *
do
    DEMYX_NON_WP=$(grep wordpress /srv/demyx/apps/"$i"/docker-compose.yml || true)
    if [[ -z "$DEMYX_NON_WP" ]]; then
        echo -e "\e[34m[$i]\e[39m Replacing network to demyx"
        sed -i "s/traefik/demyx/g" /srv/demyx/apps/"$i"/docker-compose.yml
        cd /srv/demyx/apps/"$i" && docker-compose up -d
    fi
done

cd /srv/demyx/apps

for i in *
do
    if [[ -f /srv/demyx/apps/"$i"/.env ]]; then
        source /srv/demyx/apps/"$i"/.env
    else
        continue
    fi

    [[ -z "$WP_ID" ]] && continue

    mkdir -p /srv/demyx/apps/"$i"/config
  
    DEMYX_SSL_CHECK=$(docker run -t --rm demyx/utilities "curl -I $DOMAIN" | grep 307 || true)
    DEMYX_CDN_CHECK=$(docker exec -t "$WP" ls wp-content/plugins | grep cdn-enabler || true)

    if [[ -n "$DEMYX_SSL_CHECK" ]];  then
        DEMYX_APP_SSL=on
    else
        DEMYX_APP_SSL=off
    fi

    if [[ -n "$DEMYX_CDN_CHECK" ]];  then
        DEMYX_CDN_CHECK=on
    else
        DEMYX_CDN_CHECK=off
    fi

    cat > /srv/demyx/apps/"$i"/.env <<-EOF
    # AUTO GENERATED
    DEMYX_APP_ID=$WP_ID
    DEMYX_APP_TYPE=wp
    DEMYX_APP_PATH=/demyx/app/wp/$DOMAIN
    DEMYX_APP_CONFIG=/demyx/app/wp/$DOMAIN/config
    DEMYX_APP_CONTAINER=$CONTAINER_NAME
    DEMYX_APP_DOMAIN=$DOMAIN
    DEMYX_APP_SSL=$DEMYX_APP_SSL
    DEMYX_APP_RATE_LIMIT=on
    DEMYX_APP_AUTH=off
    DEMYX_APP_CACHE=$FASTCGI_CACHE
    DEMYX_APP_CDN=$DEMYX_CDN_CHECK
    DEMYX_APP_DEV=off
    DEMYX_APP_MONITOR_THRESHOLD=3
    DEMYX_APP_MONITOR_SCALE=5
    DEMYX_APP_MONITOR_CPU=25
    DEMYX_APP_FORCE_STS_HEADER=true
    DEMYX_APP_STS_SECONDS=315360000
    DEMYX_APP_STS_INCLUDE_SUBDOMAINS=true
    DEMYX_APP_STS_PRELOAD=true
    DEMYX_APP_WP_CONTAINER=$WP
    DEMYX_APP_DB_CONTAINER=$DB
    WORDPRESS_USER=$WORDPRESS_USER
    WORDPRESS_USER_PASSWORD=$WORDPRESS_USER_PASSWORD
    WORDPRESS_USER_EMAIL=info@$DOMAIN
    WORDPRESS_DB_HOST=$WORDPRESS_DB_HOST
    WORDPRESS_DB_NAME=$WORDPRESS_DB_NAME
    WORDPRESS_DB_USER=$WORDPRESS_DB_USER
    WORDPRESS_DB_PASSWORD=$WORDPRESS_DB_PASSWORD
    MARIADB_ROOT_PASSWORD=$MARIADB_ROOT_PASSWORD
    MARIADB_DEFAULT_CHARACTER_SET=utf8
    MARIADB_CHARACTER_SET_SERVER=utf8
    MARIADB_COLLATION_SERVER=utf8_general_ci
    MARIADB_KEY_BUFFER_SIZE=32M
    MARIADB_MAX_ALLOWED_PACKET=16M
    MARIADB_TABLE_OPEN_CACHE=2000
    MARIADB_SORT_BUFFER_SIZE=4M
    MARIADB_NET_BUFFER_SIZE=4M
    MARIADB_READ_BUFFER_SIZE=2M
    MARIADB_READ_RND_BUFFER_SIZE=1M
    MARIADB_MYISAM_SORT_BUFFER_SIZE=32M
    MARIADB_LOG_BIN=mysql-bin
    MARIADB_BINLOG_FORMAT=mixed
    MARIADB_SERVER_ID=1
    MARIADB_INNODB_DATA_FILE_PATH=ibdata1:10M:autoextend
    MARIADB_INNODB_BUFFER_POOL_SIZE=32M
    MARIADB_INNODB_LOG_FILE_SIZE=5M
    MARIADB_INNODB_LOG_BUFFER_SIZE=8M
    MARIADB_INNODB_FLUSH_LOG_AT_TRX_COMMIT=1
    MARIADB_INNODB_LOCK_WAIT_TIMEOUT=50
    MARIADB_INNODB_USE_NATIVE_AIO=1
    MARIADB_READ_BUFFER=2M
    MARIADB_WRITE_BUFFER=2M
    MARIADB_MAX_CONNECTIONS=100
EOF
    echo -e "\e[34m[$i]\e[39m Migrating to demyx"
    docker cp /srv/demyx/apps/"$i" demyx:/demyx/app/wp
    docker stop "$WP"
    docker rm "$WP"
    docker exec -t demyx demyx compose "$i" up -d
    docker exec -t demyx demyx config "$i" --refresh
done

docker cp /srv/demyx/custom/. demyx:/demyx/custom

echo -e "\e[34m[$i]\e[39m Removing old cron from host"
crontab -l > /srv/demyx/cron_tmp
sed -i '\/srv\/demyx\/etc\/cron/d' /srv/demyx/cron_tmp
crontab /srv/demyx/cron_tmp
demyx --rs
