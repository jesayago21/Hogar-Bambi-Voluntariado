@echo off
setlocal EnableExtensions
chcp 65001 >nul

REM ============================================================
REM  Verifica en la PC de Bambi que todo este listo
REM ============================================================

echo === Verificacion BD Voluntariado (maquina destino) ===
echo.

set "OK=1"

echo [1] Docker Desktop
where docker >nul 2>&1
if errorlevel 1 (
  echo   FALLO: docker no esta instalado o no esta en PATH.
  set "OK=0"
) else (
  docker info >nul 2>&1
  if errorlevel 1 (
    echo   FALLO: Docker esta instalado pero NO esta corriendo.
    echo          Abre Docker Desktop y espera a que diga Ready.
    set "OK=0"
  ) else (
    echo   OK
  )
)

echo [2] Node.js
call "%~dp0ensure-node.bat"
if errorlevel 1 (
  echo   FALLO: instala Node.js LTS desde https://nodejs.org
  echo          Marca "Add to PATH", luego REINICIA el PC.
  set "OK=0"
) else (
  for /f "delims=" %%V in ('node -v 2^>nul') do echo   OK  %%V
  if exist "%ProgramFiles%\nodejs\node.exe" (
    echo   Ruta: %ProgramFiles%\nodejs\node.exe
  )
)

echo [3] Backend
if exist "%~dp0backend\package.json" (
  echo   OK  backend\package.json
) else (
  echo   FALLO: no esta la carpeta backend
  set "OK=0"
)
if exist "%~dp0backend\node_modules" (
  echo   OK  node_modules
) else (
  echo   AVISO: falta node_modules - se instalara al iniciar, o corre:
  echo          cd backend ^& npm install
)

echo [4] App
if exist "%~dp0app\voluntariado_desktop_app.exe" (
  echo   OK  app\voluntariado_desktop_app.exe
) else if exist "%~dp0build\windows\x64\runner\Release\voluntariado_desktop_app.exe" (
  echo   OK  build\...\Release\voluntariado_desktop_app.exe
) else (
  echo   AVISO: no hay .exe Release aqui. En tu PC corre empaquetar.bat y copia dist\.
)

echo [5] Dump
dir /b "%~dp0backups\*.dump" >nul 2>&1
if errorlevel 1 (
  echo   AVISO: no hay .dump en backups\ - la base estara vacia hasta restaurar.
) else (
  echo   OK  hay dump^(s^) en backups\
)

echo.
if "%OK%"=="1" (
  echo Resultado: listo para iniciar-app.bat / BD Voluntariado.exe
) else (
  echo Resultado: hay fallos. Corrige lo marcado FALLO y vuelve a verificar.
  echo.
  echo En Bambi, orden tipico:
  echo   1. Instalar Docker Desktop + reiniciar si pide
  echo   2. Instalar Node.js LTS ^(Add to PATH^) + REINICIAR PC
  echo   3. Abrir Docker Desktop
  echo   4. Doble clic verificar-bambi.bat ^(este archivo^)
  echo   5. restaurar-en-bambi.bat  ^(escribe SI^)
  echo   6. BD Voluntariado.exe
)
echo.
pause
exit /b 0
