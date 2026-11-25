@echo off
setlocal
rem Let Windows PowerShell 5.1 resolve its own built-in modules, even from pwsh 7.
set "PSModulePath="
cd /d "%~dp0"
if not "%~1"=="" goto classic
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher\Handscroll.ps1"
if not errorlevel 1 exit /b 0
echo Could not start the handscroll. Opening the classic launcher instead.
:classic
call "%~dp0Launch-Classic.cmd" %*
exit /b %errorlevel%
