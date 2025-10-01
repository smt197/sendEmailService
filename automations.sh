#!/bin/sh
# Laravel automations with robust database connection handling

set -e

echo "🚀 Starting Laravel automations..."

# Set APP_BASE_DIR if not set
: "${APP_BASE_DIR:=/var/www/html}"
: "${AUTORUN_ENABLED:=false}"
: "${AUTORUN_LARAVEL_MIGRATION_TIMEOUT:=60}"

cd "$APP_BASE_DIR"

if [ "$DISABLE_DEFAULT_CONFIG" = "false" ] && [ -f "$APP_BASE_DIR/artisan" ] && [ "$AUTORUN_ENABLED" = "true" ]; then
    echo "📋 Running Laravel automations..."

    # Clear any cached config/routes/views from previous builds
    echo "🧹 Clearing stale cache..."
    php artisan config:clear 2>/dev/null || true
    php artisan route:clear 2>/dev/null || true
    php artisan view:clear 2>/dev/null || true
    php artisan cache:clear 2>/dev/null || true

    # Rebuild package manifest with production dependencies only
    echo "📦 Discovering packages..."
    php artisan package:discover --ansi 2>/dev/null || true

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

    # Test database connection before migrations
    if [ "${AUTORUN_LARAVEL_MIGRATION:=true}" = "true" ]; then
        echo "⚡️ Attempting database connection..."
        
        RETRY_COUNT=0
        MAX_RETRIES=$((AUTORUN_LARAVEL_MIGRATION_TIMEOUT / 2))
        
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            if php artisan db:show 2>/dev/null; then
                echo "✅ Database connection successful!"
                break
            fi
            
            RETRY_COUNT=$((RETRY_COUNT + 1))
            REMAINING=$((AUTORUN_LARAVEL_MIGRATION_TIMEOUT - (RETRY_COUNT * 2)))
            
            if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
                echo "❌ Failed to connect to database after ${AUTORUN_LARAVEL_MIGRATION_TIMEOUT} seconds"
                echo "Database configuration:"
                echo "  Host: ${DB_HOST}"
                echo "  Port: ${DB_PORT}"
                echo "  Database: ${DB_DATABASE}"
                echo "  User: ${DB_USERNAME}"
                exit 1
            fi
            
            echo "Waiting on database connection, retrying... $REMAINING seconds left"
            sleep 2
        done
        
        echo "📊 Running database migrations..."
        php artisan migrate --force 2>&1 || {
            echo "⚠️  Migration failed"
            php artisan migrate:status 2>&1 || true
            exit 1
        }
    fi

    # Laravel caching (rebuild cache with production config)
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