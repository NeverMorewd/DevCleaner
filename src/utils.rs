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
