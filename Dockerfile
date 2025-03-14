#syntax=docker/dockerfile:1

# Versions
FROM dunglas/frankenphp:php8.4 AS frankenphp_upstream

# The different stages of this Dockerfile are meant to be built into separate images
# https://docs.docker.com/develop/develop-images/multistage-build/#stop-at-a-specific-build-stage
# https://docs.docker.com/compose/compose-file/#target


# Base FrankenPHP image
FROM frankenphp_upstream AS frankenphp_base

WORKDIR /app

VOLUME /app/var/

# persistent / runtime deps
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
	acl \
	file \
	gettext \
	git \
	&& rm -rf /var/lib/apt/lists/*

RUN set -eux; \
	install-php-extensions \
		@composer \
		apcu \
		intl \
		opcache \
		zip \
	;

## »»» juliendufresne/adventofcode —————————————————————————————————————————————————————————————————————————————————————
# fix composer issue with git "detected dubious ownership in repository"
RUN git config --global --add safe.directory /app
## ««« juliendufresne/adventofcode —————————————————————————————————————————————————————————————————————————————————————

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

ENV PHP_INI_SCAN_DIR=":$PHP_INI_DIR/app.conf.d"

###> recipes ###
###< recipes ###

COPY --link frankenphp/conf.d/10-app.ini $PHP_INI_DIR/app.conf.d/
COPY --link --chmod=755 frankenphp/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --link frankenphp/Caddyfile /etc/caddy/Caddyfile

ENTRYPOINT ["docker-entrypoint"]

HEALTHCHECK --start-period=60s CMD curl -f http://localhost:2019/metrics || exit 1
CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile" ]

# Dev FrankenPHP image
FROM frankenphp_base AS frankenphp_dev

ENV APP_ENV=dev XDEBUG_MODE=off

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

RUN set -eux; \
	install-php-extensions \
		xdebug \
	;

## »»» juliendufresne/adventofcode —————————————————————————————————————————————————————————————————————————————————————
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG LIB_SRC_DIR=/usr/local/src

# Add phpstan
COPY --link frankenphp/phpstan $LIB_SRC_DIR/phpstan

# hadolint ignore=DL3008
RUN <<EOF
# Add [docker] to the prompt for developers to distinguish in what machine they are on their terminal
sed -i "s/PS1='\${debian_chroot/PS1='\\\033[38;5;36m[docker]\\\033[39m \${debian_chroot/" /etc/bash.bashrc

# install phpstan
composer update \
         --quiet \
         --no-interaction \
         --working-dir=$LIB_SRC_DIR/phpstan \
         --optimize-autoloader \
         --classmap-authoritative \
         --prefer-stable \
         --with-all-dependencies \
         --bump-after-update
composer clear-cache
ln -s $LIB_SRC_DIR/phpstan/vendor/bin/phpstan /usr/local/bin/phpstan

# install bash-completion and make
apt-get update
apt-get -y --no-install-recommends install \
    bash-completion \
    make
rm -rf /var/lib/apt/lists/*

# enable bash-completion in bashrc
sed -i '/#if ! shopt -oq posix; then/,/^#fi/s/#//' /etc/bash.bashrc

# enable bash completion for composer script
composer completion bash | tee /etc/bash_completion.d/composer

# enable bash completion for symfony console
# Note: docker is not aware of our current code so we have to create a symfony
#       project and extract the completion bash script from it, then remove the
#       project
tmp="$( mktemp -d )"
composer create-project "symfony/skeleton ${SYMFONY_VERSION:-}" "$tmp" \
         --stability="${STABILITY:-stable}" \
         --prefer-dist \
         --no-progress \
         --no-interaction
"$tmp/bin/console" completion bash | tee /etc/bash_completion.d/symfony_console
rm -rf "$tmp"

# enable bash completion for phpstan
/usr/local/bin/phpstan completion bash | tee /etc/bash_completion.d/phpstan
EOF

## ««« juliendufresne/adventofcode —————————————————————————————————————————————————————————————————————————————————————

COPY --link frankenphp/conf.d/20-app.dev.ini $PHP_INI_DIR/app.conf.d/

CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile", "--watch" ]

# Prod FrankenPHP image
FROM frankenphp_base AS frankenphp_prod

ENV APP_ENV=prod
ENV FRANKENPHP_CONFIG="import worker.Caddyfile"

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY --link frankenphp/conf.d/20-app.prod.ini $PHP_INI_DIR/app.conf.d/
COPY --link frankenphp/worker.Caddyfile /etc/caddy/worker.Caddyfile

# prevent the reinstallation of vendors at every changes in the source code
COPY --link composer.* symfony.* ./
RUN set -eux; \
	composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

# copy sources
COPY --link . ./
RUN rm -Rf frankenphp/

RUN set -eux; \
	mkdir -p var/cache var/log; \
	composer dump-autoload --classmap-authoritative --no-dev; \
	composer dump-env prod; \
	composer run-script --no-dev post-install-cmd; \
	chmod +x bin/console; sync;
