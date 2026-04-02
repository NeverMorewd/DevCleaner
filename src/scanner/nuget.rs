use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::{dir_size, old_versions};
use std::collections::HashMap;

pub fn scan(_config: &Config) -> ScanResult {
    let mut result = ScanResult::new("NuGet");

    // Main package store
    if let Some(home) = dirs::home_dir() {
        let packages_dir = home.join(".nuget").join("packages");
        if packages_dir.exists() {
            scan_versioned_store(&packages_dir, &mut result);
        }
    }

    // Legacy HTTP cache
    if let Some(local) = dirs::data_local_dir() {
        let cache = local.join("NuGet").join("Cache");
        if cache.exists() {
            let size = dir_size(&cache);
            if size > 0 {
                result.add_item(CleanItem {
                    path: cache.clone(),
                    size,
                    description: "NuGet HTTP cache".to_string(),
                    scanner: "NuGet".to_string(),
                    item_type: CleanItemType::Cache,
                    package_name: None,
                    version: None,
                    registry_info: None,
                });
            }
        }
    }

    // NuGetScratch temp
    if let Ok(temp) = std::env::var("TEMP") {
        let scratch = std::path::PathBuf::from(temp).join("NuGetScratch");
        if scratch.exists() {
            let size = dir_size(&scratch);
            if size > 0 {
                result.add_item(CleanItem {
                    path: scratch,
                    size,
                    description: "NuGet temp scratch".to_string(),
                    scanner: "NuGet".to_string(),
                    item_type: CleanItemType::Cache,
                    package_name: None,
                    version: None,
                    registry_info: None,
                });
            }
        }
    }

    result
}

fn scan_versioned_store(packages_dir: &std::path::Path, result: &mut ScanResult) {
    // Structure: packages_dir/pkg_name/version/
    let Ok(pkg_entries) = std::fs::read_dir(packages_dir) else {
        return;
    };

    for pkg_entry in pkg_entries.flatten() {
        let pkg_path = pkg_entry.path();
        if !pkg_path.is_dir() {
            continue;
        }
        let pkg_name = pkg_entry.file_name().to_string_lossy().to_string();

        let Ok(ver_entries) = std::fs::read_dir(&pkg_path) else {
            continue;
        };
        let mut versions: HashMap<String, std::path::PathBuf> = HashMap::new();

        for ver_entry in ver_entries.flatten() {
            let ver_path = ver_entry.path();
            if !ver_path.is_dir() {
                continue;
            }
            let ver = ver_entry.file_name().to_string_lossy().to_string();
            versions.insert(ver, ver_path);
        }

        let items: Vec<(String, std::path::PathBuf)> = versions.into_iter().collect();
        let old = old_versions(items);
        for path in old {
            let size = dir_size(&path);
            let ver = path
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();
            result.add_item(CleanItem {
                path: path.clone(),
                size,
                description: format!("{} v{}", pkg_name, ver),
                scanner: "NuGet".to_string(),
                item_type: CleanItemType::OldVersion,
                package_name: Some(pkg_name.clone()),
                version: Some(ver),
                registry_info: None,
            });
        }
    }
}
