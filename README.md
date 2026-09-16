# Facturación

Proyecto con la misma arquitectura que [turismo-desarrollo](https://github.com/hernanriveros2014-maker/turismo-desarrollo):

- **Backend:** Django 5 + Django REST Framework + JWT + OAuth2 + PostgreSQL
- **Frontend:** React 19 + Vite
- **DevOps:** Docker Compose (dev), Nginx, GitHub Actions CI, scripts de deploy VPS

## Estructura

```
facturacion/
├── backend/                 # API Django
│   ├── api/                 # App REST
│   └── facturacion/         # Settings y URLs
├── frontend/                # SPA React
├── deploy/                  # Bootstrap y env producción
├── nginx/                   # Proxy dev (docker-compose)
├── docker-compose.dev.yml
├── instalar-dependencias.bat
└── iniciar-sitio.bat
```

## Inicio rápido (Windows)

1. Instalar [Python 3.12](https://www.python.org/) y [Node.js 22](https://nodejs.org/)
2. Tener PostgreSQL corriendo (o usar `docker compose -f docker-compose.dev.yml up`)
3. Ejecutar:

```bat
instalar-dependencias.bat
iniciar-sitio.bat
```

4. Abrir http://localhost:5173/

## Variables de entorno

Copia `backend/.env.example` a `backend/.env` y ajusta:

- `SECRET_KEY` — mínimo 40 caracteres
- `DB_*` — conexión PostgreSQL

## Docker (desarrollo)

```bash
docker compose -f docker-compose.dev.yml up --build
```

## API

- `GET /api/health/` — estado del servicio
- `POST /api/token/` — login JWT
- `POST /api/token/refresh/` — refrescar token

## CI

GitHub Actions ejecuta `manage.py check`, tests unitarios y `npm run build` en cada push a `main`.
