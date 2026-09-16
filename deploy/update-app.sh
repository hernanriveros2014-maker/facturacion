#!/usr/bin/env bash
# Actualiza aplicación (código, pip, migrate, static, reinicio).
# Uso: sudo bash /var/www/facturacion/deploy/update-app.sh
set -eu
set -o pipefail

APP_ROOT="${APP_ROOT:-/var/www/facturacion}"

log() {
  echo "[update-app] $*"
}

if [[ ! -f "$APP_ROOT/backend/manage.py" ]]; then
  echo "No se encontró el proyecto en $APP_ROOT"
  exit 1
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Ejecuta como root: sudo bash deploy/update-app.sh"
  exit 1
fi

cd "$APP_ROOT"

if [[ -d .git ]]; then
  log "Actualizando código (git pull)..."
  git pull --ff-only
fi

log "Dependencias Python..."
"$APP_ROOT/venv/bin/pip" install -r "$APP_ROOT/backend/requirements.txt"

log "Compilando frontend..."
cd "$APP_ROOT/frontend"
if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi
VITE_API_URL="$(grep -E '^VITE_API_URL=' "$APP_ROOT/backend/.env" | head -n1 | cut -d= -f2- || true)"
VITE_API_URL="${VITE_API_URL:-}" npm run build

log "Migraciones Django..."
cd "$APP_ROOT/backend"
"$APP_ROOT/venv/bin/python" manage.py migrate --noinput
"$APP_ROOT/venv/bin/python" manage.py createcachetable 2>/dev/null || true
"$APP_ROOT/venv/bin/python" manage.py collectstatic --noinput

chown -R www-data:www-data "$APP_ROOT/backend/Media" "$APP_ROOT/backend/staticfiles" "$APP_ROOT/frontend/dist"

log "Reiniciando servicios..."
systemctl restart facturacion-gunicorn
systemctl reload nginx

log "Aplicación actualizada."
