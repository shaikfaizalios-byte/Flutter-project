# Run all formatters, static analysis and tests. Exits non-zero on the first failure.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')

function Invoke-Step([string]$Name, [scriptblock]$Command) {
    Write-Host "==> $Name" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Name failed (exit $LASTEXITCODE)" }
}

Push-Location (Join-Path $root 'services\api')
try {
    Invoke-Step 'api: ruff format --check' { .\.venv\Scripts\ruff.exe format --check . }
    Invoke-Step 'api: ruff check' { .\.venv\Scripts\ruff.exe check . }
    Invoke-Step 'api: mypy' { .\.venv\Scripts\mypy.exe app tests }
    Invoke-Step 'api: pytest' { .\.venv\Scripts\pytest.exe }
} finally { Pop-Location }

Push-Location (Join-Path $root 'apps\mobile')
try {
    Invoke-Step 'mobile: dart format' { dart format --output=none --set-exit-if-changed lib test }
    Invoke-Step 'mobile: flutter analyze' { flutter analyze }
    Invoke-Step 'mobile: flutter test' { flutter test }
} finally { Pop-Location }

Write-Host 'All checks passed.' -ForegroundColor Green
