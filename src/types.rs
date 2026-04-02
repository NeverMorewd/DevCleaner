use std::path::PathBuf;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CleanItemType {
    OldVersion,
    Cache,
    BuildArtifact,
    NodeModules,
    InvalidEnvVar,
    InvalidPathEntry,
    DumpFile,
    /// A system temp directory whose *contents* should be cleared but the
    /// directory itself must be preserved (e.g. %TEMP%, C:\Windows\Temp).
    TempDirectory,
}

impl CleanItemType {
    pub fn label(&self) -> &'static str {
        match self {
            CleanItemType::OldVersion => "Old Version",
            CleanItemType::Cache => "Cache",
            CleanItemType::BuildArtifact => "Build Artifact",
            CleanItemType::NodeModules => "node_modules",
            CleanItemType::InvalidEnvVar => "Invalid Env Var",
            CleanItemType::InvalidPathEntry => "Invalid PATH Entry",
            CleanItemType::DumpFile => "Dump File",
            CleanItemType::TempDirectory => "Temp Directory",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum RegScope {
    User,
    System,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegistryCleanInfo {
    pub scope: RegScope,
    pub var_name: String,
    pub path_entry: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CleanItem {
    pub path: PathBuf,
    pub size: u64,
    pub description: String,
    pub scanner: String,
    pub item_type: CleanItemType,
    pub package_name: Option<String>,
    pub version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub registry_info: Option<RegistryCleanInfo>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ScanResult {
    pub scanner_name: String,
    pub items: Vec<CleanItem>,
    pub total_size: u64,
    pub error: Option<String>,
}

impl ScanResult {
    pub fn new(scanner_name: &str) -> Self {
        ScanResult {
            scanner_name: scanner_name.to_string(),
            items: Vec::new(),
            total_size: 0,
            error: None,
        }
    }

    pub fn add_item(&mut self, item: CleanItem) {
        self.total_size += item.size;
        self.items.push(item);
    }

    pub fn with_error(scanner_name: &str, err: &str) -> Self {
        let mut r = Self::new(scanner_name);
        r.error = Some(err.to_string());
        r
    }
}
