@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0launcher\Launcher.ps1" %*
if errorlevel 1 (
  echo.
  echo Launcher failed. See .local\launcher.log or launcher\README.md.
  pause
)
endlocal
