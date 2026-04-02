use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, RegScope, RegistryCleanInfo, ScanResult};
use std::path::PathBuf;

const SCANNER_NAME: &str = "Environment Variables";

/// Well-known environment variable names that hold a single path value.
const KNOWN_PATH_VARS: &[&str] = &[
    "JAVA_HOME",
    "GOROOT",
    "GOPATH",
    "GOBIN",
    "ANDROID_HOME",
    "ANDROID_SDK_ROOT",
    "ANDROID_NDK_ROOT",
    "ANDROID_NDK_HOME",
    "KOTLINC_HOME",
    "FLUTTER_HOME",
    "M2_HOME",
    "MAVEN_HOME",
    "GRADLE_HOME",
    "GRADLE_USER_HOME",
    "NODE_HOME",
    "PYTHON_HOME",
    "RUBY_HOME",
    "GEM_HOME",
    "GEM_PATH",
    "CARGO_HOME",
    "RUSTUP_HOME",
    "DOTNET_ROOT",
    "DOTNET_HOME",
    "VCPKG_ROOT",
    "CMAKE_PREFIX_PATH",
    "LLVM_HOME",
    "CUDA_PATH",
    "CUDA_HOME",
    "VULKAN_SDK",
];

pub fn scan(_config: &Config) -> ScanResult {
    #[cfg(windows)]
    {
        scan_windows()
    }
    #[cfg(not(windows))]
    {
        ScanResult::new(SCANNER_NAME)
    }
}

#[cfg(windows)]
fn scan_windows() -> ScanResult {
    use winreg::enums::{HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE, KEY_READ};
    use winreg::RegKey;

    let mut result = ScanResult::new(SCANNER_NAME);

    // --- User environment variables ---
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    match hkcu.open_subkey_with_flags("Environment", KEY_READ) {
        Ok(key) => scan_reg_key(&key, RegScope::User, &mut result),
        Err(e) => {
            result.error = Some(format!("Cannot read HKCU\\Environment: {}", e));
        }
    }

    // --- System environment variables ---
    let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
    let sys_path = r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment";
    match hklm.open_subkey_with_flags(sys_path, KEY_READ) {
        Ok(key) => scan_reg_key(&key, RegScope::System, &mut result),
        Err(e) => {
            // System env may require elevation; treat as non-fatal warning.
            let existing_err = result.error.take();
            let new_err = format!("Cannot read HKLM\\…\\Environment (need elevation?): {}", e);
            result.error = Some(match existing_err {
                Some(prev) => format!("{} | {}", prev, new_err),
                None => new_err,
            });
        }
    }

    result
}

#[cfg(windows)]
fn scan_reg_key(key: &winreg::RegKey, scope: RegScope, result: &mut ScanResult) {
    use winreg::enums::RegType;

    let scope_str = match scope {
        RegScope::User => "User",
        RegScope::System => "System",
    };

    for (name, value) in key.enum_values().flatten() {
        // Only look at REG_SZ and REG_EXPAND_SZ
        let val_str: String = match value.vtype {
            RegType::REG_SZ | RegType::REG_EXPAND_SZ => match value.to_string().parse::<String>() {
                Ok(s) => s,
                Err(_) => continue,
            },
            _ => continue,
        };

        // Expand environment variables in the value
        let expanded = expand_env_vars(&val_str);

        let name_upper = name.to_uppercase();

        if name_upper == "PATH" {
            check_path_var(&name, &expanded, scope.clone(), scope_str, result);
        } else if is_path_var(&name_upper, &expanded) {
            check_single_path_var(&name, &expanded, scope.clone(), scope_str, result);
        }
    }
}

