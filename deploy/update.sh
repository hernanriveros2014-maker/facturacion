#!/usr/bin/env bash
# Atajo: actualiza solo aplicación.
set -eu
set -o pipefail

APP_ROOT="${APP_ROOT:-/var/www/facturacion}"
bash "$APP_ROOT/deploy/update-app.sh"
