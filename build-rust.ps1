# build-rust.ps1 — Compile Rust backend (debug)
# Usage: .\build-rust.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
Push-Location $root

try {
    Write-Host "`n==> Building Rust backend (debug) ..." -ForegroundColor Cyan
    $sw = [Diagnostics.Stopwatch]::StartNew()

    cargo build
    if ($LASTEXITCODE -ne 0) { throw "cargo build failed (exit $LASTEXITCODE)" }

    $sw.Stop()
    $elapsed = $sw.Elapsed.ToString("m\:ss")
    Write-Host "==> Done in $elapsed  ->  target\debug\devcleaner.exe`n" -ForegroundColor Green
} finally {
    Pop-Location
}
