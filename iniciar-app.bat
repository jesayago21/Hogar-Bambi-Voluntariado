@echo off
setlocal EnableExtensions
chcp 65001 >nul

REM ============================================================
REM  Lanzador Voluntariado Hogar Bambi
REM  1) Arranca el backend si no esta corriendo
REM  2) Abre la app desktop
REM ============================================================

set "BACKEND_DIR=%~dp0backend"
set "APP_EXE=%~dp0build\windows\x64\runner\Release\voluntariado_desktop_app.exe"

if not exist "%BACKEND_DIR%\package.json" (
  set "BACKEND_DIR=%~dp0..\..\backend"
)
if not exist "%APP_EXE%" (
  set "APP_EXE=%~dp0..\..\build\windows\x64\runner\Release\voluntariado_desktop_app.exe"
)
if not exist "%APP_EXE%" (
  set "APP_EXE=%~dp0build\windows\x64\runner\Debug\voluntariado_desktop_app.exe"
)
if not exist "%APP_EXE%" (
  set "APP_EXE=%~dp0..\..\build\windows\x64\runner\Debug\voluntariado_desktop_app.exe"
)
REM Empaquetado dist\BD Voluntariado\app\
if not exist "%APP_EXE%" (
  set "APP_EXE=%~dp0app\voluntariado_desktop_app.exe"
)

call "%~dp0ensure-node.bat"
if errorlevel 1 (
  pause
  exit /b 1
)

if not exist "%BACKEND_DIR%\package.json" (
  echo ERROR: No encuentro backend\package.json en:
  echo   %BACKEND_DIR%
  pause
  exit /b 1
)

if not exist "%APP_EXE%" (
  echo ERROR: No encuentro el ejecutable de la app.
  echo Buscado en Release/Debug y en app\ del paquete dist.
  echo Genera uno con: flutter build windows --release
  echo   o: empaquetar.bat
  pause
  exit /b 1
)

call "%~dp0iniciar-backend.bat"
if errorlevel 1 (
  pause
  exit /b 1
)

echo Abriendo la app...
echo   %APP_EXE%
start "" "%APP_EXE%"
exit /b 0