/// Expand %VAR% references in a string using the current process environment.
/// Uses regex to correctly handle multi-byte UTF-8 characters.
fn expand_env_vars(s: &str) -> String {
    // %VAR_NAME% — var names are always ASCII uppercase on Windows
    let re = match regex::Regex::new(r"%([^%\r\n]+)%") {
        Ok(r) => r,
        Err(_) => return s.to_string(),
    };
    re.replace_all(s, |caps: &regex::Captures| {
        std::env::var(&caps[1]).unwrap_or_else(|_| caps[0].to_string())
    })
    .into_owned()
}

/// Returns true if this variable name/value looks like it holds a filesystem path.
fn is_path_var(name_upper: &str, value: &str) -> bool {
    // Check if it's a known path variable
    if KNOWN_PATH_VARS.contains(&name_upper) {
        return true;
    }
    // Check if the value looks like an absolute path (drive-letter path or UNC)
    looks_like_path(value)
}

fn looks_like_path(value: &str) -> bool {
    let v = value.trim();
    // Drive letter: C:\ or C:/
    if v.len() >= 3 {
        let b = v.as_bytes();
        if b[0].is_ascii_alphabetic() && b[1] == b':' && (b[2] == b'\\' || b[2] == b'/') {
            return true;
        }
    }
    // UNC path
    if v.starts_with("\\\\") || v.starts_with("//") {
        return true;
    }
    false
}

/// Paths that must never be reported as invalid, even if they appear inaccessible.
/// These are Windows system virtual directories used by the App Execution Alias and
/// WinGet mechanisms; `Path::exists()` can return false for them depending on the
/// caller's security context, but they are legitimate PATH entries.
#[cfg(windows)]
const PROTECTED_PATH_PREFIXES: &[&str] = &[
    r"Microsoft\WindowsApps",
    r"Microsoft\WinGet",
    r"Windows\system32",
    r"Windows\System32",
    r"Windows\SysWOW64",
];

#[cfg(windows)]
fn is_protected_path(entry: &str) -> bool {
    let lower = entry.to_lowercase();
    PROTECTED_PATH_PREFIXES
        .iter()
        .any(|p| lower.contains(&p.to_lowercase()))
}

fn check_path_var(
    var_name: &str,
    value: &str,
    scope: RegScope,
    scope_str: &str,
    result: &mut ScanResult,
) {
    for raw_entry in value.split(';') {
        let entry = raw_entry.trim().trim_matches('"');
        if entry.is_empty() {
            continue;
        }
        #[cfg(windows)]
        if is_protected_path(entry) {
            continue; // never flag critical Windows system paths
        }
        if !std::path::Path::new(entry).exists() {
            result.add_item(CleanItem {
                path: PathBuf::from(entry),
                size: 0,
                description: format!("PATH entry does not exist ({} scope): {}", scope_str, entry),
                scanner: SCANNER_NAME.to_string(),
                item_type: CleanItemType::InvalidPathEntry,
                package_name: Some("PATH".to_string()),
                version: Some(scope_str.to_string()),
                registry_info: Some(RegistryCleanInfo {
                    scope: scope.clone(),
                    var_name: var_name.to_string(),
                    path_entry: Some(entry.to_string()),
                }),
            });
        }
    }
}

fn check_single_path_var(
    var_name: &str,
    value: &str,
    scope: RegScope,
    scope_str: &str,
    result: &mut ScanResult,
) {
    let path = value.trim().trim_matches('"');
    if path.is_empty() {
        return;
    }
    if !std::path::Path::new(path).exists() {
        result.add_item(CleanItem {
            path: PathBuf::from(path),
            size: 0,
            description: format!(
                "Env var {} points to non-existent path ({} scope): {}",
                var_name, scope_str, path
            ),
            scanner: SCANNER_NAME.to_string(),
            item_type: CleanItemType::InvalidEnvVar,
            package_name: Some(var_name.to_string()),
            version: Some(scope_str.to_string()),
            registry_info: Some(RegistryCleanInfo {
                scope: scope.clone(),
                var_name: var_name.to_string(),
                path_entry: None,
            }),
        });
    }
}
