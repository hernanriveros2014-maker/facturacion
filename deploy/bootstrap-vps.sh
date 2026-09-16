#!/usr/bin/env bash
set -euo pipefail

# Bootstrap mínimo para VPS — misma idea que turismo-desarrollo.
# Uso: sudo DOMAIN=tudominio.cl bash deploy/bootstrap-vps.sh

DOMAIN="${DOMAIN:-localhost}"
APP_DIR="${APP_DIR:-/var/www/facturacion}"
APP_USER="${APP_USER:-www-data}"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"

echo "==> Instalando dependencias del sistema"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  "$PYTHON_BIN" "$PYTHON_BIN"-venv python3-pip \
  postgresql postgresql-contrib nginx git curl

echo "==> Preparando directorio $APP_DIR"
mkdir -p "$APP_DIR"
chown -R "$SUDO_USER":"$SUDO_USER" "$APP_DIR" 2>/dev/null || true

echo "==> Creando entorno virtual"
cd "$APP_DIR"
"$PYTHON_BIN" -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r backend/requirements.txt

echo "==> Migraciones Django"
cd "$APP_DIR/backend"
../venv/bin/python manage.py migrate --noinput
../venv/bin/python manage.py collectstatic --noinput

echo "==> Frontend build"
cd "$APP_DIR/frontend"
if command -v npm >/dev/null 2>&1; then
  npm ci
  npm run build
else
  echo "Node.js no instalado; instala Node 22 y ejecuta npm ci && npm run build"
fi

echo "==> Bootstrap base completado para $DOMAIN"
echo "Configura systemd/nginx según tu VPS (ver deploy/README.md)."
