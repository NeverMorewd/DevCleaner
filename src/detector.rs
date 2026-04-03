/// Detect which development ecosystems are present on this machine.
/// Only checks path existence and environment variables — never spawns
/// subprocesses — so it is fast and safe to call at startup.
use std::path::Path;

pub struct DetectedEnvs {
    pub python: bool,
    pub dotnet: bool,
    pub node: bool,
    pub rust_cargo: bool,
    pub go: bool,
    pub java: bool,
    pub gradle: bool,
    pub flutter: bool,
    pub android_sdk: bool,
    pub ide: bool,
    pub rustup: bool,
    pub vcpkg: bool,
    pub conan: bool,
}

pub fn detect() -> DetectedEnvs {
    let home = dirs::home_dir().unwrap_or_default();
    // %LOCALAPPDATA%  (e.g. C:\Users\user\AppData\Local)
    let local = dirs::data_local_dir().unwrap_or_default();
    // %APPDATA%  (e.g. C:\Users\user\AppData\Roaming)
    let roaming = dirs::config_dir().unwrap_or_default();

    DetectedEnvs {
        python: detect_python(&home, &local),
        dotnet: detect_dotnet(&home, &local),
        node: detect_node(&home, &local, &roaming),
        rust_cargo: home.join(".cargo").join("bin").exists(),
        go: detect_go(&home, &local),
        java: detect_java(&home),
        gradle: home.join(".gradle").join("caches").exists(),
        flutter: detect_flutter(&home, &local),
        android_sdk: detect_android(&local),
        ide: detect_ide(&roaming, &local),
        rustup: home.join(".rustup").exists(),
        vcpkg: detect_vcpkg(&home),
        conan: home.join(".conan").exists() || home.join(".conan2").exists(),
    }
}

// ── PATH helper ───────────────────────────────────────────────────────────────

/// Returns true if any segment of the system PATH contains `needle`
/// (case-insensitive). Covers custom install locations that don't match any
/// hard-coded directory pattern (e.g. Python in D:\tools\python, nvm4w, etc.).
fn path_has(needle: &str) -> bool {
    let needle_lower = needle.to_ascii_lowercase();
    std::env::var("PATH")
        .unwrap_or_default()
        .split(';')
        .any(|seg| seg.to_ascii_lowercase().contains(needle_lower.as_str()))
}

// ── per-ecosystem helpers ─────────────────────────────────────────────────────

fn detect_python(home: &Path, local: &Path) -> bool {
    // pip cache
    local.join("pip").join("cache").exists()
        || home.join(".cache").join("pip").exists()
        // Standard Windows installer path
        || local.join("Programs").join("Python").exists()
        // Conda / Miniconda / Anaconda / Mambaforge
        || home.join("miniconda3").exists()
        || home.join("anaconda3").exists()
        || home.join("mambaforge").exists()
        || home.join("miniforge3").exists()
        // uv cache
        || local.join("uv").join("cache").exists()
        // pyenv on Windows
        || home.join(".pyenv").exists()
        // Windows Store Python lives here
        || local
            .join("Microsoft")
            .join("WindowsApps")
            .join("python.exe")
            .exists()
        || local
            .join("Microsoft")
            .join("WindowsApps")
            .join("python3.exe")
            .exists()
        // Custom / portable install: python.exe anywhere on PATH
        || path_has("python")
}

fn detect_dotnet(home: &Path, local: &Path) -> bool {
    // NuGet packages cache
    home.join(".nuget").join("packages").exists()
        // Standard install locations
        || exists_dir(r"C:\Program Files\dotnet")
        || exists_dir(r"C:\Program Files (x86)\dotnet")
        // Local / CI dotnet install
        || local.join("Microsoft").join("dotnet").exists()
        // DOTNET_ROOT env var
        || std::env::var("DOTNET_ROOT").is_ok()
        // dotnet.exe anywhere on PATH
        || path_has("dotnet")
}

