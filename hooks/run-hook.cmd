: << 'CMDBLOCK'
@echo off
setlocal

:: Try bash on PATH first
where bash >nul 2>&1 && (
    for /f "tokens=*" %%B in ('where bash 2^>nul') do (
        "%%B" "%~dp0%1" %2 %3 %4 %5
        exit /b %ERRORLEVEL%
    )
)
:: Git for Windows fallback
if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" "%~dp0%1" %2 %3 %4 %5
    exit /b %ERRORLEVEL%
)
:: No bash found — exit silently (plugin continues to function)
echo {}
exit /b 0
CMDBLOCK
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec bash "$SCRIPT_DIR/$1" "${@:2}"
