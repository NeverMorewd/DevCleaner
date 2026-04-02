use crate::types::{CleanItem, ScanResult};
use comfy_table::{presets::UTF8_FULL, Attribute, Cell, Color, Table};
use console::style;
use humansize::{format_size, BINARY};

pub fn print_banner() {
    println!();
    println!(
        "{}",
        style("=======================================================").cyan()
    );
    println!("  {}", style("DevCleaner - Reclaim Your Disk Space").bold());
    println!(
        "{}",
        style("=======================================================").cyan()
    );
    println!();
}

pub fn print_scan_summary(results: &[ScanResult]) {
    let mut table = Table::new();
    table.load_preset(UTF8_FULL);
    table.set_header(vec![
        Cell::new("Scanner")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Type")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Items")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Reclaimable")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Status")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
    ]);

    let mut grand_total: u64 = 0;
    let mut grand_count: usize = 0;

    for result in results {
        if let Some(ref err) = result.error {
            table.add_row(vec![
                Cell::new(&result.scanner_name),
                Cell::new("-"),
                Cell::new("-"),
                Cell::new("-"),
                Cell::new(format!("WARN: {}", err)).fg(Color::Yellow),
            ]);
            continue;
        }

        if result.items.is_empty() {
            table.add_row(vec![
                Cell::new(&result.scanner_name),
                Cell::new("-"),
                Cell::new("0"),
                Cell::new("0 B"),
                Cell::new("Clean").fg(Color::Green),
            ]);
            continue;
        }

        // Group by type
        let mut by_type: std::collections::HashMap<String, (usize, u64)> =
            std::collections::HashMap::new();
        for item in &result.items {
            let e = by_type
                .entry(item.item_type.label().to_string())
                .or_default();
            e.0 += 1;
            e.1 += item.size;
        }

        for (type_label, (count, size)) in &by_type {
            grand_total += size;
            grand_count += count;
            table.add_row(vec![
                Cell::new(&result.scanner_name),
                Cell::new(type_label),
                Cell::new(count.to_string()),
                Cell::new(format_size(*size, BINARY)).fg(Color::Red),
                Cell::new(format!("Found {count}")).fg(Color::Yellow),
            ]);
        }
    }

    println!("{table}");
    println!(
        "\n  {} {} items found - {} reclaimable\n",
        style(">>").cyan().bold(),
        style(grand_count).yellow().bold(),
        style(format_size(grand_total, BINARY)).red().bold()
    );
}

pub fn print_item_details(items: &[CleanItem]) {
    let mut table = Table::new();
    table.load_preset(UTF8_FULL);
    table.set_header(vec![
        Cell::new("Scanner")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Package")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Version")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Size")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Path")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
    ]);

    for item in items {
        table.add_row(vec![
            Cell::new(&item.scanner),
            Cell::new(item.package_name.as_deref().unwrap_or(&item.description)),
            Cell::new(item.version.as_deref().unwrap_or("-")),
            Cell::new(format_size(item.size, BINARY)).fg(Color::Red),
            Cell::new(item.path.display().to_string()),
        ]);
    }
    println!("{table}");
}

#[allow(dead_code)]
pub fn format_size_human(size: u64) -> String {
    format_size(size, BINARY)
}

pub fn print_success(msg: &str) {
    println!("  {} {}", style("OK").green().bold(), msg);
}

pub fn print_error(msg: &str) {
    eprintln!("  {} {}", style("ERR").red().bold(), msg);
}

pub fn print_info(msg: &str) {
    println!("  {} {}", style(">>").blue(), msg);
}
