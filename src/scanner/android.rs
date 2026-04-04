use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::old_versions;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;

pub fn scan(_config: &Config, abort: &Arc<AtomicBool>) -> ScanResult {
    let mut result = ScanResult::new("Android SDK");

    let local = match dirs::data_local_dir() {
        Some(d) => d,
        None => return result,
    };
    let home = match dirs::home_dir() {
        Some(d) => d,
        None => return result,
    };

    let sdk_root = local.join("Android").join("Sdk");

    // build-tools: keep only newest
    let build_tools = sdk_root.join("build-tools");
    if build_tools.exists() {
        scan_build_tools(&build_tools, &mut result, abort);
    }

    // platforms: android-NN dirs, keep newest 2
    let platforms = sdk_root.join("platforms");
    if platforms.exists() {
        scan_platforms(&platforms, &mut result, abort);
    }

    // NOTE: system-images and AVDs are NOT scanned.
    // - system-images: installed to support specific AVD configurations chosen by the user.
    //   Deleting them breaks any AVD that references them; use Android SDK Manager to manage.
    // - AVDs (.android/avd/): user-created virtual devices, not regenerable cache.
    //   Manage via `avdmanager` or Android Studio's Device Manager.
    // NOTE: extras/ is not scanned — it may contain local Maven repos (google/m2repository)
    //   that active projects depend on. Safe only if unused; too risky to auto-delete.

    // ~/.android/cache/
    let android_cache = home.join(".android").join("cache");
    if android_cache.exists() {
        let size = crate::utils::dir_size_abortable(&android_cache, abort);
        if size > 0 {
            result.add_item(CleanItem {
                path: android_cache,
                size,
                description: "Android SDK cache".to_string(),
                scanner: "Android SDK".to_string(),
                item_type: CleanItemType::Cache,
                package_name: None,
                version: None,
                registry_info: None,
            });
        }
    }

    result
}

fn scan_build_tools(
    build_tools: &std::path::Path,
    result: &mut ScanResult,
    abort: &Arc<AtomicBool>,
) {
    let Ok(entries) = std::fs::read_dir(build_tools) else {
        return;
    };
    let mut versions: Vec<(String, std::path::PathBuf)> = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            let ver = entry.file_name().to_string_lossy().to_string();
            versions.push((ver, path));
        }
    }
    let old = old_versions(versions);
    for path in old {
        let size = crate::utils::dir_size_abortable(&path, abort);
        let ver = path
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string();
        result.add_item(CleanItem {
            path,
            size,
            description: format!("Android build-tools {}", ver),
            scanner: "Android SDK".to_string(),
            item_type: CleanItemType::OldVersion,
            package_name: Some("build-tools".to_string()),
            version: Some(ver),
            registry_info: None,
        });
    }
}

/// Keep the N newest Android platform API levels installed.
/// Projects typically only need `compileSdkVersion` and one below it.
const KEEP_PLATFORMS: usize = 2;

fn scan_platforms(platforms: &std::path::Path, result: &mut ScanResult, abort: &Arc<AtomicBool>) {
    let Ok(entries) = std::fs::read_dir(platforms) else {
        return;
    };
    let mut versions: Vec<(String, std::path::PathBuf)> = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            let name = entry.file_name().to_string_lossy().to_string();
            // Extract numeric API level from "android-NN"
            let ver_str = name.strip_prefix("android-").unwrap_or(&name).to_string();
            versions.push((ver_str, path));
        }
    }
    if versions.len() <= KEEP_PLATFORMS {
        return;
    }
    versions.sort_by(|a, b| crate::utils::compare_versions(&a.0, &b.0));
    let old_count = versions.len() - KEEP_PLATFORMS;
    for (ver_str, path) in versions.into_iter().take(old_count) {
        let size = crate::utils::dir_size_abortable(&path, abort);
        let name = path
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string();
        result.add_item(CleanItem {
            path,
            size,
            description: format!("Android platform {}", name),
            scanner: "Android SDK".to_string(),
            item_type: CleanItemType::OldVersion,
            package_name: Some("platforms".to_string()),
            version: Some(ver_str),
            registry_info: None,
        });
    }
}
