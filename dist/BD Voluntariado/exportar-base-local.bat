@echo off
setlocal EnableExtensions
chcp 65001 >nul

REM ============================================================
REM  Genera un backup de la base LOCAL (Docker) para llevar a Bambi
REM  Salida: backups\voluntariado_YYYYMMDD_HHMM.dump
REM ============================================================

set "BACKEND_DIR=%~dp0backend"
set "OUT_DIR=%~dp0backups"
set "CONTAINER=voluntariado_db_local"
set "DB=voluntariado_hogar_bambi"
set "USER=postgres"

where docker >nul 2>&1
if errorlevel 1 (
  echo ERROR: Docker no esta en el PATH. Abre Docker Desktop e intenta de nuevo.
  pause
  exit /b 1
)

docker ps --format "{{.Names}}" | findstr /i /x "%CONTAINER%" >nul 2>&1
if errorlevel 1 (
  echo Postgres no esta corriendo. Levantando...
  pushd "%BACKEND_DIR%"
  docker compose up -d
  popd
  ping -n 6 127.0.0.1 >nul
)

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmm"') do set "STAMP=%%I"
set "OUT_FILE=%OUT_DIR%\voluntariado_%STAMP%.dump"
set "TMP_IN_CONTAINER=/tmp/voluntariado_%STAMP%.dump"

echo Creando dump en el contenedor...
docker exec "%CONTAINER%" pg_dump -U "%USER%" -d "%DB%" -F c -f "%TMP_IN_CONTAINER%"
if errorlevel 1 (
  echo ERROR: pg_dump fallo.
  pause
  exit /b 1
)

echo Copiando a:
echo   %OUT_FILE%
docker cp "%CONTAINER%:%TMP_IN_CONTAINER%" "%OUT_FILE%"
if errorlevel 1 (
  echo ERROR: docker cp fallo.
  pause
  exit /b 1
)

docker exec "%CONTAINER%" rm -f "%TMP_IN_CONTAINER%" >nul 2>&1

echo.
echo Listo. Lleva este archivo a Bambi (USB / OneDrive):
echo   %OUT_FILE%
echo.
echo En Bambi: primero respalda su base, luego restaura este dump
echo   (ver restaurar-en-bambi.bat).
pause
exit /b 0
