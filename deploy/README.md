# Despliegue en VPS — Facturación

Misma arquitectura que turismo-desarrollo: Nginx + Gunicorn + PostgreSQL + systemd.

## Requisitos

- Ubuntu 22.04 / 24.04 con SSH root
- Dominio apuntando a la IP (recomendado para SSL)
- Repo: https://github.com/hernanriveros2014-maker/facturacion

## Instalación inicial (VPS)

```bash
ssh root@IP_DE_TU_VPS

sudo git clone https://github.com/hernanriveros2014-maker/facturacion.git /var/www/facturacion
cd /var/www/facturacion

# Editar SECRET_KEY y DB antes de arrancar
cp deploy/env.production.example backend/.env
nano backend/.env

# Con dominio + SSL
sudo DOMAIN=facturacion.tudominio.cl ENABLE_SSL=1 SSL_EMAIL=admin@tudominio.cl bash deploy/bootstrap-vps.sh

# Solo IP (pruebas)
sudo DOMAIN=203.0.113.10 bash deploy/bootstrap-vps.sh
```

## Verificar

```bash
systemctl status facturacion-gunicorn nginx postgresql
curl -I http://TU_DOMINIO/api/health/
```

## Actualizar después de cambios

En tu PC: `git push origin main`

En la VPS:

```bash
cd /var/www/facturacion
git pull origin main
sudo bash deploy/update-app.sh
```

## Instalar junto a ArriendaVIP (sin impacto)

Usa el script sidecar — **no toca turismo**:

```bash
sudo DOMAIN=facturacion.arriendavip.cl ENABLE_SSL=1 SSL_EMAIL=admin@arriendavip.cl \
  bash deploy/install-sidecar-vps.sh
```

Guía completa: `deploy/instalar-junto-arriendavip.txt`

Requisito previo: DNS `facturacion.arriendavip.cl` → misma IP de la VPS.

## Convivencia con turismo en la misma VPS

| Proyecto    | Ruta                  | Gunicorn   | Nginx site     |
|-------------|-----------------------|------------|----------------|
| Turismo     | `/var/www/turismo`    | `:8000`    | `turismo`      |
| Facturación | `/var/www/facturacion`| `:8001`    | `facturacion`  |

Cada uno con su propio dominio en Nginx.

## Archivos clave

- `bootstrap-vps.sh` — instalación completa
- `update-app.sh` — actualizar código en producción
- `nginx/facturacion*.conf` — configuración Nginx
- `systemd/facturacion-gunicorn.service` — servicio backend

Ver también: `subir-cambios-vps.txt`
