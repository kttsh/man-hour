@echo off
rem Run the check SQL files. Double-click, or pass options such as: run-checks.cmd -Only v01
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-checks.ps1" %*
set RC=%ERRORLEVEL%
if "%~1"=="" pause
exit /b %RC%
