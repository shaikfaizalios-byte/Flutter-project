# Run the FastAPI backend with auto-reload on http://127.0.0.1:8000
$ErrorActionPreference = 'Stop'
$api = Join-Path $PSScriptRoot '..\services\api'
Push-Location $api
try {
    if (-not (Test-Path '.venv')) { throw 'services/api/.venv not found. Run scripts/setup.ps1 first.' }
    & .\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
} finally {
    Pop-Location
}
