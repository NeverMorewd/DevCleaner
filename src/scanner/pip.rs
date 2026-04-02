use crate::config::Config;
use crate::types::{CleanItem, CleanItemType, ScanResult};
use crate::utils::dir_size;

pub fn scan(_config: &Config) -> ScanResult {
    let mut result = ScanResult::new("pip / uv");

    // pip cache
    if let Some(local) = dirs::data_local_dir() {
        let pip_cache = local.join("pip").join("Cache");
        if pip_cache.exists() {
            let size = dir_size(&pip_cache);
            if size > 0 {
                result.add_item(CleanItem {
                    path: pip_cache,
                    size,
                    description: "pip cache".to_string(),
                    scanner: "pip / uv".to_string(),
                    item_type: CleanItemType::Cache,
                    package_name: None,
                    version: None,
                    registry_info: None,
                });
            }
        }
        // uv cache
        let uv_cache = local.join("uv").join("cache");
        if uv_cache.exists() {
            let size = dir_size(&uv_cache);
            if size > 0 {
                result.add_item(CleanItem {
                    path: uv_cache,
                    size,
                    description: "uv cache".to_string(),
                    scanner: "pip / uv".to_string(),
                    item_type: CleanItemType::Cache,
                    package_name: None,
                    version: None,
                    registry_info: None,
                });
            }
        }
    }

    result
}
