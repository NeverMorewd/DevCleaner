use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::{dir_size, old_versions};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

pub fn scan(_config: &Config) -> ScanResult {
    let mut result = ScanResult::new("Flutter/Dart Pub");

    let local = match dirs::data_local_dir() {
        Some(d) => d,
        None => return result,
    };
    let home = match dirs::home_dir() {
        Some(d) => d,
        None => return result,
    };

    // %LOCALAPPDATA%\Pub\Cache\ — main pub cache on Windows
    let win_pub_cache = local.join("Pub").join("Cache");

    // ~/.pub-cache\ — alternative location
    let home_pub_cache = home.join(".pub-cache");

    // Process both cache roots if they exist
    for cache_root in &[win_pub_cache, home_pub_cache] {
        if !cache_root.exists() {
            continue;
        }

        // hosted/pub.dev/PACKAGE-VERSION dirs — old versions
        let hosted_pub_dev = cache_root.join("hosted").join("pub.dev");
        if hosted_pub_dev.exists() {
            scan_hosted_packages(&hosted_pub_dev, &mut result);
        }

        // hosted-hashes — report as Cache
        let hosted_hashes = cache_root.join("hosted-hashes");
        add_cache_item(&hosted_hashes, "Dart pub hosted-hashes", &mut result);

        // bin — compiled executables
        let bin = cache_root.join("bin");
        add_cache_item(&bin, "Dart pub compiled executables", &mut result);
    }

    result
}

fn scan_hosted_packages(hosted_pub_dev: &PathBuf, result: &mut ScanResult) {
    let Ok(entries) = std::fs::read_dir(hosted_pub_dev) else {
        return;
    };

    // Each entry is PACKAGE-VERSION, e.g. "http-1.2.0", "path-1.9.0"
    // Group by package name (everything before the last '-VERSION' segment)
    let mut packages: HashMap<String, Vec<(String, PathBuf)>> = HashMap::new();

    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }
        let dir_name = entry.file_name().to_string_lossy().to_string();
        // Split on last '-' to get package name and version
        if let Some(sep) = dir_name.rfind('-') {
            let pkg_name = dir_name[..sep].to_string();
            let version = dir_name[sep + 1..].to_string();
            packages.entry(pkg_name).or_default().push((version, path));
        }
    }

    for (pkg_name, versions) in packages {
        let old = old_versions(versions);
        for path in old {
            let size = dir_size(&path);
            let dir_name = path
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();
            let version = dir_name
                .rfind('-')
                .map(|i| dir_name[i + 1..].to_string())
                .unwrap_or_default();
            result.add_item(CleanItem {
                path,
                size,
                description: format!("Dart pub {} v{}", pkg_name, version),
                scanner: "Flutter/Dart Pub".to_string(),
                item_type: CleanItemType::OldVersion,
                package_name: Some(pkg_name.clone()),
                version: Some(version),
                registry_info: None,
            });
        }
    }
}

fn add_cache_item(path: &Path, description: &str, result: &mut ScanResult) {
    if !path.exists() {
        return;
    }
    let size = dir_size(path);
    if size > 0 {
        result.add_item(CleanItem {
            path: path.to_path_buf(),
            size,
            description: description.to_string(),
            scanner: "Flutter/Dart Pub".to_string(),
            item_type: CleanItemType::Cache,
            package_name: None,
            version: None,
            registry_info: None,
        });
    }
}
