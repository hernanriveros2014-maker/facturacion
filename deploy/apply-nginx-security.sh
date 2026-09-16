#!/usr/bin/env bash
# Aplica configuración Nginx con cabeceras de seguridad y HTTPS.
# Uso: sudo DOMAIN=facturacion.tudominio.cl bash /var/www/facturacion/deploy/apply-nginx-security.sh
set -euo pipefail

APP_ROOT="${APP_ROOT:-/var/www/facturacion}"
DOMAIN="${DOMAIN:-}"
GUNICORN_PORT="${GUNICORN_PORT:-8001}"

log() {
  echo "[nginx-security] $*"
}

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Ejecuta como root: sudo DOMAIN=tudominio.cl bash deploy/apply-nginx-security.sh"
  exit 1
fi

if [[ -z "$DOMAIN" ]]; then
  if [[ -f "$APP_ROOT/backend/.env" ]]; then
    DOMAIN="$(grep -E '^ALLOWED_HOSTS=' "$APP_ROOT/backend/.env" | head -n1 | cut -d= -f2- | cut -d, -f1 | tr -d ' ' || true)"
  fi
fi

if [[ -z "$DOMAIN" ]]; then
  echo "Indica DOMAIN: sudo DOMAIN=tudominio.cl bash deploy/apply-nginx-security.sh"
  exit 1
fi

SSL_CERT="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
NGINX_SITE="/etc/nginx/sites-available/facturacion"

if [[ -f "$SSL_CERT" ]]; then
  log "Certificado SSL encontrado; aplicando facturacion-production.conf"
  sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__GUNICORN_PORT__/${GUNICORN_PORT}/g" \
    "$APP_ROOT/deploy/nginx/facturacion-production.conf" > "$NGINX_SITE"
else
  log "Sin certificado SSL; aplicando facturacion.conf (HTTP + cabeceras)"
  sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__GUNICORN_PORT__/${GUNICORN_PORT}/g" \
    "$APP_ROOT/deploy/nginx/facturacion.conf" > "$NGINX_SITE"
fi

ln -sf "$NGINX_SITE" /etc/nginx/sites-enabled/facturacion

nginx -t
systemctl reload nginx

log "Nginx recargado."
