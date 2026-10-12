# Run all formatters, static analysis and tests. Exits non-zero on the first failure.
# Database tests and the migration drift check need PostgreSQL (see docs/database.md);
# without PREPLOOP_TEST_DATABASE_URL the database tests are skipped, not failed.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')

function Invoke-Step([string]$Name, [scriptblock]$Command) {
    Write-Host "==> $Name" -ForegroundColor Cyan
    # Judge native tools by exit code only: some (alembic, flutter) log to stderr, which
    # Windows PowerShell 5.1 would otherwise turn into a terminating error when redirected.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Command } finally { $ErrorActionPreference = $previous }
    if ($LASTEXITCODE -ne 0) { throw "$Name failed (exit $LASTEXITCODE)" }
}

Push-Location (Join-Path $root 'services\api')
try {
    Invoke-Step 'api: ruff format --check' { .\.venv\Scripts\ruff.exe format --check . }
    Invoke-Step 'api: ruff check' { .\.venv\Scripts\ruff.exe check . }
    Invoke-Step 'api: mypy' { .\.venv\Scripts\mypy.exe app tests migrations }
    Invoke-Step 'api: pytest' { .\.venv\Scripts\pytest.exe }
    if (Select-String -Path '.env' -Pattern '^PREPLOOP_DATABASE_URL=.+' -Quiet -ErrorAction SilentlyContinue) {
        # Fails if the models changed without a matching migration.
        Invoke-Step 'api: alembic check' { .\.venv\Scripts\alembic.exe check }
    } else {
        Write-Host '==> api: alembic check skipped (PREPLOOP_DATABASE_URL not set)' -ForegroundColor Yellow
    }
} finally { Pop-Location }

Push-Location (Join-Path $root 'apps\mobile')
try {
    # Generated code (*.g.dart, l10n) is excluded from the format check.
    $dartFiles = Get-ChildItem lib, test, integration_test -Recurse -Filter *.dart |
        Where-Object { $_.Name -notlike '*.g.dart' -and $_.FullName -notmatch '\\generated\\' } |
        ForEach-Object { $_.FullName }
    Invoke-Step 'mobile: dart format' { dart format --output=none --set-exit-if-changed @dartFiles }
    Invoke-Step 'mobile: flutter analyze' { flutter analyze }
    Invoke-Step 'mobile: flutter test' { flutter test }
} finally { Pop-Location }

Write-Host 'All checks passed.' -ForegroundColor Green
