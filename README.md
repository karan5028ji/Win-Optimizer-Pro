# Win-Optimizer-Pro

[![GitHub release](https://img.shields.io/github/v/release/karan5028ji/Win-Optimizer-Pro)](https://github.com/karan5028ji/Win-Optimizer-Pro/releases)
[![Downloads](https://img.shields.io/github/downloads/karan5028ji/Win-Optimizer-Pro/total)](https://github.com/karan5028ji/Win-Optimizer-Pro/releases)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-0078D6)](https://www.microsoft.com/windows)
[![License: MIT](https://img.shields.io/github/license/karan5028ji/Win-Optimizer-Pro)](LICENSE)

A modern, Tauri-based **Windows optimizer, cleaner and debloater** built to squeeze maximum performance out of low-end setups — with a clean React + Tailwind UI, live system dashboard, and a PowerShell engine under the hood.

This script **automates cleanup, debloating and tweaking** so you don't have to click through ten different settings apps. It's designed for **Windows 10 / Windows 11**.

> **⚠️ Warning:** This tool modifies your system (removes apps, changes registry, clears data). Everything runs in **Dry-run mode by default** — review before applying.

## Run

The fastest way — one line, directly from GitHub. No install needed:

```powershell
irm https://raw.githubusercontent.com/karan5028ji/Win-Optimizer-Pro/main/run.ps1 | iex
```

This downloads the **latest portable build**, extracts it to `%TEMP%` and launches it right away. No setup, no shortcut, no clutter.

Prefer a proper install (Start Menu shortcut, per-machine install)? Grab the **`*-setup.exe`** from the [Releases](https://github.com/karan5028ji/Win-Optimizer-Pro/releases) page.

## Features

| Feature | What it does |
|---------|--------------|
| **Dashboard** | Live CPU / RAM / OS / architecture overview, elevated-status badge, one-click Quick Scan |
| **Deep Clean** | Granular cleanup with per-item toggles — user & Windows temp, prefetch, DNS cache, browser caches |
| **Debloater** | Browse *real* installed bloatware by category, remove or restore apps individually |
| **System Tweaks** | Apply / rollback privacy & performance tweaks — telemetry, background apps, hibernation, fast startup, game bar, Cortana, tips, Bing search |
| **Safety first** | Dry-run mode **ON by default**; app auto-re-launches elevated via UAC only when needed |

## How it works

- **Frontend** — React 18 + Tailwind CSS + Vite
- **Backend** — Rust (Tauri v2) shell
- **Engine** — PowerShell (`optimizer.ps1` / `engine.ps1`), invoked invisibly (no console popups)
- **Installer** — NSIS; portable build ships the raw binary + engine side-by-side

## Command line (power users)

```powershell
.\optimizer.ps1 -Clean | -Network | -Debloat | -Tweaks | -All
.\optimizer.ps1 -Category Bing,Xbox     # filter bloatware categories
.\optimizer.ps1 -Package X              # remove one specific package
.\optimizer.ps1 -Tweak telemetry,x      # apply specific system tweaks
.\optimizer.ps1 -ListCategories         # list bloatware categories
.\optimizer.ps1 -ListTweaks             # list available tweaks
```

Add `-DryRun` for a read-only preview of every action before applying it.

## Development

```powershell
npm install
npm run tauri dev
```

## Building

```powershell
npm run tauri build
```

Output:

- Installer: `src-tauri\target\release\bundle\nsis\PC Optimizer_0.1.0_x64-setup.exe`
- Raw binary: `src-tauri\target\release\pc-optimizer.exe`

**Requirements:** Node.js 18+, Rust stable (MSVC toolchain), WebView2 (bundled with Windows 11 / modern Windows 10).

## Disclaimer

This project is provided **as-is**, without warranty of any kind. Running the app performs real system changes (app removal, registry edits, file deletion). Always keep backups, review Dry-run output, and use at your own risk. The author is not responsible for any damage, data loss, or system issues that may arise.

## Contributing

Issues, ideas and PRs are welcome. Open an issue to report bugs or request tweaks/categories before submitting large changes.

## License

MIT
