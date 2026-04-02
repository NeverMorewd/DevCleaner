use crate::locking::{self, LockingProcess};
use crate::types::{CleanItem, CleanItemType};
use std::path::Path;

// ── Public error type ─────────────────────────────────────────────────────────

/// Richer delete error: includes whether the failure was an access-denied
/// condition and the list of processes that are locking the file/directory.
#[derive(Debug)]
pub struct DeleteError {
    pub message: String,
    /// True when the underlying OS error is PermissionDenied / access denied.
    pub access_denied: bool,
    /// Processes found to be holding the file open (empty when none detected).
    pub locking_processes: Vec<LockingProcess>,
}

impl std::fmt::Display for DeleteError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        if self.locking_processes.is_empty() {
            write!(f, "{}", self.message)
        } else {
            let names: Vec<String> = self
                .locking_processes
                .iter()
                .map(|p| format!("{} (PID {})", p.name, p.pid))
                .collect();
            write!(f, "{} [locked by: {}]", self.message, names.join(", "))
        }
    }
}

impl std::error::Error for DeleteError {}

// ── Public interface ──────────────────────────────────────────────────────────

pub fn delete_item(item: &CleanItem) -> Result<(), DeleteError> {
    match item.item_type {
        CleanItemType::InvalidEnvVar => delete_env_var(item).map_err(|e| DeleteError {
            message: e.to_string(),
            access_denied: false,
            locking_processes: vec![],
        }),
        CleanItemType::InvalidPathEntry => remove_path_entry(item).map_err(|e| DeleteError {
            message: e.to_string(),
            access_denied: false,
            locking_processes: vec![],
        }),
        CleanItemType::TempDirectory => clear_dir_contents(&item.path).map_err(|e| DeleteError {
            message: e.to_string(),
            access_denied: false,
            locking_processes: vec![],
        }),
        _ => delete_path_checked(&item.path),
    }
}

// ── Path deletion with lock/permission diagnostics ────────────────────────────

fn delete_path_checked(path: &Path) -> Result<(), DeleteError> {
    match delete_path(path) {
        Ok(()) => Ok(()),
        Err(io_err) => {
            let access_denied = io_err.kind() == std::io::ErrorKind::PermissionDenied
                || matches!(
                    io_err.raw_os_error(),
                    Some(5)   // ERROR_ACCESS_DENIED
                    | Some(32) // ERROR_SHARING_VIOLATION
                    | Some(33) // ERROR_LOCK_VIOLATION
                );
            let locking_processes = if access_denied {
                locking::find_locking_processes(path)
            } else {
                vec![]
            };
            Err(DeleteError {
                message: io_err.to_string(),
                access_denied,
                locking_processes,
            })
        }
    }
}

fn delete_path(path: &Path) -> std::io::Result<()> {
    if path.is_file() || path.is_symlink() {
        std::fs::remove_file(path)
    } else if path.is_dir() {
        fix_readonly_recursive(path);
        std::fs::remove_dir_all(path)
    } else {
        Ok(()) // already gone
    }
}

// ── Temp-directory contents clearing ─────────────────────────────────────────

/// Clear all children of `dir` without removing `dir` itself.
/// Skips entries that are locked/in-use (best-effort; temp dirs).
fn clear_dir_contents(dir: &Path) -> anyhow::Result<()> {
    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(e) => return Err(anyhow::anyhow!("Cannot read {}: {}", dir.display(), e)),
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_file() || path.is_symlink() {
            let _ = std::fs::remove_file(&path);
        } else if path.is_dir() {
            fix_readonly_recursive(&path);
            let _ = std::fs::remove_dir_all(&path);
        }
    }
    Ok(())
}

// ── Registry helpers (Windows only) ──────────────────────────────────────────

fn delete_env_var(item: &CleanItem) -> anyhow::Result<()> {
    #[cfg(windows)]
    {
        let info = item
            .registry_info
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("Missing registry_info for InvalidEnvVar item"))?;
        let key = open_env_key_write(&info.scope)?;
        key.delete_value(&info.var_name).map_err(|e| {
            anyhow::anyhow!("Failed to delete registry value '{}': {}", info.var_name, e)
        })?;
        broadcast_env_change();
        Ok(())
    }
    #[cfg(not(windows))]
    {
        let _ = item;
        Err(anyhow::anyhow!(
            "Registry operations not supported on this platform"
        ))
    }
}

