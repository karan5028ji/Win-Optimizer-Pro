use std::io::{BufRead, BufReader, Read};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use std::thread;
use std::time::{Duration, Instant};

use tauri::path::BaseDirectory;
use tauri::{AppHandle, Emitter, Manager, State};
use windows_sys::Win32::UI::Shell::{IsUserAnAdmin, ShellExecuteW};

struct Runner(Mutex<Option<Child>>);

impl Runner {
    fn store(&self, child: Child) {
        *self.0.lock().unwrap() = Some(child);
    }
    fn stop(&self) {
        if let Some(mut child) = self.0.lock().unwrap().take() {
            kill_tree(&mut child);
        }
    }
}

#[derive(Default)]
struct CacheInner {
    sys_info: Option<(Instant, String)>,
    bloat_apps: Option<(Instant, String)>,
    tweak_state: Option<(Instant, String)>,
    winget_apps: Option<(Instant, String)>,
    dns_presets: Option<(Instant, String)>,
    update_modes: Option<(Instant, String)>,
    power_plans: Option<(Instant, String)>,
    win_features: Option<(Instant, String)>,
    fixes: Option<(Instant, String)>,
    legacy_panels: Option<(Instant, String)>,
    startup_items: Option<(Instant, String)>,
    configs: Option<(Instant, String)>,
    tweak_registry_info: Option<(Instant, String)>,
}

#[derive(Default)]
struct AppCache(Mutex<CacheInner>);

impl AppCache {
    fn get(&self, field: &str) -> Option<String> {
        let guard = self.0.lock().unwrap();
        let entry = match field {
            "sys_info" => &guard.sys_info,
            "bloat_apps" => &guard.bloat_apps,
            "tweak_state" => &guard.tweak_state,
            "winget_apps" => &guard.winget_apps,
            "dns_presets" => &guard.dns_presets,
            "update_modes" => &guard.update_modes,
            "power_plans" => &guard.power_plans,
            "win_features" => &guard.win_features,
            "fixes" => &guard.fixes,
            "legacy_panels" => &guard.legacy_panels,
            "startup_items" => &guard.startup_items,
            "configs" => &guard.configs,
            "tweak_registry_info" => &guard.tweak_registry_info,
            _ => return None,
        };
        entry.as_ref().map(|(_, s)| s.clone())
    }
    fn put(&self, field: &str, value: String) {
        let mut guard = self.0.lock().unwrap();
        let entry = match field {
            "sys_info" => &mut guard.sys_info,
            "bloat_apps" => &mut guard.bloat_apps,
            "tweak_state" => &mut guard.tweak_state,
            "winget_apps" => &mut guard.winget_apps,
            "dns_presets" => &mut guard.dns_presets,
            "update_modes" => &mut guard.update_modes,
            "power_plans" => &mut guard.power_plans,
            "win_features" => &mut guard.win_features,
            "fixes" => &mut guard.fixes,
            "legacy_panels" => &mut guard.legacy_panels,
            "startup_items" => &mut guard.startup_items,
            "configs" => &mut guard.configs,
            "tweak_registry_info" => &mut guard.tweak_registry_info,
            _ => return,
        };
        *entry = Some((Instant::now(), value));
    }
    fn fresh(&self, field: &str, ttl: Duration) -> bool {
        let guard = self.0.lock().unwrap();
        let entry = match field {
            "sys_info" => &guard.sys_info,
            "bloat_apps" => &guard.bloat_apps,
            "tweak_state" => &guard.tweak_state,
            "winget_apps" => &guard.winget_apps,
            "dns_presets" => &guard.dns_presets,
            "update_modes" => &guard.update_modes,
            "power_plans" => &guard.power_plans,
            "win_features" => &guard.win_features,
            "fixes" => &guard.fixes,
            "legacy_panels" => &guard.legacy_panels,
            "startup_items" => &guard.startup_items,
            "configs" => &guard.configs,
            "tweak_registry_info" => &guard.tweak_registry_info,
            _ => return false,
        };
        matches!(entry, Some((t, _)) if t.elapsed() < ttl)
    }
}

