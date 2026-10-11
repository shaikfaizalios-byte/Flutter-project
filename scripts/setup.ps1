# One-time local setup: backend venv + dependencies, Flutter packages + l10n.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')

Push-Location (Join-Path $root 'services\api')
try {
    if (-not (Test-Path '.venv')) { python -m venv .venv }
    & .\.venv\Scripts\python.exe -m pip install --upgrade pip
    # Exact versions from the lock file, then the project itself in editable mode.
    & .\.venv\Scripts\python.exe -m pip install -r requirements.lock.txt
    & .\.venv\Scripts\python.exe -m pip install -e ".[dev]" --no-deps
    if (-not (Test-Path '.env')) { Copy-Item '.env.example' '.env' }
} finally { Pop-Location }

Push-Location (Join-Path $root 'apps\mobile')
try {
    flutter pub get
    flutter gen-l10n
} finally { Pop-Location }

Write-Host 'Setup complete.'