fn remove_path_entry(item: &CleanItem) -> anyhow::Result<()> {
    #[cfg(windows)]
    {
        use winreg::enums::RegType;

        let info = item
            .registry_info
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("Missing registry_info for InvalidPathEntry item"))?;
        let bad_entry = info
            .path_entry
            .as_deref()
            .ok_or_else(|| anyhow::anyhow!("Missing path_entry in registry_info"))?;
        let key = open_env_key_write(&info.scope)?;

        let (current_val, reg_type): (String, RegType) = key
            .get_raw_value(&info.var_name)
            .map(|rv| {
                let s = decode_utf16le(&rv.bytes);
                (s, rv.vtype)
            })
            .unwrap_or_else(|_| (String::new(), RegType::REG_EXPAND_SZ));

        let bad_lower = bad_entry.to_lowercase();
        let filtered: Vec<&str> = current_val
            .split(';')
            .filter(|entry| {
                let trimmed = entry.trim().trim_matches('"');
                trimmed.to_lowercase() != bad_lower
            })
            .collect();

        if filtered.len() == current_val.split(';').count() {
            return Ok(());
        }
        let new_val = filtered.join(";");

        use winreg::RegValue;
        let mut bytes: Vec<u8> = new_val
            .encode_utf16()
            .flat_map(|c| c.to_le_bytes())
            .collect();
        bytes.extend_from_slice(&[0u8, 0u8]);
        key.set_raw_value(
            &info.var_name,
            &RegValue {
                bytes,
                vtype: reg_type,
            },
        )
        .map_err(|e| anyhow::anyhow!("Failed to write '{}' to registry: {}", info.var_name, e))?;
        broadcast_env_change();
        Ok(())
    }
    #[cfg(not(windows))]
    {
        let _ = item;
        Err(anyhow::anyhow!(
            "Registry operations not supported on this platform"
        ))
    }
}

#[cfg(windows)]
fn decode_utf16le(bytes: &[u8]) -> String {
    let units: Vec<u16> = bytes
        .chunks_exact(2)
        .map(|b| u16::from_le_bytes([b[0], b[1]]))
        .take_while(|&u| u != 0)
        .collect();
    String::from_utf16_lossy(&units).to_owned()
}

#[cfg(windows)]
fn open_env_key_write(scope: &crate::types::RegScope) -> anyhow::Result<winreg::RegKey> {
    use crate::types::RegScope;
    use winreg::enums::{HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE, KEY_READ, KEY_SET_VALUE};
    use winreg::RegKey;
    match scope {
        RegScope::User => {
            let hkcu = RegKey::predef(HKEY_CURRENT_USER);
            hkcu.open_subkey_with_flags("Environment", KEY_READ | KEY_SET_VALUE)
                .map_err(|e| anyhow::anyhow!("Cannot open HKCU\\Environment for writing: {}", e))
        }
        RegScope::System => {
            let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
            let sys_path = r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment";
            hklm.open_subkey_with_flags(sys_path, KEY_READ | KEY_SET_VALUE)
                .map_err(|e| {
                    anyhow::anyhow!(
                        "Cannot open HKLM\\...\\Environment for writing (need elevation?): {}",
                        e
                    )
                })
        }
    }
}

#[cfg(windows)]
fn broadcast_env_change() {
    use std::ffi::OsStr;
    use std::os::windows::ffi::OsStrExt;

    #[allow(clippy::upper_case_acronyms)]
    type HWND = *mut std::ffi::c_void;
    #[allow(clippy::upper_case_acronyms)]
    type WPARAM = usize;
    #[allow(clippy::upper_case_acronyms)]
    type LPARAM = isize;
    #[allow(clippy::upper_case_acronyms)]
    type LRESULT = isize;
    #[allow(clippy::upper_case_acronyms)]
    type UINT = u32;
    #[allow(non_camel_case_types)]
    type PDWORD_PTR = *mut usize;

    #[allow(non_snake_case)]
    extern "system" {
        fn SendMessageTimeoutW(
            hWnd: HWND,
            Msg: UINT,
            wParam: WPARAM,
            lParam: LPARAM,
            fuFlags: UINT,
            uTimeout: UINT,
            lpdwResult: PDWORD_PTR,
        ) -> LRESULT;
    }

    const HWND_BROADCAST: HWND = 0xFFFF as HWND;
    const WM_SETTINGCHANGE: UINT = 0x001A;
    const SMTO_ABORTIFHUNG: UINT = 0x0002;

    let env_str: Vec<u16> = OsStr::new("Environment")
        .encode_wide()
        .chain(std::iter::once(0))
        .collect();

    unsafe {
        let mut result: usize = 0;
        let _ = SendMessageTimeoutW(
            HWND_BROADCAST,
            WM_SETTINGCHANGE,
            0,
            env_str.as_ptr() as LPARAM,
            SMTO_ABORTIFHUNG,
            5000,
            &mut result,
        );
    }
}

// ── Read-only fixup ───────────────────────────────────────────────────────────

fn fix_readonly_recursive(dir: &Path) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if let Ok(meta) = path.metadata() {
            if meta.permissions().readonly() {
                let mut perms = meta.permissions();
                #[allow(clippy::permissions_set_readonly_false)]
                perms.set_readonly(false);
                let _ = std::fs::set_permissions(&path, perms);
            }
        }
        if path.is_dir() {
            fix_readonly_recursive(&path);
        }
    }
}
