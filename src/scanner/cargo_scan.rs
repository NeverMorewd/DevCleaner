use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::{dir_size, old_versions};
use regex::Regex;
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::OnceLock;

/// Compiled once at first use; matches "name-1.2.3" or "name-1.2.3.crate"
static CRATE_RE: OnceLock<Regex> = OnceLock::new();

fn crate_re() -> &'static Regex {
    CRATE_RE.get_or_init(|| Regex::new(r"^(.+)-(\d+\.\d+.*)$").expect("valid regex"))
}

pub fn scan(_config: &Config) -> ScanResult {
    let mut result = ScanResult::new("Cargo");

    let Some(home) = dirs::home_dir() else {
        return result;
    };
    let cargo_home = std::env::var("CARGO_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| home.join(".cargo"));

    // Registry cache: .crate files
    let registry_cache = cargo_home.join("registry").join("cache");
    if registry_cache.exists() {
        scan_crate_files(&registry_cache, &mut result);
    }

    // Registry src: extracted sources
    let registry_src = cargo_home.join("registry").join("src");
    if registry_src.exists() {
        scan_src_dirs(&registry_src, &mut result);
    }

    result
}

fn parse_crate_name_version(filename: &str) -> Option<(String, String)> {
    // filename like "serde-1.0.210.crate"
    let stem = filename.strip_suffix(".crate")?;
    let caps = crate_re().captures(stem)?;
    Some((caps[1].to_string(), caps[2].to_string()))
}

fn scan_crate_files(registry_cache: &std::path::Path, result: &mut ScanResult) {
    let Ok(index_entries) = std::fs::read_dir(registry_cache) else {
        return;
    };

    for index_entry in index_entries.flatten() {
        let index_path = index_entry.path();
        if !index_path.is_dir() {
            continue;
        }

        let Ok(crate_entries) = std::fs::read_dir(&index_path) else {
            continue;
        };
        let mut by_name: HashMap<String, Vec<(String, PathBuf)>> = HashMap::new();

        for crate_entry in crate_entries.flatten() {
            let fname = crate_entry.file_name().to_string_lossy().to_string();
            if let Some((name, ver)) = parse_crate_name_version(&fname) {
                by_name
                    .entry(name)
                    .or_default()
                    .push((ver, crate_entry.path()));
            }
        }

        for (pkg_name, versions) in by_name {
            let old = old_versions(versions);
            for path in old {
                let size = path.metadata().map(|m| m.len()).unwrap_or(0);
                let ver = path
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_string();
                result.add_item(CleanItem {
                    path,
                    size,
                    description: format!("{} (crate cache)", pkg_name),
                    scanner: "Cargo".to_string(),
                    item_type: CleanItemType::OldVersion,
                    package_name: Some(pkg_name.clone()),
                    version: Some(ver),
                    registry_info: None,
                });
            }
        }
    }
}

fn scan_src_dirs(registry_src: &std::path::Path, result: &mut ScanResult) {
    let re = crate_re();

    let Ok(index_entries) = std::fs::read_dir(registry_src) else {
        return;
    };

    for index_entry in index_entries.flatten() {
        let index_path = index_entry.path();
        if !index_path.is_dir() {
            continue;
        }

        let Ok(pkg_entries) = std::fs::read_dir(&index_path) else {
            continue;
        };
        let mut by_name: HashMap<String, Vec<(String, PathBuf)>> = HashMap::new();

        for pkg_entry in pkg_entries.flatten() {
            let dir_name = pkg_entry.file_name().to_string_lossy().to_string();
            if let Some(caps) = re.captures(&dir_name) {
                let name = caps[1].to_string();
                let ver = caps[2].to_string();
                by_name
                    .entry(name)
                    .or_default()
                    .push((ver, pkg_entry.path()));
            }
        }

        for (pkg_name, versions) in by_name {
            let old = old_versions(versions);
            for path in old {
                let size = dir_size(&path);
                let ver = path
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_string();
                result.add_item(CleanItem {
                    path,
                    size,
                    description: format!("{} (src)", pkg_name),
                    scanner: "Cargo".to_string(),
                    item_type: CleanItemType::OldVersion,
                    package_name: Some(pkg_name.clone()),
                    version: Some(ver),
                    registry_info: None,
                });
            }
        }
    }
}
