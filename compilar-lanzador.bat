@echo off
setlocal EnableExtensions
chcp 65001 >nul

REM Compila BD Voluntariado.exe y lo copia a la raiz del proyecto

set "ROOT=%~dp0"
set "LAUNCHER=%ROOT%tools\launcher"
set "OUT=%ROOT%BD Voluntariado.exe"

where dotnet >nul 2>&1
if errorlevel 1 (
  echo ERROR: Se necesita el SDK de .NET ^(dotnet^).
  pause
  exit /b 1
)

echo Compilando lanzador...
dotnet publish "%LAUNCHER%\BdVoluntariado.csproj" -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o "%LAUNCHER%\publish"
if errorlevel 1 (
  echo ERROR: fallo la compilacion.
  pause
  exit /b 1
)

copy /Y "%LAUNCHER%\publish\BD Voluntariado.exe" "%OUT%" >nul
echo.
echo Listo:
echo   %OUT%
echo.
echo Uso: doble clic en "BD Voluntariado.exe" ^(misma carpeta que iniciar-app.bat^).
exit /b 0
