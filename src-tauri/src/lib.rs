use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use std::thread;

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
            let _ = child.kill();
        }
    }
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
fn run_capture(app: &AppHandle, extra: &[&str]) -> Result<String, String> {
    let script = resolve_script(app).ok_or_else(|| "optimizer.ps1 not found".to_string())?;
    let mut args: Vec<String> = vec!["-NoElevate".into()];
    args.extend(extra.iter().map(|s| s.to_string()));
    let output = spawn_powershell(&script, &args)?
        .wait_with_output()
        .map_err(|e| e.to_string())?;
    let mut text = String::from_utf8_lossy(&output.stdout).to_string();
    text.push_str(&String::from_utf8_lossy(&output.stderr));
    Ok(text)
}

#[tauri::command]
fn is_elevated() -> bool {
    unsafe { IsUserAnAdmin() != 0 }
}

#[tauri::command]
fn get_system_info(app: AppHandle) -> Result<String, String> {
    run_capture(&app, &["-SysInfo"])
}

#[tauri::command]
fn get_bloat_apps(app: AppHandle) -> Result<String, String> {
    run_capture(&app, &["-ListApps"])
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
fn stop_optimizer(state: State<'_, Runner>) {
    state.stop();
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
        .invoke_handler(tauri::generate_handler![
            is_elevated,
            get_system_info,
            get_bloat_apps,
            run_optimizer,
            stop_optimizer
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
