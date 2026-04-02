/// Detect which development ecosystems are present on this machine.
/// Only checks path existence — never spawns subprocesses — so it is fast
/// and safe to call at startup.
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

// ── per-ecosystem helpers ─────────────────────────────────────────────────────

fn detect_python(home: &Path, local: &Path) -> bool {
    // pip cache is the most reliable signal
    local.join("pip").join("cache").exists()
        || home.join(".cache").join("pip").exists()
        // Windows installer locations
        || local.join("Programs").join("Python").exists()
        // Conda / Miniconda / Anaconda
        || home.join("miniconda3").exists()
        || home.join("anaconda3").exists()
        || home.join("mambaforge").exists()
        // uv cache
        || local.join("uv").join("cache").exists()
}

fn detect_dotnet(home: &Path, local: &Path) -> bool {
    // NuGet packages cache is the most reliable signal
    home.join(".nuget").join("packages").exists()
        // dotnet CLI in common install locations
        || exists_file(r"C:\Program Files\dotnet\dotnet.exe")
        || exists_file(r"C:\Program Files (x86)\dotnet\dotnet.exe")
        // Local dotnet install (some CI tools do this)
        || local.join("Microsoft").join("dotnet").exists()
}

fn detect_node(home: &Path, local: &Path, roaming: &Path) -> bool {
    // npm cache
    local.join("npm-cache").exists()
        || home.join(".npm").exists()
        // pnpm store
        || local.join("pnpm").join("store").exists()
        // yarn cache
        || local.join("Yarn").join("Cache").exists()
        // npm global modules (most reliable)
        || roaming.join("npm").exists()
        // Node.js installed in Program Files
        || exists_file(r"C:\Program Files\nodejs\node.exe")
        || local.join("nvm").exists() // nvm for windows
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
        || exists_file(r"C:\Program Files\Go\bin\go.exe")
        || exists_file(r"C:\Go\bin\go.exe")
}

fn detect_java(home: &Path) -> bool {
    // Maven local repository is the strongest signal
    home.join(".m2").join("repository").exists()
        // Common JDK install paths
        || exists_file(r"C:\Program Files\Java")
        || exists_file(r"C:\Program Files\Microsoft\jdk-17.0.0")
        || std::env::var("JAVA_HOME").is_ok()
}

fn detect_flutter(home: &Path, local: &Path) -> bool {
    // Dart pub cache
    local.join("Pub").join("Cache").exists()
        || home.join(".pub-cache").exists()
        || std::env::var("FLUTTER_HOME").is_ok()
        || std::env::var("FLUTTER_ROOT").is_ok()
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
        || exists_file(r"C:\vcpkg\vcpkg.exe")
        || exists_file(r"C:\src\vcpkg\vcpkg.exe")
}

fn exists_file(path: &str) -> bool {
    Path::new(path).exists()
}
