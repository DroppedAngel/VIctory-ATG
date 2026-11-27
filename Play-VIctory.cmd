@echo off
rem Starts the title with scripts\play.ps1 (README.md, "Getting started").
rem Every argument goes to it, e.g.:
rem   Play-VIctory.cmd -Exe <path of your copy's executable> [-Console series-s] [-Windowed]
rem Without -Exe it takes the executable started last time, or asks for it once.
rem PowerShell 7 when it is installed, else the Windows PowerShell every Windows has.
where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\play.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\play.ps1" %*
)
set result=%errorlevel%
if not %result% equ 0 pause
exit /b %result%
