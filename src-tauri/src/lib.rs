use std::io::{BufRead, BufReader, Read};
use std::os::windows::io::AsRawHandle;
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStderr, ChildStdout, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use tauri::path::BaseDirectory;
use tauri::{AppHandle, Emitter, Manager, State};
use windows_sys::Win32::Foundation::{CloseHandle, HANDLE};
use windows_sys::Win32::System::JobObjects::{
    AssignProcessToJobObject, CreateJobObjectW, JobObjectExtendedLimitInformation,
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
    SetInformationJobObject,
};
use windows_sys::Win32::UI::Shell::{IsUserAnAdmin, ShellExecuteW};

/// A kill-on-close Windows job handle. Closing the handle terminates every
/// process in the job - including grandchildren that reparented out of the
/// direct tree (winget's msiexec installers, detached processes), which
/// `taskkill /T` alone can miss.
///
/// HANDLE is a raw pointer (not Send/Sync), so we wrap it. The value is only
/// ever closed from the owning thread; the unsafe impl is safe because the
/// handle is never shared mutably across threads and Drop is idempotent.
struct JobHandle(HANDLE);

unsafe impl Send for JobHandle {}
unsafe impl Sync for JobHandle {}

impl Drop for JobHandle {
    fn drop(&mut self) {
        unsafe {
            CloseHandle(self.0);
        }
    }
}

/// A spawned PowerShell run plus its kill-on-close job.
struct Managed {
    child: Option<Child>,
    job: Option<JobHandle>,
}

impl Managed {
    fn kill(&mut self) {
        // Closing the job handle terminates the whole tree. Fall back to
        // taskkill /T /F for the direct child when the job is absent
        // (creation/assignment failed, e.g. the parent already put the app in
        // a job that blocks nesting).
        self.job = None;
        if let Some(c) = self.child.as_mut() {
            kill_tree(c);
        }
    }

    /// Called when a run completes naturally. The job handle is deliberately
    /// leaked so processes the engine launched with Start-Process (control
    /// panels, the new Explorer, installers that should outlive the run) are
    /// allowed to keep running; closing it would kill them.
    fn detach_job(&mut self) {
        if let Some(job) = self.job.take() {
            std::mem::forget(job);
        }
    }
}

impl Drop for Managed {
    fn drop(&mut self) {
        // Close the job if it is still present; KILL_ON_JOB_CLOSE reaps any
        // process still inside it. On natural completion detach_job() already
        // leaked the handle, so this is a no-op. Crucially we must NOT run
        // taskkill here: the direct child has already exited and killing the
        // tree at this point would race the parent's buffered stdout flush
        // (dropping output) and reap Start-Process children that are meant to
        // outlive the run.
        self.job = None;
    }
}

struct Runner {
    child: Arc<Mutex<Option<Managed>>>,
}

