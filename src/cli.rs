use clap::{Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(
    name = "devcleaner",
    version,
    about = "Clean dev package caches and reclaim disk space",
    long_about = None,
)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Option<Command>,

    /// Run as JSON-RPC 2.0 daemon over stdin/stdout
    #[arg(long, hide = true)]
    pub daemon: bool,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    /// Scan for cleanable items (no deletion)
    Scan,
    /// Scan and interactively clean selected items
    Clean {
        /// Skip confirmation prompt and delete immediately
        #[arg(short, long)]
        yes: bool,
    },
    /// View and edit configuration
    Config {
        #[command(subcommand)]
        action: Option<ConfigAction>,
    },
}

#[derive(Subcommand, Debug)]
pub enum ConfigAction {
    /// Show current configuration
    Show,
    /// Interactively configure which scanners to enable
    Edit,
    /// Add a project root for artifact scanning
    AddRoot { path: String },
    /// Remove a project root
    RemoveRoot { path: String },
}
