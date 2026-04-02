use crate::types::{CleanItem, CleanItemType};
use anyhow::Result;
use std::path::Path;

/// Decode a Windows registry string value (UTF-16LE bytes) into a Rust String.
/// Stops at the first UTF-16 null terminator and handles odd-length byte slices.
#[cfg(windows)]
fn decode_utf16le(bytes: &[u8]) -> String {
    let units: Vec<u16> = bytes
        .chunks_exact(2)
        .map(|b| u16::from_le_bytes([b[0], b[1]]))
        .take_while(|&u| u != 0)
        .collect();
    String::from_utf16_lossy(&units).to_owned()
}

pub fn delete_item(item: &CleanItem) -> Result<()> {
    match item.item_type {
        CleanItemType::InvalidEnvVar => delete_env_var(item),
        CleanItemType::InvalidPathEntry => remove_path_entry(item),
        // TempDirectory: clear contents but keep the directory itself so the
        // OS / other processes can continue to use it as a temp folder.
        CleanItemType::TempDirectory => clear_dir_contents(&item.path),
        _ => delete_path(&item.path),
    }
}

fn delete_env_var(item: &CleanItem) -> Result<()> {
    #[cfg(windows)]
    {
        let info = item
            .registry_info
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("Missing registry_info for InvalidEnvVar item"))?;

        let key = open_env_key_write(&info.scope)?;
        key.delete_value(&info.var_name)
            .map_err(|e| anyhow::anyhow!("Failed to delete registry value '{}': {}", info.var_name, e))?;

        broadcast_env_change();
        Ok(())
    }
    #[cfg(not(windows))]
    {
        Err(anyhow::anyhow!("Registry operations not supported on this platform"))
    }
}

fn remove_path_entry(item: &CleanItem) -> Result<()> {
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

        // Read current PATH value.
        // Registry strings are UTF-16LE; read raw bytes and decode properly.
        let (current_val, reg_type): (String, RegType) = key
            .get_raw_value(&info.var_name)
            .map(|rv| {
                let s = decode_utf16le(&rv.bytes);
                (s, rv.vtype)
            })
            .unwrap_or_else(|_| (String::new(), RegType::REG_EXPAND_SZ));

        // Filter out the invalid entry (case-insensitive comparison).
        let bad_lower = bad_entry.to_lowercase();
        let filtered: Vec<&str> = current_val
            .split(';')
            .filter(|entry| {
                let trimmed = entry.trim().trim_matches('"');
                trimmed.to_lowercase() != bad_lower
            })
            .collect();

        // Only write back if something was actually removed.
        if filtered.len() == current_val.split(';').count() {
            return Ok(()); // nothing changed
        }
        let new_val = filtered.join(";");

        // Write the cleaned PATH back, preserving the original registry type.
        use winreg::RegValue;
        let mut bytes: Vec<u8> = new_val.encode_utf16().flat_map(|c| c.to_le_bytes()).collect();
        bytes.extend_from_slice(&[0u8, 0u8]); // null terminator
        key.set_raw_value(&info.var_name, &RegValue { bytes, vtype: reg_type })
            .map_err(|e| anyhow::anyhow!("Failed to write '{}' to registry: {}", info.var_name, e))?;

        broadcast_env_change();
        Ok(())
    }
    #[cfg(not(windows))]
    {
        Err(anyhow::anyhow!("Registry operations not supported on this platform"))
    }
}

#[cfg(windows)]
fn open_env_key_write(scope: &crate::types::RegScope) -> Result<winreg::RegKey> {
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
            let sys_path =
                r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment";
            hklm.open_subkey_with_flags(sys_path, KEY_READ | KEY_SET_VALUE)
                .map_err(|e| anyhow::anyhow!("Cannot open HKLM\\…\\Environment for writing (need elevation?): {}", e))
        }
    }
}

/// Broadcast WM_SETTINGCHANGE so the system picks up the env change without a reboot.
#[cfg(windows)]
fn broadcast_env_change() {
    use std::ffi::OsStr;
    use std::os::windows::ffi::OsStrExt;

    // Raw FFI declarations — avoids adding a windows-sys direct dependency.
    type HWND = *mut std::ffi::c_void;
    type WPARAM = usize;
    type LPARAM = isize;
    type LRESULT = isize;
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

    // "Environment\0" as UTF-16
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

/// Clear all children of `dir` without removing `dir` itself.
/// Skips entries that are locked/in-use (best-effort).
fn clear_dir_contents(dir: &Path) -> Result<()> {
    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(e) => return Err(anyhow::anyhow!("Cannot read {}: {}", dir.display(), e)),
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_file() || path.is_symlink() {
            let _ = std::fs::remove_file(&path); // skip locked files silently
        } else if path.is_dir() {
            fix_readonly_recursive(&path);
            let _ = std::fs::remove_dir_all(&path); // skip locked dirs silently
        }
    }
    Ok(())
}

fn delete_path(path: &Path) -> Result<()> {
    if path.is_file() {
        std::fs::remove_file(path)?;
    } else if path.is_dir() {
        // On Windows, some dirs (Go module cache) are read-only.
        // We need to fix permissions before removing.
        remove_dir_all_force(path)?;
    }
    Ok(())
}

fn remove_dir_all_force(dir: &Path) -> Result<()> {
    // First pass: remove read-only flag on all files
    fix_readonly_recursive(dir);
    std::fs::remove_dir_all(dir)?;
    Ok(())
}

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
