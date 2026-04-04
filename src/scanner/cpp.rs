use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use std::path::PathBuf;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;

pub fn scan_vcpkg(_config: &Config, abort: &Arc<AtomicBool>) -> ScanResult {
    let mut result = ScanResult::new("vcpkg");

    let vcpkg_root = std::env::var("VCPKG_ROOT")
        .ok()
        .map(PathBuf::from)
        .or_else(|| dirs::home_dir().map(|h| h.join("vcpkg")));

    let Some(root) = vcpkg_root else {
        return result;
    };
    if !root.exists() {
        return result;
    }

    // buildtrees - intermediate build files
    let buildtrees = root.join("buildtrees");
    if buildtrees.exists() {
        let size = crate::utils::dir_size_abortable(&buildtrees, abort);
        if size > 0 {
            result.add_item(CleanItem {
                path: buildtrees,
                size,
                description: "vcpkg buildtrees".to_string(),
                scanner: "vcpkg".to_string(),
                item_type: CleanItemType::BuildArtifact,
                package_name: None,
                version: None,
                registry_info: None,
            });
        }
    }

    // packages - installed staging area (can be rebuilt)
    let packages = root.join("packages");
    if packages.exists() {
        let size = crate::utils::dir_size_abortable(&packages, abort);
        if size > 0 {
            result.add_item(CleanItem {
                path: packages,
                size,
                description: "vcpkg packages staging".to_string(),
                scanner: "vcpkg".to_string(),
                item_type: CleanItemType::Cache,
                package_name: None,
                version: None,
                registry_info: None,
            });
        }
    }

    result
}

pub fn scan_conan(_config: &Config, abort: &Arc<AtomicBool>) -> ScanResult {
    let mut result = ScanResult::new("Conan");

    let Some(home) = dirs::home_dir() else {
        return result;
    };
    let conan_data = home.join(".conan").join("data");
    let conan2_data = home.join(".conan2").join("p");

    for (path, label) in [
        (&conan_data, "Conan 1.x data"),
        (&conan2_data, "Conan 2.x cache"),
    ] {
        if path.exists() {
            let size = crate::utils::dir_size_abortable(path, abort);
            if size > 0 {
                result.add_item(CleanItem {
                    path: path.clone(),
                    size,
                    description: label.to_string(),
                    scanner: "Conan".to_string(),
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
