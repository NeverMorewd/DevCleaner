use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};

use crate::config::Config;
use crate::types::ScanResult;

pub struct DaemonState {
    pub config: Config,
    pub abort_flag: Arc<AtomicBool>,
    pub scan_id: Option<String>,
    pub last_results: Option<Vec<ScanResult>>,
    pub scan_running: bool,
}

impl DaemonState {
    pub fn new(config: Config) -> Self {
        DaemonState {
            config,
            abort_flag: Arc::new(AtomicBool::new(false)),
            scan_id: None,
            last_results: None,
            scan_running: false,
        }
    }

    pub fn reset_abort(&mut self) {
        self.abort_flag.store(false, Ordering::Relaxed);
    }

    pub fn abort_scan(&self) {
        self.abort_flag.store(true, Ordering::Relaxed);
    }
}
