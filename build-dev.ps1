# build-dev.ps1 — Compile Rust backend (debug) + launch Flutter dev app
# Usage: .\build-dev.ps1
#   Flutter runs with hot-reload enabled. Press R to reload, q to quit.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
Push-Location $root

try {
    # 1. Build Rust daemon (debug)
    Write-Host "`n==> [1/2] Building Rust backend (debug) ..." -ForegroundColor Cyan
    $sw = [Diagnostics.Stopwatch]::StartNew()

    cargo build
    if ($LASTEXITCODE -ne 0) { throw "cargo build failed (exit $LASTEXITCODE)" }

    $sw.Stop()
    Write-Host "    Done in $($sw.Elapsed.ToString('m\:ss'))  ->  target\debug\devcleaner.exe" -ForegroundColor Green

    # 2. Run Flutter (hot-reload dev mode)
    Write-Host "`n==> [2/2] Launching Flutter (hot-reload) ..." -ForegroundColor Cyan
    Push-Location "$root\flutter_app"
    try {
        flutter run -d windows
        if ($LASTEXITCODE -ne 0) { throw "flutter run failed (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
} finally {
    Pop-Location
}
