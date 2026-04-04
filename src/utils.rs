use std::path::Path;
use walkdir::WalkDir;

/// Calculate total size of a directory recursively.
///
/// Does NOT follow symlinks or junctions (`follow_links(false)` is the WalkDir default).
/// This prevents infinite loops in directories that contain junction points, and avoids
/// double-counting Docker WSL2 VHD disk images which are exposed as junctions on Windows.
pub fn dir_size(path: &Path) -> u64 {
    if path.is_file() {
        return path.metadata().map(|m| m.len()).unwrap_or(0);
    }
    WalkDir::new(path)
        .follow_links(false) // never follow symlinks/junctions
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
        .map(|e| e.metadata().map(|m| m.len()).unwrap_or(0))
        .sum()
}

/// Calculate total size of a directory recursively, checking abort flag periodically.
/// Returns partial size if aborted.
pub fn dir_size_abortable(
    path: &Path,
    abort: &std::sync::Arc<std::sync::atomic::AtomicBool>,
) -> u64 {
    use std::sync::atomic::Ordering;
    if path.is_file() {
        return path.metadata().map(|m| m.len()).unwrap_or(0);
    }
    let mut total = 0u64;
    let mut count = 0u32;
    for entry in WalkDir::new(path)
        .follow_links(false)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        count += 1;
        if count % 500 == 0 && abort.load(Ordering::Relaxed) {
            return total;
        }
        if entry.file_type().is_file() {
            total += entry.metadata().map(|m| m.len()).unwrap_or(0);
        }
    }
    total
}

/// Compare two version strings, returning Ordering
pub fn compare_versions(a: &str, b: &str) -> std::cmp::Ordering {
    let a = a.trim_start_matches('v');
    let b = b.trim_start_matches('v');
    // try semver
    if let (Ok(va), Ok(vb)) = (semver::Version::parse(a), semver::Version::parse(b)) {
        return va.cmp(&vb);
    }
    // fall back: numeric component comparison
    let parts = |s: &str| -> Vec<u64> {
        s.split(|c: char| !c.is_ascii_digit())
            .filter(|p| !p.is_empty())
            .map(|p| p.parse().unwrap_or(0))
            .collect()
    };
    parts(a).cmp(&parts(b))
}

/// Given a list of (version_string, value), return values NOT at the maximum version
pub fn old_versions<T: Clone>(mut items: Vec<(String, T)>) -> Vec<T> {
    if items.len() <= 1 {
        return Vec::new();
    }
    items.sort_by(|a, b| compare_versions(&a.0, &b.0));
    // last is newest, return all but last
    items[..items.len() - 1]
        .iter()
        .map(|(_, v)| v.clone())
        .collect()
}
