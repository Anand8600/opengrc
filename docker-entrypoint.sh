#!/bin/bash
set -e

echo "Starting OpenGRC container..."

# Wait for database (only if using external DB like MySQL)
if [ -n "$DB_HOST" ]; then
    echo "Waiting for database connection..."
    max_attempts=30
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if php artisan tinker --execute="try { DB::connection()->getPdo(); echo 'ok'; } catch (\Exception \$e) { exit(1); }" 2>/dev/null | grep -q "ok"; then
            echo "Database connected."
            break
        fi
        attempt=$((attempt + 1))
        echo "Waiting for database... (attempt $attempt/$max_attempts)"
        sleep 2
    done
    if [ $attempt -eq $max_attempts ]; then
        echo "Warning: Could not connect to database after $max_attempts attempts. Continuing anyway..."
    fi
fi

# Run migrations
echo "Running database migrations..."
php artisan migrate --force

# Cache configs
echo "Caching configuration..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Fix permissions
echo "Setting permissions..."
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Start cron
echo "Starting cron..."
service cron start

# ❌ REMOVED PHP-FPM COMPLETELY (THIS WAS THE ERROR)

# Start Apache
echo "Starting Apache..."
exec apache2ctl -D FOREGROUND