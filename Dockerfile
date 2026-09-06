FROM php:8.3-apache

RUN <<EOF
  set -euxo pipefail

  apt-get update
  apt-get install -y --no-install-recommends \
    libpng-dev \
    libjpeg-dev \
    libwebp-dev \
    libavif-dev \
    libfreetype6-dev \
    libmagickwand-dev \
    libzip-dev \
    libicu-dev \
    libmemcached-dev

  docker-php-ext-configure gd \
    --with-jpeg \
    --with-webp \
    --with-avif \
    --with-freetype

  docker-php-ext-install -j$(nproc) \
    bcmath \
    exif \
    gd \
    intl \
    mysqli \
    zip

  pecl install \
    imagick \
    redis \
    memcached \
    apcu

  docker-php-ext-enable \
    imagick \
    redis \
    memcached \
    apcu

  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
  rm -rf /tmp/pear
  rm -rf /var/lib/apt/lists/*
EOF

RUN <<EOF
  set -euxo pipefail

  #
  # PHP
  #
  cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

  {
    echo 'opcache.memory_consumption=256'
    echo 'opcache.interned_strings_buffer=32'
    echo 'opcache.max_accelerated_files=4000'
    echo 'opcache.revalidate_freq=2'
  } > "$PHP_INI_DIR/conf.d/wordpress-opcache-recommended.ini"

  {
    echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'
    echo 'display_errors = Off'
    echo 'display_startup_errors = Off'
    echo 'log_errors = On'
    echo 'error_log = /dev/stderr'
    echo 'log_errors_max_len = 1024'
    echo 'ignore_repeated_errors = On'
    echo 'ignore_repeated_source = Off'
    echo 'html_errors = Off'
  } > "$PHP_INI_DIR/conf.d/wordpress-error-logging.ini"

  {
    echo 'file_uploads = On'
    echo 'upload_max_filesize = 64M'
    echo 'post_max_size = 128M'
    echo 'memory_limit = 256M'
    echo 'max_execution_time = 60'
  } > "$PHP_INI_DIR/conf.d/99-custom.ini"

  #
  # Apache
  #
  a2enmod rewrite expires remoteip

  {
    echo 'SetEnvIf X-Forwarded-Proto ^https$ HTTPS=on'
    echo 'RemoteIPHeader X-Forwarded-For'
    echo 'RemoteIPInternalProxy 10.0.0.0/8'
    echo 'RemoteIPInternalProxy 172.16.0.0/12'
    echo 'RemoteIPInternalProxy 192.168.0.0/16'
    echo 'RemoteIPInternalProxy 169.254.0.0/16'
    echo 'RemoteIPInternalProxy 127.0.0.0/8'
  } > "/etc/apache2/conf-available/99-apache-behind-nginx.conf"

  a2enconf 99-apache-behind-nginx
EOF

RUN <<EOF
  set -euxo pipefail

  #
  # Show PHP info if root directory has not been overriden by a volume
  #
  {
    echo '<?php'
    echo 'echo "<pre>";'
    echo 'print_r($_SERVER);'
    echo 'echo "</pre>";'
    echo 'phpinfo(INFO_ALL);'
  } > "/var/www/html/index.php"

EOF
