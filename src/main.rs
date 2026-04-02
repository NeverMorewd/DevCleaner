mod cli;
mod cleaner;
mod config;
mod daemon;
mod display;
mod scanner;
mod types;
mod utils;

use anyhow::Result;
use cli::{Cli, Command, ConfigAction};
use clap::Parser;
use std::sync::{Arc, atomic::AtomicBool};
use console::style;
use dialoguer::{Confirm, MultiSelect, Select};
use humansize::{format_size, BINARY};
use indicatif::{ProgressBar, ProgressStyle};
use std::time::Duration;

fn main() -> Result<()> {
    let cli = Cli::parse();

    if cli.daemon {
        return daemon::run();
    }

    let mut config = config::Config::load()?;

    match cli.command {
        None | Some(Command::Clean { yes: false }) => {
            run_interactive(&config, false)?;
        }
        Some(Command::Clean { yes: true }) => {
            run_interactive(&config, true)?;
        }
        Some(Command::Scan) => {
            run_scan_only(&config)?;
        }
        Some(Command::Config { action }) => {
            run_config(&mut config, action)?;
        }
    }

    Ok(())
}

fn run_scan_only(config: &config::Config) -> Result<()> {
    display::print_banner();
    let results = do_scan(config);
    display::print_scan_summary(&results);

    // Offer detail view
    let all_items: Vec<_> = results.iter().flat_map(|r| r.items.iter()).collect();
    if !all_items.is_empty() {
        let show = Confirm::new()
            .with_prompt("Show detailed item list?")
            .default(false)
            .interact()?;
        if show {
            display::print_item_details(
                &all_items.into_iter().cloned().collect::<Vec<_>>(),
            );
        }
    }
    Ok(())
}

fn run_interactive(config: &config::Config, auto_yes: bool) -> Result<()> {
    display::print_banner();
    let results = do_scan(config);
    display::print_scan_summary(&results);

    let all_items: Vec<_> = results
        .iter()
        .flat_map(|r| r.items.iter().cloned())
        .collect();

    if all_items.is_empty() {
        display::print_success("Nothing to clean - your dev cache is already tidy!");
        return Ok(());
    }

    // Build scanner groups for selection
    let scanner_labels: Vec<String> = {
        let mut order: Vec<String> = Vec::new();
        for item in &all_items {
            if !order.contains(&item.scanner) {
                order.push(item.scanner.clone());
            }
        }
        order
    };

    let choices = vec!["Clean all", "Select by category", "Show details", "Exit"];
    let selection = Select::new()
        .with_prompt("What would you like to do?")
        .items(&choices)
        .default(0)
        .interact()?;

    let items_to_clean: Vec<types::CleanItem> = match selection {
        0 => all_items,
        1 => {
            // Multi-select by scanner
            let selected = MultiSelect::new()
                .with_prompt(
                    "Select categories to clean (space to toggle, enter to confirm)",
                )
                .items(&scanner_labels)
                .defaults(&vec![true; scanner_labels.len()])
                .interact()?;
            let selected_scanners: Vec<&String> =
                selected.iter().map(|&i| &scanner_labels[i]).collect();
            results
                .iter()
                .flat_map(|r| r.items.iter().cloned())
                .filter(|item| selected_scanners.contains(&&item.scanner))
                .collect()
        }
        2 => {
            display::print_item_details(&all_items);
            return run_interactive(config, auto_yes);
        }
        _ => return Ok(()),
    };

    if items_to_clean.is_empty() {
        display::print_info("No items selected.");
        return Ok(());
    }

    let total_size: u64 = items_to_clean.iter().map(|i| i.size).sum();
    println!(
        "\n  Will delete {} items ({}).\n",
        style(items_to_clean.len()).yellow().bold(),
        style(format_size(total_size, BINARY)).red().bold()
    );

    let confirmed = if auto_yes {
        true
    } else {
        Confirm::new()
            .with_prompt("Proceed with deletion?")
            .default(false)
            .interact()?
    };

    if !confirmed {
        display::print_info("Aborted.");
        return Ok(());
    }

    // Clean
    let pb = ProgressBar::new(items_to_clean.len() as u64);
    pb.set_style(
        ProgressStyle::with_template(
            "{spinner:.cyan} [{bar:40.cyan/blue}] {pos}/{len} {msg}",
        )
        .unwrap()
        .progress_chars("##-"),
    );
    pb.enable_steady_tick(Duration::from_millis(100));

    let mut freed: u64 = 0;
    let mut errors: Vec<String> = Vec::new();

    for item in &items_to_clean {
        pb.set_message(
            item.path
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string(),
        );
        match cleaner::delete_item(item) {
            Ok(()) => freed += item.size,
            Err(e) => errors.push(format!("{}: {}", item.path.display(), e)),
        }
        pb.inc(1);
    }
    pb.finish_and_clear();

    println!(
        "\n  {} Freed {}",
        style("OK").green().bold(),
        style(format_size(freed, BINARY)).green().bold()
    );

    if !errors.is_empty() {
        println!(
            "\n  {} {} errors occurred:",
            style("WARN").yellow(),
            errors.len()
        );
        for e in &errors {
            display::print_error(e);
        }
    }

    Ok(())
}