impl Runner {
    fn new() -> Self {
        Self {
            child: Arc::new(Mutex::new(None)),
        }
    }
    fn store(&self, managed: Managed) {
        *self.child.lock().unwrap() = Some(managed);
    }
    fn stop(&self) {
        // Take the Managed out first; the temporary mutex guard is dropped at
        // the end of this statement so kill() (taskkill fallback, up to 5s)
        // never runs while holding the lock.
        let mut managed = self.child.lock().unwrap().take();
        if let Some(m) = managed.as_mut() {
            m.kill();
        }
    }
    fn child_handle(&self) -> Arc<Mutex<Option<Managed>>> {
        Arc::clone(&self.child)
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
    if std::env::var("WIN_OPT_DEBUG").is_err() {
        return;
    }
    if let Some(dir) = std::env::var_os("TEMP") {
        use std::io::Write;
        let path = Path::new(&dir).join("winopt_resolve.log");
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

fn spawn_powershell(script: &Path, args: &[String]) -> Result<Managed, String> {
    use std::os::windows::process::CommandExt;
    const CREATE_NO_WINDOW: u32 = 0x0800_0000;
    let child = Command::new("powershell.exe")
        .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"])
        .arg(script)
        .args(args)
        .creation_flags(CREATE_NO_WINDOW)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| e.to_string())?;

    // Put the process in a kill-on-close job. On Windows 8+ every descendant
    // (winget, DISM, msiexec, detached installers) is auto-assigned to the job,
    // so closing the job on Stop reaps the whole tree even if it reparented.
    let mut job: HANDLE = std::ptr::null_mut();
    unsafe {
        let created = CreateJobObjectW(std::ptr::null(), std::ptr::null());
        if !created.is_null() {
            let mut info: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = std::mem::zeroed();
            info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
            let ok = SetInformationJobObject(
                created,
                JobObjectExtendedLimitInformation,
                &info as *const _ as *const core::ffi::c_void,
                std::mem::size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
            ) != 0;
            let assigned =
                ok && AssignProcessToJobObject(created, child.as_raw_handle() as HANDLE) != 0;
            if assigned {
                job = created;
            } else {
                CloseHandle(created);
            }
        }
    }
    let job = if job.is_null() { None } else { Some(JobHandle(job)) };

    Ok(Managed {
        child: Some(child),
        job,
    })
}

/// Run a quick ps1 command and return its combined stdout.
/// Reads output on a side thread and hard-kills the process tree on timeout so
/// the UI can never hang on a stuck PowerShell child.
fn run_capture(app: &AppHandle, extra: &[&str], timeout: Duration) -> Result<String, String> {
    let script = resolve_script(app).ok_or_else(|| "optimizer.ps1 not found".to_string())?;
    let mut args: Vec<String> = vec!["-NoElevate".into()];
    args.extend(extra.iter().map(|s| s.to_string()));
    let mut managed = spawn_powershell(&script, &args)?;
    let child = managed.child.as_mut().ok_or("managed run has no child")?;
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
        let exited = managed
            .child
            .as_mut()
            .map(|c| c.try_wait())
            .transpose()
            .map_err(|e| e.to_string())?
            .is_some();
        if exited {
            break;
        }
        if Instant::now() >= deadline {
            managed.kill();
            return Err(format!(
                "Command timed out after {}s",
                timeout.as_secs()
            ));
        }
        thread::sleep(Duration::from_millis(100));
    }

    // Drain buffered output with the same grace period as supervise_run. A
    // grandchild that inherits the stdout pipe keeps it open past EOF; without
    // this fallback reader.join() would block forever and the invoke would
    // never resolve.
    let drain_deadline = Instant::now() + DRAIN_GRACE;
    loop {
        if reader.is_finished() {
            return Ok(reader.join().unwrap_or_default());
        }
        if Instant::now() >= drain_deadline {
            managed.kill();
            return Err(format!(
                "Command output drain timed out after {}s",
                DRAIN_GRACE.as_secs()
            ));
        }
        thread::sleep(Duration::from_millis(50));
    }
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
async fn get_context_menu(app: AppHandle) -> Result<String, String> {
    tauri::async_runtime::spawn_blocking(move || {
        run_capture(&app, &["-ContextMenuState"], Duration::from_secs(30))
    })
    .await
    .map_err(|e| e.to_string())?
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

/// Emitted when a run finishes. Payload = the run sequence id (u32), supplied
/// by the frontend so it can tell a real completion from a stale event that
/// raced in after a Stop + immediate re-run.
const DONE_EVENT: &str = "optimizer:done";

/// How long readers may take to drain buffered output after the process exits
/// before we force-kill the tree. A grandchild that inherits the stdout pipe
/// keeps the pipe open past EOF; without this fallback `optimizer:done` would
/// never fire and the UI would stay stuck in "running" with every button dead.
const DRAIN_GRACE: Duration = Duration::from_secs(5);

/// Watches a child process and its stdout/stderr reader threads, then always
/// reports completion. Guarantees `optimizer:done` fires even when a grandchild
/// inherited the stdout pipe and keeps it open after the parent has exited.
fn supervise_run<L>(
    stdout: Option<ChildStdout>,
    stderr: Option<ChildStderr>,
    child: Arc<Mutex<Option<Managed>>>,
    seq: u32,
    emit_log: L,
    emit_done: impl FnOnce(u32),
) where
    L: Fn(String) + Clone + Send + Sync + 'static,
{
    let mut threads = Vec::new();
    if let Some(out) = stdout {
        let e = emit_log.clone();
        threads.push(thread::spawn(move || {
            for line in BufReader::new(out).lines().map_while(Result::ok) {
                e(line);
            }
        }));
    }
    if let Some(err) = stderr {
        let e = emit_log;
        threads.push(thread::spawn(move || {
            for line in BufReader::new(err).lines().map_while(Result::ok) {
                e(format!("[stderr] {line}"));
            }
        }));
    }

    // Wait for the child process to exit, reaping it from state when done.
    // Polling (instead of a blocking wait) keeps this decoupled from Stop.
    loop {
        let (exited, reaped) = {
            let mut guard = child.lock().unwrap();
            let child_exited = guard
                .as_mut()
                .and_then(|m| m.child.as_mut())
                .map(|c| c.try_wait())
                .transpose()
                .ok()
                .flatten()
                .is_some();
            let missing = guard
                .as_ref()
                .map(|m| m.child.is_none())
                .unwrap_or(true);
            let done = child_exited || missing;
            if done {
                // Natural exit: detach the job so Start-Process panels and
                // installers that should outlive the run are not killed when
                // the Managed is dropped below.
                if let Some(m) = guard.as_mut() {
                    m.detach_job();
                }
                (true, guard.take())
            } else {
                (false, None)
            }
        };
        if exited {
            // Drop the reaped Managed outside the lock: its Drop runs the
            // taskkill fallback, which must never hold the shared mutex (it
            // would block Stop for up to its 5s wait).
            drop(reaped);
            break;
        }
        thread::sleep(Duration::from_millis(100));
    }

    // Drain buffered output with a grace period. If a grandchild is still
    // holding the pipe, force-kill the whole tree to unblock the readers.
    let deadline = Instant::now() + DRAIN_GRACE;
    let drained = loop {
        if threads.iter().all(|t| t.is_finished()) {
            break true;
        }
        if Instant::now() >= deadline {
            let mut m = child.lock().unwrap().take();
            if let Some(m) = m.as_mut() {
                m.kill();
            }
            break false;
        }
        thread::sleep(Duration::from_millis(50));
    };

    // NEVER block on thread.join() here: a grandchild that inherited the pipe
    // can keep a reader thread alive indefinitely, and if we block we never
    // emit done - leaving the UI stuck in "running" with Stop a no-op. We only
    // join readers that already finished.
    if drained {
        for t in threads {
            let _ = t.join();
        }
    }

    // Always emit done so the UI can never stay stuck in "running".
    emit_done(seq);
}

#[tauri::command]
fn run_optimizer(
    app: AppHandle,
    state: State<'_, Runner>,
    seq: u32,
    args: Vec<String>,
) -> Result<(), String> {
    let script = resolve_script(&app).ok_or_else(|| "optimizer.ps1 not found".to_string())?;
    let mut managed = spawn_powershell(&script, &args)?;
    let stdout = managed.child.as_mut().unwrap().stdout.take();
    let stderr = managed.child.as_mut().unwrap().stderr.take();
    state.store(managed);

    let handle = app.clone();
    let child_handle = state.child_handle();
    thread::spawn(move || {
        let emit = handle.clone();
        supervise_run(
            stdout,
            stderr,
            child_handle,
            seq,
            move |line| {
                let _ = emit.emit("optimizer:log", line);
            },
            move |s| {
                let _ = handle.emit(DONE_EVENT, s);
            },
        );
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
    tauri::Builder::default()
        .manage(Runner::new())
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
            get_context_menu,
            get_configs,
            get_tweak_registry_info,
            run_optimizer,
            stop_optimizer,
            relaunch_elevated
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Regression test for the reported bug where the app appeared frozen
    /// ("status bar not moving / buttons not working"). If a grandchild
    /// inherits the stdout pipe and keeps it open after the parent exits, the
    /// old reader logic blocked on EOF forever and `optimizer:done` never
    /// fired — leaving the UI stuck in "running" with every button disabled.
    #[test]
    fn done_fires_even_when_grandchild_holds_stdout_pipe() {
        // powershell exits instantly, but `start /b` launches a grandchild that
        // inherits the stdout pipe and holds it open for 20s.
        let mut child = Command::new("powershell.exe")
            .args([
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-Command",
                "Write-Output 'parent output'; cmd /c \"start /b powershell -NoProfile -Command Start-Sleep -Seconds 20 & exit\"; exit",
            ])
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .expect("spawn powershell");
        let stdout = child.stdout.take();
        let stderr = child.stderr.take();
        let shared = Arc::new(Mutex::new(Some(Managed {
            child: Some(child),
            job: None,
        })));

        let logs = Arc::new(Mutex::new(Vec::<String>::new()));
        let done = Arc::new(Mutex::new(false));
        let (l, d) = (Arc::clone(&logs), Arc::clone(&done));
        let seq = 7u32;
        let supervisor = thread::spawn(move || {
            supervise_run(
                stdout,
                stderr,
                shared,
                seq,
                move |line| l.lock().unwrap().push(line),
                move |s| *d.lock().unwrap() = s == seq,
            );
        });

        // done must fire well before the 20s grandchild finishes (grace kill).
        let deadline = Instant::now() + Duration::from_secs(12);
        while Instant::now() < deadline {
            if *done.lock().unwrap() {
                break;
            }
            thread::sleep(Duration::from_millis(100));
        }
        let fired = *done.lock().unwrap();
        let _ = supervisor.join();

        assert!(fired, "optimizer:done must fire despite a grandchild holding the stdout pipe");
        // The stdout reader thread is detached (not joined by supervise_run, since
        // the grandchild keeps the pipe open). On a busy CI runner it may not get
        // scheduled the instant `done` fires, so poll instead of asserting once.
        let deadline = Instant::now() + Duration::from_secs(10);
        let captured = loop {
            if !logs.lock().unwrap().is_empty() {
                break true;
            }
            if Instant::now() >= deadline {
                break false;
            }
            thread::sleep(Duration::from_millis(100));
        };
        assert!(captured, "parent output should still be captured");
    }
}
