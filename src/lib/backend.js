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

// Matched case-sensitively against raw fields - see the note in parseBootGuardRow.
const BOOT_GUARD_KINDS = ["REGISTRY", "FOLDER", "TASK", "SERVICE"];

// parseBootGuardRow is exported so the regression tests in backend.test.js can
// exercise it directly; app code should use getBootGuardItems() instead.

// Rows look like:
//   BOOTGUARD|reg|HKCU|loopMIDI|REGISTRY|loopMIDI|"C:\...\loopMIDI.exe"|True|low|20|True|HKCU
// Both the Id (reg|HKCU|<value>) and the Command may contain "|", and Write-Log
// prefixes every line with "[timestamp] ", so this cannot be parsed with a fixed
// regex. Walk from both ends instead: the trailing five fields are always
// enabled|impact|ram|safe|scope and the middle is id|kind|name|command, where
// kind is one of a known small set.
export const parseBootGuardRow = (line) => {
  const at = line.indexOf("BOOTGUARD|");
  if (at === -1) return null;

  const parts = line.slice(at + "BOOTGUARD|".length).replace(/\r$/, "").split("|");
  if (parts.length < 10) return null;

  const scope = parts.pop();
  const safe = parts.pop();
  const ram = parts.pop();
  const impact = parts.pop();
  const enabled = parts.pop();

  const asBool = (v) => String(v).trim().toLowerCase() === "true";
  const asImpact = String(impact).trim().toLowerCase();
  if (!asBool(enabled) && !/^false$/i.test(String(enabled).trim())) return null;
  if (!/^(high|medium|low)$/.test(asImpact)) return null;
  if (!/^\d+$/.test(String(ram).trim())) return null;

  // What is left is <id>|<kind>|<name>|<command>. Both the Id ("reg|HKCU|<value>")
  // and the Command can contain "|", so neither can be read as a single field.
  // Locate the Kind token instead and take everything around it: the Id is all
  // fields before it, the Name is the one right after it, and the Command is
  // everything from two after it onwards (rejoined, so its pipes survive).
  //
  // The match must stay case-SENSITIVE. Task Ids begin with the literal prefix
  // "task", which would otherwise collide with the TASK kind and swallow the
  // task path into the Id. The engine always writes the kind upper-cased.
  const kindIndex = parts.findIndex((p) => BOOT_GUARD_KINDS.includes(p));
  if (kindIndex < 1) return null;

  const kind = parts[kindIndex];
  const id = parts.slice(0, kindIndex).join("|").trim();
  const name = (parts[kindIndex + 1] ?? "").trim();
  const command = parts.slice(kindIndex + 2).join("|").trim();
  if (!id || !name) return null;

  return {
    id,
    kind,
    name,
    command,
    enabled: asBool(enabled),
    impact: asImpact,
    ram: Number(ram),
    safe: asBool(safe),
    scope: scope.trim(),
  };
};

export const getBootGuardItems = async () => {
  const raw = await invoke("get_boot_guard_items");
  return raw.split("\n").map(parseBootGuardRow).filter(Boolean);
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