fn detect_node(home: &Path, local: &Path, roaming: &Path) -> bool {
    // npm cache
    local.join("npm-cache").exists()
        || home.join(".npm").exists()
        // pnpm store
        || local.join("pnpm").join("store").exists()
        // yarn cache
        || local.join("Yarn").join("Cache").exists()
        // npm global modules (reliable on Windows)
        || roaming.join("npm").exists()
        // Standard nodejs install dir in Program Files
        || exists_dir(r"C:\Program Files\nodejs")
        // nvm for Windows (classic) stores at %APPDATA%\nvm
        || roaming.join("nvm").exists()
        // nvm4w (nvm4windows) stores at %LOCALAPPDATA%\nvm
        || local.join("nvm").exists()
        // node or nodejs anywhere on PATH (catches nvm4w, fnm, volta, etc.)
        || path_has("nodejs")
        || path_has(r"\node")
        // Volta installs node here
        || local.join("Volta").exists()
        // fnm
        || local.join("fnm").exists()
}

fn detect_go(home: &Path, local: &Path) -> bool {
    // Go module cache
    home.join("go").join("pkg").join("mod").exists()
        || std::env::var("GOPATH")
            .ok()
            .map(|p| Path::new(&p).join("pkg").join("mod").exists())
            .unwrap_or(false)
        // Go build cache
        || local.join("go").join("build-cache").exists()
        || exists_dir(r"C:\Program Files\Go")
        || exists_dir(r"C:\Go")
        || std::env::var("GOROOT").is_ok()
        || path_has("golang")
        || path_has(r"\go\bin")
}

fn detect_java(home: &Path) -> bool {
    // Maven local repository is the strongest signal
    home.join(".m2").join("repository").exists()
        // Common JDK install roots
        || exists_dir(r"C:\Program Files\Java")
        || exists_dir(r"C:\Program Files\Eclipse Adoptium")
        || exists_dir(r"C:\Program Files\Microsoft")
            && Path::new(r"C:\Program Files\Microsoft")
                .read_dir()
                .map(|mut d| d.any(|e| {
                    e.ok()
                        .and_then(|e| e.file_name().into_string().ok())
                        .map(|n| n.starts_with("jdk") || n.starts_with("jre"))
                        .unwrap_or(false)
                }))
                .unwrap_or(false)
        || std::env::var("JAVA_HOME").is_ok()
        || path_has(r"\jdk")
        || path_has(r"\jre")
}

fn detect_flutter(home: &Path, local: &Path) -> bool {
    // Dart pub cache
    local.join("Pub").join("Cache").exists()
        || home.join(".pub-cache").exists()
        || std::env::var("FLUTTER_HOME").is_ok()
        || std::env::var("FLUTTER_ROOT").is_ok()
        || path_has("flutter")
}

fn detect_android(local: &Path) -> bool {
    local.join("Android").join("Sdk").exists()
        || std::env::var("ANDROID_HOME").is_ok()
        || std::env::var("ANDROID_SDK_ROOT").is_ok()
}

fn detect_ide(roaming: &Path, local: &Path) -> bool {
    // JetBrains IDEs store caches in AppData\Roaming\JetBrains
    roaming.join("JetBrains").exists()
        // VS Code
        || roaming.join("Code").exists()
        // VS Code Insiders / Cursor / Windsurf
        || roaming.join("Code - Insiders").exists()
        || roaming.join("Cursor").exists()
        || local.join("Programs").join("cursor").exists()
}

fn detect_vcpkg(home: &Path) -> bool {
    std::env::var("VCPKG_ROOT").is_ok()
        || home.join("vcpkg").join("vcpkg.exe").exists()
        || exists_dir(r"C:\vcpkg")
        || exists_dir(r"C:\src\vcpkg")
        || path_has("vcpkg")
}

fn exists_dir(path: &str) -> bool {
    Path::new(path).is_dir()
}
