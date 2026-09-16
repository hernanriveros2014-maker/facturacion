#!/usr/bin/env bash
# Instala Facturación en la MISMA VPS que turismo/arriendavip SIN tocar turismo.
#
# No modifica: turismo-gunicorn, nginx/turismo, turismo1, puerto 8000.
# Solo agrega: /var/www/facturacion, facturacion1, puerto 8001, nginx/facturacion.
#
# Uso (recomendado — subdominio):
#   sudo DOMAIN=facturacion.arriendavip.cl \
#        GIT_REPO=https://github.com/hernanriveros2014-maker/facturacion.git \
#        bash deploy/install-sidecar-vps.sh
#
# Con SSL (cuando el subdominio apunte a la VPS):
#   sudo DOMAIN=facturacion.arriendavip.cl ENABLE_SSL=1 SSL_EMAIL=admin@arriendavip.cl \
#        bash deploy/install-sidecar-vps.sh
set -euo pipefail

APP_ROOT="${APP_ROOT:-/var/www/facturacion}"
DOMAIN="${DOMAIN:-}"
GIT_REPO="${GIT_REPO:-https://github.com/hernanriveros2014-maker/facturacion.git}"
DB_NAME="${DB_NAME:-facturacion1}"
DB_USER="${DB_USER:-facturacion_user}"
DB_PASSWORD="${DB_PASSWORD:-}"
ENABLE_SSL="${ENABLE_SSL:-0}"
SSL_EMAIL="${SSL_EMAIL:-}"
GUNICORN_PORT="${GUNICORN_PORT:-8001}"
TURISMO_ROOT="${TURISMO_ROOT:-/var/www/turismo}"

log() { echo "[sidecar] $*"; }

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "Ejecuta con sudo."; exit 1; }
}

preflight() {
  if [[ -z "$DOMAIN" ]]; then
    echo "Indica DOMAIN (subdominio recomendado: facturacion.arriendavip.cl)"
    exit 1
  fi

  if [[ -d "$TURISMO_ROOT" ]]; then
    log "Turismo detectado en $TURISMO_ROOT — no se modificará."
  fi

  if ss -tlnp 2>/dev/null | grep -q ":${GUNICORN_PORT} "; then
    echo "Puerto ${GUNICORN_PORT} ya en uso. Cambia GUNICORN_PORT o libera el puerto."
    exit 1
  fi

  if [[ "$DOMAIN" == "arriendavip.cl" || "$DOMAIN" == "www.arriendavip.cl" ]]; then
    echo "Usa un subdominio (ej. facturacion.arriendavip.cl) para no interferir con ArriendaVIP."
    exit 1
  fi
}

ensure_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    log "Node.js ya instalado ($(node -v))."
    return 0
  fi
  log "Instalando Node.js 20 (no afecta turismo)..."
  export DEBIAN_FRONTEND=noninteractive
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
}

clone_app() {
  mkdir -p "$(dirname "$APP_ROOT")"
  if [[ ! -d "$APP_ROOT/.git" ]]; then
    log "Clonando en $APP_ROOT..."
    git clone "$GIT_REPO" "$APP_ROOT"
  else
    log "Repo ya existe; git pull..."
    git -C "$APP_ROOT" pull --ff-only
  fi
}

setup_postgresql() {
  log "Creando BD ${DB_NAME} (independiente de turismo1)..."
  if [[ -z "$DB_PASSWORD" ]]; then
    DB_PASSWORD="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)"
    log "DB_PASSWORD generado: $DB_PASSWORD"
  fi

  local role_exists db_exists
  role_exists="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" || true)"
  if [[ "$role_exists" != "1" ]]; then
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
  else
    sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
  fi

  db_exists="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" || true)"
  if [[ "$db_exists" != "1" ]]; then
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
  fi

  sudo -u postgres psql -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"
}

ensure_env() {
  if [[ ! -f "$APP_ROOT/backend/.env" ]]; then
    cp "$APP_ROOT/deploy/env.production.example" "$APP_ROOT/backend/.env"
  fi
  sed -i "s/tudominio.cl/${DOMAIN}/g" "$APP_ROOT/backend/.env" || true
  sed -i "s/IP_DE_TU_VPS/${DOMAIN}/g" "$APP_ROOT/backend/.env" || true
  if ! grep -q "^DB_NAME=" "$APP_ROOT/backend/.env"; then
    echo "DB_NAME=${DB_NAME}" >> "$APP_ROOT/backend/.env"
  fi
  if ! grep -q "^DB_USER=" "$APP_ROOT/backend/.env"; then
    echo "DB_USER=${DB_USER}" >> "$APP_ROOT/backend/.env"
  fi
  grep -q "^DB_PASSWORD=${DB_PASSWORD}$" "$APP_ROOT/backend/.env" 2>/dev/null || \
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" "$APP_ROOT/backend/.env"

  if grep -q "REEMPLAZAR_CON_CLAVE" "$APP_ROOT/backend/.env"; then
    local sk
    sk="$("$APP_ROOT/venv/bin/python" -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())" 2>/dev/null || true)"
    if [[ -n "$sk" ]]; then
      sed -i "s/SECRET_KEY=.*/SECRET_KEY=${sk}/" "$APP_ROOT/backend/.env"
    fi
  fi

  log "Revisa $APP_ROOT/backend/.env si necesitas correo u Odoo."
}

