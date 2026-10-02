@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

REM ============================================================
REM  Restaura un dump en la base local (Docker).
REM
REM  Uso:
REM    Doble clic  -> usa el .dump MAS RECIENTE en backups\
REM    O: restaurar-en-bambi.bat backups\voluntariado_XXXX.dump
REM ============================================================

set "ROOT=%~dp0"
set "BACKEND_DIR=%ROOT%backend"
set "OUT_DIR=%ROOT%backups"
set "CONTAINER=voluntariado_db_local"
set "DB=voluntariado_hogar_bambi"
set "PGUSER=postgres"

set "DUMP=%~1"

if not "%DUMP%"=="" goto have_dump

if not exist "%OUT_DIR%" (
  echo ERROR: No existe la carpeta backups\
  echo Genera un dump antes con exportar-base-local.bat
  pause
  exit /b 1
)

set "DUMP="
for /f "delims=" %%F in ('dir /b /o-d "%OUT_DIR%\voluntariado_*.dump" 2^>nul') do (
  set "DUMP=%OUT_DIR%\%%F"
  goto have_dump
)

echo ERROR: No hay ningun archivo voluntariado_*.dump en:
echo   %OUT_DIR%
echo Genera uno con exportar-base-local.bat
pause
exit /b 1

:have_dump
REM Resolver ruta relativa respecto a la carpeta del script
if not exist "%DUMP%" if exist "%ROOT%%DUMP%" set "DUMP=%ROOT%%DUMP%"

if not exist "%DUMP%" (
  echo ERROR: No encuentro el dump:
  echo   %DUMP%
  pause
  exit /b 1
)

echo Dump a usar:
echo   %DUMP%
echo.

where docker >nul 2>&1
if errorlevel 1 (
  echo ERROR: Docker no esta en el PATH.
  echo Abre Docker Desktop e intenta de nuevo.
  pause
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo ERROR: Docker Desktop no esta corriendo.
  echo Abrelo, espera a que diga "Engine running" y vuelve a intentar.
  pause
  exit /b 1
)

if not exist "%BACKEND_DIR%\docker-compose.yml" (
  echo ERROR: No encuentro backend\docker-compose.yml
  pause
  exit /b 1
)

echo Levantando Postgres (si hace falta)...
pushd "%BACKEND_DIR%"
docker compose up -d
if errorlevel 1 (
  popd
  echo ERROR: docker compose up fallo.
  pause
  exit /b 1
)
popd

echo Esperando a que Postgres acepte conexiones...
set /a _tries=0
:wait_pg
set /a _tries+=1
docker exec "%CONTAINER%" pg_isready -U "%PGUSER%" -d "%DB%" >nul 2>&1
if not errorlevel 1 goto pg_ok
if %_tries% GEQ 40 (
  echo ERROR: Postgres no respondio a tiempo.
  echo Estado del contenedor:
  docker ps -a --filter "name=%CONTAINER%"
  pause
  exit /b 1
)
ping -n 2 127.0.0.1 >nul
goto wait_pg

:pg_ok
echo Postgres listo.

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmm"') do set "STAMP=%%I"
set "SAFETY=%OUT_DIR%\bambi_antes_de_restaurar_%STAMP%.dump"

echo.
echo === PASO 1: Respaldo de seguridad de la base ACTUAL ===
docker exec "%CONTAINER%" pg_dump -U "%PGUSER%" -d "%DB%" -F c -f /tmp/bambi_safety.dump
if errorlevel 1 (
  echo ERROR: no se pudo crear el respaldo de seguridad.
  pause
  exit /b 1
)
docker cp "%CONTAINER%:/tmp/bambi_safety.dump" "%SAFETY%"
docker exec "%CONTAINER%" rm -f /tmp/bambi_safety.dump >nul 2>&1
echo Guardado en:
echo   %SAFETY%

echo.
echo === PASO 2: Restaurar dump ===
echo Esto REEMPLAZA los datos actuales por los del dump.
echo.
set /p CONFIRM=Escribe SI para continuar: 
if /i not "%CONFIRM%"=="SI" (
  echo Cancelado. Solo se creo el respaldo; la base no se cambio.
  pause
  exit /b 0
)

echo Copiando dump al contenedor...
docker cp "%DUMP%" "%CONTAINER%:/tmp/restore.dump"
if errorlevel 1 (
  echo ERROR: docker cp del dump fallo.
  pause
  exit /b 1
)

echo Restaurando (puede tardar un momento)...
docker exec "%CONTAINER%" pg_restore -U "%PGUSER%" -d "%DB%" --clean --if-exists --no-owner --no-acl /tmp/restore.dump
set "RC=%ERRORLEVEL%"
docker exec "%CONTAINER%" rm -f /tmp/restore.dump >nul 2>&1

echo.
if %RC% GEQ 2 (
  echo ERROR: pg_restore fallo con codigo %RC%.
  echo Puedes volver atras con:
  echo   %SAFETY%
  pause
  exit /b 1
)

if %RC% EQU 1 (
  echo AVISO: pg_restore termino con advertencias, codigo 1. Suele ser normal.
)

echo.
echo Restauracion lista.
echo Siguiente (una vez), en una terminal:
echo   cd backend
echo   npm run migrate
echo Luego: iniciar-app.bat  o  BD Voluntariado.exe
echo.
echo Respaldo anterior por si hace falta:
echo   %SAFETY%
pause
exit /b 0
