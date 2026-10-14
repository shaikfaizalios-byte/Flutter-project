# Run the FastAPI backend with auto-reload on http://127.0.0.1:8000
# -Lan listens on all interfaces so a phone on the same Wi-Fi can reach it (test APKs).
param([switch]$Lan)
$ErrorActionPreference = 'Stop'
$api = Join-Path $PSScriptRoot '..\services\api'
$bindHost = if ($Lan) { '0.0.0.0' } else { '127.0.0.1' }
Push-Location $api
try {
    if (-not (Test-Path '.venv')) { throw 'services/api/.venv not found. Run scripts/setup.ps1 first.' }
    & .\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host $bindHost --port 8000
} finally {
    Pop-Location
}
