ARG PHP_VERSION=7.2

FROM php:${PHP_VERSION}-fpm-alpine

LABEL maintainer="Johannes Engel <jcnengel@gmail.com>"

#####
# SYSTEM REQUIREMENT
#####
ARG INVOICENINJA_VERSION
WORKDIR /var/www/app

COPY entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

RUN set -eux; \
    apk add --no-cache \
    gmp-dev \
    freetype-dev \
    libarchive-tools \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev\ 
    libzip-dev

RUN docker-php-ext-configure gd --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include --with-webp-dir=/usr/include --with-freetype-dir=/usr/include/; \
	docker-php-ext-configure zip --with-libzip; \
	docker-php-ext-install -j$(nproc) \
       iconv \
       gd \
       gmp \
       mbstring \
       opcache \
       pdo \
       pdo_mysql \
       zip

COPY ./config/php/php.ini /usr/local/etc/php/php.ini
COPY ./config/php/php-cli.ini /usr/local/etc/php/php-cli.ini

# Separate user
ENV IN_USER=invoiceninja

RUN addgroup -S "$IN_USER" && \
    adduser \
    --disabled-password \
    --gecos "" \
    --home "$(pwd)" \
    --ingroup "$IN_USER" \ 
    --no-create-home \
    "$IN_USER"; \
    addgroup "$IN_USER" www-data; \
    chown -R "$IN_USER":"$IN_USER" .

# Install requirements
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin \
        --filename=composer;

USER $IN_USER

# Download and install IN
ENV INVOICENINJA_VERSION="${INVOICENINJA_VERSION}"

RUN curl -s -o /tmp/ninja.zip -SL https://github.com/invoiceninja/invoiceninja/archive/master.zip \
    && bsdtar --strip-components=1 -C /var/www/app -xf /tmp/ninja.zip \
    && rm /tmp/ninja.zip \
    && mv /var/www/app/storage /var/www/app/docker-backup-storage  \
    && mv /var/www/app/public /var/www/app/docker-backup-public  \
    && mkdir -p /var/www/app/public/logo /var/www/app/storage \
    && cp /var/www/app/.env.example /var/www/app/.env \
    && chmod -R 755 /var/www/app/storage  \
    && rm -rf /var/www/app/docs /var/www/app/tests

VOLUME /var/www/app/vendor

# Import composer packages from last released version
RUN mv /var/www/app/composer.json /var/www/app/composer.json.master \
    && mv /var/www/app/composer.lock /var/www/app/composer.lock.master \
    && curl -s -o /tmp/ninja-$INVOICENINJA_VERSION.zip -SL https://download.invoiceninja.com \
    && bsdtar --strip-components=1 -C /var/www/app -xkf /tmp/ninja-$INVOICENINJA_VERSION.zip \
    && rm /tmp/ninja-$INVOICENINJA_VERSION.zip

# Override the environment settings from projects .env file
ENV LOG errorlog
ENV SELF_UPDATER_SOURCE ''

# Use to be mounted into nginx
VOLUME /var/www/app/public

ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm"]
