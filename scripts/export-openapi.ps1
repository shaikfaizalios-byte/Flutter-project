# Regenerate contracts/openapi/openapi.json from the FastAPI app.
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..\services\api')
try {
    & .\.venv\Scripts\python.exe -m app.openapi_export ..\..\contracts\openapi\openapi.json
} finally { Pop-Location }