fn kill_tree(child: &mut Child) {
    use std::io::Write;
    use std::os::windows::process::CommandExt;
    const CREATE_NO_WINDOW: u32 = 0x0800_0000;
    let pid = child.id();

    // taskkill /T /F must be allowed to finish so the entire process tree
    // (powershell + any winget/DISM grandchildren) is gone before we return.
    // Fire-and-forget here left orphaned children running after Stop.
    if let Ok(mut tk) = Command::new("taskkill.exe")
        .args(["/PID", &pid.to_string(), "/T", "/F"])
        .creation_flags(CREATE_NO_WINDOW)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
    {
        // Give taskkill up to ~5s, then force-stop the direct child too.
        for _ in 0..50 {
            if let Ok(Some(_)) = tk.try_wait() {
                break;
            }
            thread::sleep(Duration::from_millis(100));
        }
        let _ = tk.kill();
    }
    // Direct handle kill as a final safety net (also drains any buffered I/O).
    let _ = child.kill();
    let _ = child.wait();
    let _ = std::io::stderr().flush();
}

fn wide(s: &str) -> Vec<u16> {
    s.encode_utf16().chain(std::iter::once(0)).collect()
}

fn debug_log(msg: &str) {
    if std::env::var("PC_OPT_DEBUG").is_err() {
        return;
    }
    if let Some(dir) = std::env::var_os("TEMP") {
        use std::io::Write;
        let path = Path::new(&dir).join("pcopt_resolve.log");
        if let Ok(mut f) = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(path)
        {
            let _ = writeln!(f, "{msg}");
        }
    }
}

fn strip_verbatim(p: PathBuf) -> PathBuf {
    let s = p.to_string_lossy();
    if s.starts_with("\\\\?\\UNC\\") {
        PathBuf::from(format!("\\\\{}", &s[8..]))
    } else if s.starts_with("\\\\?\\") {
        PathBuf::from(&s[4..])
    } else {
        p
    }
}

/// Locate optimizer.ps1 via Tauri's resource mapping (installed app), next to
/// the exe, in the resource dir, or relative to the src-tauri directory (dev mode).
fn resolve_script(app: &AppHandle) -> Option<PathBuf> {
    let mut candidates: Vec<PathBuf> = Vec::new();
    if let Ok(p) = app
        .path()
        .resolve("../optimizer.ps1", BaseDirectory::Resource)
    {
        candidates.push(p);
    }
    if let Ok(dir) = app.path().resource_dir() {
        candidates.push(dir.join("optimizer.ps1"));
        candidates.push(dir.join("_up_/optimizer.ps1"));
    }
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            candidates.push(dir.join("optimizer.ps1"));
            candidates.push(dir.join("_up_/optimizer.ps1"));
        }
    }
    if let Ok(manifest) = std::env::var("CARGO_MANIFEST_DIR") {
        let base = PathBuf::from(manifest);
        candidates.push(base.join("../optimizer.ps1"));
        candidates.push(base.join("optimizer.ps1"));
    }
    candidates.push(PathBuf::from("optimizer.ps1"));
    let found = candidates.iter().find(|p| p.is_file()).cloned().map(strip_verbatim);
    if let Some(p) = &found {
        debug_log(&format!("resolve_script -> {}", p.display()));
    } else {
        debug_log("resolve_script -> NOT FOUND");
    }
    found
}

fn spawn_powershell(script: &Path, args: &[String]) -> Result<Child, String> {
    use std::os::windows::process::CommandExt;
    const CREATE_NO_WINDOW: u32 = 0x0800_0000;
    Command::new("powershell.exe")
        .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"])
        .arg(script)
        .args(args)
        .creation_flags(CREATE_NO_WINDOW)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| e.to_string())
}

