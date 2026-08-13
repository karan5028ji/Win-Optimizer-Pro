<div align="center">

<img src="src-tauri/icons/icon.png" alt="Win-Optimizer-Pro" width="128" />

# Win-Optimizer-Pro

**A modern, enterprise-grade Windows optimizer, cleaner & debloater — powered by Rust, React and PowerShell.**

[![Version](https://img.shields.io/badge/version-2.1.4-teal)](https://github.com/karan5028ji/Win-Optimizer-Pro/releases)
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

Prefer a proper install (per-machine, Start Menu + Desktop shortcuts)? Grab the **`Win-Optimizer-Pro_2.1.4_x64-setup.exe`** from the [Releases](https://github.com/karan5028ji/Win-Optimizer-Pro/releases) page.

## 🆕 What's new in v2.1.4

| Area | Change |
| --- | --- |
| 🛑 **Reliable Stop button** | Optimizer processes now run inside a Windows Job Object that kills the whole tree (including escaped installers) on close — Stop actually stops, and the status bar no longer gets stuck in "Running". |
| 🚀 **Snappier console** | Console renders only the last 300 log lines instead of all 4,000, so long cleanup runs stay responsive. |
| ⚙️ **Context menu toggle fixed** | The Sidebar context-menu switch now reflects the *real* on-disk state and reliably toggles desktop/mobile context menus. |
| 🧹 **Cleaner cleanup** | Locked temp files are taken ownership of and swept on a second pass instead of being left behind; "already empty" false alarms removed. |
| 🏷️ **Consistent naming** | Branding fully renamed from the old `pc-optimizer` / `PC Optimizer` to `Win-Optimizer-Pro` (window title, installer, PS1 headers, logs, debug env). |

## 🆕 What's new in v2.1.3

| Area | Change |
| --- | --- |
| ⚡ **Blazing-fast temp cleanup** | Temp / Windows Temp / Prefetch now clean via a native `robocopy /mir` sweep instead of a slow `cmd for /f` loop. 20,000 files clear in ~13s (was 60s+). Locked files are skipped safely and ownership is taken only when something actually survives the first pass. |
| 📈 **Smooth live progress** | The status bar now climbs percent-by-percent while folders are cleaning — progress is streamed from robocopy's own output with zero filesystem contention. |
| 🛡️ **Bulletproof run supervision** | `optimizer:done` now always fires, even when a background process keeps the console pipe open — the UI can never get stuck in "running" with dead buttons. Run-sequence IDs stop stale completions after Stop + re-run. |
| 🎨 **Fresh app icon** | New application icon propagated to the exe, taskbar, window, Start Menu, Desktop and installer. |
| 🖥️ **UI responsiveness** | Console output is batched to one paint per ~80 ms, so heavy logs (winget/DISM/sfc) no longer freeze the interface. |
| 🔧 **Engine hardening** | Weighted progress phases, monotonic percent math, safe enumeration on locked folders (`-1` never leaks into logs). |

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

v2.1.3 verified against the cleanup & progress rework on the production build:

- **20,000-file temp folder** cleared in ~13 seconds with a monotonic 0→100% status-bar climb (44 progress frames, no frozen UI)
- **Locked-file fallback**: `takeown`/`icacls` runs only on survivors; locked items are reported and safely skipped
- **Nested trees** (sub-folder + deep paths) fully cleaned in the first pass
- **Dry-run** mode deletes nothing; non-admin preview is read-only
- Empty folders, missing folders and access-denied enumeration handled cleanly
- Full `optimizer.ps1 -DryRun -Clean` phase flow (temp + network) exits clean with weighted progress

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

- Installer: `src-tauri\target\release\bundle\nsis\Win-Optimizer-Pro_2.1.4_x64-setup.exe`
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
