#!/bin/bash
set -e

echo "Starting OpenGRC container..."

# Fix permissions
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Clear caches (IMPORTANT)
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Generate key if missing
php artisan key:generate --force || true

# Run migrations
php artisan migrate --force

# Cache again
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Start cron
service cron start

# Start Apache
exec apache2ctl -D FOREGROUND