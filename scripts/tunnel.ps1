# Make the API on this PC reachable from the internet with a Cloudflare quick tunnel, for
# testing. Keep this window open; closing it stops the tunnel.
#
# Quick tunnels get a new random address each time. When it changes, this script writes it to
# deploy/public-api-url and pushes, so GitHub rebuilds the web app (about 5-10 minutes).
#
# Start the API first (another window):  .\scripts\dev-api.ps1 -Lan
# Then:                                 powershell -ExecutionPolicy Bypass -File scripts\tunnel.ps1
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$urlFile = Join-Path $root 'deploy\public-api-url'
$log = Join-Path $env:TEMP 'preploop-tunnel.log'

$cf = (Get-Command cloudflared -ErrorAction SilentlyContinue).Source
if (-not $cf) {
    foreach ($p in @("${env:ProgramFiles(x86)}\cloudflared\cloudflared.exe", "$env:ProgramFiles\cloudflared\cloudflared.exe")) {
        if (Test-Path $p) { $cf = $p }
    }
}
if (-not $cf) { throw 'cloudflared not found. Install it: winget install --id Cloudflare.cloudflared' }

if (Test-Path $log) { Remove-Item $log }
$tunnel = Start-Process -FilePath $cf -ArgumentList @('tunnel', '--no-autoupdate', '--url', 'http://127.0.0.1:8000', '--logfile', $log) -PassThru -WindowStyle Hidden

$url = $null
for ($i = 0; $i -lt 60 -and -not $url; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $log) {
        $m = Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1
        if ($m) { $url = $m.Matches[0].Value }
    }
}
if (-not $url) { Stop-Process -Id $tunnel.Id; throw "No tunnel address after 60 s; see $log" }
Write-Host "Tunnel: $url  ->  http://127.0.0.1:8000"

$old = if (Test-Path $urlFile) { (Get-Content $urlFile -Raw).Trim() } else { '' }
if ($old -ne $url) {
    Set-Content -Path $urlFile -Value $url -Encoding ascii -NoNewline
    Push-Location $root
    try {
        git add deploy/public-api-url
        git commit -m "Tunnel address changed" | Out-Null
        git push origin HEAD:main
        Write-Host 'Pushed: the web app is being rebuilt on GitHub (5-10 minutes).'
    } finally { Pop-Location }
} else {
    Write-Host 'Address unchanged; nothing to rebuild.'
}

Write-Host 'Tunnel running. Press Ctrl+C or close this window to stop it.'
try { Wait-Process -Id $tunnel.Id } finally { if (-not $tunnel.HasExited) { Stop-Process -Id $tunnel.Id } }
