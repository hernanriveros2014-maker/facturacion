# Despliegue en VPS — Facturación

Scripts y configuración para levantar el sitio en Ubuntu (VPS).

## Requisitos

- Ubuntu 22.04 / 24.04 con acceso root (SSH)
- Dominio apuntando a la IP (opcional al inicio)
- Código del proyecto en la VPS

## 1. Subir el proyecto

**Opción A — Git**

```bash
sudo mkdir -p /var/www
sudo git clone https://github.com/hernanriveros2014-maker/facturacion.git /var/www/facturacion
```

**Opción B — Copiar desde tu PC (PowerShell)**

```powershell
scp -r C:\Facturacion root@IP_VPS:/var/www/facturacion
```

## 2. Configurar variables

```bash
cp /var/www/facturacion/deploy/env.production.example /var/www/facturacion/backend/.env
nano /var/www/facturacion/backend/.env
```

Completa al menos:

- `SECRET_KEY` (clave larga aleatoria)
- `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS`, `CORS_ALLOWED_ORIGINS`
- `DB_PASSWORD`
- `VITE_API_URL` (ej. `https://tudominio.cl`)

## 3. Instalación inicial

Con dominio y SSL:

```bash
cd /var/www/facturacion
sudo DOMAIN=tudominio.cl ENABLE_SSL=1 SSL_EMAIL=admin@tudominio.cl bash deploy/bootstrap-vps.sh
```

Solo con IP (pruebas):

```bash
sudo DOMAIN=203.0.113.10 bash deploy/bootstrap-vps.sh
```

## 4. Verificar

```bash
systemctl status facturacion-gunicorn nginx postgresql
curl -I http://tudominio.cl/api/health/
```

## Estructura (igual que turismo-desarrollo)

```
facturacion/
├── backend/          # Django + DRF
├── frontend/         # React + Vite
├── deploy/           # Scripts VPS
├── nginx/            # Config dev (docker-compose)
└── docker-compose.dev.yml
```
