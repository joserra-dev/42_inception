#!/bin/bash

set -e

if [ -z "$DOMAIN_NAME" ]; then
    echo "Error: DOMAIN_NAME no está definido" >&2
    exit 1
fi

DOMAIN="$DOMAIN_NAME"
SSL_DIR="${SSL_DIR:-${HOME}/data/ssl}"

mkdir -p "$SSL_DIR"

openssl genrsa -out "$SSL_DIR/nginx.key" 2048

openssl req -new -x509 -key "$SSL_DIR/nginx.key" -out "$SSL_DIR/nginx.crt" -days 365 -subj "/C=FR/ST=75/L=Paris/O=42/OU=42/CN=$DOMAIN"

chmod 600 "$SSL_DIR/nginx.key"
chmod 644 "$SSL_DIR/nginx.crt"

echo "Certificados SSL generados en $SSL_DIR"
echo "Dominio: $DOMAIN"
echo "Certificado: $SSL_DIR/nginx.crt"
echo "Clave privada: $SSL_DIR/nginx.key"