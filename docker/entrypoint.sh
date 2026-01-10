#!/bin/bash
# ZoneMinder Docker entrypoint script
set -e

# Default values
ZM_DB_HOST=${ZM_DB_HOST:-db}
ZM_DB_PORT=${ZM_DB_PORT:-3306}
ZM_DB_NAME=${ZM_DB_NAME:-zm}
ZM_DB_USER=${ZM_DB_USER:-zmuser}
ZM_DB_PASS=${ZM_DB_PASS:-zmpass}
TZ=${TZ:-UTC}

echo "Starting ZoneMinder container..."

# Set timezone
if [ -n "$TZ" ]; then
    echo "Setting timezone to $TZ"
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo "$TZ" > /etc/timezone

    # Update PHP timezone
    for phpini in /etc/php/*/apache2/php.ini /etc/php/*/cli/php.ini; do
        if [ -f "$phpini" ]; then
            sed -i "s|^;*date.timezone.*|date.timezone = $TZ|" "$phpini"
        fi
    done
fi

# Configure ZoneMinder database connection
ZMCONF="/etc/zm/zm.conf"
if [ -f "$ZMCONF" ]; then
    echo "Configuring ZoneMinder database connection..."
    sed -i "s|^ZM_DB_HOST=.*|ZM_DB_HOST=$ZM_DB_HOST|" "$ZMCONF"
    sed -i "s|^ZM_DB_NAME=.*|ZM_DB_NAME=$ZM_DB_NAME|" "$ZMCONF"
    sed -i "s|^ZM_DB_USER=.*|ZM_DB_USER=$ZM_DB_USER|" "$ZMCONF"
    sed -i "s|^ZM_DB_PASS=.*|ZM_DB_PASS=$ZM_DB_PASS|" "$ZMCONF"
fi

# Wait for database to be available
echo "Waiting for database at $ZM_DB_HOST:$ZM_DB_PORT..."
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if mysqladmin ping -h"$ZM_DB_HOST" -P"$ZM_DB_PORT" -u"$ZM_DB_USER" -p"$ZM_DB_PASS" --silent 2>/dev/null; then
        echo "Database is available."
        break
    fi
    attempt=$((attempt + 1))
    echo "Waiting for database... ($attempt/$max_attempts)"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "Warning: Could not connect to database after $max_attempts attempts."
    echo "ZoneMinder may fail to start properly."
fi

# Check if ZoneMinder database schema exists (check for Config table)
echo "Checking ZoneMinder database schema..."
if ! mysql -h"$ZM_DB_HOST" -P"$ZM_DB_PORT" -u"$ZM_DB_USER" -p"$ZM_DB_PASS" "$ZM_DB_NAME" -e "SELECT 1 FROM Config LIMIT 1" 2>/dev/null; then
    echo "Database schema not initialized. Importing..."
    if [ -f /usr/share/zoneminder/db/zm_create.sql ]; then
        mysql -h"$ZM_DB_HOST" -P"$ZM_DB_PORT" -u"$ZM_DB_USER" -p"$ZM_DB_PASS" "$ZM_DB_NAME" < /usr/share/zoneminder/db/zm_create.sql
        echo "Schema imported."
    fi
fi

# Run database updates
echo "Running ZoneMinder database updates..."
if [ -x /usr/bin/zmupdate.pl ]; then
    /usr/bin/zmupdate.pl --nointeractive || true
    /usr/bin/zmupdate.pl --nointeractive -f || true
fi

# Fix permissions
echo "Setting permissions..."
chown -R www-data:www-data /var/cache/zoneminder 2>/dev/null || true
chown -R www-data:www-data /var/log/zm 2>/dev/null || true
chown -R www-data:www-data /var/run/zm 2>/dev/null || true

# Start Apache
echo "Starting Apache..."
source /etc/apache2/envvars 2>/dev/null || true
rm -f /var/run/apache2/apache2.pid 2>/dev/null || true

# Start ZoneMinder
echo "Starting ZoneMinder..."
if [ -x /usr/bin/zmpkg.pl ]; then
    /usr/bin/zmpkg.pl start || true
fi

# Start Apache in foreground
echo "ZoneMinder is ready. Starting Apache in foreground..."
exec apache2 -DFOREGROUND
