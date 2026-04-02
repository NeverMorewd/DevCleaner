use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use std::path::{Path, PathBuf};

const SCANNER_NAME: &str = "Dump Files";

pub fn scan(_config: &Config) -> ScanResult {
    let mut result = ScanResult::new(SCANNER_NAME);

    // %LOCALAPPDATA%\CrashDumps\
    if let Some(local) = dirs::data_local_dir() {
        scan_dir_for_dmp(&local.join("CrashDumps"), "App crash dump", &mut result);
    }

    // %WINDIR%\Minidump\
    if let Ok(windir) = std::env::var("WINDIR") {
        let windir = PathBuf::from(windir);

        scan_dir_for_dmp(&windir.join("Minidump"), "BSOD minidump", &mut result);

        // %WINDIR%\MEMORY.DMP — single file
        let memory_dmp = windir.join("MEMORY.DMP");
        add_file_if_exists(&memory_dmp, "Full memory dump (BSOD)", &mut result);

        // %WINDIR%\LiveKernelReports\ — subdirs containing *.dmp
        scan_live_kernel_reports(&windir.join("LiveKernelReports"), &mut result);
    }

    // %TEMP%\*.dmp (top-level only, no subdirs)
    if let Ok(temp) = std::env::var("TEMP") {
        scan_temp_dmp(&PathBuf::from(temp), &mut result);
    }

    // WER report directories
    let wer_dirs: Vec<(PathBuf, &str)> = collect_wer_dirs();
    for (dir, description) in &wer_dirs {
        scan_wer_dir(dir, description, &mut result);
    }

    result
}

/// Scan a directory for all *.dmp files (non-recursive).
fn scan_dir_for_dmp(dir: &Path, description: &str, result: &mut ScanResult) {
    if !dir.exists() {
        return;
    }
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_file() && has_dmp_extension(&path) {
            add_file_if_exists(&path, description, result);
        }
    }
}

/// Scan %TEMP% top-level for *.dmp files only (no subdirectories).
fn scan_temp_dmp(temp_dir: &Path, result: &mut ScanResult) {
    if !temp_dir.exists() {
        return;
    }
    let Ok(entries) = std::fs::read_dir(temp_dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_file() && has_dmp_extension(&path) {
            add_file_if_exists(&path, "Temp crash dump", result);
        }
    }
}

/// Scan %WINDIR%\LiveKernelReports\ — subdirs that contain *.dmp files.
fn scan_live_kernel_reports(dir: &Path, result: &mut ScanResult) {
    if !dir.exists() {
        return;
    }
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            scan_dir_for_dmp(&path, "Live kernel report dump", result);
        } else if path.is_file() && has_dmp_extension(&path) {
            // Top-level .dmp files in LiveKernelReports
            add_file_if_exists(&path, "Live kernel report dump", result);
        }
    }
}

/// Scan a WER report directory (ReportArchive / ReportQueue).
/// Each subfolder is a report; we collect the whole subfolder if it contains a .dmp,
/// otherwise add individual .dmp files.
fn scan_wer_dir(dir: &Path, description: &str, result: &mut ScanResult) {
    if !dir.exists() {
        return;
    }
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            // Scan inside each report subfolder for .dmp files
            scan_dir_for_dmp(&path, description, result);
        } else if path.is_file() && has_dmp_extension(&path) {
            add_file_if_exists(&path, description, result);
        }
    }
}

fn add_file_if_exists(path: &Path, description: &str, result: &mut ScanResult) {
    if !path.exists() {
        return;
    }
    let size = path.metadata().map(|m| m.len()).unwrap_or(0);
    result.add_item(CleanItem {
        path: path.to_path_buf(),
        size,
        description: description.to_string(),
        scanner: SCANNER_NAME.to_string(),
        item_type: CleanItemType::DumpFile,
        package_name: None,
        version: None,
        registry_info: None,
    });
}

fn has_dmp_extension(path: &Path) -> bool {
    path.extension()
        .and_then(|e| e.to_str())
        .map(|e| e.eq_ignore_ascii_case("dmp"))
        .unwrap_or(false)
}

fn collect_wer_dirs() -> Vec<(PathBuf, &'static str)> {
    let mut dirs: Vec<(PathBuf, &'static str)> = Vec::new();

    // %LOCALAPPDATA%\Microsoft\Windows\WER\ReportArchive
    // %LOCALAPPDATA%\Microsoft\Windows\WER\ReportQueue
    if let Some(local) = ::dirs::data_local_dir() {
        let wer_base = local.join("Microsoft").join("Windows").join("WER");
        dirs.push((wer_base.join("ReportArchive"), "WER report (user archive)"));
        dirs.push((wer_base.join("ReportQueue"), "WER report (user queue)"));
    }

    // %ProgramData%\Microsoft\Windows\WER\ReportArchive
    // %ProgramData%\Microsoft\Windows\WER\ReportQueue
    if let Ok(programdata) = std::env::var("ProgramData") {
        let wer_base = PathBuf::from(programdata)
            .join("Microsoft")
            .join("Windows")
            .join("WER");
        dirs.push((
            wer_base.join("ReportArchive"),
            "WER report (system archive)",
        ));
        dirs.push((wer_base.join("ReportQueue"), "WER report (system queue)"));
    }

    dirs
}
