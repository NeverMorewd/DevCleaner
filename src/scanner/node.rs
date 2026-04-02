use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::dir_size;
use std::path::PathBuf;

pub fn scan(_config: &Config) -> ScanResult {
    let mut result = ScanResult::new("Node.js");

    // npm cache locations
    let npm_caches = npm_cache_paths();
    for cache in npm_caches {
        if cache.exists() {
            let size = dir_size(&cache);
            if size > 0 {
                result.add_item(CleanItem {
                    path: cache,
                    size,
                    description: "npm cache".to_string(),
                    scanner: "Node.js".to_string(),
                    item_type: CleanItemType::Cache,
                    package_name: None,
                    version: None,
                    registry_info: None,
                });
            }
        }
    }

    // yarn v1 cache
    if let Some(local) = dirs::data_local_dir() {
        let yarn_cache = local.join("Yarn").join("Cache");
        if yarn_cache.exists() {
            let size = dir_size(&yarn_cache);
            if size > 0 {
                result.add_item(CleanItem {
                    path: yarn_cache,
                    size,
                    description: "Yarn v1 cache".to_string(),
                    scanner: "Node.js".to_string(),
                    item_type: CleanItemType::Cache,
                    package_name: None,
                    version: None,
                    registry_info: None,
                });
            }
        }
    }

    // pnpm store
    if let Some(local) = dirs::data_local_dir() {
        let pnpm_store = local.join("pnpm").join("store");
        if pnpm_store.exists() {
            let size = dir_size(&pnpm_store);
            if size > 0 {
                result.add_item(CleanItem {
                    path: pnpm_store,
                    size,
                    description: "pnpm store".to_string(),
                    scanner: "Node.js".to_string(),
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

fn npm_cache_paths() -> Vec<PathBuf> {
    let mut paths = Vec::new();
    // Try running `npm config get cache`
    if let Ok(out) = std::process::Command::new("npm")
        .args(["config", "get", "cache"])
        .output()
    {
        if out.status.success() {
            let p = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if !p.is_empty() && p != "undefined" {
                paths.push(PathBuf::from(p));
            }
        }
    }
    // Fallback default locations
    if let Some(roaming) = dirs::data_dir() {
        let p = roaming.join("npm-cache");
        if !paths.contains(&p) {
            paths.push(p);
        }
    }
    if let Some(local) = dirs::data_local_dir() {
        let p = local.join("npm-cache");
        if !paths.contains(&p) {
            paths.push(p);
        }
    }
    paths
}
