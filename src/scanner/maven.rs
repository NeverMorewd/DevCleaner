use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::old_versions;
use std::path::{Path, PathBuf};
use std::sync::atomic::AtomicBool;
use std::sync::Arc;

pub fn scan(_config: &Config, abort: &Arc<AtomicBool>) -> ScanResult {
    let mut result = ScanResult::new("Maven");

    let Some(home) = dirs::home_dir() else {
        return result;
    };
    let repo = home.join(".m2").join("repository");
    if !repo.exists() {
        return result;
    }

    // Walk the tree: find artifact directories (dirs that contain version subdirs)
    scan_group_dir(&repo, "", &mut result, abort);

    result
}

fn scan_group_dir(dir: &Path, prefix: &str, result: &mut ScanResult, abort: &Arc<AtomicBool>) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    let mut version_dirs: Vec<(String, PathBuf)> = Vec::new();
    let mut sub_dirs: Vec<(String, PathBuf)> = Vec::new();

    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }
        let name = entry.file_name().to_string_lossy().to_string();
        // If name looks like a version (starts with digit), treat this dir as artifact dir
        if name
            .chars()
            .next()
            .map(|c| c.is_ascii_digit())
            .unwrap_or(false)
        {
            version_dirs.push((name, path));
        } else {
            sub_dirs.push((name, path));
        }
    }

    if !version_dirs.is_empty() {
        // This is an artifact dir — keep only newest
        let artifact = prefix.split('/').next_back().unwrap_or(prefix);
        let old = old_versions(version_dirs);
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
                description: format!("{} v{}", artifact, ver),
                scanner: "Maven".to_string(),
                item_type: CleanItemType::OldVersion,
                package_name: Some(prefix.to_string()),
                version: Some(ver),
                registry_info: None,
            });
        }
    }

    for (name, path) in sub_dirs {
        let new_prefix = if prefix.is_empty() {
            name
        } else {
            format!("{}/{}", prefix, name)
        };
        scan_group_dir(&path, &new_prefix, result, abort);
    }
}
