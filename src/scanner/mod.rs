pub mod android;
pub mod artifacts;
pub mod browser;
pub mod cargo_scan;
pub mod cpp;
pub mod dumps;
pub mod envvars;
pub mod flutter_pub;
pub mod golang;
pub mod gradle;
pub mod ide_cache;
pub mod maven;
pub mod node;
pub mod nuget;
pub mod pip;
pub mod rustup;
pub mod windows_temp;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use crate::config::Config;
use crate::types::ScanResult;

/// Run all enabled scanners.
///
/// * `on_start`  — called with the scanner label just before it runs.
/// * `on_result` — called with the completed `ScanResult` immediately after
///                 each scanner finishes so callers can stream results to the UI.
pub fn run_all_scanners(
    config: &Config,
    mut on_start: impl FnMut(&str),
    mut on_result: impl FnMut(ScanResult),
    abort: &Arc<AtomicBool>,
) {
    // Compile whitelist regexes once up front
    let whitelist_regexes: Vec<regex::Regex> = config
        .filter
        .whitelist_patterns
        .iter()
        .filter_map(|p| regex::Regex::new(p).ok())
        .collect();

    macro_rules! maybe_scan {
        ($enabled:expr, $scanner:expr, $label:expr) => {
            if $enabled {
                if abort.load(Ordering::Relaxed) {
                    return;
                }
                on_start($label);
                let mut result = $scanner;
                // Apply whitelist filter
                if !whitelist_regexes.is_empty() {
                    result.items.retain(|item| {
                        let path_str = item.path.to_string_lossy();
                        !whitelist_regexes.iter().any(|re| re.is_match(&path_str))
                    });
                    result.total_size = result.items.iter().map(|i| i.size).sum();
                }
                on_result(result);
            }
        };
    }

    maybe_scan!(config.scanners.nuget, nuget::scan(config, abort), "NuGet");
    maybe_scan!(
        config.scanners.cargo,
        cargo_scan::scan(config, abort),
        "Cargo"
    );
    maybe_scan!(
        config.scanners.golang,
        golang::scan(config, abort),
        "Go Modules"
    );
    maybe_scan!(config.scanners.node, node::scan(config, abort), "Node.js");
    maybe_scan!(config.scanners.pip, pip::scan(config, abort), "pip / uv");
    maybe_scan!(config.scanners.maven, maven::scan(config, abort), "Maven");
    maybe_scan!(
        config.scanners.gradle,
        gradle::scan(config, abort),
        "Gradle"
    );
    maybe_scan!(
        config.scanners.cpp_vcpkg,
        cpp::scan_vcpkg(config, abort),
        "vcpkg"
    );
    maybe_scan!(
        config.scanners.cpp_conan,
        cpp::scan_conan(config, abort),
        "Conan"
    );
    maybe_scan!(
        config.scanners.build_artifacts,
        artifacts::scan(config, abort),
        "Build Artifacts"
    );
    maybe_scan!(
        config.scanners.env_vars,
        envvars::scan(config, abort),
        "Environment Variables"
    );
    maybe_scan!(
        config.scanners.dump_files,
        dumps::scan(config, abort),
        "Dump Files"
    );
    maybe_scan!(
        config.scanners.android_sdk,
        android::scan(config, abort),
        "Android SDK"
    );
    maybe_scan!(
        config.scanners.ide_cache,
        ide_cache::scan(config, abort),
        "IDE Caches"
    );
    maybe_scan!(
        config.scanners.windows_temp,
        windows_temp::scan(config, abort),
        "Windows Temp"
    );
    maybe_scan!(
        config.scanners.rustup,
        rustup::scan(config, abort),
        "Rustup"
    );
    maybe_scan!(
        config.scanners.browser_cache,
        browser::scan(config, abort),
        "Browser Caches"
    );
    maybe_scan!(
        config.scanners.flutter_pub,
        flutter_pub::scan(config, abort),
        "Flutter/Dart Pub"
    );
}
