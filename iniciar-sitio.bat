@echo off
chcp 65001 >nul
title Facturacion - Iniciar sitio
cd /d "%~dp0"

echo ============================================
echo   FACTURACION - Arrancar el sitio
echo ============================================
echo.

if not exist "%~dp0env\Scripts\python.exe" (
    echo [ERROR] No se encontro el entorno virtual en: env\Scripts\python.exe
    echo.
    echo Ejecuta primero: instalar-dependencias.bat
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0backend\.env" (
    echo [INFO] Copiando backend\.env.example a backend\.env ...
    copy /Y "%~dp0backend\.env.example" "%~dp0backend\.env" >nul
)

if not exist "%~dp0frontend\node_modules" (
    echo [INFO] Instalando dependencias del frontend ^(npm install^)...
    cd /d "%~dp0frontend"
    call npm install
    if errorlevel 1 (
        echo [ERROR] Fallo npm install. Verifica que Node.js este instalado.
        pause
        exit /b 1
    )
    cd /d "%~dp0"
    echo.
)

echo [1/2] Iniciando Backend ^(Django^) en http://localhost:8000/
start "Facturacion - Backend (Django)" cmd /k "cd /d "%~dp0backend" && "%~dp0env\Scripts\python.exe" manage.py runserver"

echo [2/2] Esperando 2 segundos antes del frontend...
timeout /t 2 /nobreak >nul

echo [2/2] Iniciando Frontend ^(Vite/React^) en http://localhost:5173/
start "Facturacion - Frontend (Vite)" cmd /k "cd /d "%~dp0frontend" && npm run dev"

echo.
echo ============================================
echo   Sitio en marcha
echo ============================================
echo.
echo   Frontend:  http://localhost:5173/
echo   API:       http://localhost:8000/api/health/
echo   Admin:     http://localhost:8000/admin/
echo.
pause
