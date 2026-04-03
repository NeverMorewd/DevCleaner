use crate::detector;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Config {
    pub general: GeneralConfig,
    pub scanners: ScannersConfig,
    pub artifacts: ArtifactsConfig,
    #[serde(default)]
    pub filter: FilterConfig,
    #[serde(default)]
    pub env_vars_options: EnvVarsOptions,
    #[serde(default)]
    pub windows_temp_options: WindowsTempOptions,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct FilterConfig {
    /// Regex patterns matched against full path string. Matching items are excluded from results.
    #[serde(default)]
    pub whitelist_patterns: Vec<String>,
}

fn bool_true() -> bool {
    true
}

/// Sub-options for the env_vars scanner.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct EnvVarsOptions {
    /// Check env vars (JAVA_HOME, GOROOT, etc.) whose value points to a non-existent path.
    #[serde(default = "bool_true")]
    pub check_invalid_values: bool,
    /// Check PATH entries that don't exist on disk.
    #[serde(default = "bool_true")]
    pub check_path_entries: bool,
}

impl Default for EnvVarsOptions {
    fn default() -> Self {
        Self {
            check_invalid_values: true,
            check_path_entries: true,
        }
    }
}

/// Sub-options for the windows_temp scanner.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct WindowsTempOptions {
    /// Scan the user's %TEMP% / %LOCALAPPDATA%\Temp directory.
    #[serde(default = "bool_true")]
    pub user_temp: bool,
    /// Scan C:\Windows\Temp (may need elevation).
    #[serde(default = "bool_true")]
    pub system_temp: bool,
    /// Scan C:\Windows\Prefetch.
    #[serde(default = "bool_true")]
    pub prefetch: bool,
    /// Scan C:\Windows\SoftwareDistribution\Download (Windows Update cache).
    #[serde(default = "bool_true")]
    pub wu_download: bool,
    /// Scan IE/Edge legacy internet cache.
    #[serde(default = "bool_true")]
    pub inet_cache: bool,
    /// Scan Windows Error Reporting archive and queue.
    #[serde(default = "bool_true")]
    pub wer: bool,
}

