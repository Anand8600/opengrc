FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

ENV PHP_VERSION=8.4
ENV NODE_VERSION=20.x
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install base tools + repos
RUN apt-get update && apt-get install -y \
    software-properties-common curl ca-certificates gnupg apt-utils \
    && add-apt-repository ppa:ondrej/php \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION} | bash -

# Install Apache + PHP (MOD_PHP, NOT FPM)
RUN apt-get update && apt-get install -y \
    apache2 \
    libapache2-mod-php${PHP_VERSION} \
    php${PHP_VERSION} \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-intl \
    nodejs zip cron wget unzip git openssl sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Enable Apache modules
RUN a2enmod rewrite php${PHP_VERSION}

# Apache config
RUN echo "Listen 10000" > /etc/apache2/ports.conf

RUN echo '<VirtualHost *:10000>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/public

    <Directory /var/www/html/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    DirectoryIndex index.php index.html

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Set working dir
WORKDIR /var/www/html

# Copy code
COPY . .

# Install PHP deps
RUN composer install --no-dev --optimize-autoloader

# Install Node deps
COPY package*.json ./
RUN npm ci

# Build frontend
RUN npm run build && rm -rf node_modules

# Fix permissions
RUN mkdir -p storage/framework/cache/data \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache \
    database \
    && touch database/opengrc.sqlite \
    && touch storage/logs/laravel.log \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 storage bootstrap/cache database \
    && chmod 664 storage/logs/laravel.log

# Cron
RUN echo "* * * * * www-data cd /var/www/html && php artisan schedule:run >> /dev/null 2>&1" > /etc/cron.d/laravel-cron \
    && chmod 0644 /etc/cron.d/laravel-cron

EXPOSE 10000

# Health check
HEALTHCHECK CMD curl -f http://localhost:10000 || exit 1

# Entrypoint
COPY docker-entrypoint.sh /var/www/html/docker-entrypoint.sh
RUN chmod +x /var/www/html/docker-entrypoint.sh

ENTRYPOINT ["/var/www/html/docker-entrypoint.sh"]