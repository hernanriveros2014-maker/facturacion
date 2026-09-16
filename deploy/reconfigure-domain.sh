#!/usr/bin/env bash
# Cambia el dominio de Facturación en una VPS ya instalada (modo sidecar).
# Ejemplo sinfon-ia.cl:
#   sudo DOMAIN=sinfon-ia.cl SSL_EMAIL=admin@sinfon-ia.cl bash deploy/reconfigure-domain.sh
set -euo pipefail

APP_ROOT="${APP_ROOT:-/var/www/facturacion}"
DOMAIN="${DOMAIN:-}"
SSL_EMAIL="${SSL_EMAIL:-}"
GUNICORN_PORT="${GUNICORN_PORT:-8001}"
REMOVE_TURISMO_WHITELABEL="${REMOVE_TURISMO_WHITELABEL:-1}"

log() { echo "[reconfigure] $*"; }

[[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "Ejecuta con sudo."; exit 1; }
[[ -n "$DOMAIN" ]] || { echo "Indica DOMAIN=sinfon-ia.cl"; exit 1; }
[[ -f "$APP_ROOT/backend/.env" ]] || { echo "No existe $APP_ROOT/backend/.env"; exit 1; }

if [[ "$REMOVE_TURISMO_WHITELABEL" == "1" && -L /etc/nginx/sites-enabled/turismo-white-label ]]; then
  log "Quitando nginx turismo-white-label (sinfon-ia.cl dejaba de servir turismo)..."
  rm -f /etc/nginx/sites-enabled/turismo-white-label
fi

log "Actualizando backend/.env..."
ENV_FILE="$APP_ROOT/backend/.env"
sed -i "s/^ALLOWED_HOSTS=.*/ALLOWED_HOSTS=${DOMAIN},www.${DOMAIN}/" "$ENV_FILE"
sed -i "s|^CSRF_TRUSTED_ORIGINS=.*|CSRF_TRUSTED_ORIGINS=https://${DOMAIN},https://www.${DOMAIN}|" "$ENV_FILE"
sed -i "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=https://${DOMAIN},https://www.${DOMAIN}|" "$ENV_FILE"
grep -q '^VITE_API_URL=' "$ENV_FILE" && \
  sed -i "s|^VITE_API_URL=.*|VITE_API_URL=https://${DOMAIN}|" "$ENV_FILE" || \
  echo "VITE_API_URL=https://${DOMAIN}" >> "$ENV_FILE"
grep -q '^FRONTEND_BASE_URL=' "$ENV_FILE" && \
  sed -i "s|^FRONTEND_BASE_URL=.*|FRONTEND_BASE_URL=https://${DOMAIN}|" "$ENV_FILE" || \
  echo "FRONTEND_BASE_URL=https://${DOMAIN}" >> "$ENV_FILE"

if grep -q "REEMPLAZAR_CON_CLAVE" "$ENV_FILE"; then
  SK="$("$APP_ROOT/venv/bin/python" -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")"
  sed -i "s/^SECRET_KEY=.*/SECRET_KEY=${SK}/" "$ENV_FILE"
  log "SECRET_KEY generada."
fi

log "Compilando frontend..."
cd "$APP_ROOT/frontend"
npm ci --silent 2>/dev/null || npm install --silent
VITE_API_URL="https://${DOMAIN}" npm run build
chown -R www-data:www-data "$APP_ROOT/frontend/dist"

log "Nginx facturacion → ${DOMAIN}..."
sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__GUNICORN_PORT__/${GUNICORN_PORT}/g" \
  "$APP_ROOT/deploy/nginx/facturacion.conf" > /etc/nginx/sites-available/facturacion
ln -sf /etc/nginx/sites-available/facturacion /etc/nginx/sites-enabled/facturacion
nginx -t
systemctl reload nginx

systemctl restart facturacion-gunicorn

if [[ -n "$SSL_EMAIL" ]]; then
  log "Solicitando certificado SSL..."
  certbot --nginx -d "$DOMAIN" -d "www.${DOMAIN}" \
    --non-interactive --agree-tos -m "$SSL_EMAIL" || true
  if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__GUNICORN_PORT__/${GUNICORN_PORT}/g" \
      "$APP_ROOT/deploy/nginx/facturacion-production.conf" > /etc/nginx/sites-available/facturacion
    nginx -t && systemctl reload nginx
  fi
fi

curl -sf -o /dev/null "http://127.0.0.1:${GUNICORN_PORT}/api/health/" && \
  log "OK: API responde" || log "WARN: revisa journalctl -u facturacion-gunicorn"

cat <<EOF

Dominio configurado: https://${DOMAIN}/
Turismo arriendavip.cl: sin cambios
Nota: sinfon-ia.cl ya no sirve el portal turismo white-label
      (se deshabilitó turismo-white-label en nginx).

Verificar:
  curl -s https://${DOMAIN}/api/health/
  systemctl status turismo-gunicorn facturacion-gunicorn
EOF
