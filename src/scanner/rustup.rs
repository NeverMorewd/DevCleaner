use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::dir_size;
use std::collections::HashMap;

pub fn scan(_config: &Config) -> ScanResult {
    let mut result = ScanResult::new("Rustup");

    let home = match dirs::home_dir() {
        Some(d) => d,
        None => return result,
    };

    let rustup_root = home.join(".rustup");

    // Toolchains
    let toolchains_dir = rustup_root.join("toolchains");
    if toolchains_dir.exists() {
        scan_toolchains(&toolchains_dir, &mut result);
    }

    // Cached downloads
    let downloads_dir = rustup_root.join("downloads");
    if downloads_dir.exists() {
        let size = dir_size(&downloads_dir);
        if size > 0 {
            result.add_item(CleanItem {
                path: downloads_dir,
                size,
                description: "Rustup cached downloads".to_string(),
                scanner: "Rustup".to_string(),
                item_type: CleanItemType::Cache,
                package_name: None,
                version: None,
                registry_info: None,
            });
        }
    }

    result
}

/// Keep this many nightly toolchains per target (current + one fallback).
const KEEP_NIGHTLY: usize = 2;
/// Keep this many stable/beta toolchains per target.
const KEEP_STABLE: usize = 1;

fn scan_toolchains(toolchains_dir: &std::path::Path, result: &mut ScanResult) {
    let Ok(entries) = std::fs::read_dir(toolchains_dir) else {
        return;
    };

    // Group toolchains by "channel-target" key
    // Toolchain name format: stable-x86_64-pc-windows-msvc
    //                        nightly-2024-01-15-x86_64-pc-windows-msvc
    // Parse: first segment (split on '-') is the channel; for nightly the date follows.
    // Key for grouping: channel + target_arch (everything after the optional date part)

    let mut groups: HashMap<String, Vec<(String, std::path::PathBuf)>> = HashMap::new();

    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }
        let name = entry.file_name().to_string_lossy().to_string();
        let (sort_key, group_key) = parse_toolchain_name(&name);
        groups
            .entry(group_key)
            .or_default()
            .push((sort_key, path));
    }

    for (group_key, mut toolchains) in groups {
        // For stable, keep 1 (newest). For nightly, keep 2.
        let keep = if group_key.starts_with("nightly") { KEEP_NIGHTLY } else { KEEP_STABLE };
        if toolchains.len() <= keep {
            continue;
        }
        toolchains.sort_by(|a, b| crate::utils::compare_versions(&a.0, &b.0));
        let old_count = toolchains.len() - keep;
        for (_, path) in toolchains.into_iter().take(old_count) {
            let size = dir_size(&path);
            let tc_name = path
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();
            result.add_item(CleanItem {
                path,
                size,
                description: format!("Rustup toolchain: {}", tc_name),
                scanner: "Rustup".to_string(),
                item_type: CleanItemType::OldVersion,
                package_name: Some(group_key.clone()),
                version: Some(tc_name),
                registry_info: None,
            });
        }
    }
}

/// Returns (sort_key, group_key) for a toolchain directory name.
/// For `stable-x86_64-pc-windows-msvc`:  sort_key = "stable", group_key = "stable-x86_64-pc-windows-msvc"
/// For `nightly-2024-01-15-x86_64-pc-windows-msvc`: sort_key = "2024-01-15", group_key = "nightly-x86_64-pc-windows-msvc"
fn parse_toolchain_name(name: &str) -> (String, String) {
    let parts: Vec<&str> = name.splitn(2, '-').collect();
    if parts.len() < 2 {
        return (name.to_string(), name.to_string());
    }
    let channel = parts[0]; // "stable", "nightly", "beta"
    let rest = parts[1];    // everything after channel-

    if channel == "nightly" || channel == "beta" {
        // Check if rest starts with a date: YYYY-MM-DD
        // Date is 10 chars: "2024-01-15"
        if rest.len() > 11 && rest.chars().nth(4) == Some('-') && rest.chars().nth(7) == Some('-') {
            // rest = "2024-01-15-x86_64-pc-windows-msvc"
            let date_end = rest.find('-').map(|i| {
                // find third '-' (after YYYY-MM-DD)
                let after_year = &rest[i + 1..];
                let month_end = after_year.find('-').unwrap_or(0);
                let after_month = &after_year[month_end + 1..];
                let day_end = after_month.find('-').unwrap_or(after_month.len());
                i + 1 + month_end + 1 + day_end
            });
            if let Some(d) = date_end {
                let date = &rest[..d];
                let target = &rest[d + 1..]; // skip the '-' after the date
                let sort_key = date.to_string();
                let group_key = format!("{}-{}", channel, target);
                return (sort_key, group_key);
            }
        }
        // No date — treat like stable
        return (channel.to_string(), name.to_string());
    }

    // stable or other: no date, group = full name
    (channel.to_string(), name.to_string())
}

