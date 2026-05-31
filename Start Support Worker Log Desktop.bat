@echo off
cd /d "C:\Users\Danie\support_worker_log"

start "" powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Users\Danie\support_worker_log\start_desktop_app.ps1"
exit /b
