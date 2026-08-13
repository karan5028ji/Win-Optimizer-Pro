# Contributing to Win-Optimizer-Pro

Thanks for wanting to help! This guide explains how the project is structured,
how to run it locally, and how to get changes merged.

## Project layout

```
├── optimizer.ps1        # Main engine (cleanup, tweaks, debloat, WinGet)
├── engine.ps1           # Core helper functions shared across operations
├── winutil.ps1          # WinUtil-style toolkit (profiles, tweak registry)
├── run.ps1              # One-line launcher (downloads latest release)
├── src/                 # React frontend
│   └── lib/backend.js   # IPC bridge to the Rust backend
└── src-tauri/
    ├── src/lib.rs       # Rust backend: process supervision, job objects
    └── tauri.conf.json  # App config (bundle targets, resources, CSP)
```

## Prerequisites

- Node.js 18+
- Rust stable (MSVC toolchain)
- Windows 10 / 11 (this is a Windows-only app)
- WebView2 (bundled with Windows 11 / modern Windows 10)

## Running locally

```powershell
npm install
npm run tauri dev
```

## Building a release

```powershell
npm run tauri build
```

Output lands in `src-tauri\target\release\bundle\nsis\`.

## Testing

The Rust backend has an integration test suite that spawns real PowerShell
processes and verifies process supervision / output capture:

```powershell
cd src-tauri
cargo test
```

Always run `cargo test` before opening a PR. The CI pipeline runs the same
checks (see `.github/workflows/ci.yml`).

## Commit conventions

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — new feature or behavior
- `fix:` — bug fix
- `docs:` — documentation only
- `chore:` — tooling, versions, no behavior change
- `refactor:` — code change with no behavior change

Examples: `fix: no taskkill on natural completion`, `docs: update install links`.

## Making a PR

1. Fork the repo and create a branch off `main`.
2. Make focused, small changes — one logical change per commit.
3. Run `cargo test` and `npm run build` locally and confirm they pass.
4. Open a pull request using the template. Describe **what** changed and **why**.
5. Keep public-facing text (PRs, issues, docs) in **English**.

## Good first issues

Look for issues labeled `good first issue` — small, self-contained changes
suitable for a first contribution. Ask questions in the issue before starting if
anything is unclear.

## Code of conduct

All contributors are expected to follow our
[Code of Conduct](CODE_OF_CONDUCT.md). Be kind, be respectful, be constructive.