fn do_scan(config: &config::Config) -> Vec<types::ScanResult> {
    let pb = ProgressBar::new_spinner();
    pb.set_style(
        ProgressStyle::with_template("{spinner:.cyan} Scanning {msg}...")
            .unwrap()
            .tick_strings(&["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]),
    );
    pb.enable_steady_tick(Duration::from_millis(80));

    let abort = Arc::new(AtomicBool::new(false));
    let results = scanner::run_all_scanners(config, |name| {
        pb.set_message(name.to_string());
    }, &abort);

    pb.finish_and_clear();
    results
}

fn run_config(config: &mut config::Config, action: Option<ConfigAction>) -> Result<()> {
    match action {
        None | Some(ConfigAction::Show) => {
            println!("{}", toml::to_string_pretty(config)?);
            if let Some(path) = config::Config::config_path() {
                display::print_info(&format!("Config file: {}", path.display()));
            }
        }
        Some(ConfigAction::Edit) => {
            interactive_config_edit(config)?;
        }
        Some(ConfigAction::AddRoot { path }) => {
            if !config.artifacts.project_roots.contains(&path) {
                config.artifacts.project_roots.push(path.clone());
                config.save()?;
                display::print_success(&format!("Added project root: {}", path));
            } else {
                display::print_info("Path already in project roots.");
            }
        }
        Some(ConfigAction::RemoveRoot { path }) => {
            config.artifacts.project_roots.retain(|p| p != &path);
            config.save()?;
            display::print_success(&format!("Removed project root: {}", path));
        }
    }
    Ok(())
}

fn interactive_config_edit(config: &mut config::Config) -> Result<()> {
    display::print_banner();
    println!(
        "  {} Configure DevCleaner\n",
        style(">>").cyan()
    );

    let labels = vec![
        "NuGet (.NET)",
        "Cargo (Rust)",
        "Go Modules",
        "Node.js (npm/yarn/pnpm)",
        "pip / uv (Python)",
        "Maven (Java)",
        "Gradle (Java)",
        "vcpkg (C++)",
        "Conan (C++)",
        "Build Artifacts (obj/bin/target)",
        "Invalid Environment Variables (PATH, JAVA_HOME, …)",
        "Dump Files (.dmp crash & WER reports)",
        "Android SDK (build-tools, platforms, system-images, AVDs)",
        "IDE Caches (VS Code family, JetBrains)",
        "Windows Temp (TEMP, Prefetch, Windows Update cache)",
        "Rustup (old toolchain versions & download cache)",
        "Browser Caches (Chrome, Edge, Firefox, Brave, Opera)",
        "Flutter/Dart Pub cache",
    ];

    let defaults: Vec<bool> = vec![
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
    ];

    let selected = MultiSelect::new()
        .with_prompt("Enable scanners (space to toggle, enter to save)")
        .items(&labels)
        .defaults(&defaults)
        .interact()?;

    config.scanners.nuget = selected.contains(&0);
    config.scanners.cargo = selected.contains(&1);
    config.scanners.golang = selected.contains(&2);
    config.scanners.node = selected.contains(&3);
    config.scanners.pip = selected.contains(&4);
    config.scanners.maven = selected.contains(&5);
    config.scanners.gradle = selected.contains(&6);
    config.scanners.cpp_vcpkg = selected.contains(&7);
    config.scanners.cpp_conan = selected.contains(&8);
    config.scanners.build_artifacts = selected.contains(&9);
    config.scanners.env_vars = selected.contains(&10);
    config.scanners.dump_files = selected.contains(&11);
    config.scanners.android_sdk = selected.contains(&12);
    config.scanners.ide_cache = selected.contains(&13);
    config.scanners.windows_temp = selected.contains(&14);
    config.scanners.rustup = selected.contains(&15);
    config.scanners.browser_cache = selected.contains(&16);
    config.scanners.flutter_pub = selected.contains(&17);

    // Artifact sub-options if enabled
    if config.scanners.build_artifacts {
        let art_options = vec![
            "C# / .NET  — obj/ bin/",
            "Rust        — target/",
            "Node.js     — node_modules/",
            "JS/TS       — .next/ .nuxt/ .svelte-kit/ dist/ (frontend frameworks)",
            "Java        — Maven target/ Gradle build/ Android build/",
            "Python      — __pycache__/ .pytest_cache/ .mypy_cache/ build/ dist/",
            "C/C++       — CMakeFiles/ cmake-build-*/ build/ out/",
            "Flutter     — build/ .dart_tool/",
            "Go          — vendor/",
        ];
        let art_defaults = vec![
            config.artifacts.scan_csharp_obj_bin,
            config.artifacts.scan_rust_target,
            config.artifacts.scan_node_modules,
            config.artifacts.scan_frontend_dist,
            config.artifacts.scan_java_build,
            config.artifacts.scan_python_cache,
            config.artifacts.scan_cmake_build,
            config.artifacts.scan_flutter_build,
            config.artifacts.scan_go_vendor,
        ];
        let art_sel = MultiSelect::new()
            .with_prompt("Select artifact types to scan (auto-discovery enabled for common dev paths)")
            .items(&art_options)
            .defaults(&art_defaults)
            .interact()?;
        config.artifacts.scan_csharp_obj_bin  = art_sel.contains(&0);
        config.artifacts.scan_rust_target     = art_sel.contains(&1);
        config.artifacts.scan_node_modules    = art_sel.contains(&2);
        config.artifacts.scan_frontend_dist   = art_sel.contains(&3);
        config.artifacts.scan_java_build      = art_sel.contains(&4);
        config.artifacts.scan_python_cache    = art_sel.contains(&5);
        config.artifacts.scan_cmake_build     = art_sel.contains(&6);
        config.artifacts.scan_flutter_build   = art_sel.contains(&7);
        config.artifacts.scan_go_vendor       = art_sel.contains(&8);

        println!("\n  Auto-discovery scans common paths (~/source/repos, ~/projects, etc.)");
        if !config.artifacts.project_roots.is_empty() {
            println!("  Additional project roots:");
            for root in &config.artifacts.project_roots {
                println!("    • {}", root);
            }
        }
        println!("  Add more roots: devcleaner config add-root <path>");
    }

    config.save()?;
    display::print_success("Configuration saved.");
    Ok(())
}
