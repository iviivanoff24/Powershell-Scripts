@echo off
setlocal

echo [INFO] Removing Osfetch from startup configuration...

REM Create temp PS script for profile cleaning
set "TEMP_PS=%TEMP%\osfetch_remove_%RANDOM%.ps1"
(
echo $ErrorActionPreference = 'SilentlyContinue'
echo Write-Host '[INFO] Cleaning PowerShell Profile...' -ForegroundColor Cyan
echo $ProfilePath = $PROFILE.CurrentUserCurrentHost
echo if ^(-not $ProfilePath^) { $ProfilePath = $PROFILE }
echo if ^(Test-Path $ProfilePath^) {
echo     $Lines = Get-Content $ProfilePath
echo     $NewLines = $Lines ^| Where-Object { $_ -notmatch 'osfetch.ps1' }
echo     if ^($Lines.Count -ne $NewLines.Count^) {
echo         $NewLines ^| Set-Content $ProfilePath -Encoding UTF8
echo         Write-Host '  - PowerShell profile cleaned.' -ForegroundColor Green
echo     } else {
echo         Write-Host '  - Osfetch not found in profile.' -ForegroundColor Yellow
echo     }
echo } else {
echo     Write-Host '  - PowerShell profile not found.' -ForegroundColor Yellow
echo }
) > "%TEMP_PS%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS%"
if exist "%TEMP_PS%" del "%TEMP_PS%"

REM 2. Clean CMD AutoRun
echo [INFO] Cleaning CMD AutoRun Registry...
REM Check if it contains osfetch before deleting to be safe
reg query "HKCU\Software\Microsoft\Command Processor" /v AutoRun 2>nul | find /i "osfetch.ps1" >nul
if %errorlevel% equ 0 (
    reg delete "HKCU\Software\Microsoft\Command Processor" /v AutoRun /f >nul
    echo   - CMD AutoRun removed.
) else (
    echo   - CMD AutoRun does not seem to contain osfetch.ps1. Skipping.
)

echo.
echo [SUCCESS] Cleanup complete!
pause
