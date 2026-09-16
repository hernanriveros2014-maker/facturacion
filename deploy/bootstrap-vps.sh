#!/usr/bin/env bash
# Instalación inicial en Ubuntu VPS.
# Uso:
#   sudo DOMAIN=tudominio.cl bash deploy/bootstrap-vps.sh
#   sudo DOMAIN=203.0.113.10 GIT_REPO=https://github.com/hernanriveros2014-maker/facturacion.git bash deploy/bootstrap-vps.sh
#   sudo DOMAIN=tudominio.cl ENABLE_SSL=1 SSL_EMAIL=admin@tudominio.cl bash deploy/bootstrap-vps.sh
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

log() {
  echo "[bootstrap] $*"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Ejecuta como root: sudo DOMAIN=tudominio.cl bash deploy/bootstrap-vps.sh"
    exit 1
  fi
}

install_packages() {
  log "Instalando paquetes del sistema..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y \
    nginx \
    postgresql \
    postgresql-contrib \
    python3-venv \
    python3-pip \
    python3-dev \
    libpq-dev \
    git \
    curl \
    certbot \
    python3-certbot-nginx \
    ufw

  if ! command -v node >/dev/null 2>&1; then
    log "Instalando Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  fi
}

ensure_app_tree() {
  mkdir -p "$(dirname "$APP_ROOT")"

  if [[ -n "$GIT_REPO" ]]; then
    if [[ ! -d "$APP_ROOT/.git" ]]; then
      log "Clonando repositorio en $APP_ROOT..."
      git clone "$GIT_REPO" "$APP_ROOT"
    else
      log "Repositorio ya existe en $APP_ROOT"
    fi
  fi

  if [[ ! -f "$APP_ROOT/backend/manage.py" ]]; then
    cat <<EOF
No se encontró el proyecto en $APP_ROOT.

Opciones:
  1) Copia el código con git/scp/rsync a $APP_ROOT
  2) Define GIT_REPO=https://... y vuelve a ejecutar este script
EOF
    exit 1
  fi
}

setup_postgresql() {
  log "Configurando PostgreSQL..."

  if [[ -z "$DB_PASSWORD" ]]; then
    DB_PASSWORD="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)"
    log "DB_PASSWORD generado automáticamente: $DB_PASSWORD"
    log "Guárdalo en backend/.env"
  fi

  local role_exists
  role_exists="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" || true)"
  if [[ "$role_exists" != "1" ]]; then
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
  else
    sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
  fi

  local db_exists
  db_exists="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" || true)"
  if [[ "$db_exists" != "1" ]]; then
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
  fi

  sudo -u postgres psql -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"
  sudo -u postgres psql -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};"
  sudo -u postgres psql -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};"
}

ensure_env_file() {
  if [[ ! -f "$APP_ROOT/backend/.env" ]]; then
    log "Creando backend/.env desde deploy/env.production.example"
    cp "$APP_ROOT/deploy/env.production.example" "$APP_ROOT/backend/.env"
  fi

  if ! grep -q "^DB_PASSWORD=" "$APP_ROOT/backend/.env"; then
    echo "DB_PASSWORD=${DB_PASSWORD}" >> "$APP_ROOT/backend/.env"
  fi

  if [[ -n "$DOMAIN" ]]; then
    sed -i "s/tudominio.cl/${DOMAIN}/g" "$APP_ROOT/backend/.env" || true
    sed -i "s/IP_DE_TU_VPS/${DOMAIN}/g" "$APP_ROOT/backend/.env" || true
  fi

  log "Revisa y completa: $APP_ROOT/backend/.env (SECRET_KEY obligatorio)"
}

setup_python() {
  log "Instalando dependencias Python..."
  python3 -m venv "$APP_ROOT/venv"
  "$APP_ROOT/venv/bin/pip" install --upgrade pip
  "$APP_ROOT/venv/bin/pip" install -r "$APP_ROOT/backend/requirements.txt"
}

build_frontend() {
  log "Compilando frontend..."
  local vite_api_url="https://${DOMAIN}"
  if [[ -f "$APP_ROOT/backend/.env" ]]; then
    local from_env
    from_env="$(grep -E '^VITE_API_URL=' "$APP_ROOT/backend/.env" | head -n1 | cut -d= -f2- || true)"
    if [[ -n "$from_env" ]]; then
      vite_api_url="$from_env"
    fi
  fi

  cd "$APP_ROOT/frontend"
  if [[ -f package-lock.json ]]; then
    npm ci
  else
    npm install
  fi
  VITE_API_URL="$vite_api_url" npm run build
}

