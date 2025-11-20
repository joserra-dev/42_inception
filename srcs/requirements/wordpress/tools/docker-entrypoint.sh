#!/bin/bash

set -e

echo "🚀 Iniciando WordPress..."

# Leer credenciales de los secrets
DB_USER=$(cat /run/secrets/mariadb_user | tr -d '\n\r' | sed 's/[[:space:]]*$//')
DB_PASSWORD=$(cat /run/secrets/mariadb_password | tr -d '\n\r' | sed 's/[[:space:]]*$//')
DB_ROOT_PASSWORD=$(cat /run/secrets/mariadb_root_password | tr -d '\n\r' | sed 's/[[:space:]]*$//')

# Variables de entorno
DOMAIN_NAME=${DOMAIN_NAME:-localhost}
WP_TITLE=${WP_TITLE:-Mi WordPress}
WP_ADMIN_USER=${WP_ADMIN_USER:-wpuser}
WP_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD:-secure_password}
WP_ADMIN_EMAIL=${WP_ADMIN_EMAIL:-admin@42.fr}

# Handle volume masking: if /var/www/wordpress is empty (due to bind mount overlay)
# copy WordPress files from the image to the volume
echo "📁 Checking WordPress directory..."
if [ -z "$(ls -A /var/www/wordpress 2>/dev/null)" ]; then
    echo "📦 Volume appears empty, initializing WordPress structure..."
    # Copy pre-installed WordPress from a temporary location or download
    # For now, ensure wp-cli can download and set up WordPress
    if ! command -v wp &> /dev/null; then
        echo "⚠️  wp-cli not found, WordPress setup will be via wp-cli download"
    fi
fi

# Generar wp-config.php si no existe
if [ ! -f /var/www/wordpress/wp-config.php ]; then
    echo "📝 Generando wp-config.php..."
    envsubst '${DOMAIN_NAME}' < /tmp/wp-config.php.template > /var/www/wordpress/wp-config.php
    chown www-data:www-data /var/www/wordpress/wp-config.php
    chmod 644 /var/www/wordpress/wp-config.php
fi

# Esperar a que MariaDB esté lista
echo "⏳ Esperando a que MariaDB esté lista..."
# Intentar con el usuario de la base de datos primero, luego con root
until mysql -h mariadb -u "${DB_USER}" -p"${DB_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1 || mysql -h mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
    sleep 2
done
echo "✅ MariaDB está lista"

# Cambiar al directorio de WordPress
cd /var/www/wordpress

# Verificar si WordPress ya está instalado
if wp core is-installed --allow-root 2>/dev/null; then
    echo "✅ WordPress ya está instalado"
else
    echo "📦 Instalando WordPress automáticamente..."
    
    # Instalar WordPress
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root
    
    if [ $? -eq 0 ]; then
        echo "✅ WordPress instalado correctamente"
        echo "🌐 URL: https://${DOMAIN_NAME}"
        echo "👤 Usuario admin: ${WP_ADMIN_USER}"
    else
        echo "⚠️  Error al instalar WordPress, pero continuando..."
    fi
fi

# Asegurar permisos correctos
chown -R www-data:www-data /var/www/wordpress
chmod -R 755 /var/www/wordpress

echo "🔧 Iniciando PHP-FPM..."

exec php-fpm7.3 -F

