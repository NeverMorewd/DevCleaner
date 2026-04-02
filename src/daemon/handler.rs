use std::io::{BufRead, BufReader, Write};
use std::sync::{Arc, Mutex};
use std::thread;

use serde_json::{json, Value};

use crate::cleaner;
use crate::config::Config;
use crate::daemon::protocol::{error_codes, RpcNotification, RpcRequest, RpcResponse};
use crate::daemon::state::DaemonState;
use crate::scanner;

pub fn run() -> anyhow::Result<()> {
    let config = Config::load().unwrap_or_default();
    let state = Arc::new(Mutex::new(DaemonState::new(config)));

    let stdin = std::io::stdin();
    let stdout = Arc::new(Mutex::new(std::io::stdout()));

    // Helper: write a JSON line to stdout
    let write_line = {
        let stdout = Arc::clone(&stdout);
        move |val: &Value| {
            let mut out = stdout.lock().unwrap();
            let _ = writeln!(out, "{}", serde_json::to_string(val).unwrap_or_default());
            let _ = out.flush();
        }
    };

    let reader = BufReader::new(stdin.lock());
    for line in reader.lines() {
        let line = match line {
            Ok(l) if l.trim().is_empty() => continue,
            Ok(l) => l,
            Err(_) => break,
        };

        let req: RpcRequest = match serde_json::from_str(&line) {
            Ok(r) => r,
            Err(e) => {
                write_line(
                    &serde_json::to_value(RpcResponse::err(
                        None,
                        error_codes::PARSE_ERROR,
                        format!("Parse error: {}", e),
                    ))
                    .unwrap(),
                );
                continue;
            }
        };

        let id = req.id;
        match req.method.as_str() {
            "get_config" => handle_get_config(id, &state, &write_line),
            "set_config" => handle_set_config(id, req.params, &state, &write_line),
            "start_scan" => handle_start_scan(id, &state, &stdout, &write_line),
            "delete_items" => handle_delete_items(id, req.params, &state, &write_line),
            "abort_scan" => {
                state.lock().unwrap().abort_scan();
            }
            _ => {
                write_line(
                    &serde_json::to_value(RpcResponse::err(
                        id,
                        error_codes::METHOD_NOT_FOUND,
                        format!("Unknown method: {}", req.method),
                    ))
                    .unwrap(),
                );
            }
        }
    }
    Ok(())
}

fn handle_get_config(
    id: Option<u64>,
    state: &Arc<Mutex<DaemonState>>,
    write: &impl Fn(&Value),
) {
    let config = state.lock().unwrap().config.clone();
    let val = serde_json::to_value(&config).unwrap_or(Value::Null);
    write(&serde_json::to_value(RpcResponse::ok(id, val)).unwrap());
}

fn handle_set_config(
    id: Option<u64>,
    params: Value,
    state: &Arc<Mutex<DaemonState>>,
    write: &impl Fn(&Value),
) {
    match serde_json::from_value::<Config>(params) {
        Ok(new_config) => match new_config.save() {
            Ok(()) => {
                state.lock().unwrap().config = new_config;
                write(
                    &serde_json::to_value(RpcResponse::ok(id, json!({"ok": true}))).unwrap(),
                );
            }
            Err(e) => {
                write(
                    &serde_json::to_value(RpcResponse::err(
                        id,
                        error_codes::CONFIG_ERROR,
                        e.to_string(),
                    ))
                    .unwrap(),
                );
            }
        },
        Err(e) => {
            write(
                &serde_json::to_value(RpcResponse::err(
                    id,
                    error_codes::INVALID_REQUEST,
                    e.to_string(),
                ))
                .unwrap(),
            );
        }
    }
}