impl Default for WindowsTempOptions {
    fn default() -> Self {
        Self {
            user_temp: true,
            system_temp: true,
            prefetch: true,
            wu_download: true,
            inet_cache: true,
            wer: true,
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GeneralConfig {
    pub confirm_before_delete: bool,
    /// Set to true after the first-run smart-default detection has been applied.
    /// Old config files written before this field existed will deserialize it as
    /// false (thanks to `#[serde(default)]`), triggering a one-time re-detection.
    #[serde(default)]
    pub smart_defaults_applied: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ScannersConfig {
    pub nuget: bool,
    pub cargo: bool,
    pub golang: bool,
    pub node: bool,
    pub pip: bool,
    pub maven: bool,
    pub gradle: bool,
    pub cpp_vcpkg: bool,
    pub cpp_conan: bool,
    pub build_artifacts: bool,
    pub env_vars: bool,
    pub dump_files: bool,
    pub android_sdk: bool,
    pub ide_cache: bool,
    pub windows_temp: bool,
    pub rustup: bool,
    pub browser_cache: bool,
    pub flutter_pub: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ArtifactsConfig {
    // Per-language toggles
    pub scan_csharp_obj_bin: bool, // C# obj/ bin/
    pub scan_rust_target: bool,    // Rust target/
    pub scan_node_modules: bool,   // node_modules/
    pub scan_frontend_dist: bool,  // .next/ .nuxt/ .svelte-kit/ dist/ etc.
    pub scan_java_build: bool,     // Maven target/ Gradle build/ Android build/
    pub scan_python_cache: bool,   // __pycache__/ .pytest_cache/ .mypy_cache/ build/ dist/
    pub scan_cmake_build: bool,    // CMakeFiles/ cmake-build-*/ build/ out/ (C/C++)
    pub scan_flutter_build: bool,  // Flutter build/ .dart_tool/
    pub scan_go_vendor: bool,      // Go vendor/
    /// Additional project roots to scan (auto-discovery is always on)
    pub project_roots: Vec<String>,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            general: GeneralConfig {
                confirm_before_delete: true,
                smart_defaults_applied: true,
            },
            scanners: ScannersConfig {
                nuget: true,
                cargo: true,
                golang: true,
                node: true,
                pip: true,
                maven: true,
                gradle: true,
                cpp_vcpkg: false,
                cpp_conan: false,
                build_artifacts: true,
                env_vars: true,
                dump_files: true,
                android_sdk: true,
                ide_cache: true,
                windows_temp: true,
                rustup: true,
                browser_cache: true,
                flutter_pub: true,
            },
            artifacts: ArtifactsConfig {
                scan_csharp_obj_bin: true,
                scan_rust_target: true,
                scan_node_modules: false,
                scan_frontend_dist: true,
                scan_java_build: true,
                scan_python_cache: true,
                scan_cmake_build: true,
                scan_flutter_build: true,
                scan_go_vendor: false,
                project_roots: Vec::new(),
            },
            filter: FilterConfig::default(),
            env_vars_options: EnvVarsOptions::default(),
            windows_temp_options: WindowsTempOptions::default(),
        }
    }
}

impl Config {
    pub fn config_path() -> Option<PathBuf> {
        dirs::config_dir().map(|d| d.join("devcleaner").join("config.toml"))
    }

    /// Build a first-run default by probing installed ecosystems.
    /// Scanners are enabled only for ecosystems that are actually present.
    /// Universally-useful scanners (env_vars, dump_files, windows_temp,
    /// browser_cache, build_artifacts) are always on.
    pub fn smart_default() -> Self {
        let env = detector::detect();
        Config {
            general: GeneralConfig {
                confirm_before_delete: true,
                smart_defaults_applied: true,
            },
            scanners: ScannersConfig {
                nuget: env.dotnet,
                cargo: env.rust_cargo,
                golang: env.go,
                node: env.node,
                pip: env.python,
                maven: env.java,
                gradle: env.gradle,
                cpp_vcpkg: env.vcpkg,
                cpp_conan: env.conan,
                build_artifacts: true,
                env_vars: true,
                dump_files: true,
                android_sdk: env.android_sdk,
                ide_cache: env.ide,
                windows_temp: true,
                rustup: env.rustup,
                browser_cache: true,
                flutter_pub: env.flutter,
            },
            artifacts: ArtifactsConfig {
                scan_csharp_obj_bin: env.dotnet,
                scan_rust_target: env.rust_cargo,
                scan_node_modules: false,
                scan_frontend_dist: env.node,
                scan_java_build: env.java || env.gradle,
                scan_python_cache: env.python,
                scan_cmake_build: env.vcpkg || env.conan,
                scan_flutter_build: env.flutter,
                scan_go_vendor: false,
                project_roots: Vec::new(),
            },
            filter: FilterConfig::default(),
            env_vars_options: EnvVarsOptions::default(),
            windows_temp_options: WindowsTempOptions::default(),
        }
    }

    pub fn load() -> Result<Self> {
        let path = match Self::config_path() {
            Some(p) => p,
            None => return Ok(Self::smart_default()),
        };
        if !path.exists() {
            return Ok(Self::smart_default());
        }
        let content = std::fs::read_to_string(&path)?;
        let mut config: Config = toml::from_str(&content)?;

        // Migration: config files written before smart-defaults existed (or ones
        // where all scanners ended up false due to earlier bugs) get a one-time
        // re-detection pass.  The flag is then saved so this only runs once.
        if !config.general.smart_defaults_applied {
            let smart = Self::smart_default();
            config.scanners = smart.scanners;
            config.artifacts = smart.artifacts;
            config.general.smart_defaults_applied = true;
            let _ = config.save(); // best-effort; ignore I/O errors here
        }

        Ok(config)
    }

    pub fn save(&self) -> Result<()> {
        let path =
            Self::config_path().ok_or_else(|| anyhow::anyhow!("Cannot determine config path"))?;
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let content = toml::to_string_pretty(self)?;
        std::fs::write(&path, content)?;
        Ok(())
    }
}
