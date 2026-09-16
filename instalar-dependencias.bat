@echo off
chcp 65001 >nul
title Facturacion - Instalar dependencias
cd /d "%~dp0"

echo ============================================
echo   FACTURACION - Instalar dependencias
echo ============================================
echo.

if not exist "%~dp0env\Scripts\python.exe" (
    echo [1/4] Creando entorno virtual Python...
    python -m venv env
    if errorlevel 1 (
        echo [ERROR] No se pudo crear el venv. Instala Python 3.12.
        pause
        exit /b 1
    )
) else (
    echo [1/4] Entorno virtual ya existe.
)

echo [2/4] Instalando paquetes Python...
"%~dp0env\Scripts\pip.exe" install -r "%~dp0backend\requirements.txt"
if errorlevel 1 (
    echo [ERROR] Fallo la instalacion de paquetes Python.
    pause
    exit /b 1
)

if not exist "%~dp0backend\.env" (
    echo [3/4] Creando backend\.env desde .env.example ...
    copy /Y "%~dp0backend\.env.example" "%~dp0backend\.env" >nul
) else (
    echo [3/4] backend\.env ya existe.
)

echo [4/4] Instalando dependencias del frontend...
cd /d "%~dp0frontend"
call npm install
if errorlevel 1 (
    echo [ERROR] Fallo npm install. Instala Node.js desde https://nodejs.org/
    pause
    exit /b 1
)

cd /d "%~dp0backend"
echo.
echo [OPCIONAL] Aplicando migraciones de Django...
"%~dp0env\Scripts\python.exe" manage.py migrate

echo.
echo ============================================
echo   Instalacion completada
echo ============================================
echo.
echo   Para arrancar el sitio, ejecuta: iniciar-sitio.bat
echo.
pause
