import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

export const isElevated = () => invoke("is_elevated");

export const runOptimizer = (args) => invoke("run_optimizer", { args });

export const stopOptimizer = () => invoke("stop_optimizer");

export const getSystemInfo = async () => {
  const raw = await invoke("get_system_info");
  const grab = (key) => {
    const line = raw.split("\n").find((l) => l.includes(`${key}|`));
    return line ? line.split(`${key}|`)[1]?.trim() || "—" : "—";
  };
  return {
    cpu: grab("CPU"),
    ram: grab("RAM"),
    os: grab("OS"),
    arch: grab("ARCH"),
  };
};

export const getBloatApps = async () => {
  const raw = await invoke("get_bloat_apps");
  return raw
    .split("\n")
    .map((line) => {
      const m = line.match(/APP\|([^|]+)\|([^|]+)\|(.+)/);
      return m ? { category: m[1], name: m[2], display: m[3].trim() } : null;
    })
    .filter(Boolean);
};

export const onLog = (cb) => listen("optimizer:log", (e) => cb(String(e.payload)));

export const onDone = (cb) => listen("optimizer:done", () => cb());
