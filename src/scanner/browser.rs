use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

pub fn scan(_config: &Config, abort: &Arc<AtomicBool>) -> ScanResult {
    let mut result = ScanResult::new("Browser Caches");

    let local = match dirs::data_local_dir() {
        Some(d) => d,
        None => return result,
    };
    let roaming = match dirs::config_dir() {
        Some(d) => d,
        None => return result,
    };

    // Chrome
    let chrome_user_data = local.join("Google").join("Chrome").join("User Data");
    scan_chromium_profiles(&chrome_user_data, "Chrome", &mut result, abort);

    // Edge
    let edge_user_data = local.join("Microsoft").join("Edge").join("User Data");
    scan_chromium_profiles(&edge_user_data, "Edge", &mut result, abort);

    // Brave
    let brave_user_data = local
        .join("BraveSoftware")
        .join("Brave-Browser")
        .join("User Data");
    scan_chromium_profiles(&brave_user_data, "Brave", &mut result, abort);

    // Firefox
    let firefox_profiles = local.join("Mozilla").join("Firefox").join("Profiles");
    scan_firefox_profiles(&firefox_profiles, &mut result, abort);

    // Opera
    let opera_dir = roaming.join("Opera Software").join("Opera Stable");
    scan_dir_as_cache(&opera_dir.join("Cache"), "Opera Cache", &mut result, abort);

    result
}

fn scan_chromium_profiles(
    user_data: &PathBuf,
    browser: &str,
    result: &mut ScanResult,
    abort: &Arc<AtomicBool>,
) {
    if !user_data.exists() {
        return;
    }
    let Ok(entries) = std::fs::read_dir(user_data) else {
        return;
    };
    for entry in entries.flatten() {
        if abort.load(Ordering::Relaxed) {
            return;
        }
        let profile_path = entry.path();
        if !profile_path.is_dir() {
            continue;
        }
        let profile_name = entry.file_name().to_string_lossy().to_string();
        // Profile dirs are: Default, Profile 1, Profile 2, etc.
        if profile_name != "Default" && !profile_name.starts_with("Profile ") {
            continue;
        }
        for cache_subdir in &["Cache", "Code Cache", "GPUCache"] {
            let cache_path = profile_path.join(cache_subdir);
            let desc = format!("{} {} ({})", browser, cache_subdir, profile_name);
            scan_dir_as_cache(&cache_path, &desc, result, abort);
        }
    }
}

fn scan_firefox_profiles(profiles_dir: &PathBuf, result: &mut ScanResult, abort: &Arc<AtomicBool>) {
    if !profiles_dir.exists() {
        return;
    }
    let Ok(entries) = std::fs::read_dir(profiles_dir) else {
        return;
    };
    for entry in entries.flatten() {
        if abort.load(Ordering::Relaxed) {
            return;
        }
        let profile_path = entry.path();
        if !profile_path.is_dir() {
            continue;
        }
        let profile_name = entry.file_name().to_string_lossy().to_string();
        for cache_subdir in &["cache2", "startupCache"] {
            let cache_path = profile_path.join(cache_subdir);
            let desc = format!("Firefox {} ({})", cache_subdir, profile_name);
            scan_dir_as_cache(&cache_path, &desc, result, abort);
        }
    }
}

fn scan_dir_as_cache(
    path: &Path,
    description: &str,
    result: &mut ScanResult,
    abort: &Arc<AtomicBool>,
) {
    if !path.exists() {
        return;
    }
    let size = crate::utils::dir_size_abortable(path, abort);
    if size > 0 {
        result.add_item(CleanItem {
            path: path.to_path_buf(),
            size,
            description: description.to_string(),
            scanner: "Browser Caches".to_string(),
            item_type: CleanItemType::Cache,
            package_name: None,
            version: None,
            registry_info: None,
        });
    }
}
