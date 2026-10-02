@echo off
REM Agrega Node al PATH de esta sesion si where node falla
REM (doble clic a .bat a veces no hereda el PATH actualizado)

where node >nul 2>&1
if not errorlevel 1 goto :eof

if exist "%ProgramFiles%\nodejs\node.exe" (
  set "PATH=%ProgramFiles%\nodejs;%PATH%"
)
if exist "%ProgramFiles(x86)%\nodejs\node.exe" (
  set "PATH=%ProgramFiles(x86)%\nodejs;%PATH%"
)
if exist "%LOCALAPPDATA%\Programs\nodejs\node.exe" (
  set "PATH=%LOCALAPPDATA%\Programs\nodejs;%PATH%"
)
if exist "%APPDATA%\nvm" (
  REM nvm-windows: intentar version actual si existe symlink
  if exist "%ProgramFiles%\nodejs\node.exe" set "PATH=%ProgramFiles%\nodejs;%PATH%"
)

where node >nul 2>&1
if errorlevel 1 (
  echo ERROR: No encuentro Node.js / npm.
  echo Instala Node.js LTS desde https://nodejs.org
  echo Si ya esta instalado, cierra y vuelve a abrir esta ventana
  echo o reinicia el PC para refrescar el PATH.
  exit /b 1
)
exit /b 0