/// Run a quick ps1 command and return its combined stdout.
/// Reads output on a side thread and hard-kills the process tree on timeout so
/// the UI can never hang on a stuck PowerShell child.
fn run_capture(app: &AppHandle, extra: &[&str], timeout: Duration) -> Result<String, String> {
    let script = resolve_script(app).ok_or_else(|| "optimizer.ps1 not found".to_string())?;
    let mut args: Vec<String> = vec!["-NoElevate".into()];
    args.extend(extra.iter().map(|s| s.to_string()));
    let mut child = spawn_powershell(&script, &args)?;
    let stdout = child.stdout.take();
    let stderr = child.stderr.take();

    let reader = thread::spawn(move || {
        let mut text = String::new();
        if let Some(mut o) = stdout {
            let mut buf = Vec::new();
            let _ = o.read_to_end(&mut buf);
            text.push_str(&String::from_utf8_lossy(&buf));
        }
        if let Some(mut e) = stderr {
            let mut buf = Vec::new();
            let _ = e.read_to_end(&mut buf);
            text.push_str(&String::from_utf8_lossy(&buf));
        }
        text
    });

    let deadline = Instant::now() + timeout;
    loop {
        match child.try_wait() {
            Ok(Some(_)) => break,
            Ok(None) => {
                if Instant::now() >= deadline {
                    kill_tree(&mut child);
                    return Err(format!(
                        "Command timed out after {}s",
                        timeout.as_secs()
                    ));
                }
                thread::sleep(Duration::from_millis(100));
            }
            Err(e) => return Err(e.to_string()),
        }
    }
    Ok(reader.join().unwrap_or_default())
}

/// Cached, async wrapper so no capture ever blocks the Tauri main thread.
async fn cached_capture(
    app: AppHandle,
    cache: State<'_, AppCache>,
    field: &'static str,
    extra: &'static [&'static str],
    ttl: Duration,
    timeout: Duration,
) -> Result<String, String> {
    if cache.fresh(field, ttl) {
        if let Some(v) = cache.get(field) {
            return Ok(v);
        }
    }
    let result = tauri::async_runtime::spawn_blocking(move || run_capture(&app, extra, timeout))
        .await
        .map_err(|e| e.to_string())??;
    cache.put(field, result.clone());
    Ok(result)
}

#[tauri::command]
fn is_elevated() -> bool {
    unsafe { IsUserAnAdmin() != 0 }
}

#[tauri::command]
async fn get_system_info(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "sys_info",
        &["-SysInfo"],
        Duration::from_secs(10),
        Duration::from_secs(30),
    )
    .await
}

#[tauri::command]
async fn get_bloat_apps(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "bloat_apps",
        &["-ListApps"],
        Duration::from_secs(60),
        Duration::from_secs(120),
    )
    .await
}

#[tauri::command]
async fn get_tweak_state(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "tweak_state",
        &["-TweakState"],
        Duration::from_secs(5),
        Duration::from_secs(30),
    )
    .await
}

#[tauri::command]
async fn get_winget_apps(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "winget_apps",
        &["-WingetList"],
        Duration::from_secs(60),
        Duration::from_secs(180),
    )
    .await
}

#[tauri::command]
async fn get_dns_presets(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "dns_presets",
        &["-ListDNS"],
        Duration::from_secs(60),
        Duration::from_secs(30),
    )
    .await
}

#[tauri::command]
async fn get_update_modes(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "update_modes",
        &["-ListUpdateModes"],
        Duration::from_secs(60),
        Duration::from_secs(30),
    )
    .await
}

#[tauri::command]
async fn get_power_plans(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "power_plans",
        &["-ListPower"],
        Duration::from_secs(60),
        Duration::from_secs(30),
    )
    .await
}

#[tauri::command]
async fn get_win_features(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "win_features",
        &["-ListFeatures"],
        Duration::from_secs(60),
        Duration::from_secs(120),
    )
    .await
}

#[tauri::command]
async fn get_fixes(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "fixes",
        &["-ListFixes"],
        Duration::from_secs(3600),
        Duration::from_secs(30),
    )
    .await
}

#[tauri::command]
async fn get_legacy_panels(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "legacy_panels",
        &["-ListPanels"],
        Duration::from_secs(3600),
        Duration::from_secs(30),
    )
    .await
}

