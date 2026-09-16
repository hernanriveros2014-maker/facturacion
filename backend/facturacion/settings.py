"""Django settings for facturacion project."""

import os
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured

try:
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).resolve().parent.parent / '.env', override=True)
except ImportError:
    pass

BASE_DIR = Path(__file__).resolve().parent.parent

MEDIA_ROOT = BASE_DIR / 'Media'
MEDIA_URL = '/media/'

MAX_UPLOAD_SIZE = 20 * 1024 * 1024
DATA_UPLOAD_MAX_MEMORY_SIZE = MAX_UPLOAD_SIZE
FILE_UPLOAD_MAX_MEMORY_SIZE = MAX_UPLOAD_SIZE

_SECRET_KEY = (os.environ.get('SECRET_KEY') or '').strip()
_SECRET_KEY_PLACEHOLDERS = {
    '',
    'reemplazar-por-clave-aleatoria-de-al-menos-40-caracteres',
    'REEMPLAZAR_CON_CLAVE_ALEATORIA_MINIMO_40_CARACTERES_XYZ',
}
if (
    not _SECRET_KEY
    or _SECRET_KEY in _SECRET_KEY_PLACEHOLDERS
    or _SECRET_KEY.startswith('django-insecure-')
    or len(_SECRET_KEY) < 40
):
    raise ImproperlyConfigured(
        'SECRET_KEY inválida o ausente. Defínela en backend/.env '
        '(mín. 40 caracteres). Copia backend/.env.example para local.'
    )
SECRET_KEY = _SECRET_KEY

DEBUG = os.environ.get('DJANGO_DEBUG', 'false').lower() in ('1', 'true', 'yes', 'on')

ALLOWED_HOSTS = [
    host.strip()
    for host in os.environ.get(
        'ALLOWED_HOSTS',
        'localhost,127.0.0.1,facturacion.local,host.docker.internal',
    ).split(',')
    if host.strip()
]

CSRF_TRUSTED_ORIGINS = [
    origin.strip()
    for origin in os.environ.get('CSRF_TRUSTED_ORIGINS', '').split(',')
    if origin.strip()
]

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'corsheaders',
    'rest_framework',
    'oauth2_provider',
    'api',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'facturacion.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'facturacion.wsgi.application'


def _clean_env_secret(raw):
    value = '' if raw is None else str(raw)
    value = value.strip().strip('\ufeff').strip('\r')
    if len(value) >= 2 and value[0] == value[-1] and value[0] in '"\'':
        value = value[1:-1].strip()
    return value


_DB_PASSWORD = _clean_env_secret(os.environ.get('DB_PASSWORD'))
_DB_PASSWORD_PLACEHOLDERS = {
    '',
    'cambia_esta_contrasena',
    'tu_password',
    'REEMPLAZAR_DB_PASSWORD',
}
if _DB_PASSWORD in _DB_PASSWORD_PLACEHOLDERS:
    raise ImproperlyConfigured(
        'DB_PASSWORD inválida o ausente. Defínela en backend/.env '
        'según tu PostgreSQL local o deploy/env.production.example.'
    )

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'facturacion1'),
        'USER': os.environ.get('DB_USER', 'postgres'),
        'PASSWORD': _DB_PASSWORD,
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'es'
TIME_ZONE = 'America/Santiago'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'


def _env_bool(name, default='false'):
    return os.environ.get(name, default).lower() in ('1', 'true', 'yes', 'on')


if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_REFERRER_POLICY = 'strict-origin-when-cross-origin'
    X_FRAME_OPTIONS = 'SAMEORIGIN'

    if _env_bool('DJANGO_SECURE_SSL', 'true'):
        SECURE_SSL_REDIRECT = True
        SESSION_COOKIE_SECURE = True
        CSRF_COOKIE_SECURE = True
        SECURE_HSTS_SECONDS = int(os.environ.get('SECURE_HSTS_SECONDS', '31536000'))
        SECURE_HSTS_INCLUDE_SUBDOMAINS = _env_bool('SECURE_HSTS_INCLUDE_SUBDOMAINS', 'true')
        SECURE_HSTS_PRELOAD = _env_bool('SECURE_HSTS_PRELOAD', 'false')

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

if DEBUG:
    CORS_ALLOW_ALL_ORIGINS = True
    CORS_ALLOWED_ORIGINS = ['http://localhost:5173']
else:
    CORS_ALLOW_ALL_ORIGINS = False
    CORS_ALLOWED_ORIGINS = [
        origin.strip()
        for origin in os.environ.get('CORS_ALLOWED_ORIGINS', '').split(',')
        if origin.strip()
    ]
CORS_ALLOW_CREDENTIALS = True

EMAIL_SSL_INSECURE = os.environ.get('EMAIL_SSL_INSECURE', 'true').lower() == 'true'
EMAIL_HOST = os.environ.get('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT = int(os.environ.get('EMAIL_PORT', '587'))
EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'true').lower() == 'true'
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = (os.environ.get('EMAIL_HOST_PASSWORD', '') or '').strip().replace(' ', '')
EMAIL_TIMEOUT = int(os.environ.get('EMAIL_TIMEOUT', '30'))
EMAIL_BACKEND = os.environ.get(
    'EMAIL_BACKEND',
    'django.core.mail.backends.console.EmailBackend' if DEBUG else 'django.core.mail.backends.smtp.EmailBackend',
)
DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL', 'Facturacion <noreply@example.com>')

_frontend_base_url = os.environ.get('FRONTEND_BASE_URL', '').strip()
if not _frontend_base_url:
    _frontend_base_url = 'http://localhost:5173' if DEBUG else 'https://tudominio.cl'
FRONTEND_BASE_URL = _frontend_base_url.rstrip('/')

_backend_public_url = os.environ.get('BACKEND_PUBLIC_URL', '').strip()
if not _backend_public_url:
    _backend_public_url = 'http://localhost:8000' if DEBUG else _frontend_base_url
BACKEND_PUBLIC_URL = _backend_public_url.rstrip('/')

ODOO_URL = os.environ.get('ODOO_URL', '').strip()
ODOO_DB = os.environ.get('ODOO_DB', '').strip()
ODOO_USER = os.environ.get('ODOO_USER', '').strip()
ODOO_PASSWORD = os.environ.get('ODOO_PASSWORD', '').strip()
ODOO_ENABLED = _env_bool('ODOO_ENABLED', 'false')
ODOO_SSL_VERIFY = _env_bool('ODOO_SSL_VERIFY', 'true')

_cache_backend = os.environ.get('CACHE_BACKEND', '').strip().lower()
if _cache_backend == 'locmem':
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        }
    }
else:
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.db.DatabaseCache',
            'LOCATION': os.environ.get('CACHE_TABLE', 'django_cache'),
        }
    }

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'oauth2_provider.contrib.rest_framework.OAuth2Authentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_THROTTLE_CLASSES': (
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ),
    'DEFAULT_THROTTLE_RATES': {
        'anon': os.environ.get('THROTTLE_ANON', '120/min'),
        'user': os.environ.get('THROTTLE_USER', '600/min'),
    },
}