setup_django() {
  log "Migraciones y archivos estáticos Django..."
  cd "$APP_ROOT/backend"
  "$APP_ROOT/venv/bin/python" manage.py migrate --noinput
  "$APP_ROOT/venv/bin/python" manage.py createcachetable 2>/dev/null || true
  "$APP_ROOT/venv/bin/python" manage.py collectstatic --noinput
}

fix_permissions() {
  log "Ajustando permisos..."
  mkdir -p "$APP_ROOT/backend/Media"
  mkdir -p "$APP_ROOT/backend/staticfiles"
  chown -R www-data:www-data "$APP_ROOT/backend/Media" "$APP_ROOT/backend/staticfiles"
  chown -R www-data:www-data "$APP_ROOT/frontend/dist"
}

configure_nginx() {
  log "Configurando Nginx (puerto Gunicorn ${GUNICORN_PORT})..."
  if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__GUNICORN_PORT__/${GUNICORN_PORT}/g" \
      "$APP_ROOT/deploy/nginx/facturacion-production.conf" \
      > /etc/nginx/sites-available/facturacion
  else
    sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__GUNICORN_PORT__/${GUNICORN_PORT}/g" \
      "$APP_ROOT/deploy/nginx/facturacion.conf" \
      > /etc/nginx/sites-available/facturacion
  fi
  ln -sf /etc/nginx/sites-available/facturacion /etc/nginx/sites-enabled/facturacion
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl enable nginx
  systemctl restart nginx
}

configure_systemd() {
  log "Configurando servicio Gunicorn..."
  sed -e "s|__APP_ROOT__|${APP_ROOT}|g" -e "s|__GUNICORN_PORT__|${GUNICORN_PORT}|g" \
    "$APP_ROOT/deploy/systemd/facturacion-gunicorn.service" \
    > /etc/systemd/system/facturacion-gunicorn.service
  systemctl daemon-reload
  systemctl enable facturacion-gunicorn
  systemctl restart facturacion-gunicorn
}

configure_firewall() {
  log "Configurando firewall..."
  ufw allow OpenSSH || true
  ufw allow 'Nginx Full' || true
  ufw --force enable || true
}

configure_ssl() {
  if [[ "$ENABLE_SSL" != "1" ]]; then
    return 0
  fi
  if [[ -z "$SSL_EMAIL" ]]; then
    log "ENABLE_SSL=1 pero falta SSL_EMAIL; omitiendo certbot"
    return 0
  fi
  log "Solicitando certificado SSL..."
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$SSL_EMAIL" || true
  if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    log "Aplicando Nginx producción (HTTPS + cabeceras)..."
    sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__GUNICORN_PORT__/${GUNICORN_PORT}/g" \
      "$APP_ROOT/deploy/nginx/facturacion-production.conf" \
      > /etc/nginx/sites-available/facturacion
    nginx -t
    systemctl reload nginx
  fi
}

main() {
  require_root

  if [[ -z "$DOMAIN" ]]; then
    echo "Debes indicar DOMAIN (dominio o IP pública)."
    echo "Ejemplo: sudo DOMAIN=facturacion.tudominio.cl bash deploy/bootstrap-vps.sh"
    exit 1
  fi

  install_packages
  ensure_app_tree
  setup_postgresql
  ensure_env_file
  setup_python
  build_frontend
  setup_django
  fix_permissions
  configure_nginx
  configure_systemd
  configure_firewall
  configure_ssl

  cat <<EOF

========================================
Instalación base completada
========================================
URL:      http://${DOMAIN}
Proyecto: ${APP_ROOT}
Env:      ${APP_ROOT}/backend/.env
Gunicorn: 127.0.0.1:${GUNICORN_PORT}

Siguientes pasos:
  1) Editar ${APP_ROOT}/backend/.env (SECRET_KEY, correo, dominio)
  2) systemctl restart facturacion-gunicorn nginx
  3) Verificar:
       curl -I http://${DOMAIN}/api/health/
  4) SSL (cuando el dominio apunte a la VPS):
       sudo DOMAIN=${DOMAIN} ENABLE_SSL=1 SSL_EMAIL=tu@mail.cl bash deploy/bootstrap-vps.sh

Actualizar código después:
  sudo bash ${APP_ROOT}/deploy/update-app.sh
EOF
}

main "$@"