/// Non-cached capture for checks that must be fresh every time.

#[tauri::command]
async fn get_preflight(
    app: AppHandle,
    action: String,
) -> Result<String, String> {
    let action = if action.is_empty() { "dism".to_string() } else { action };
    let extra: Vec<String> = vec!["-Preflight".into(), action];
    tauri::async_runtime::spawn_blocking(move || {
        run_capture(&app, &extra.iter().map(|s| s.as_str()).collect::<Vec<_>>(), Duration::from_secs(60))
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
async fn get_startup_items(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "startup_items",
        &["-ListStartup"],
        Duration::from_secs(15),
        Duration::from_secs(30),
    )
    .await
}

#[tauri::command]
async fn get_configs(app: AppHandle, cache: State<'_, AppCache>) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "configs",
        &["-ListConfigs"],
        Duration::from_secs(30),
        Duration::from_secs(30),
    )
    .await
}

#[tauri::command]
async fn get_tweak_registry_info(
    app: AppHandle,
    cache: State<'_, AppCache>,
) -> Result<String, String> {
    cached_capture(
        app,
        cache,
        "tweak_registry_info",
        &["-TweakInfo"],
        Duration::from_secs(3600),
        Duration::from_secs(30),
    )
    .await
}

#[tauri::command]
fn run_optimizer(
    app: AppHandle,
    state: State<'_, Runner>,
    args: Vec<String>,
) -> Result<(), String> {
    let script = resolve_script(&app).ok_or_else(|| "optimizer.ps1 not found".to_string())?;
    let mut child = spawn_powershell(&script, &args)?;
    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    state.store(child);

    let handle = app.clone();
    thread::spawn(move || {
        let mut threads = Vec::new();
        if let Some(out) = stdout {
            let h = handle.clone();
            threads.push(thread::spawn(move || {
                for line in BufReader::new(out).lines().map_while(Result::ok) {
                    let _ = h.emit("optimizer:log", line);
                }
            }));
        }
        if let Some(err) = stderr {
            let h = handle.clone();
            threads.push(thread::spawn(move || {
                for line in BufReader::new(err).lines().map_while(Result::ok) {
                    let _ = h.emit("optimizer:log", format!("[stderr] {line}"));
                }
            }));
        }
        for t in threads {
            let _ = t.join();
        }
        let _ = handle.emit("optimizer:done", ());
    });
    Ok(())
}

#[tauri::command]
async fn stop_optimizer(state: State<'_, Runner>) -> Result<(), String> {
    state.stop();
    Ok(())
}

#[tauri::command]
fn relaunch_elevated() {
    request_elevation();
    thread::sleep(Duration::from_millis(800));
    std::process::exit(0);
}

fn request_elevation() {
    let Ok(exe) = std::env::current_exe() else {
        return;
    };
    let file = wide(&exe.to_string_lossy());
    let operation = wide("runas");
    unsafe {
        ShellExecuteW(
            std::ptr::null_mut(),
            operation.as_ptr(),
            file.as_ptr(),
            std::ptr::null(),
            std::ptr::null(),
            1,
        );
    }
}

pub fn run() {
    #[cfg(target_os = "windows")]
    {
        if std::env::var("PC_OPT_NO_ELEVATE").is_err() && unsafe { IsUserAnAdmin() } == 0 {
            request_elevation();
            return;
        }
    }

    tauri::Builder::default()
        .manage(Runner(Mutex::new(None)))
        .manage(AppCache::default())
        .invoke_handler(tauri::generate_handler![
            is_elevated,
            get_system_info,
            get_bloat_apps,
            get_tweak_state,
            get_winget_apps,
            get_dns_presets,
            get_update_modes,
            get_power_plans,
            get_win_features,
            get_fixes,
            get_legacy_panels,
            get_preflight,
            get_startup_items,
            get_configs,
            get_tweak_registry_info,
            run_optimizer,
            stop_optimizer,
            relaunch_elevated
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
