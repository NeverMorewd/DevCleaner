/// Detect which processes are locking a file or directory on Windows.
/// Uses the Windows Restart Manager API (available since Vista).
use std::path::Path;

use serde::Serialize;

#[derive(Debug, Serialize, Clone)]
pub struct LockingProcess {
    pub pid: u32,
    pub name: String,
}

/// Return any processes that currently have `path` open/locked.
/// For directories, walks up to 3 levels deep looking for locked files.
/// Returns an empty vec on non-Windows or when nothing is found.
pub fn find_locking_processes(path: &Path) -> Vec<LockingProcess> {
    #[cfg(windows)]
    {
        if path.is_file() || path.is_symlink() {
            query_rm(path)
        } else if path.is_dir() {
            scan_dir_for_locks(path)
        } else {
            vec![]
        }
    }
    #[cfg(not(windows))]
    {
        let _ = path;
        vec![]
    }
}

/// Walk a directory (max depth 3, max 60 files) and collect unique locking
/// processes across all files that can't be read.
#[cfg(windows)]
fn scan_dir_for_locks(dir: &Path) -> Vec<LockingProcess> {
    use walkdir::WalkDir;
    let mut result: Vec<LockingProcess> = Vec::new();
    let mut checked = 0usize;

    for entry in WalkDir::new(dir).max_depth(3).into_iter().flatten() {
        if checked >= 60 {
            break;
        }
        let p = entry.path();
        if p.is_file() {
            for proc in query_rm(p) {
                if !result.iter().any(|r: &LockingProcess| r.pid == proc.pid) {
                    result.push(proc);
                }
            }
            checked += 1;
        }
    }
    result
}

/// Query the Windows Restart Manager for processes locking `path`.
#[cfg(windows)]
fn query_rm(path: &Path) -> Vec<LockingProcess> {
    use std::os::windows::ffi::OsStrExt;
    use windows_sys::Win32::Foundation::{ERROR_MORE_DATA, ERROR_SUCCESS};
    use windows_sys::Win32::System::RestartManager::{
        RmEndSession, RmGetList, RmRegisterResources, RmStartSession, RM_PROCESS_INFO,
    };

    unsafe {
        // ── Start session ────────────────────────────────────────────────────
        let mut session: u32 = 0;
        let mut key = [0u16; 256];
        if RmStartSession(&mut session, 0, key.as_mut_ptr()) != ERROR_SUCCESS {
            return vec![];
        }

        // ── Register the path ────────────────────────────────────────────────
        let wide: Vec<u16> = path
            .as_os_str()
            .encode_wide()
            .chain(std::iter::once(0))
            .collect();
        let ptr: *const u16 = wide.as_ptr();
        let files: [*const u16; 1] = [ptr];

        if RmRegisterResources(
            session,
            1,
            files.as_ptr(),
            0,
            std::ptr::null(),
            0,
            std::ptr::null(),
        ) != ERROR_SUCCESS
        {
            RmEndSession(session);
            return vec![];
        }

        // ── First call: discover how many processes are needed ────────────────
        let mut needed: u32 = 0;
        let mut n: u32 = 0;
        let mut reboot: u32 = 0;
        let rc = RmGetList(
            session,
            &mut needed,
            &mut n,
            std::ptr::null_mut(),
            &mut reboot,
        );
        if rc != ERROR_SUCCESS && rc != ERROR_MORE_DATA {
            RmEndSession(session);
            return vec![];
        }
        if needed == 0 {
            RmEndSession(session);
            return vec![];
        }

        // ── Second call: fill the buffer ─────────────────────────────────────
        let cap = needed + 4; // a little extra
        let mut buf: Vec<RM_PROCESS_INFO> =
            vec![std::mem::zeroed::<RM_PROCESS_INFO>(); cap as usize];
        n = cap;
        let rc2 = RmGetList(session, &mut needed, &mut n, buf.as_mut_ptr(), &mut reboot);

        RmEndSession(session);

        if rc2 != ERROR_SUCCESS && rc2 != ERROR_MORE_DATA {
            return vec![];
        }

        // ── Extract names ────────────────────────────────────────────────────
        (0..n as usize)
            .map(|i| {
                let info = &buf[i];
                let name = String::from_utf16_lossy(
                    &info
                        .strAppName
                        .iter()
                        .copied()
                        .take_while(|&c| c != 0)
                        .collect::<Vec<u16>>(),
                );
                let pid = info.Process.dwProcessId;
                let name = if name.trim().is_empty() {
                    format!("PID {pid}")
                } else {
                    name.trim().to_string()
                };
                LockingProcess { pid, name }
            })
            .collect()
    }
}
