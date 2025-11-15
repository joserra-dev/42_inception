# 42_inception
# GUÍA DE DEFENSA DEL PROYECTO INCEPTION

## ÍNDICE
1. [Project Overview - Explicaciones Conceptuales](#1-project-overview)
2. [Simple Setup](#2-simple-setup)
3. [Docker Basics](#3-docker-basics)
4. [Docker Network](#4-docker-network)
5. [NGINX with SSL/TLS](#5-nginx-with-ssltls)
6. [WordPress with php-fpm](#6-wordpress-with-php-fpm)
7. [MariaDB and its volume](#7-mariadb-and-its-volume)
8. [Persistence](#8-persistence)
9. [Comandos Útiles de Demostración](#9-comandos-útiles-de-demostración)

---

## 1. PROJECT OVERVIEW

### 1.1 ¿Cómo funcionan Docker y docker-compose?

**Docker:**
- Docker es una plataforma de contenedorización que permite empaquetar aplicaciones con todas sus dependencias en contenedores.
- Un contenedor es una unidad de software ligera que incluye código, runtime, herramientas del sistema, bibliotecas y configuraciones.
- Los contenedores comparten el kernel del sistema operativo del host pero están aislados entre sí.
- Docker utiliza imágenes como plantillas para crear contenedores. Las imágenes se construyen en capas usando Dockerfiles.

**docker-compose:**
- docker-compose es una herramienta para definir y ejecutar aplicaciones Docker multi-contenedor.
- Permite definir servicios, redes, volúmenes y dependencias en un archivo YAML (`docker-compose.yml`).
- Facilita la orquestación de múltiples contenedores que trabajan juntos.
- Con un solo comando (`docker-compose up`) puedes levantar toda la infraestructura.

### 1.2 Diferencia entre imagen Docker con docker-compose y sin docker-compose

**Sin docker-compose:**
- Debes construir y ejecutar cada contenedor manualmente con comandos `docker build` y `docker run`.
- Debes crear redes manualmente con `docker network create`.
- Debes gestionar volúmenes manualmente.
- Debes especificar todas las dependencias y conexiones manualmente.
- Ejemplo: `docker run -d --name mariadb -e MYSQL_ROOT_PASSWORD=pass mariadb`

**Con docker-compose:**
- Todo se define en un archivo YAML declarativo.
- Las redes y volúmenes se crean automáticamente.
- Las dependencias entre servicios se gestionan automáticamente (`depends_on`).
- Un solo comando levanta toda la infraestructura.
- Facilita la gestión de múltiples servicios relacionados.

### 1.3 Beneficios de Docker comparado con VMs

1. **Menor uso de recursos:**
   - Los contenedores comparten el kernel del host, no necesitan un OS completo.
   - VMs necesitan un OS completo para cada máquina virtual.

2. **Inicio más rápido:**
   - Contenedores: segundos
   - VMs: minutos

3. **Mayor densidad:**
   - Puedes ejecutar más contenedores que VMs en el mismo hardware.

4. **Portabilidad:**
   - "Funciona en mi máquina" se resuelve: el contenedor funciona igual en cualquier entorno.

5. **Aislamiento ligero:**
   - Aislamiento entre contenedores sin la sobrecarga de virtualización completa.

6. **Escalabilidad:**
   - Fácil crear múltiples instancias del mismo contenedor.

### 1.4 Pertinencia de la estructura de directorios

```
INCEPTION-FINAL-CORREGIDO-main/
├── Makefile
├── secrets/
│   ├── mariadb_root_passwd.txt
│   ├── mariadb_usr_passwd.txt
│   └── mycredentials.txt
├── setup-database.sh
└── srcs/
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   └── configuration/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        └── wordpress/
            ├── Dockerfile
            ├── conf/
            └── tools/
```

**Ventajas:**
- **Separación por servicios:** Cada servicio tiene su directorio con sus archivos.
- **Reutilización:** Fácil copiar/modificar un servicio sin afectar otros.
- **Mantenibilidad:** Estructura clara y organizada.
- **Escalabilidad:** Fácil agregar nuevos servicios.
- **Seguridad:** Los secrets están separados del código.

---

## 2. SIMPLE SETUP

### 2.1 Explicación

El proyecto implementa:
- NGINX accesible solo por puerto 443 (HTTPS)
- Certificado SSL/TLS autofirmado
- WordPress instalado y configurado automáticamente
- Redirección automática de HTTP a HTTPS

### 2.2 Comandos de Verificación

```bash
# Verificar que solo el puerto 443 está expuesto
docker-compose -f srcs/docker-compose.yml ps
# O con el Makefile
make info

# Verificar puertos expuestos
docker port nginx

# Intentar conectar por HTTP (debe fallar o redirigir)
curl -I http://localhost  # Desde fuera del contenedor no debería funcionar
curl -I http://$USER.42.fr  # Debe fallar o redirigir

# Verificar acceso HTTPS
curl -k https://$USER.42.fr  # -k ignora certificado autofirmado

# Verificar certificado SSL
openssl s_client -connect localhost:443 -servername $USER.42.fr
```

---

## 3. DOCKER BASICS

### 3.1 Explicación

- Cada servicio (mariadb, nginx, wordpress) tiene su propio Dockerfile.
- Los Dockerfiles construyen imágenes desde cero usando Debian Bookworm.
- No se usan imágenes ready-made de DockerHub.
- Las imágenes tienen el mismo nombre que sus servicios.
- El Makefile gestiona todo mediante docker-compose.

### 3.2 Comandos de Verificación

```bash
# Verificar que existen los Dockerfiles
ls -la srcs/requirements/*/Dockerfile

# Verificar contenido de Dockerfiles (no vacíos)
wc -l srcs/requirements/*/Dockerfile

# Verificar que no hay NGINX en Dockerfiles de WordPress y MariaDB
grep -i nginx srcs/requirements/wordpress/Dockerfile
grep -i nginx srcs/requirements/mariadb/Dockerfile
# No debe mostrar resultados

# Verificar imágenes construidas
docker images | grep -E "mariadb|nginx|wordpress"

# Verificar que las imágenes tienen el nombre del servicio
docker images

# Construir imágenes manualmente
docker-compose -f srcs/docker-compose.yml build

# Verificar que las imágenes se construyeron correctamente
docker images

# Verificar que no hay imágenes de DockerHub
docker images | grep -E "wordpress|mariadb|nginx" | grep -v "$USER\|localhost"
```

---

## 4. DOCKER NETWORK

### 4.1 Explicación

**¿Qué es docker-network?**
- Una red Docker permite que los contenedores se comuniquen entre sí.
- Sin red, los contenedores no pueden comunicarse.
- Con docker-compose, todos los servicios en la misma red pueden comunicarse usando el nombre del servicio como hostname.

**¿Por qué se usa?**
- Permite que nginx se comunique con wordpress usando `wordpress:9000`.
- Permite que wordpress se comunique con mariadb usando `mariadb:3306`.
- Aislamiento de otros contenedores en el sistema.

**Driver bridge:**
- Es el driver por defecto.
- Crea una red interna donde los contenedores pueden comunicarse.
- Cada contenedor tiene su propia IP en esa red.

### 4.2 Comandos de Verificación

```bash
# Verificar red en docker-compose.yml
cat srcs/docker-compose.yml | grep -A 3 "networks:"

# Listar redes Docker
docker network ls

# Inspeccionar la red creada
docker network inspect inception-final-corregido-main_network
# O buscar el nombre exacto
docker network ls | grep network
docker network inspect <nombre-red>

# Verificar que los contenedores están en la misma red
docker network inspect <nombre-red> | grep -A 5 "Containers"

# Verificar conectividad entre contenedores
docker exec nginx ping -c 2 wordpress
docker exec wordpress ping -c 2 mariadb

# Verificar resolución DNS
docker exec nginx nslookup wordpress
docker exec wordpress nslookup mariadb
```

---

## 5. NGINX WITH SSL/TLS

### 5.1 Explicación

- NGINX actúa como reverse proxy y servidor web.
- Escucha en puerto 443 con SSL/TLS.
- Usa certificados TLS v1.2 y v1.3.
- Redirige tráfico HTTP (puerto 80) a HTTPS.
- Sirve archivos estáticos y procesa PHP mediante FastCGI.

### 5.2 Comandos de Verificación

```bash
# Verificar que el contenedor NGINX existe
docker-compose -f srcs/docker-compose.yml ps nginx

# Verificar configuración SSL en nginx.conf
cat srcs/requirements/nginx/conf/nginx.conf | grep -A 2 "ssl_protocols"

# Verificar certificados SSL
ls -la /home/$USER/data/ssl/

# Verificar certificado SSL
openssl x509 -in /home/$USER/data/ssl/nginx.crt -text -noout

# Verificar protocolos TLS soportados
openssl s_client -connect localhost:443 -tls1_2
openssl s_client -connect localhost:443 -tls1_3

# Verificar configuración de NGINX dentro del contenedor
docker exec nginx cat /etc/nginx/nginx.conf | grep -A 5 "ssl_protocols"

# Verificar logs de NGINX
docker logs nginx

# Probar conexión HTTPS
curl -k -v https://$USER.42.fr

# Verificar que el puerto 80 no está expuesto externamente
docker port nginx
# Solo debe mostrar 443/tcp

# Verificar redirección interna (desde dentro del contenedor)
docker exec nginx curl -I http://localhost
# Debe mostrar redirección 301 a HTTPS
```

---

## 6. WORDPRESS WITH PHP-FPM

### 6.1 Explicación

- WordPress corre en un contenedor separado con PHP-FPM.
- PHP-FPM escucha en el puerto 9000.
- NGINX se comunica con PHP-FPM mediante FastCGI.
- Los archivos de WordPress están en un volumen persistente.
- WordPress se instala automáticamente al iniciar el contenedor.

### 6.2 Comandos de Verificación

```bash
# Verificar Dockerfile de WordPress
cat srcs/requirements/wordpress/Dockerfile | grep php-fpm

# Verificar que no hay NGINX en Dockerfile de WordPress
grep -i nginx srcs/requirements/wordpress/Dockerfile
# No debe mostrar resultados

# Verificar contenedor WordPress
docker-compose -f srcs/docker-compose.yml ps wordpress

# Verificar volumen de WordPress
docker volume ls
docker volume inspect inception-final-corregido-main_wordpress_data
# Debe mostrar: /home/$USER/data/wordpress

# Verificar contenido del volumen
ls -la /home/$USER/data/wordpress/

# Verificar que PHP-FPM está corriendo
docker exec wordpress ps aux | grep php-fpm

# Verificar puerto PHP-FPM
docker exec wordpress netstat -tlnp | grep 9000

# Verificar instalación de WordPress
docker exec wordpress wp core is-installed --allow-root

# Verificar usuario administrador
docker exec wordpress wp user list --allow-root

# Verificar que el usuario no contiene "admin"
docker exec wordpress wp user list --allow-root | grep -i admin
# El usuario "$USER" no contiene "admin"

# Verificar conexión NGINX -> PHP-FPM
docker exec nginx curl http://wordpress:9000
# Debe mostrar respuesta de PHP-FPM

# Ver logs de WordPress
docker logs wordpress
```

---

## 7. MARIADB AND ITS VOLUME

### 7.1 Explicación

**¿Cómo hacer login en la base de datos?**

1. **Como usuario root:**
   ```bash
   docker exec -it mariadb mysql -u root -p
   # Ingresar contraseña del archivo secrets/mariadb_root_passwd.txt
   ```

2. **Como usuario de WordPress:**
   ```bash
   docker exec -it mariadb mysql -u <usuario> -p wordpress
   # Usuario y contraseña desde secrets
   ```

**Seguridad:**
- El usuario root tiene contraseña obligatoria.
- No se puede hacer login sin contraseña.
- Los usuarios se crean con permisos específicos.

### 7.2 Comandos de Verificación

```bash
# Verificar Dockerfile de MariaDB
cat srcs/requirements/mariadb/Dockerfile

# Verificar que no hay NGINX
grep -i nginx srcs/requirements/mariadb/Dockerfile
# No debe mostrar resultados

# Verificar contenedor MariaDB
docker-compose -f srcs/docker-compose.yml ps mariadb

# Verificar volumen de MariaDB
docker volume ls
docker volume inspect inception-final-corregido-main_mariadb_data
# Debe mostrar: /home/$USER/data/mariadb

# Verificar contenido del volumen
ls -la /home/$USER/data/mariadb/

# Intentar login como root SIN contraseña (debe fallar)
docker exec -it mariadb mysql -u root
# Debe mostrar error de acceso denegado

# Login como root CON contraseña (debe funcionar)
docker exec -it mariadb mysql -u root -p
# Ingresar contraseña desde secrets/mariadb_root_passwd.txt

# Dentro de MySQL, verificar usuarios
SELECT User, Host FROM mysql.user;

# Verificar que root tiene contraseña
SELECT User, Host, plugin FROM mysql.user WHERE User='root';

# Login como usuario de WordPress
docker exec -it mariadb mysql -u $(cat secrets/mariadb_usr_passwd.txt) -p wordpress
# Ingresar contraseña desde secrets/mycredentials.txt

# Verificar que la base de datos no está vacía
docker exec -it mariadb mysql -u root -p -e "USE wordpress; SHOW TABLES;"
# Debe mostrar tablas de WordPress

# Contar tablas
docker exec -it mariadb mysql -u root -p -e "USE wordpress; SELECT COUNT(*) as total_tables FROM information_schema.tables WHERE table_schema='wordpress';"

# Ver estructura de una tabla
docker exec -it mariadb mysql -u root -p -e "USE wordpress; DESCRIBE wp_posts;"

# Ver logs de MariaDB
docker logs mariadb
```

---

## 8. PERSISTENCE

### 8.1 Explicación

**¿Cómo funciona la persistencia?**

1. **Volúmenes bind mount:**
   - Los datos se almacenan en `/home/$USER/data/` en el host.
   - Son directorios del sistema de archivos, no volúmenes Docker gestionados.
   - Los datos persisten aunque se eliminen los contenedores.

2. **Después de reiniciar la VM:**
   - Los datos en `/home/$USER/data/` siguen ahí.
   - Al ejecutar `docker-compose up`, los contenedores se recrean.
   - Los contenedores se conectan a los mismos directorios.
   - WordPress detecta que ya está instalado y no reinstala.
   - Los cambios previos (posts, páginas, comentarios) siguen ahí.

### 8.2 Comandos de Verificación

```bash
# Verificar que los volúmenes son bind mounts
docker volume inspect inception-final-corregido-main_wordpress_data | grep -A 3 "Mountpoint"
docker volume inspect inception-final-corregido-main_mariadb_data | grep -A 3 "Mountpoint"

# Verificar datos en el host
ls -la /home/$USER/data/wordpress/
ls -la /home/$USER/data/mariadb/

# Simular reinicio (detener y volver a levantar)
docker-compose -f srcs/docker-compose.yml down
docker-compose -f srcs/docker-compose.yml up -d

# Verificar que los datos persisten
ls -la /home/$USER/data/wordpress/
# Los archivos deben seguir ahí

# Verificar que WordPress detecta instalación previa
docker logs wordpress | grep "ya está instalado"

# Verificar base de datos después de reinicio
docker exec -it mariadb mysql -u root -p -e "USE wordpress; SHOW TABLES;"
# Las tablas deben seguir ahí

# Verificar que los posts/páginas persisten
docker exec wordpress wp post list --allow-root
docker exec wordpress wp page list --allow-root
```

---

## 9. COMANDOS ÚTILES DE DEMOSTRACIÓN

### 9.1 Comandos Generales

```bash
# Ver estado de todos los contenedores
docker-compose -f srcs/docker-compose.yml ps

# Ver logs de todos los servicios
docker-compose -f srcs/docker-compose.yml logs

# Ver logs de un servicio específico
docker-compose -f srcs/docker-compose.yml logs wordpress
docker-compose -f srcs/docker-compose.yml logs nginx
docker-compose -f srcs/docker-compose.yml logs mariadb

# Ver recursos usados
docker stats

# Ver información de red
docker network inspect <nombre-red>

# Ver información de volúmenes
docker volume inspect <nombre-volumen>

# Verificar que los servicios están corriendo
docker ps

# Ejecutar comandos dentro de contenedores
docker exec -it wordpress bash
docker exec -it nginx bash
docker exec -it mariadb bash
```

### 9.2 Comandos de Troubleshooting

```bash
# Verificar conectividad entre servicios
docker exec nginx ping wordpress
docker exec wordpress ping mariadb

# Verificar resolución DNS
docker exec nginx nslookup wordpress

# Verificar puertos abiertos en contenedores
docker exec nginx netstat -tlnp
docker exec wordpress netstat -tlnp
docker exec mariadb netstat -tlnp

# Verificar variables de entorno
docker exec wordpress env | grep -E "DB_|WP_|DOMAIN"
docker exec nginx env | grep DOMAIN

# Verificar archivos de configuración
docker exec nginx cat /etc/nginx/nginx.conf
docker exec wordpress cat /var/www/wordpress/wp-config.php

# Verificar procesos corriendo
docker exec wordpress ps aux
docker exec nginx ps aux
docker exec mariadb ps aux
```

### 9.3 Comandos de WordPress

```bash
# Verificar instalación
docker exec wordpress wp core is-installed --allow-root

# Listar usuarios
docker exec wordpress wp user list --allow-root

# Ver información del sitio
docker exec wordpress wp option get siteurl --allow-root
docker exec wordpress wp option get home --allow-root

# Listar posts
docker exec wordpress wp post list --allow-root

# Listar páginas
docker exec wordpress wp page list --allow-root

# Ver configuración de base de datos
docker exec wordpress wp db check --allow-root
```

### 9.4 Script de Demostración Completa

```bash
#!/bin/bash
echo "=== DEMOSTRACIÓN COMPLETA DEL PROYECTO ==="

echo -e "\n1. Estado de contenedores:"
docker-compose -f srcs/docker-compose.yml ps

echo -e "\n2. Redes Docker:"
docker network ls | grep network

echo -e "\n3. Volúmenes:"
docker volume ls | grep -E "mariadb|wordpress"

echo -e "\n4. Verificación de volúmenes (paths):"
docker volume inspect inception-final-corregido-main_mariadb_data | grep -A 2 "Mountpoint"
docker volume inspect inception-final-corregido-main_wordpress_data | grep -A 2 "Mountpoint"

echo -e "\n5. Verificación SSL/TLS:"
openssl s_client -connect localhost:443 -servername $USER.42.fr </dev/null 2>/dev/null | grep "Protocol"

echo -e "\n6. Verificación WordPress instalado:"
docker exec wordpress wp core is-installed --allow-root

echo -e "\n7. Verificación usuario administrador:"
docker exec wordpress wp user list --allow-root | grep -v "admin"

echo -e "\n8. Verificación base de datos no vacía:"
docker exec mariadb mysql -u root -p$(cat secrets/mariadb_root_passwd.txt) -e "USE wordpress; SELECT COUNT(*) as total_tables FROM information_schema.tables WHERE table_schema='wordpress';" 2>/dev/null

echo -e "\n9. Verificación PHP-FPM:"
docker exec wordpress ps aux | grep php-fpm | head -1

echo -e "\n10. Verificación NGINX -> PHP-FPM:"
docker exec nginx curl -s http://wordpress:9000 | head -1

echo -e "\n=== DEMOSTRACIÓN COMPLETA ==="
```

---

## PREGUNTAS FRECUENTES Y RESPUESTAS

### P: ¿Por qué usaste bind mounts en lugar de volúmenes Docker gestionados?

**R:** Los bind mounts permiten acceso directo a los datos desde el host, facilitando backups y gestión. Además, los datos persisten en rutas conocidas (`/home/$USER/data/`) que son fáciles de localizar y gestionar.

### P: ¿Cómo garantizas que root no pueda hacer login sin contraseña?

**R:** El script `entrypoint.sh` de MariaDB:
1. Crea usuarios root con contraseña obligatoria
2. Elimina usuarios root sin contraseña
3. Ejecuta scripts en background que verifican periódicamente que root tenga contraseña
4. Usa `mysql_native_password` como plugin de autenticación

### P: ¿Por qué WordPress no muestra la página de instalación?

**R:** El script `setup-admin.sh` verifica si WordPress ya está instalado usando `wp core is-installed`. Si está instalado, salta la instalación. Si no, instala WordPress automáticamente usando WP-CLI con todas las credenciales necesarias.

### P: ¿Cómo funciona la comunicación entre NGINX y WordPress?

**R:** 
- NGINX actúa como reverse proxy
- WordPress corre PHP-FPM en el puerto 9000
- NGINX usa FastCGI para comunicarse con PHP-FPM
- En `nginx.conf`: `fastcgi_pass wordpress:9000;`
- La red Docker permite que NGINX resuelva "wordpress" como hostname

### P: ¿Qué pasa si reinicio la VM?

**R:** 
1. Los datos en `/home/$USER/data/` persisten
2. Al ejecutar `docker-compose up`, los contenedores se recrean
3. Los contenedores se conectan a los mismos directorios
4. WordPress detecta instalación previa y no reinstala
5. Todos los cambios (posts, páginas, comentarios) persisten

### P: ¿Por qué el certificado SSL muestra una advertencia?

**R:** Es un certificado autofirmado (self-signed). Esto es aceptable según los requisitos del proyecto. Un certificado autofirmado es suficiente para desarrollo y pruebas. Para producción se usaría un certificado de una autoridad certificadora (Let's Encrypt, etc.).

---

## CHECKLIST DE VERIFICACIÓN PRE-DEFENSA

- [ ] Todos los contenedores están corriendo: `docker-compose ps`
- [ ] La red existe: `docker network ls`
- [ ] Los volúmenes tienen los paths correctos: `docker volume inspect`
- [ ] WordPress está instalado: `docker exec wordpress wp core is-installed`
- [ ] El usuario admin no contiene "admin": `docker exec wordpress wp user list`
- [ ] Root requiere contraseña: Intentar login sin contraseña debe fallar
- [ ] Solo puerto 443 expuesto: `docker port nginx`
- [ ] SSL/TLS funciona: `curl -k https://$USER.42.fr`
- [ ] Base de datos no está vacía: Verificar tablas en MySQL
- [ ] Los datos persisten: Verificar `/home/$USER/data/`

---

¡Éxito en tu defensa! 🚀

