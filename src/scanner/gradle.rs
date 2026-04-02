use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::{dir_size, old_versions};
use std::path::{Path, PathBuf};

pub fn scan(_config: &Config) -> ScanResult {
    let mut result = ScanResult::new("Gradle");

    let Some(home) = dirs::home_dir() else {
        return result;
    };
    let gradle_caches = home.join(".gradle").join("caches");
    if !gradle_caches.exists() {
        return result;
    }

    // Find modules-* directories
    let Ok(entries) = std::fs::read_dir(&gradle_caches) else {
        return result;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().to_string();
        if name.starts_with("modules-") && path.is_dir() {
            let files_dir = path.join("files-2.1");
            if files_dir.exists() {
                scan_gradle_files_dir(&files_dir, &mut result);
            }
        }
    }

    result
}

fn scan_gradle_files_dir(files_dir: &Path, result: &mut ScanResult) {
    // Structure: GROUP/ARTIFACT/VERSION/HASH/file
    let Ok(group_entries) = std::fs::read_dir(files_dir) else {
        return;
    };
    for group_entry in group_entries.flatten() {
        let group_path = group_entry.path();
        if !group_path.is_dir() {
            continue;
        }
        let group = group_entry.file_name().to_string_lossy().to_string();

        let Ok(artifact_entries) = std::fs::read_dir(&group_path) else {
            continue;
        };
        for artifact_entry in artifact_entries.flatten() {
            let artifact_path = artifact_entry.path();
            if !artifact_path.is_dir() {
                continue;
            }
            let artifact = artifact_entry.file_name().to_string_lossy().to_string();

            let Ok(ver_entries) = std::fs::read_dir(&artifact_path) else {
                continue;
            };
            let mut versions: Vec<(String, PathBuf)> = Vec::new();
            for ver_entry in ver_entries.flatten() {
                let ver_path = ver_entry.path();
                if !ver_path.is_dir() {
                    continue;
                }
                let ver = ver_entry.file_name().to_string_lossy().to_string();
                versions.push((ver, ver_path));
            }

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
                    description: format!("{}:{} v{}", group, artifact, ver),
                    scanner: "Gradle".to_string(),
                    item_type: CleanItemType::OldVersion,
                    package_name: Some(format!("{}:{}", group, artifact)),
                    version: Some(ver),
                    registry_info: None,
                });
            }
        }
    }
}