setup_python() {
  if [[ ! -d "$APP_ROOT/venv" ]]; then
    python3 -m venv "$APP_ROOT/venv"
  fi
  "$APP_ROOT/venv/bin/pip" install --upgrade pip -q
  "$APP_ROOT/venv/bin/pip" install -r "$APP_ROOT/backend/requirements.txt" -q
}

build_and_migrate() {
  cd "$APP_ROOT/frontend"
  npm ci --silent 2>/dev/null || npm install --silent
  VITE_API_URL="https://${DOMAIN}" npm run build

  cd "$APP_ROOT/backend"
  "$APP_ROOT/venv/bin/python" manage.py migrate --noinput
  "$APP_ROOT/venv/bin/python" manage.py createcachetable 2>/dev/null || true
  "$APP_ROOT/venv/bin/python" manage.py collectstatic --noinput

  mkdir -p "$APP_ROOT/backend/Media" "$APP_ROOT/backend/staticfiles"
  chown -R www-data:www-data "$APP_ROOT/backend/Media" "$APP_ROOT/backend/staticfiles" "$APP_ROOT/frontend/dist"
}

configure_nginx_sidecar() {
  log "Agregando sitio nginx/facturacion (sin tocar turismo)..."
  local tpl="$APP_ROOT/deploy/nginx/facturacion.conf"
  if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    tpl="$APP_ROOT/deploy/nginx/facturacion-production.conf"
  fi
  sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__GUNICORN_PORT__/${GUNICORN_PORT}/g" \
    "$tpl" > /etc/nginx/sites-available/facturacion
  ln -sf /etc/nginx/sites-available/facturacion /etc/nginx/sites-enabled/facturacion
  # NO eliminar default ni turismo. Solo validar y recargar.
  nginx -t
  systemctl reload nginx
}

configure_systemd_sidecar() {
  log "Servicio facturacion-gunicorn en 127.0.0.1:${GUNICORN_PORT}..."
  sed -e "s|__APP_ROOT__|${APP_ROOT}|g" -e "s|__GUNICORN_PORT__|${GUNICORN_PORT}|g" \
    "$APP_ROOT/deploy/systemd/facturacion-gunicorn.service" \
    > /etc/systemd/system/facturacion-gunicorn.service
  systemctl daemon-reload
  systemctl enable facturacion-gunicorn
  systemctl start facturacion-gunicorn
}

configure_ssl_sidecar() {
  [[ "$ENABLE_SSL" == "1" ]] || return 0
  [[ -n "$SSL_EMAIL" ]] || { log "Falta SSL_EMAIL; omitiendo certbot."; return 0; }

  log "Certificado SSL solo para ${DOMAIN}..."
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$SSL_EMAIL" || true
  if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__GUNICORN_PORT__/${GUNICORN_PORT}/g" \
      "$APP_ROOT/deploy/nginx/facturacion-production.conf" > /etc/nginx/sites-available/facturacion
    nginx -t && systemctl reload nginx
  fi
}

verify() {
  log "Verificando turismo sigue activo..."
  if systemctl is-active --quiet turismo-gunicorn 2>/dev/null; then
    log "OK: turismo-gunicorn active"
  fi
  curl -sf -o /dev/null "http://127.0.0.1:${GUNICORN_PORT}/api/health/" && \
    log "OK: facturacion API responde en :${GUNICORN_PORT}" || \
    log "WARN: API facturacion no respondió aún (revisa .env SECRET_KEY)"
}

main() {
  require_root
  preflight
  ensure_node
  clone_app
  setup_python
  setup_postgresql
  ensure_env
  build_and_migrate
  configure_systemd_sidecar
  configure_nginx_sidecar
  configure_ssl_sidecar
  verify

  cat <<EOF

========================================
Facturación instalada (modo sidecar)
========================================
URL nueva:  https://${DOMAIN}/
Turismo:    NO modificado (arriendavip.cl sigue igual)
Proyecto:   ${APP_ROOT}
Gunicorn:   127.0.0.1:${GUNICORN_PORT}
BD:         ${DB_NAME} (separada de turismo1)

Antes de SSL: crea DNS A  ${DOMAIN}  →  IP de la VPS

Actualizar después:
  cd ${APP_ROOT} && git pull && sudo bash deploy/update-app.sh
EOF
}

main "$@"
