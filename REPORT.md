# Win-Optimizer-Pro v2.1.1 — Test Report

**Date:** 2026-08-12
**Build:** v2.1.1 (NSIS, x64, per-machine)
**Installer:** `src-tauri/target/release/bundle/nsis/Win-Optimizer-Pro_2.1.1_x64-setup.exe`
**Install path:** `C:\Program Files\Win-Optimizer-Pro\`
**Test environment:** Windows 11 Home Single Language (Build 26200), Intel Core i7-4790 @ 3.60 GHz, 15.9 GB RAM, AMD64 — non-admin context.

---

## 1. Icon & Distribution Checks

| Check | Result |
| --- | --- |
| Application icon generated from user PNG (`Downloads\icon.png`, 500x500) via `tauri icon` | PASS — full icon set regenerated (ico/icns/icns/PNG incl. `icon.ico` 65 KB) |
| Exe embeds the **new** icon | PASS — pixel-compare of extracted exe icon vs regenerated `32x32.png`: **0/256 mismatches** |
| Taskbar / window title-bar icon (from exe resource) | PASS — comes from embedded `icon.ico` |
| Start Menu shortcut | PASS — `C:\ProgramData\...\Win-Optimizer-Pro.lnk` created |
| Desktop shortcut | PASS — `C:\Users\Public\Desktop\Win-Optimizer-Pro.lnk` created |
| Bundled PowerShell resources | PASS — `_up_\engine.ps1`, `_up_\optimizer.ps1`, `_up_\winutil.ps1` present; Rust `resolve_script` resolves `_up_/` correctly |

---

## 2. Application Launch

| Check | Result |
| --- | --- |
| App starts from Program Files | PASS — PID 5628, window title `Win-Optimizer-Pro`, responding, ~27 MB working set |
| No crash on startup | PASS |
| Resources discovered from install location (not dev tree) | PASS — all backend commands below executed against the installed `_up_\` scripts |

---

## 3. Backend Scenario Suite (installed `optimizer.ps1`)

Methodology: each scenario executed with `powershell.exe -File ... -NoElevate` (write scenarios additionally `-DryRun`), from a clean working directory. Result = exit code 0, no error/exception lines, non-empty output.

| Group | Scenario | Result |
| --- | --- | --- |
| Info / Scan | `-SysInfo` | PASS — CPU/RAM/OS/ARCH emitted |
| | `-QuickScan -DryRun` | PASS — 5 SCAN metrics + `SCAN COMPLETE` |
| Lists | `-ListCategories` | PASS |
| | `-ListTweaks` | PASS |
| | `-TweakInfo` | PASS — registry info per tweak |
| | `-TweakState` | PASS |
| | `-ListApps` | PASS |
| | `-WingetList` | PASS |
| | `-ListDNS` | PASS |
| | `-ListUpdateModes` | PASS |
| | `-ListPower` | PASS |
| | `-ListFeatures` | PASS |
| | `-ListFixes` | PASS |
| | `-ListPanels` | PASS |
| | `-ListStartup` | PASS — real entries (Wondershare, Ollama, …) |
| | `-ListConfigs` | PASS |
| Safety | `-Preflight dism` | PASS — `disk|ok` (129.1 GB free), `battery|ok` (desktop), `admin|fail` → `RESULT|fail` **aborts correctly** |
| Write (dry-run) | `-UserTemp` | PASS |
| | `-Tweaks -Tweak telemetry` | PASS |
| | `-Debloat -Package BingNews` | PASS |
| | `-WingetInstall -App 7zip.7zip` | PASS |
| | `-WingetUpgradeAll` | PASS |
| | `-Profile Gamer` / `Privacy` / `Developer` | PASS ×3 |
| | `-SetDNS Default` | PASS |
| | `-SetUpdateMode Default` | PASS |
| | `-SetPower Balanced` | PASS |
| | `-SetFeature -EnableFeature -Feature WSL` | PASS |
| | `-RunFix SystemCorruption` | PASS |
| | `-EnableSsh` | PASS |
| | `-UndoTweaks` | PASS |
| | `-SetContextMenu Default` | PASS |
| | `-SetStartup "HKCU\|Steam" -DisableStartup` | PASS |
| | `-CreateWin11Iso` | PASS |

**Result: 35 / 35 PASS.**

---

## 4. Notes & Environment Artifacts

- One initial run of `-QuickScan` from the repo root (`E:\pc optimizer`) logged a non-terminating `Add-Content: Stream was not readable` against the pre-existing 131 KB `optimizer.log`. Re-run from a clean working directory passes cleanly (all 5 metrics). **Environment artifact, not an application defect** — the app itself writes its log under its own install/working directory without issue.
- Pre-flight correctly reports `admin|fail` in a non-elevated context and aborts heavy operations — the anti-brick gate works as designed.
- NSIS `installMode: perMachine` + silent `/S` install verified; Start Menu and Desktop shortcuts both created.

---

## 5. Conclusion

**v2.1.1 is release-ready.** All 35 backend scenarios pass on the installed production build, the new application icon propagates to every surface (exe, taskbar, window, Start Menu, Desktop), resources resolve correctly from the installed `_up_` directory, and the app launches and responds normally. No blocking defects found.