fn handle_start_scan(
    id: Option<u64>,
    state: &Arc<Mutex<DaemonState>>,
    stdout: &Arc<Mutex<std::io::Stdout>>,
    write: &impl Fn(&Value),
) {
    {
        let st = state.lock().unwrap();
        if st.scan_running {
            write(
                &serde_json::to_value(RpcResponse::err(
                    id,
                    error_codes::SCAN_RUNNING,
                    "Scan already running",
                ))
                .unwrap(),
            );
            return;
        }
    }

    {
        let mut st = state.lock().unwrap();
        st.scan_running = true;
        st.reset_abort();
    }

    let config = state.lock().unwrap().config.clone();
    let abort = Arc::clone(&state.lock().unwrap().abort_flag);
    let stdout_clone = Arc::clone(stdout);
    let state_clone = Arc::clone(state);

    thread::spawn(move || {
        // Count enabled scanners for progress reporting
        let total_scanners: u32 = [
            config.scanners.nuget,
            config.scanners.cargo,
            config.scanners.golang,
            config.scanners.node,
            config.scanners.pip,
            config.scanners.maven,
            config.scanners.gradle,
            config.scanners.cpp_vcpkg,
            config.scanners.cpp_conan,
            config.scanners.build_artifacts,
            config.scanners.env_vars,
            config.scanners.dump_files,
            config.scanners.android_sdk,
            config.scanners.ide_cache,
            config.scanners.windows_temp,
            config.scanners.rustup,
            config.scanners.browser_cache,
            config.scanners.flutter_pub,
        ]
        .iter()
        .filter(|&&b| b)
        .count() as u32;

        let mut done: u32 = 0;

        let results = scanner::run_all_scanners(
            &config,
            |scanner_name| {
                done += 1;
                let notif = RpcNotification::new(
                    "scan_progress",
                    json!({
                        "scanner_name": scanner_name,
                        "scanners_done": done,
                        "scanners_total": total_scanners,
                    }),
                );
                let mut out = stdout_clone.lock().unwrap();
                let _ = writeln!(
                    out,
                    "{}",
                    serde_json::to_string(&notif).unwrap_or_default()
                );
                let _ = out.flush();
            },
            &abort,
        );

        // Calculate totals
        let grand_total_size: u64 = results.iter().map(|r| r.total_size).sum();
        let grand_total_items: usize = results.iter().map(|r| r.items.len()).sum();

        // Generate scan_id
        let scan_id = format!(
            "{:x}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .subsec_nanos()
        );

        // Store results
        {
            let mut st = state_clone.lock().unwrap();
            st.scan_id = Some(scan_id.clone());
            st.last_results = Some(
                results
                    .iter()
                    .map(|r| crate::types::ScanResult {
                        scanner_name: r.scanner_name.clone(),
                        items: r.items.clone(),
                        total_size: r.total_size,
                        error: r.error.clone(),
                    })
                    .collect(),
            );
            st.scan_running = false;
        }

        let aborted = abort.load(std::sync::atomic::Ordering::Relaxed);
        let response = if aborted {
            serde_json::to_value(RpcResponse::err(
                id,
                error_codes::SCAN_ABORTED,
                "Scan aborted by user",
            ))
            .unwrap()
        } else {
            let results_val = serde_json::to_value(&results).unwrap_or(Value::Null);
            serde_json::to_value(RpcResponse::ok(
                id,
                json!({
                    "scan_id": scan_id,
                    "results": results_val,
                    "grand_total_size": grand_total_size,
                    "grand_total_items": grand_total_items,
                }),
            ))
            .unwrap()
        };

        let mut out = stdout_clone.lock().unwrap();
        let _ = writeln!(
            out,
            "{}",
            serde_json::to_string(&response).unwrap_or_default()
        );
        let _ = out.flush();
    });
}

fn handle_delete_items(
    id: Option<u64>,
    params: Value,
    state: &Arc<Mutex<DaemonState>>,
    write: &impl Fn(&Value),
) {
    let scan_id = params
        .get("scan_id")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());
    let paths: Vec<String> = params
        .get("paths")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default();

    // Validate scan_id
    {
        let st = state.lock().unwrap();
        if let (Some(req_id), Some(cur_id)) = (&scan_id, &st.scan_id) {
            if req_id != cur_id {
                write(
                    &serde_json::to_value(RpcResponse::err(
                        id,
                        error_codes::STALE_SCAN_ID,
                        "Stale scan_id, re-scan first",
                    ))
                    .unwrap(),
                );
                return;
            }
        }
    }

    // Find CleanItems matching the paths
    let items_to_delete = {
        let st = state.lock().unwrap();
        match &st.last_results {
            None => vec![],
            Some(results) => results
                .iter()
                .flat_map(|r| r.items.iter())
                .filter(|item| {
                    let path_str = item.path.to_string_lossy().to_string();
                    paths.contains(&path_str)
                })
                .cloned()
                .collect::<Vec<_>>(),
        }
    };

    let total = items_to_delete.len();
    let mut freed: u64 = 0;
    let mut deleted_count: u32 = 0;
    let mut errors: Vec<Value> = Vec::new();

    for (i, item) in items_to_delete.iter().enumerate() {
        let path_str = item.path.to_string_lossy().to_string();
        match cleaner::delete_item(item) {
            Ok(()) => {
                freed += item.size;
                deleted_count += 1;
                let notif = RpcNotification::new(
                    "delete_progress",
                    json!({
                        "path": path_str,
                        "items_done": i + 1,
                        "items_total": total,
                        "freed_bytes": freed,
                        "error": null,
                    }),
                );
                write(&serde_json::to_value(notif).unwrap());
            }
            Err(e) => {
                errors.push(json!({"path": path_str, "message": e.to_string()}));
                let notif = RpcNotification::new(
                    "delete_progress",
                    json!({
                        "path": path_str,
                        "items_done": i + 1,
                        "items_total": total,
                        "freed_bytes": freed,
                        "error": e.to_string(),
                    }),
                );
                write(&serde_json::to_value(notif).unwrap());
            }
        }
    }

    write(
        &serde_json::to_value(RpcResponse::ok(
            id,
            json!({
                "freed_bytes": freed,
                "deleted_count": deleted_count,
                "error_count": errors.len(),
                "errors": errors,
            }),
        ))
        .unwrap(),
    );
}
