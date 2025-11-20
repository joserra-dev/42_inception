#!/bin/bash

set -e

echo "🚀 Iniciando MariaDB..."

DB_ROOT_PASSWORD=$(cat /run/secrets/mariadb_root_password | tr -d '\n\r' | sed 's/[[:space:]]*$//')
DB_USER=$(cat /run/secrets/mariadb_user | tr -d '\n\r' | sed 's/[[:space:]]*$//')
DB_PASSWORD=$(cat /run/secrets/mariadb_password | tr -d '\n\r' | sed 's/[[:space:]]*$//')

chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql

# Preparar script de inicialización SQL
# --init-file se ejecuta cada vez que mysqld se inicia, antes de aceptar conexiones
INIT_SQL_FILE="/tmp/init-config.sql"
cat > "$INIT_SQL_FILE" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON wordpress.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF
chmod 644 "$INIT_SQL_FILE"

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "📦 Inicializando base de datos MariaDB..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db
    echo "✅ Base de datos inicializada"
else
    echo "📦 Base de datos ya existe"
fi

mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

echo "🔧 Iniciando MariaDB..."

# Usar --init-file para ejecutar comandos SQL al inicio sin procesos en background
# Esto se ejecuta antes de que mysqld acepte conexiones, tanto en primera inicialización
# como en reinicios posteriores
exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 --init-file="$INIT_SQL_FILE"
