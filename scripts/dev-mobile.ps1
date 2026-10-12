# Run the Flutter app. Examples:
#   .\scripts\dev-mobile.ps1                         # Chrome, API at 127.0.0.1:8000
#   .\scripts\dev-mobile.ps1 -Device emulator-5554   # Android emulator (uses 10.0.2.2)
param(
    [string]$Device = 'chrome',
    [string]$ApiBaseUrl = ''
)
$ErrorActionPreference = 'Stop'
if (-not $ApiBaseUrl) {
    $ApiBaseUrl = if ($Device -like 'emulator-*') { 'http://10.0.2.2:8000' } else { 'http://127.0.0.1:8000' }
}
$webArgs = @()
if ($Device -in @('chrome', 'edge', 'web-server')) {
    # Lets the local database use OPFS storage on web (see docs/database.md).
    $webArgs = @('--cross-origin-isolation')
}
Push-Location (Join-Path $PSScriptRoot '..\apps\mobile')
try {
    flutter run -d $Device --dart-define=API_BASE_URL=$ApiBaseUrl --dart-define=FLAVOR=development @webArgs
} finally {
    Pop-Location
}
