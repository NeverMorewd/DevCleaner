# build-release.ps1 — Full release build + Inno Setup installer
# Usage:
#   .\build-release.ps1              # version read from Cargo.toml
#   .\build-release.ps1 -Version 1.2.3
#
# Prerequisites:
#   - Rust toolchain (cargo)
#   - Flutter SDK
#   - Inno Setup 6.x (iscc must be on PATH, or installed via choco)
param(
    [string]$Version = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
Push-Location $root

try {
    # ── Resolve version ────────────────────────────────────────────────────────
    if (-not $Version) {
        $versionLine = Select-String -Path "$root\Cargo.toml" -Pattern '^version\s*=\s*"(.*)"' |
            Select-Object -First 1
        $Version = $versionLine.Matches[0].Groups[1].Value
    }
    Write-Host "`n  DevCleaner Release Build  v$Version" -ForegroundColor White
    Write-Host "  ────────────────────────────────────" -ForegroundColor DarkGray

    $totalSw = [Diagnostics.Stopwatch]::StartNew()

    # ── 1. Rust release build ──────────────────────────────────────────────────
    Write-Host "`n==> [1/4] Building Rust backend (release) ..." -ForegroundColor Cyan
    $sw = [Diagnostics.Stopwatch]::StartNew()

    cargo build --release
    if ($LASTEXITCODE -ne 0) { throw "cargo build --release failed (exit $LASTEXITCODE)" }

    $sw.Stop()
    Write-Host "    Done in $($sw.Elapsed.ToString('m\:ss'))  ->  target\release\devcleaner.exe" -ForegroundColor Green

    # ── 2. Flutter release build ───────────────────────────────────────────────
    Write-Host "`n==> [2/4] Building Flutter Windows (release) ..." -ForegroundColor Cyan
    $sw = [Diagnostics.Stopwatch]::StartNew()

    Push-Location "$root\flutter_app"
    try {
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }

    $sw.Stop()
    Write-Host "    Done in $($sw.Elapsed.ToString('m\:ss'))" -ForegroundColor Green

    # ── 3. Copy daemon exe into Flutter output ─────────────────────────────────
    Write-Host "`n==> [3/4] Copying devcleaner.exe into Flutter output ..." -ForegroundColor Cyan
    $src  = "$root\target\release\devcleaner.exe"
    $dest = "$root\flutter_app\build\windows\x64\runner\Release\devcleaner.exe"
    Copy-Item -Path $src -Destination $dest -Force
    Write-Host "    Copied -> $dest" -ForegroundColor Green

    # ── 4. Inno Setup installer ────────────────────────────────────────────────
    Write-Host "`n==> [4/4] Building installer (Inno Setup) ..." -ForegroundColor Cyan
    $sw = [Diagnostics.Stopwatch]::StartNew()

    # Try common Inno Setup install locations if not on PATH
    $iscc = Get-Command iscc -ErrorAction SilentlyContinue
    if (-not $iscc) {
        $candidates = @(
            "${env:ProgramFiles(x86)}\Inno Setup 6\iscc.exe",
            "${env:ProgramFiles}\Inno Setup 6\iscc.exe"
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) { $iscc = $c; break }
        }
    } else {
        $iscc = $iscc.Source
    }
    if (-not $iscc) {
        throw "iscc.exe not found. Install Inno Setup 6 from https://jrsoftware.org/isinfo.php"
    }

    New-Item -ItemType Directory -Force "$root\dist" | Out-Null
    $env:APP_VERSION = $Version
    & $iscc /O"$root\dist" "$root\installer\devcleaner.iss"
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed (exit $LASTEXITCODE)" }

    $sw.Stop()
    $installer = "$root\dist\DevCleanerSetup-$Version.exe"
    Write-Host "    Done in $($sw.Elapsed.ToString('m\:ss'))  ->  $installer" -ForegroundColor Green

    # ── Summary ────────────────────────────────────────────────────────────────
    $totalSw.Stop()
    Write-Host "`n==> All done in $($totalSw.Elapsed.ToString('m\:ss'))" -ForegroundColor Green
    Write-Host "    Installer: dist\DevCleanerSetup-$Version.exe`n" -ForegroundColor White

} finally {
    Pop-Location
}
