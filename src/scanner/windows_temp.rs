use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use std::path::{Path, PathBuf};
use std::sync::atomic::AtomicBool;
use std::sync::Arc;

pub fn scan(config: &Config, abort: &Arc<AtomicBool>) -> ScanResult {
    let mut result = ScanResult::new("Windows Temp");
    let opts = &config.windows_temp_options;

    // User temp dir — clear CONTENTS only, never delete the directory itself
    if opts.user_temp {
        if let Ok(temp) = std::env::var("TEMP") {
            let temp_path = PathBuf::from(temp);
            add_temp_dir_item(&temp_path, "User temp files", &mut result, abort);
        }
    }

    // Windows system temp — clear contents only, may need elevation
    if opts.system_temp {
        let win_temp = PathBuf::from(r"C:\Windows\Temp");
        match try_add_temp_dir_item(&win_temp, "Windows system temp", abort) {
            Ok(Some(item)) => result.add_item(item),
            Ok(None) => {}
            Err(e) => {
                if result.error.is_none() {
                    result.error = Some(format!("C:\\Windows\\Temp: {}", e));
                }
            }
        }
    }

    // Windows Prefetch — safe to clear entirely, Windows rebuilds it
    if opts.prefetch {
        let prefetch = PathBuf::from(r"C:\Windows\Prefetch");
        match try_add_cache_item(&prefetch, "Windows Prefetch files", abort) {
            Ok(Some(item)) => result.add_item(item),
            Ok(None) => {}
            Err(e) => {
                if result.error.is_none() {
                    result.error = Some(format!("C:\\Windows\\Prefetch: {}", e));
                }
            }
        }
    }

    // Windows Update download cache — safe to delete entirely
    if opts.wu_download {
        let wu_download = PathBuf::from(r"C:\Windows\SoftwareDistribution\Download");
        match try_add_cache_item(&wu_download, "Windows Update download cache", abort) {
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
    }

    if opts.inet_cache || opts.wer {
        if let Some(local) = dirs::data_local_dir() {
            // IE/Edge legacy cache
            if opts.inet_cache {
                let inet_cache = local.join("Microsoft").join("Windows").join("INetCache");
                add_cache_item(
                    &inet_cache,
                    "IE/Edge legacy internet cache",
                    &mut result,
                    abort,
                );
            }

            // Windows Error Reporting
            if opts.wer {
                let wer = local.join("Microsoft").join("Windows").join("WER");
                let wer_archive = wer.join("ReportArchive");
                let wer_queue = wer.join("ReportQueue");
                add_cache_item(
                    &wer_archive,
                    "Windows Error Reporting archive",
                    &mut result,
                    abort,
                );
                add_cache_item(
                    &wer_queue,
                    "Windows Error Reporting queue",
                    &mut result,
                    abort,
                );
            }
        }
    }

    result
}

fn add_temp_dir_item(
    path: &Path,
    description: &str,
    result: &mut ScanResult,
    abort: &Arc<AtomicBool>,
) {
    if !path.exists() {
        return;
    }
    let size = crate::utils::dir_size_abortable(path, abort);
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

fn try_add_temp_dir_item(
    path: &PathBuf,
    description: &str,
    abort: &Arc<AtomicBool>,
) -> Result<Option<CleanItem>, String> {
    if !path.exists() {
        return Ok(None);
    }
    std::fs::read_dir(path).map_err(|e| e.to_string())?;
    let size = crate::utils::dir_size_abortable(path, abort);
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

fn add_cache_item(
    path: &Path,
    description: &str,
    result: &mut ScanResult,
    abort: &Arc<AtomicBool>,
) {
    if !path.exists() {
        return;
    }
    let size = crate::utils::dir_size_abortable(path, abort);
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

fn try_add_cache_item(
    path: &PathBuf,
    description: &str,
    abort: &Arc<AtomicBool>,
) -> Result<Option<CleanItem>, String> {
    if !path.exists() {
        return Ok(None);
    }
    std::fs::read_dir(path).map_err(|e| e.to_string())?;
    let size = crate::utils::dir_size_abortable(path, abort);
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
