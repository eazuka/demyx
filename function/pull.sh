# Demyx
# https://demyx.sh
# 
# demyx pull <image>
#
demyx_pull() {
    DEMYX_PULL_IMAGE="$1"

    if [[ "$DEMYX_PULL_IMAGE" = all ]]; then
        [[ -n "$(docker images demyx/browsersync -q)" ]] && docker pull demyx/browsersync
        docker pull demyx/code-server:browse
        # Pull other variations of code-server
        [[ -n "$(docker images demyx/code-server:openlitespeed -q)" ]] && docker pull demyx/code-server:openlitespeed
        [[ -n "$(docker images demyx/code-server:openlitespeed-sage -q)" ]] && docker pull demyx/code-server:openlitespeed-sage
        [[ -n "$(docker images demyx/code-server:sage -q)" ]] && docker pull demyx/code-server:sage
        [[ -n "$(docker images demyx/code-server:wp -q)" ]] && docker pull demyx/code-server:wp
        docker pull demyx/demyx
        docker pull demyx/docker-compose
        docker pull demyx/docker-socket-proxy
        docker pull demyx/logrotate
        docker pull demyx/mariadb
        docker pull demyx/nginx
        [[ -n "$(docker images demyx/ssh -q)" ]] && docker pull demyx/ssh
        docker pull demyx/traefik
        docker pull demyx/utilities
        docker pull demyx/wordpress
        # Pull Bedrock
        [[ -n "$(docker images demyx/wordpress:bedrock -q)" ]] && docker pull demyx/wordpress:bedrock
        docker pull demyx/wordpress:cli

        # Third party images
        docker pull phpmyadmin/phpmyadmin
    elif [[ -n "$DEMYX_PULL_IMAGE" ]]; then
        if [[ "$DEMYX_PULL_IMAGE" = pma || "$DEMYX_PULL_IMAGE" = phpmyadmin ]]; then
            docker pull phpmyadmin/phpmyadmin
        else
            docker pull demyx/"$DEMYX_PULL_IMAGE"
        fi
    else
        demyx help pull
    fi
}
