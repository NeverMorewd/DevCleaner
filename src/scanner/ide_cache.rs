use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::dir_size;
use std::path::Path;

const VSCODE_ROAMING_DIRS: &[&str] = &["Code", "Cursor", "Windsurf", "trae-cn", "lingma"];

pub fn scan(_config: &Config) -> ScanResult {
    let mut result = ScanResult::new("IDE Caches");

    // VS Code family — Roaming AppData
    if let Some(roaming) = dirs::config_dir() {
        for ide_name in VSCODE_ROAMING_DIRS {
            let ide_dir = roaming.join(ide_name);
            if !ide_dir.exists() {
                continue;
            }
            scan_dir_as_cache(
                &ide_dir.join("logs"),
                &format!("{} logs", ide_name),
                &mut result,
            );
            scan_dir_as_cache(
                &ide_dir.join("CachedExtensionVSIXs"),
                &format!("{} cached extension installers", ide_name),
                &mut result,
            );
            scan_dir_as_cache(
                &ide_dir.join("User").join("workspaceStorage"),
                &format!("{} workspace storage", ide_name),
                &mut result,
            );
        }
    }

    // VS Code family — Local AppData
    if let Some(local) = dirs::data_local_dir() {
        for ide_name in VSCODE_ROAMING_DIRS {
            let ide_dir = local.join(ide_name);
            if !ide_dir.exists() {
                continue;
            }
            scan_dir_as_cache(
                &ide_dir.join("logs"),
                &format!("{} logs (local)", ide_name),
                &mut result,
            );
            scan_dir_as_cache(
                &ide_dir.join("CachedData"),
                &format!("{} cached language server data", ide_name),
                &mut result,
            );
        }
    }

    // JetBrains — Local AppData
    if let Some(local) = dirs::data_local_dir() {
        let jb_root = local.join("JetBrains");
        if jb_root.exists() {
            scan_jetbrains(&jb_root, &mut result);
        }
    }

    result
}

fn scan_dir_as_cache(path: &Path, description: &str, result: &mut ScanResult) {
    if !path.exists() {
        return;
    }
    let size = dir_size(path);
    if size > 0 {
        result.add_item(CleanItem {
            path: path.to_path_buf(),
            size,
            description: description.to_string(),
            scanner: "IDE Caches".to_string(),
            item_type: CleanItemType::Cache,
            package_name: None,
            version: None,
            registry_info: None,
        });
    }
}

fn scan_jetbrains(jb_root: &std::path::Path, result: &mut ScanResult) {
    let Ok(entries) = std::fs::read_dir(jb_root) else {
        return;
    };
    for entry in entries.flatten() {
        let ide_dir = entry.path();
        if !ide_dir.is_dir() {
            continue;
        }
        let ide_name = entry.file_name().to_string_lossy().to_string();

        for subdir_name in &["caches", "index", "log", "snapshots"] {
            let subdir = ide_dir.join(subdir_name);
            if !subdir.exists() {
                continue;
            }
            let size = dir_size(&subdir);
            if size > 0 {
                let description = match *subdir_name {
                    "snapshots" => format!("{} profiler snapshots", ide_name),
                    _ => format!("{} {}", ide_name, subdir_name),
                };
                result.add_item(CleanItem {
                    path: subdir,
                    size,
                    description,
                    scanner: "IDE Caches".to_string(),
                    item_type: CleanItemType::Cache,
                    package_name: None,
                    version: None,
                    registry_info: None,
                });
            }
        }
    }
}
