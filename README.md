# DevCleaner

[![CI](https://github.com/your-username/dev-cleaner/actions/workflows/ci.yml/badge.svg)](https://github.com/your-username/dev-cleaner/actions/workflows/ci.yml)
[![Release](https://github.com/your-username/dev-cleaner/actions/workflows/release.yml/badge.svg)](https://github.com/your-username/dev-cleaner/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-blue)](https://github.com/your-username/dev-cleaner/releases)

> Reclaim gigabytes of disk space by scanning and cleaning stale package caches and build artifacts across every major development ecosystem — with a modern Flutter desktop GUI.

---

## DISCLAIMER

**USE AT YOUR OWN RISK.**

This tool permanently deletes files from your computer. While it is designed to only target well-known build artifact and cache directories, bugs or unexpected edge cases could result in unintended data loss.

- Always review the scan results **before** confirming deletion.
- The authors and contributors accept **no liability** for any data loss, corruption, or system damage caused by using this software.
- This software is provided "as is", without warranty of any kind, express or implied.
- Back up important data before running any cleanup operation.

---

## Features

### Scanners

| Scanner | What it cleans |
|---------|---------------|
| **.NET / NuGet** | Old package versions in `~/.nuget/packages`, HTTP cache |
| **Rust / Cargo** | Old `.crate` files and extracted sources in `~/.cargo/registry` |
| **Go** | Old module versions in `~/go/pkg/mod`, build cache |
| **Node.js** | npm cache, Yarn v1 cache, pnpm store |
| **Python** | pip cache, uv cache |
| **Java / Maven** | Old artifact versions in `~/.m2/repository` |
| **Java / Gradle** | Old versions in `~/.gradle/caches/modules-*` |
| **C++ / vcpkg** | `buildtrees/` and `packages/` staging area |
| **C++ / Conan** | Conan 1.x and 2.x local caches |
| **Build Artifacts** | C# `obj/`&`bin/`, Rust `target/`, `node_modules/`, Python `__pycache__/`, Go vendor, CMake, Flutter, etc. |
| **Windows Temp** | `%TEMP%` contents, `C:\Windows\Temp` contents, WER reports, INetCache |
| **Environment Vars** | Invalid `PATH` entries pointing to non-existent directories |

### GUI Features

- **Scan first, delete later** — always shows what will be removed before touching anything
- **Selective cleanup** — check/uncheck individual items before cleaning
- **Search & sort** — filter results by name, sort by size or category
- **Ignore list** — configure glob/regex patterns to skip specific folders or files
- **Version-aware** — for package stores (NuGet, Cargo, Maven, Gradle, Go), keeps the latest version and removes older ones
- **Live progress** — real-time scan progress with spinner and status updates
- **Settings panel** — toggle each scanner on/off, manage project roots and ignore patterns

### Safety measures

- Protected paths (e.g., `WindowsApps`, `WinGet`, `System32`) are never flagged, even if they appear non-existent
- Temp directories (`%TEMP%`, `C:\Windows\Temp`) have their **contents** cleared but the directory itself is never deleted
- Each build artifact is validated against project-specific marker files (e.g., `Cargo.toml` for Rust `target/`, `package.json` for `node_modules/`) before being flagged

---

## Installation

### Pre-built installer (recommended)

Download `DevCleanerSetup-vX.X.X.exe` from the [Releases page](https://github.com/your-username/dev-cleaner/releases) and run it.

### Build from source

**Prerequisites:**
- [Rust](https://rustup.rs/) (stable)
- [Flutter](https://flutter.dev/docs/get-started/install/windows) (stable channel)
- [Inno Setup 6](https://jrsoftware.org/isdl.php) (for building the installer)

```powershell
git clone https://github.com/your-username/dev-cleaner
cd dev-cleaner

# Build the Rust backend
cargo build --release

# Build the Flutter GUI
cd flutter_app
flutter build windows --release
cd ..

# (Optional) Build installer
$env:APP_VERSION = "0.1.0"
iscc installer\devcleaner.iss
# Installer: dist\DevCleanerSetup-0.1.0.exe
```

---

## Architecture

DevCleaner uses a two-process architecture:

```
flutter_app.exe  ←─── stdin/stdout JSON-RPC ───→  devcleaner.exe --daemon
    (GUI)                                              (Rust backend)
```

`devcleaner.exe` must be placed in the same directory as `flutter_app.exe`. The GUI launches the daemon automatically on startup.

---

## Configuration

Config is stored at `%APPDATA%\devcleaner\config.toml`.

```toml
[general]
confirm_before_delete = true

[scanners]
nuget = true
cargo = true
golang = true
node = true
pip = true
maven = true
gradle = true
cpp_vcpkg = false
cpp_conan = false
build_artifacts = true
windows_temp = true
env_vars = true

[artifacts]
scan_csharp_obj_bin = true
scan_rust_target = true
scan_node_modules = false
scan_frontend_dist = true
scan_java_build = true
scan_python_cache = true
scan_cmake_build = false
scan_flutter_build = true
scan_go_vendor = false
project_roots = [
  "C:/Users/you/projects",
]

[ignore]
patterns = [
  "my-important-project",
  ".*\\.keep$",
]
```

---

## Contributing

Contributions welcome! Please open an issue or PR.

1. Fork the repo
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Commit your changes
4. Open a Pull Request

---

## License

MIT — see [LICENSE](LICENSE).
