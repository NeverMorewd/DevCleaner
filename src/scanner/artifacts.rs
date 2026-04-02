use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::dir_size;
use std::path::{Path, PathBuf};

/// Well-known developer root directories on Windows (auto-discovered).
fn auto_dev_roots() -> Vec<PathBuf> {
    let mut roots = Vec::new();
    let Some(home) = dirs::home_dir() else {
        return roots;
    };

    let candidates = [
        // Visual Studio defaults
        "source\\repos",
        "source",
        // Common dev dirs
        "projects",
        "Projects",
        "project",
        "dev",
        "Development",
        "workspace",
        "Workspace",
        "code",
        "Code",
        "git",
        "github",
        "GitLab",
        "repos",
    ];

    for rel in &candidates {
        let p = home.join(rel);
        if p.exists() && p.is_dir() {
            roots.push(p);
        }
    }

    // Visual Studio Documents paths
    if let Some(docs) = dirs::document_dir() {
        for vs in &[
            "Visual Studio 2022\\Projects",
            "Visual Studio 2019\\Projects",
            "Visual Studio 2017\\Projects",
        ] {
            let p = docs.join(vs);
            if p.exists() {
                roots.push(p);
            }
        }
    }

    roots
}

pub fn scan(config: &Config) -> ScanResult {
    let mut result = ScanResult::new("Build Artifacts");

    // Merge auto-discovered roots with user-configured roots, deduplicating
    let mut roots: Vec<PathBuf> = auto_dev_roots();
    for r in &config.artifacts.project_roots {
        let p = PathBuf::from(r);
        if p.exists() && !roots.contains(&p) {
            roots.push(p);
        }
    }

    if roots.is_empty() {
        result.error = Some(
            "No project roots found. Add one with: devcleaner config add-root <path>".to_string(),
        );
        return result;
    }

    for root in &roots {
        scan_dir(root, config, &mut result, 0);
    }

    result
}

