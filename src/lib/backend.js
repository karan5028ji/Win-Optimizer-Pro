import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

export const isElevated = () => invoke("is_elevated");

export const runOptimizer = (seq, args) => invoke("run_optimizer", { seq, args });

export const stopOptimizer = () => invoke("stop_optimizer");

export const relaunchElevated = () => invoke("relaunch_elevated");

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

export const getTweakState = async () => {
  const raw = await invoke("get_tweak_state");
  const map = {};
  for (const line of raw.split("\n")) {
    const m = line.match(/STATE\|([a-z]+)\|(true|false)/i);
    if (m) map[m[1]] = m[2].toLowerCase() === "true";
  }
  return map;
};

export const onLog = (cb) => listen("optimizer:log", (e) => cb(String(e.payload)));

export const onDone = (cb) => listen("optimizer:done", (e) => cb(e.payload));

// --- WinUtil-style features ---
export const getWingetApps = async () => {
  const raw = await invoke("get_winget_apps");
  return raw
    .split("\n")
    .map((line) => {
      const m = line.match(/WAPP\|([^|]+)\|([^|]+)\|([^|]+)\|(true|false)/i);
      return m
        ? {
            category: m[1],
            id: m[2],
            name: m[3],
            installed: m[4].toLowerCase() === "true",
          }
        : null;
    })
    .filter(Boolean);
};

export const getDnsPresets = async () => {
  const raw = await invoke("get_dns_presets");
  return raw
    .split("\n")
    .map((line) => {
      const m = line.match(/DNS\|([^|]+)\|(.+)/);
      return m ? { id: m[1], label: m[2].trim() } : null;
    })
    .filter(Boolean);
};

export const getUpdateModes = async () => {
  const raw = await invoke("get_update_modes");
  return raw
    .split("\n")
    .map((line) => {
      const m = line.match(/UPDMODE\|([^|]+)\|(.+)/);
      return m ? { id: m[1], label: m[2].trim() } : null;
    })
    .filter(Boolean);
};

export const getPowerPlans = async () => {
  const raw = await invoke("get_power_plans");
  return raw
    .split("\n")
    .map((line) => {
      const m = line.match(/POWER\|([^|]+)\|([^|]+)\|(active|inactive)/i);
      return m ? { guid: m[1], name: m[2], active: m[3].toLowerCase() === "active" } : null;
    })
    .filter(Boolean);
};

export const getWinFeatures = async () => {
  const raw = await invoke("get_win_features");
  return raw
    .split("\n")
    .map((line) => {
      const m = line.match(/FEAT\|([^|]+)\|([^|]+)\|(true|false|unknown)/i);
      return m
        ? {
            id: m[1],
            label: m[2],
            enabled: m[3].toLowerCase() === "true" ? true : m[3].toLowerCase() === "false" ? false : null,
          }
        : null;
    })
    .filter(Boolean);
};

export const getFixes = async () => {
  const raw = await invoke("get_fixes");
  return raw
    .split("\n")
    .map((line) => {
      const m = line.match(/FIX\|([^|]+)\|(.+)/);
      return m ? { id: m[1], label: m[2].trim() } : null;
    })
    .filter(Boolean);
};

export const getLegacyPanels = async () => {
  const raw = await invoke("get_legacy_panels");
  return raw
    .split("\n")
    .map((line) => {
      const m = line.match(/PANEL\|([^|]+)\|(.+)/);
      return m ? { id: m[1], label: m[2].trim() } : null;
    })
    .filter(Boolean);
};

// --- Safety / Profiles / Profiles-json / Startup ---
export const getPreflight = async (action) => {
  const raw = await invoke("get_preflight", { action });
  const checks = [];
  for (const line of raw.split("\n")) {
    const m = line.match(/PRE\|([^|]+)\|(ok|fail)\|(.+)/);
    if (m) checks.push({ check: m[1], ok: m[2] === "ok", detail: m[3].trim() });
  }
  const result = raw.includes("PRE|RESULT|ok");
  return { checks, result };
};

export const getStartupItems = async () => {
  const raw = await invoke("get_startup_items");
  return raw
    .split("\n")
    .map((line) => {
      const m = line.match(/STARTUP\|([^|]+)\|([^|]+)\|(.+?)\|(true|false)/);
      if (!m) return null;
      const scope = m[1];
      const name = m[2];
      const command = m[3].trim();
      const isFile = scope === "USERFOLDER" || scope === "MACHINEFOLDER";
      return {
        scope,
        name,
        command,
        enabled: m[4].toLowerCase() === "true",
        id: isFile ? `${scope}|${command}` : `${scope}|${name}`,
      };
    })
    .filter(Boolean);
};

export const getContextMenuState = async () => {
  const raw = await invoke("get_context_menu");
  const line = raw.split("\n").find((l) => l.startsWith("CTXMENU|classic|"));
  return line ? /true$/i.test(line.trim()) : false;
};

export const getConfigs = async () => {
  const raw = await invoke("get_configs");
  return raw
    .split("\n")
    .map((line) => {
      const m = line.match(/CONFIG\|([^|]+)\|([^|]+)\|(.+)/);
      return m ? { name: m[1], path: m[2], modified: m[3].trim() } : null;
    })
    .filter(Boolean);
};

export const getTweakRegistryInfo = async () => {
  const raw = await invoke("get_tweak_registry_info");
  const map = {};
  for (const line of raw.split("\n")) {
    const m = line.match(/TWEAKINFO\|([^|]+)\|(.+)/);
    if (m) map[m[1]] = m[2].trim();
  }
  return map;
};
