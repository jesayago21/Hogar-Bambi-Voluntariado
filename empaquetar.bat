@echo off
setlocal EnableExtensions
chcp 65001 >nul

REM ============================================================
REM  Empaqueta todo en dist\BD Voluntariado\
REM  Esa carpeta es la que llevas a Bambi / Desktop.
REM ============================================================

set "ROOT=%~dp0"
set "DIST=%ROOT%dist\BD Voluntariado"
set "APP_SRC=%ROOT%build\windows\x64\runner\Release"
set "APP_DST=%DIST%\app"
set "BACKEND_DST=%DIST%\backend"

echo === Empaquetar BD Voluntariado ===
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: Flutter no esta en el PATH.
  pause
  exit /b 1
)

call "%ROOT%ensure-node.bat"
if errorlevel 1 (
  pause
  exit /b 1
)

where dotnet >nul 2>&1
if errorlevel 1 (
  echo AVISO: sin .NET SDK no se recompila el lanzador; se usara el existente si hay.
)

echo [1/5] Asegurando .env Flutter y compilando release...
(
  echo API_URL=http://127.0.0.1:8001
) > "%ROOT%.env"

pushd "%ROOT%"
call flutter build windows --release
set "BUILD_RC=%ERRORLEVEL%"
popd
if not "%BUILD_RC%"=="0" (
  if exist "%APP_SRC%\voluntariado_desktop_app.exe" (
    echo AVISO: no se pudo compilar; se usa el exe Release que ya existe.
    echo        Si cambiaste codigo de la app Flutter, instala Visual Studio
    echo        con Desktop development with C++ y vuelve a empaquetar.
  ) else (
    echo ERROR: fallo flutter build windows --release y no hay exe previo.
    echo        Instala Visual Studio con Desktop development with C++.
    pause
    exit /b 1
  )
)

if not exist "%APP_SRC%\voluntariado_desktop_app.exe" (
  echo ERROR: no existe el exe Release.
  pause
  exit /b 1
)

echo [2/5] Compilando lanzador BD Voluntariado.exe...
if exist "%ROOT%compilar-lanzador.bat" (
  call "%ROOT%compilar-lanzador.bat"
)

echo [3/5] Preparando carpeta dist...
if exist "%DIST%" rmdir /S /Q "%DIST%"
mkdir "%APP_DST%"
mkdir "%BACKEND_DST%"
mkdir "%DIST%\backups"

echo [4/5] Copiando archivos...
xcopy /E /I /Y "%APP_SRC%\*" "%APP_DST%\" >nul

REM Backend sin node_modules (se instala en Bambi o aqui)
robocopy "%ROOT%backend" "%BACKEND_DST%" /E /XD node_modules /NFL /NDL /NJH /NJS /nc /ns /np >nul
if errorlevel 8 (
  echo ERROR: fallo al copiar backend
  pause
  exit /b 1
)

copy /Y "%ROOT%backend\.env.example" "%BACKEND_DST%\.env" >nul
copy /Y "%ROOT%ensure-node.bat" "%DIST%\" >nul
copy /Y "%ROOT%verificar-bambi.bat" "%DIST%\" >nul
copy /Y "%ROOT%iniciar-app.bat" "%DIST%\" >nul
copy /Y "%ROOT%iniciar-backend.bat" "%DIST%\" >nul
copy /Y "%ROOT%exportar-base-local.bat" "%DIST%\" >nul
copy /Y "%ROOT%restaurar-en-bambi.bat" "%DIST%\" >nul
if exist "%ROOT%BD Voluntariado.exe" copy /Y "%ROOT%BD Voluntariado.exe" "%DIST%\" >nul

REM Acceso directo amigable (misma logica que iniciar-app.bat)
copy /Y "%ROOT%iniciar-app.bat" "%DIST%\Iniciar BD Voluntariado.bat" >nul

REM .env Flutter apuntando al API local
(
  echo API_URL=http://127.0.0.1:8001
) > "%DIST%\.env"

REM Copiar dump mas reciente si existe
if exist "%ROOT%backups\voluntariado_*.dump" (
  for /f "delims=" %%F in ('dir /b /o-d "%ROOT%backups\voluntariado_*.dump"') do (
    copy /Y "%ROOT%backups\%%F" "%DIST%\backups\" >nul
    echo Dump incluido: %%F
    goto :dump_done
  )
)
:dump_done

echo [5/5] npm install en backend del paquete...
pushd "%BACKEND_DST%"
call npm install --omit=dev
if errorlevel 1 (
  echo AVISO: npm install fallo; en Bambi puedes correrlo de nuevo.
)
popd

echo.
echo ============================================================
echo  LISTO. Lleva esta carpeta a Bambi o al Escritorio:
echo.
echo    %DIST%
echo.
echo  Uso diario: doble clic en
echo    BD Voluntariado.exe
echo    o  Iniciar BD Voluntariado.bat
echo.
echo  Primera vez en Bambi: ver docs\bambi\instalacion-desde-cero.md
echo  ^(Docker + Node una sola vez, luego restaurar dump^)
echo ============================================================
explorer "%DIST%"
pause
exit /b 0
