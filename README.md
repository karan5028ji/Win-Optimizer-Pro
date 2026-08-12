<div align="center">

<img src="src-tauri/icons/icon.png" alt="Win-Optimizer-Pro" width="128" />

# Win-Optimizer-Pro

**A modern, enterprise-grade Windows optimizer, cleaner & debloater — powered by Rust, React and PowerShell.**

[![Version](https://img.shields.io/badge/version-2.1.1-teal)](https://github.com/karan5028ji/Win-Optimizer-Pro/releases)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6)](https://www.microsoft.com/windows)
[![Tauri](https://img.shields.io/badge/built%20with-Tauri%20v2-0d9488)](https://v2.tauri.app)
[![License: MIT](https://img.shields.io/github/license/karan5028ji/Win-Optimizer-Pro)](LICENSE)

> **⚠️ Warning:** This tool modifies your system — it removes apps, edits the registry and deletes files.
> **Dry-run mode is ON by default.** Review the console output before applying anything.

</div>

---

## ✨ What is it?

Win-Optimizer-Pro is a **flat, enterprise-style desktop app** that automates cleanup, debloating, tweaking and system hardening on Windows — so you don't have to click through ten different settings apps. It combines the deep feature set of the classic **Chris Titus WinUtil** with modern power-user tools, wrapped in a clean teal/slate UI with **light & dark mode**.

Designed for **Windows 10 / Windows 11**.

## 🚀 Quick Install

The fastest way — one line, straight from GitHub, no install needed:

```powershell
irm https://raw.githubusercontent.com/karan5028ji/Win-Optimizer-Pro/main/run.ps1 | iex
```

Prefer a proper install (per-machine, Start Menu + Desktop shortcuts)? Grab the **`Win-Optimizer-Pro_2.1.1_x64-setup.exe`** from the [Releases](https://github.com/karan5028ji/Win-Optimizer-Pro/releases) page.

## 🧰 Features

### WinUtil-style toolkit
| Category | What it does |
| --- | --- |
| **Install Software** | Install, upgrade or uninstall popular apps through WinGet; bulk "Upgrade All" |
| **Debloater** | Browse *real* installed bloatware by category, remove / restore apps individually (optional System Restore point) |
| **System Tweaks** | Privacy & performance tweaks — telemetry, background apps, hibernation, fast startup, Game Bar, Cortana, tips, Bing results. Presets: Standard / Minimal / Advanced |
| **Tuning** | DNS presets, Windows Update policy, power plans, optional Windows Features, one-click **Fixes** (DISM etc.), OpenSSH server, legacy control panels, undo tweaks |
| **Win11 ISO** | Create a bootable Windows 11 ISO from an existing install |
| **Security** | Anti-brick pre-flight gate, elevation handling, dry-run by default |

### Power-user suite (v2.0+)
| Feature | What it does |
| --- | --- |
| 🛡️ **Anti-Brick Pre-Flight** | Verifies disk space (≥20 GB), battery (≥30% or charging) and admin rights **before** heavy operations (DISM, ISO, deep debloat, bulk installs). Auto-aborts safely if any check fails |
| ⚡ **1-Click Profiles** | **Gamer**, **Privacy/Stealth** and **Developer** profiles — one click applies the full stack incl. apps |
| 📂 **Config Import/Export** | Save your choices (apps, tweaks, DNS, power, updates, features, SSH) as a shareable **JSON** profile in `Documents\Win-Optimizer-Pro` |
| 🎛️ **Startup Manager** | See & control everything that launches at boot — registry Run keys and Startup folders, with Enable/Disable |
| 🖱️ **Win11 Context Menu** | Toggle the classic Win10-style right-click menu |
| 🎨 **Registry Transparency** | Hover-tooltips on every tweak show the exact registry key being changed |
| 🌗 **Light & Dark Mode** | Flat teal/slate design system with a one-click theme toggle |

### Dashboard
- System overview (CPU / RAM / OS / architecture)
- **Data-driven "System readiness" radial rings** — WinGet catalog coverage, tweak coverage, startup coverage
- One-click read-only **Quick Scan** (temp items, DNS cache, bloatware, pending tweaks)
- Live streaming console with a Stop button

## 🛠 Tech stack

- **Frontend** — React 18 + Tailwind CSS (flat design system, Inter font) + Vite
- **Backend** — Rust (Tauri v2), async process management with process-tree kill
- **Engine** — PowerShell (`optimizer.ps1` / `engine.ps1` / `winutil.ps1`), invoked invisibly (no console popups)
- **Installer** — NSIS (per-machine), bundled PowerShell resources

## 💻 Command line (power users)

```powershell
.\optimizer.ps1 -Clean | -Network | -Debloat | -Tweaks | -All
.\optimizer.ps1 -Category Bing,Xbox        # filter bloatware categories
.\optimizer.ps1 -Package X                 # remove one specific package
.\optimizer.ps1 -Tweak telemetry,x         # apply specific system tweaks
.\optimizer.ps1 -ListCategories            # list bloatware categories
.\optimizer.ps1 -ListTweaks / -TweakInfo   # list tweaks / show registry keys
.\optimizer.ps1 -WingetList                # WinGet catalog
.\optimizer.ps1 -Profile Gamer             # one-click profile (Gamer|Privacy|Developer)
.\optimizer.ps1 -ExportConfig -ConfigName my-setup    # save a JSON profile
.\optimizer.ps1 -ImportConfig -ConfigName my-setup    # apply a JSON profile
.\optimizer.ps1 -ListStartup               # startup manager
.\optimizer.ps1 -SetContextMenu Classic    # Win10-style context menu
.\optimizer.ps1 -Preflight dism            # run the anti-brick gate
.\optimizer.ps1 -QuickScan                 # read-only health snapshot
```

Add `-DryRun` to every write action for a read-only preview. `-NoElevate` skips the UAC relaunch.

## 🧪 Testing

v2.1.1 passed a **35/35 scenario suite** on the installed production build (all CLI switches, dry-run + read-only) plus icon, shortcut and launch verification. Full details: **[REPORT.md](REPORT.md)**.

## 🔧 Development

```powershell
npm install
npm run tauri dev
```

## 📦 Building

```powershell
npm run tauri build
```

Output:

- Installer: `src-tauri\target\release\bundle\nsis\Win-Optimizer-Pro_2.1.1_x64-setup.exe`
- Binary: `src-tauri\target\release\win-optimizer-pro.exe`

**Requirements:** Node.js 18+, Rust stable (MSVC toolchain), WebView2 (bundled with Windows 11 / modern Windows 10).

## 🖼 Custom app icon

Regenerate all platform icons (taskbar, window, Start Menu, Desktop, installer) from any source PNG:

```powershell
npx tauri icon path\to\icon.png
npm run tauri build
```

## ⚠️ Disclaimer

This project is provided **as-is**, without warranty of any kind. Running the app performs real system changes (app removal, registry edits, file deletion). Always keep backups, review Dry-run output, and use at your own risk. The author is not responsible for any damage, data loss, or system issues that may arise.

## 🤝 Contributing

Issues, ideas and PRs are welcome. Open an issue to report bugs or request tweaks/categories before submitting large changes.

## 📄 License

MIT
