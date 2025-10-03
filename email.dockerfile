FROM serversideup/php:8.3-fpm-nginx-alpine

ENV PHP_OPCACHE_ENABLE=1
ENV OCTANE_STATE_FILE=/var/www/html/storage/framework/octane-state.json

WORKDIR /var/www/html

USER root

# Install PHP extensions
RUN install-php-extensions \
       pdo_mysql \
       mysqli \
       mbstring \
       xml \
       zip \
       bcmath \
       gd \
       redis \
       opcache \
       pcntl \
       sockets

# Copy composer files first for better caching
COPY --chown=www-data:www-data composer.json composer.lock ./

# Switch to www-data to install dependencies
USER www-data

# Install composer dependencies
RUN composer install --no-interaction --optimize-autoloader --no-dev --no-scripts \
    && rm -rf ~/.composer/cache

# Switch back to root for file operations
USER root

# Copy application files
COPY --chown=www-data:www-data . .

# Copy automation script
COPY --chown=root:root --chmod=755 automations.sh /etc/entrypoint.d/60-laravel-automations.sh

# Create all necessary directories with correct permissions
RUN mkdir -p storage/framework/{sessions,views,cache} storage/logs storage/app bootstrap/cache \
    && touch storage/logs/laravel.log \
    && touch ${OCTANE_STATE_FILE} \
    && rm -f bootstrap/cache/packages.php bootstrap/cache/services.php bootstrap/cache/config.php \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache \
    && chmod 666 ${OCTANE_STATE_FILE}

# Copy s6-overlay services for Laravel
COPY s6-overlay /etc/s6-overlay/
RUN find /etc/s6-overlay -name "run" -type f -exec chmod +x {} \; \
    && find /etc/s6-overlay -name "up" -type f -exec chmod +x {} \; \
    && mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d \
    && echo "laravel-services" > /etc/s6-overlay/s6-rc.d/user/contents.d/laravel-services

# Final setup as www-data
USER www-data

# Run post-install scripts (without running package:discover to avoid cache issues)
RUN composer dump-autoload --no-scripts --optimize