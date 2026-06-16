@echo off
cd /d "%~dp0tools\rental_scraper"
call npm.cmd install
if errorlevel 1 goto failed
call npm.cmd run install-browser
if errorlevel 1 goto failed
echo Rental scraper setup complete.
pause
exit /b 0

:failed
echo Rental scraper setup failed.
pause
exit /b 1
