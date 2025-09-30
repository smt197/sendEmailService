#!/bin/sh
# Laravel automations with robust log handling

set -e

echo "🚀 Starting Laravel automations..."

# Set APP_BASE_DIR if not set
: "${APP_BASE_DIR:=/var/www/html}"
: "${AUTORUN_ENABLED:=false}"
: "${AUTORUN_LARAVEL_MIGRATION_TIMEOUT:=30}"

cd "$APP_BASE_DIR"

if [ "$DISABLE_DEFAULT_CONFIG" = "false" ] && [ -f "$APP_BASE_DIR/artisan" ] && [ "$AUTORUN_ENABLED" = "true" ]; then
    echo "📋 Running Laravel automations..."

    # Fix storage permissions for mounted volumes
    echo "🔧 Setting up storage permissions..."
    mkdir -p storage/logs storage/framework/{cache,sessions,views} storage/app bootstrap/cache 2>/dev/null || true

    # Ensure log directory and file are writable
    if [ ! -f storage/logs/laravel.log ]; then
        touch storage/logs/laravel.log 2>/dev/null || true
    fi

    # Fix permissions on mounted log volume
    chown -R www-data:www-data storage/logs 2>/dev/null || true
    chmod -R 777 storage/logs 2>/dev/null || true

    if [ -f storage/logs/laravel.log ]; then
        chown www-data:www-data storage/logs/laravel.log 2>/dev/null || true
        chmod 666 storage/logs/laravel.log 2>/dev/null || true
    fi

    # Test log file writability
    if [ ! -w storage/logs/laravel.log ]; then
        echo "⚠️  Log file not writable, using stderr logging"
        export LOG_CHANNEL=stderr
    fi

    # Database migrations
    if [ "${AUTORUN_LARAVEL_MIGRATION:=true}" = "true" ]; then
        echo "📊 Running database migrations..."
        php artisan migrate --force 2>/dev/null || echo "⚠️  Migration failed or not needed"
    fi

    # Laravel caching
    if [ "${AUTORUN_LARAVEL_CONFIG_CACHE:=true}" = "true" ]; then
        echo "⚡ Caching configuration..."
        php artisan config:cache 2>/dev/null || true
    fi

    if [ "${AUTORUN_LARAVEL_ROUTE_CACHE:=true}" = "true" ]; then
        echo "🛣️  Caching routes..."
        php artisan route:cache 2>/dev/null || true
    fi

    if [ "${AUTORUN_LARAVEL_VIEW_CACHE:=true}" = "true" ]; then
        echo "👁️  Caching views..."
        php artisan view:cache 2>/dev/null || true
    fi

    echo "✅ Laravel automations completed!"
else
    echo "ℹ️  Laravel automations skipped"
fi

echo "🎯 Laravel is ready!"