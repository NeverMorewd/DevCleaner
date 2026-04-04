use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::old_versions;
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;

pub fn scan(_config: &Config, abort: &Arc<AtomicBool>) -> ScanResult {
    let mut result = ScanResult::new("Go Modules");

    // Module cache
    let gopath = std::env::var("GOPATH")
        .map(PathBuf::from)
        .unwrap_or_else(|_| dirs::home_dir().unwrap_or_default().join("go"));
    let mod_cache = gopath.join("pkg").join("mod");
    if mod_cache.exists() {
        scan_mod_cache(&mod_cache, &mut result, abort);
    }

    // Build cache
    if let Some(local) = dirs::data_local_dir() {
        let build_cache = local.join("go-build");
        if build_cache.exists() {
            let size = crate::utils::dir_size_abortable(&build_cache, abort);
            if size > 0 {
                result.add_item(CleanItem {
                    path: build_cache,
                    size,
                    description: "Go build cache".to_string(),
                    scanner: "Go Modules".to_string(),
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

fn scan_mod_cache(mod_cache: &std::path::Path, result: &mut ScanResult, abort: &Arc<AtomicBool>) {
    // mod_cache contains domain dirs like `github.com`, `golang.org`, etc.
    // Each domain has user/repo@vVER dirs
    // We do a recursive walk to find @version directories

    let mut by_module: HashMap<String, Vec<(String, PathBuf)>> = HashMap::new();

    collect_versioned_dirs(mod_cache, mod_cache, &mut by_module);

    for (module_path, versions) in by_module {
        let old = old_versions(versions);
        for path in old {
            let size = crate::utils::dir_size_abortable(&path, abort);
            let dir_name = path
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();
            let ver = dir_name.split('@').nth(1).unwrap_or("?").to_string();
            result.add_item(CleanItem {
                path,
                size,
                description: format!("{} (go mod)", module_path),
                scanner: "Go Modules".to_string(),
                item_type: CleanItemType::OldVersion,
                package_name: Some(module_path.clone()),
                version: Some(ver),
                registry_info: None,
            });
        }
    }
}

fn collect_versioned_dirs(
    base: &std::path::Path,
    current: &std::path::Path,
    result: &mut HashMap<String, Vec<(String, PathBuf)>>,
) {
    let Ok(entries) = std::fs::read_dir(current) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }
        let name = entry.file_name().to_string_lossy().to_string();
        if name.contains('@') {
            // This is a versioned module dir
            let parts: Vec<&str> = name.splitn(2, '@').collect();
            if parts.len() == 2 {
                // Build the full module path relative to base
                let rel = current.strip_prefix(base).unwrap_or(current);
                let module_path = rel.join(parts[0]).to_string_lossy().replace('\\', "/");
                let ver = parts[1].to_string();
                result.entry(module_path).or_default().push((ver, path));
            }
        } else {
            // Recurse into domain/user directories
            collect_versioned_dirs(base, &path, result);
        }
    }
}
