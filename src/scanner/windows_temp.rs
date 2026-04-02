use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::dir_size;
use std::path::{Path, PathBuf};

pub fn scan(_config: &Config) -> ScanResult {
    let mut result = ScanResult::new("Windows Temp");

    // User temp dir — clear CONTENTS only, never delete the directory itself
    if let Ok(temp) = std::env::var("TEMP") {
        let temp_path = PathBuf::from(temp);
        add_temp_dir_item(&temp_path, "User temp files", &mut result);
    }

    // Windows system temp — clear contents only, may need elevation
    let win_temp = PathBuf::from(r"C:\Windows\Temp");
    match try_add_temp_dir_item(&win_temp, "Windows system temp") {
        Ok(Some(item)) => result.add_item(item),
        Ok(None) => {}
        Err(e) => {
            if result.error.is_none() {
                result.error = Some(format!("C:\\Windows\\Temp: {}", e));
            }
        }
    }

    // Windows Prefetch — safe to clear entirely, Windows rebuilds it
    let prefetch = PathBuf::from(r"C:\Windows\Prefetch");
    match try_add_cache_item(&prefetch, "Windows Prefetch files") {
        Ok(Some(item)) => result.add_item(item),
        Ok(None) => {}
        Err(e) => {
            if result.error.is_none() {
                result.error = Some(format!("C:\\Windows\\Prefetch: {}", e));
            }
        }
    }

    // Windows Update download cache — safe to delete entirely
    let wu_download = PathBuf::from(r"C:\Windows\SoftwareDistribution\Download");
    match try_add_cache_item(&wu_download, "Windows Update download cache") {
        Ok(Some(item)) => result.add_item(item),
        Ok(None) => {}
        Err(e) => {
            if result.error.is_none() {
                result.error = Some(format!(
                    "C:\\Windows\\SoftwareDistribution\\Download: {}",
                    e
                ));
            }
        }
    }

    // IE/Edge legacy cache
    if let Some(local) = dirs::data_local_dir() {
        let inet_cache = local.join("Microsoft").join("Windows").join("INetCache");
        add_cache_item(&inet_cache, "IE/Edge legacy internet cache", &mut result);

        // Windows Error Reporting
        let wer = local.join("Microsoft").join("Windows").join("WER");
        let wer_archive = wer.join("ReportArchive");
        let wer_queue = wer.join("ReportQueue");
        add_cache_item(&wer_archive, "Windows Error Reporting archive", &mut result);
        add_cache_item(&wer_queue, "Windows Error Reporting queue", &mut result);
    }

    result
}

/// Add a temp *directory* item: the directory itself is kept; only its contents
/// are deleted. Uses `CleanItemType::TempDirectory` so the cleaner knows not to
/// call `remove_dir_all` on it.
fn add_temp_dir_item(path: &Path, description: &str, result: &mut ScanResult) {
    if !path.exists() {
        return;
    }
    let size = dir_size(path);
    if size > 0 {
        result.add_item(CleanItem {
            path: path.to_path_buf(),
            size,
            description: description.to_string(),
            scanner: "Windows Temp".to_string(),
            item_type: CleanItemType::TempDirectory,
            package_name: None,
            version: None,
            registry_info: None,
        });
    }
}

fn try_add_temp_dir_item(path: &PathBuf, description: &str) -> Result<Option<CleanItem>, String> {
    if !path.exists() {
        return Ok(None);
    }
    std::fs::read_dir(path).map_err(|e| e.to_string())?;
    let size = dir_size(path);
    if size == 0 {
        return Ok(None);
    }
    Ok(Some(CleanItem {
        path: path.clone(),
        size,
        description: description.to_string(),
        scanner: "Windows Temp".to_string(),
        item_type: CleanItemType::TempDirectory,
        package_name: None,
        version: None,
        registry_info: None,
    }))
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
            scanner: "Windows Temp".to_string(),
            item_type: CleanItemType::Cache,
            package_name: None,
            version: None,
            registry_info: None,
        });
    }
}

fn try_add_cache_item(path: &PathBuf, description: &str) -> Result<Option<CleanItem>, String> {
    if !path.exists() {
        return Ok(None);
    }
    // Attempt a quick read_dir to detect permission errors before doing full size scan
    std::fs::read_dir(path).map_err(|e| e.to_string())?;
    let size = dir_size(path);
    if size == 0 {
        return Ok(None);
    }
    Ok(Some(CleanItem {
        path: path.clone(),
        size,
        description: description.to_string(),
        scanner: "Windows Temp".to_string(),
        item_type: CleanItemType::Cache,
        package_name: None,
        version: None,
        registry_info: None,
    }))
}
