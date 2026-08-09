# Win-Optimizer-Pro

A modern, Tauri-based Windows optimizer and debloater to squeeze maximum performance out of low-end setups.

## Features

- **Dashboard** — live CPU / RAM / OS / architecture overview, elevated-status badge, Quick Scan
- **Deep Clean** — granular cleanup with per-item toggles (user/windows temp, prefetch, DNS cache, browser caches)
- **Debloater** — browse real installed bloatware by category, remove or restore apps individually
- **System Tweaks** — apply/rollback privacy and performance tweaks (telemetry, background apps, hibernation, fast startup, game bar, Cortana, tips, Bing search)
- **Safety first** — Dry-run mode is ON by default; the app re-launches elevated via UAC when needed

## Tech stack

- **Frontend:** React 18 + Tailwind CSS + Vite
- **Backend:** Rust (Tauri v2) with a PowerShell engine (`optimizer.ps1` / `engine.ps1`)
- **Build:** Vite for the web assets, Cargo for the Rust shell, NSIS for the installer

## Requirements

- Node.js 18+
- Rust stable (rustup) with the MSVC toolchain
- WebView2 runtime (bundled with Windows 11 / modern Windows 10)

## Development

```powershell
npm install
npm run tauri dev
```

## Building the installer

```powershell
npm run tauri build
```

Output:

- Installer: `src-tauri\target\release\bundle\nsis\PC Optimizer_0.1.0_x64-setup.exe`
- Raw binary: `src-tauri\target\release\pc-optimizer.exe`

## CLI (power users)

```powershell
.\optimizer.ps1 -Clean | -Network | -Debloat | -Tweaks | -All
.\optimizer.ps1 -Category Bing,Xbox     # filter bloatware categories
.\optimizer.ps1 -Package X              # remove one specific package
.\optimizer.ps1 -Tweak telemetry,x      # apply specific system tweaks
.\optimizer.ps1 -ListCategories         # list bloatware categories
.\optimizer.ps1 -ListTweaks             # list available tweaks
```

Add `-DryRun` for a read-only preview of every action before applying it.

## License

MIT
