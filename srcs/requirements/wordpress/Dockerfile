FROM debian:buster

RUN apt-get update && apt-get install -y \
    php7.3-fpm \
    php7.3-mysql \
    php7.3-curl \
    php7.3-gd \
    php7.3-intl \
    php7.3-mbstring \
    php7.3-soap \
    php7.3-xml \
    php7.3-xmlrpc \
    php7.3-zip \
    php7.3-cli \
    wget \
    unzip \
    gettext-base \
    mariadb-client \
    curl \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Instalar wp-cli desde repositorio oficial
RUN wget -qO /usr/local/bin/wp https://github.com/wp-cli/wp-cli/releases/download/v2.9.0/wp-cli-2.9.0.phar \
    && chmod +x /usr/local/bin/wp \
    && /usr/local/bin/wp --version 2>&1 | head -1

RUN mkdir -p /var/www/wordpress

RUN wget https://wordpress.org/latest.tar.gz \
    && tar -xzf latest.tar.gz \
    && mv wordpress/* /var/www/wordpress/ \
    && rm -rf wordpress latest.tar.gz

COPY tools/setup-admin.sh /usr/local/bin/setup-admin.sh
RUN chmod +x /usr/local/bin/setup-admin.sh

RUN sed -i 's/listen = \/run\/php\/php7.3-fpm.sock/listen = 9000/' /etc/php/7.3/fpm/pool.d/www.conf

COPY conf/wp-config-simple.php /tmp/wp-config.php.template

RUN chown -R www-data:www-data /var/www/wordpress
RUN chmod -R 755 /var/www/wordpress

EXPOSE 9000

RUN sed -i 's/;daemonize = yes/daemonize = no/' /etc/php/7.3/fpm/php-fpm.conf

# Copiar el entrypoint script
COPY tools/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

CMD ["/usr/local/bin/docker-entrypoint.sh"]