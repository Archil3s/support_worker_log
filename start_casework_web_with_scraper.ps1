$ErrorActionPreference = "Stop"

Set-Location "C:\Users\Danie\support_worker_log"

.\start_rental_scraper.ps1
.\start_invoice_web.ps1
