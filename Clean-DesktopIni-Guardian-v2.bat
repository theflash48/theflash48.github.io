@echo off
setlocal EnableExtensions
title Project Agent - desktop.ini Guardian v2

set "PS1=%~dp0Clean-DesktopIni-Guardian-v2.ps1"

if not exist "%PS1%" (
    echo.
    echo ERROR: Clean-DesktopIni-Guardian-v2.ps1 was not found next to this BAT.
    echo Expected:
    echo %PS1%
    echo.
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo Guardian v2 stopped.
pause
exit /b %EXIT_CODE%
