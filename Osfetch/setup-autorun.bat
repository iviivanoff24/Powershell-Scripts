@echo off
setlocal EnableDelayedExpansion

REM Get the directory of this script
set "SCRIPT_DIR=%~dp0"
set "OSFETCH_PATH=%SCRIPT_DIR%osfetch.ps1"

REM Check if osfetch.ps1 exists
if not exist "%OSFETCH_PATH%" (
    echo [ERROR] Osfetch script not found at: "%OSFETCH_PATH%"
    pause
    exit /b 1
)

echo [INFO] Configuring Osfetch for startup...

REM Create a temporary PowerShell script to handle the profile logic safely
set "TEMP_PS=%TEMP%\osfetch_setup_%RANDOM%.ps1"

(
echo $ErrorActionPreference = 'Stop'
echo $Path = '%OSFETCH_PATH%'
echo Write-Host '[INFO] Adding to PowerShell Profile...' -ForegroundColor Cyan
echo $ProfilePath = $PROFILE.CurrentUserCurrentHost
echo if ^(-not $ProfilePath^) { $ProfilePath = $PROFILE }
echo $ProfileDir = Split-Path $ProfilePath
echo if ^(-not ^(Test-Path $ProfileDir^)^) { New-Item -Path $ProfileDir -ItemType Directory -Force ^| Out-Null }
echo if ^(-not ^(Test-Path $ProfilePath^)^) { New-Item -Path $ProfilePath -ItemType File -Force ^| Out-Null }
echo $Content = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
echo if ^($Content -notmatch [regex]::Escape^($Path^)^) { 
echo     Add-Content -Path $ProfilePath -Value "`r`n& '$Path'"
echo     Write-Host '  - PowerShell profile updated.' -ForegroundColor Green
echo } else {
echo     Write-Host '  - PowerShell profile already configured.' -ForegroundColor Yellow
echo }
) > "%TEMP_PS%"

REM Execute the temp PS script
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS%"
if exist "%TEMP_PS%" del "%TEMP_PS%"

REM 2. Configure CMD AutoRun
echo [INFO] Adding to CMD AutoRun Registry...
set "CMD_COMMAND=powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%OSFETCH_PATH%\""
reg add "HKCU\Software\Microsoft\Command Processor" /v AutoRun /t REG_SZ /d "%CMD_COMMAND%" /f >nul

echo.
echo [SUCCESS] Setup complete! Restart your terminals to see the change.
pause
