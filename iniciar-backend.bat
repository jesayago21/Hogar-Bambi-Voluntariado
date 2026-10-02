@echo off
setlocal EnableExtensions
chcp 65001 >nul

REM ============================================================
REM  Backend: Postgres (Docker) + API Node
REM  Usa node.exe con ruta fija (no depende de que "npm" este en PATH)
REM ============================================================

set "BACKEND_DIR=%~dp0backend"
if not exist "%BACKEND_DIR%\package.json" (
  set "BACKEND_DIR=%~dp0..\..\backend"
)

call "%~dp0ensure-node.bat"
if errorlevel 1 (
  pause
  exit /b 1
)

REM Preferir node.exe absoluto - en Bambi "npm" a menudo no se ve al doble clic
set "NODE_EXE=node.exe"
if exist "%ProgramFiles%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles(x86)%\nodejs\node.exe"

if not exist "%BACKEND_DIR%\package.json" (
  echo ERROR: No encuentro backend\package.json en:
  echo   %BACKEND_DIR%
  pause
  exit /b 1
)

if not exist "%BACKEND_DIR%\node_modules" (
  echo AVISO: Falta node_modules. Instalando dependencias una vez...
  pushd "%BACKEND_DIR%"
  call "%~dp0ensure-node.bat"
  if exist "%ProgramFiles%\nodejs\npm.cmd" (
    "%ProgramFiles%\nodejs\npm.cmd" install --omit=dev
  ) else (
    npm install --omit=dev
  )
  if errorlevel 1 (
    popd
    echo ERROR: npm install fallo. En Bambi instala Node.js LTS, reinicia el PC
    echo y vuelve a abrir este script.
    pause
    exit /b 1
  )
  popd
)

where docker >nul 2>&1
if errorlevel 1 (
  echo AVISO: Docker no esta en el PATH. Si Postgres ya corre, se ignora.
) else (
  docker info >nul 2>&1
  if errorlevel 1 (
    echo ERROR: Docker Desktop no esta corriendo.
    echo Abrelo, espera a que este listo, y vuelve a intentar.
    pause
    exit /b 1
  )
  echo Levantando Postgres con Docker...
  pushd "%BACKEND_DIR%"
  docker compose up -d
  popd
)

set "API_PORT=8001"
if exist "%BACKEND_DIR%\.env" (
  for /f "usebackq tokens=2 delims==" %%A in (`findstr /b /i "PORT=" "%BACKEND_DIR%\.env"`) do set "API_PORT=%%A"
)
for /f "tokens=1 delims= " %%P in ("%API_PORT%") do set "API_PORT=%%P"

powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri 'http://127.0.0.1:%API_PORT%/api/health' | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 (
  echo El API ya responde en el puerto %API_PORT%.
  exit /b 0
)

echo Arrancando API Node en:
echo   %BACKEND_DIR%
echo   node: %NODE_EXE%
start "Voluntariado API" /MIN /D "%BACKEND_DIR%" cmd /k ""%NODE_EXE%" server.js"

echo Esperando al API en el puerto %API_PORT% ...
set /a _tries=0
:wait_api
ping -n 2 127.0.0.1 >nul
set /a _tries+=1
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 1 -Uri 'http://127.0.0.1:%API_PORT%/api/health' | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto api_ok
if %_tries% LSS 30 goto wait_api

echo ERROR: El API no respondio.
echo Abre la ventana minimizada "Voluntariado API" y lee el error.
echo En Bambi suele faltar: Node instalado + reinicio, o Docker abierto.
pause
exit /b 1

:api_ok
echo Backend listo: Postgres + API en http://localhost:%API_PORT%
exit /b 0