/// Recursively scan a directory for build artifact folders.
/// `depth` is used to avoid scanning too deep and for skipping artifact-internal dirs.
fn scan_dir(dir: &Path, config: &Config, result: &mut ScanResult, depth: u32) {
    if depth > 8 {
        return;
    }

    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }
        let name = entry.file_name().to_string_lossy().to_string();
        let parent = path.parent().unwrap_or(dir);

        // ── C# / .NET ────────────────────────────────────────────────────────
        if config.artifacts.scan_csharp_obj_bin
            && (name == "obj" || name == "bin")
            && has_any(parent, &[".csproj", ".vbproj", ".fsproj", ".sln"])
        {
            add_artifact(&path, &format!(".NET build artifact ({})", name), "C# / .NET", result);
            continue; // don't recurse inside
        }

        // ── Rust ─────────────────────────────────────────────────────────────
        if config.artifacts.scan_rust_target && name == "target"
            && has_file(parent, "Cargo.toml")
        {
            add_artifact(&path, "Rust target/", "Rust", result);
            continue;
        }

        // ── Node.js / JS / TS ────────────────────────────────────────────────
        if config.artifacts.scan_node_modules && name == "node_modules"
            && has_file(parent, "package.json")
        {
            add_artifact(&path, "node_modules", "Node.js", result);
            continue;
        }

        // ── Next.js ──────────────────────────────────────────────────────────
        if config.artifacts.scan_frontend_dist
            && name == ".next"
            && (has_file(parent, "next.config.js")
                || has_file(parent, "next.config.ts")
                || has_file(parent, "next.config.mjs"))
        {
            add_artifact(&path, "Next.js .next/", "Next.js", result);
            continue;
        }

        // ── Nuxt ─────────────────────────────────────────────────────────────
        if config.artifacts.scan_frontend_dist
            && name == ".nuxt"
            && (has_file(parent, "nuxt.config.ts") || has_file(parent, "nuxt.config.js"))
        {
            add_artifact(&path, "Nuxt .nuxt/", "Nuxt", result);
            continue;
        }
        if config.artifacts.scan_frontend_dist
            && name == ".output"
            && (has_file(parent, "nuxt.config.ts") || has_file(parent, "nuxt.config.js"))
        {
            add_artifact(&path, "Nuxt .output/", "Nuxt", result);
            continue;
        }

        // ── SvelteKit ────────────────────────────────────────────────────────
        if config.artifacts.scan_frontend_dist
            && name == ".svelte-kit"
            && (has_file(parent, "svelte.config.js") || has_file(parent, "svelte.config.ts"))
        {
            add_artifact(&path, "SvelteKit .svelte-kit/", "SvelteKit", result);
            continue;
        }

        // ── Angular / Vite / generic dist ────────────────────────────────────
        if config.artifacts.scan_frontend_dist
            && name == "dist"
            && has_file(parent, "package.json")
        {
            add_artifact(&path, "Frontend dist/", "JS/TS", result);
            continue;
        }

        // ── Java / Maven ─────────────────────────────────────────────────────
        if config.artifacts.scan_java_build && name == "target"
            && has_file(parent, "pom.xml")
        {
            add_artifact(&path, "Maven target/", "Java/Maven", result);
            continue;
        }

        // ── Java / Gradle ────────────────────────────────────────────────────
        if config.artifacts.scan_java_build
            && name == "build"
            && (has_file(parent, "build.gradle")
                || has_file(parent, "build.gradle.kts")
                || has_file(parent, "settings.gradle")
                || has_file(parent, "settings.gradle.kts"))
        {
            add_artifact(&path, "Gradle build/", "Java/Gradle", result);
            continue;
        }
        if config.artifacts.scan_java_build
            && name == ".gradle"
            && (has_file(parent, "build.gradle") || has_file(parent, "build.gradle.kts"))
        {
            add_artifact(&path, "Gradle .gradle/", "Java/Gradle", result);
            continue;
        }

        // ── Python ───────────────────────────────────────────────────────────
        if config.artifacts.scan_python_cache && name == "__pycache__" {
            add_artifact(&path, "Python __pycache__/", "Python", result);
            continue;
        }
        if config.artifacts.scan_python_cache && name == ".pytest_cache" {
            add_artifact(&path, "pytest cache", "Python", result);
            continue;
        }
        if config.artifacts.scan_python_cache && name == ".mypy_cache" {
            add_artifact(&path, "mypy cache", "Python", result);
            continue;
        }
        if config.artifacts.scan_python_cache && name == ".ruff_cache" {
            add_artifact(&path, "ruff cache", "Python", result);
            continue;
        }
        if config.artifacts.scan_python_cache
            && (name == "dist" || name == "build")
            && (has_file(parent, "setup.py")
                || has_file(parent, "pyproject.toml")
                || has_file(parent, "setup.cfg"))
        {
            add_artifact(&path, &format!("Python build artifact ({})", name), "Python", result);
            continue;
        }
        if config.artifacts.scan_python_cache && name.ends_with(".egg-info") {
            // treated as a dir — skip below
        }

        // ── CMake / C / C++ ──────────────────────────────────────────────────
        if config.artifacts.scan_cmake_build && name == "CMakeFiles" {
            add_artifact(&path, "CMake build files", "C/C++", result);
            continue;
        }
        if config.artifacts.scan_cmake_build
            && (name == "build"
                || name.starts_with("cmake-build-")
                || name == "out"
                || name == "_build")
            && (has_file(parent, "CMakeLists.txt")
                || has_file(parent, "Makefile")
                || has_file(parent, "meson.build"))
        {
            add_artifact(&path, &format!("C/C++ build dir ({})", name), "C/C++", result);
            continue;
        }

        // ── Flutter / Dart ───────────────────────────────────────────────────
        if config.artifacts.scan_flutter_build
            && name == "build"
            && has_file(parent, "pubspec.yaml")
        {
            add_artifact(&path, "Flutter/Dart build/", "Flutter/Dart", result);
            continue;
        }
        if config.artifacts.scan_flutter_build
            && name == ".dart_tool"
            && has_file(parent, "pubspec.yaml")
        {
            add_artifact(&path, "Dart tool cache .dart_tool/", "Flutter/Dart", result);
            continue;
        }

        // ── Android ──────────────────────────────────────────────────────────
        if config.artifacts.scan_java_build
            && name == "build"
            && (has_file(parent, "AndroidManifest.xml")
                || has_file(parent, "build.gradle")
                || has_file(parent, "build.gradle.kts"))
        {
            add_artifact(&path, "Android build/", "Android", result);
            continue;
        }

        // ── Go vendor ────────────────────────────────────────────────────────
        if config.artifacts.scan_go_vendor && name == "vendor"
            && has_file(parent, "go.mod")
        {
            add_artifact(&path, "Go vendor/", "Go", result);
            continue;
        }

        // ── Skip dirs we should never recurse into ───────────────────────────
        let skip_recurse = matches!(
            name.as_str(),
            "node_modules"
                | ".git"
                | ".svn"
                | ".hg"
                | "target"
                | ".dart_tool"
                | "__pycache__"
        ) || name.starts_with('.');

        if skip_recurse {
            continue;
        }

        // Recurse
        scan_dir(&path, config, result, depth + 1);
    }
}

fn add_artifact(path: &Path, description: &str, lang: &str, result: &mut ScanResult) {
    let size = dir_size(path);
    if size > 0 {
        result.add_item(CleanItem {
            path: path.to_path_buf(),
            size,
            description: format!("{} — {}", lang, description),
            scanner: "Build Artifacts".to_string(),
            item_type: CleanItemType::BuildArtifact,
            package_name: Some(lang.to_string()),
            version: None,
            registry_info: None,
        });
    }
}

fn has_file(dir: &Path, name: &str) -> bool {
    dir.join(name).exists()
}

/// Check if the directory contains a file whose name ends with any of the given suffixes.
fn has_any(dir: &Path, suffixes: &[&str]) -> bool {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return false;
    };
    entries.flatten().any(|e| {
        let fname = e.file_name().to_string_lossy().to_string();
        suffixes.iter().any(|s| fname.ends_with(s))
    })
}
