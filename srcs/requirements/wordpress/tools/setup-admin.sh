#!/bin/bash

MYSQL_ROOT_PASSWORD=$(cat /run/secrets/mariadb_root_password)

until mysql -h mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
    echo "Esperando a que MariaDB esté lista..."
    sleep 2
done

cd /var/www/wordpress

if [ ! -f wp-config.php ]; then
    cp wp-config-sample.php wp-config.php
fi

DB_USER=$(cat /run/secrets/mariadb_user)
DB_PASSWORD=$(cat /run/secrets/mariadb_password)

sed -i "s/database_name_here/wordpress/g" wp-config.php
sed -i "s/username_here/$DB_USER/g" wp-config.php
sed -i "s/password_here/$DB_PASSWORD/g" wp-config.php
sed -i "s/localhost/mariadb/g" wp-config.php

DOMAIN_NAME=${DOMAIN_NAME:-localhost}
sed -i "s|https://example.com|https://$DOMAIN_NAME|g" wp-config.php

mysql -h mariadb -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON wordpress.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

echo "WordPress configurado. Accede a https://$DOMAIN_NAME para completar la instalación."