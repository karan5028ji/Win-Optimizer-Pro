import { useCallback, useEffect, useState } from "react";
import {
  CheckCircle2,
  Download,
  Gamepad2,
  Lock,
  RefreshCw,
  Save,
  ShieldAlert,
  Terminal,
  Upload,
  XCircle,
} from "lucide-react";
import { useApp } from "../lib/app-context";
import { getConfigs, getDnsPresets, getPowerPlans, getPreflight, getTweakState, getUpdateModes, getWingetApps } from "../lib/backend";

function Card({ icon: Icon, title, desc, children }) {
  return (
    <section className="card overflow-hidden">
      <header className="flex items-center gap-2.5 border-b border-slate-200 bg-slate-50 px-4 py-3 dark:border-slate-700 dark:bg-slate-800/60">
        <span className="rounded-md bg-teal-600/10 p-1.5 text-teal-700 dark:bg-teal-600/15 dark:text-teal-400">
          <Icon size={15} />
        </span>
        <div>
          <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">{title}</h3>
          {desc && <p className="text-[11px] text-slate-500 dark:text-slate-400">{desc}</p>}
        </div>
      </header>
      <div className="p-4">{children}</div>
    </section>
  );
}

const PROFILES = [
  {
    id: "Gamer",
    title: "Gamer Mode",
    icon: Gamepad2,
    tone: "bg-teal-600/10 text-teal-700 dark:bg-teal-600/15 dark:text-teal-400",
    desc: "Ultimate performance plan, background apps blocked, Game Bar DVR off.",
  },
  {
    id: "Privacy",
    title: "Privacy / Stealth",
    icon: Lock,
    tone: "bg-emerald-600/10 text-emerald-700 dark:bg-emerald-600/15 dark:text-emerald-400",
    desc: "Telemetry + Cortana + Bing wiped, AdGuard DNS, security update policy.",
  },
  {
    id: "Developer",
    title: "Developer Mode",
    icon: Terminal,
    tone: "bg-sky-600/10 text-sky-700 dark:bg-sky-600/15 dark:text-sky-400",
    desc: "WSL, Hyper-V, Sandbox, VM Platform + VS Code, Git, Python, Node, Docker.",
  },
];

export default function Profiles() {
  const { running, run, toast } = useApp();
  const [preflight, setPreflight] = useState(null);
  const [preflightLoading, setPreflightLoading] = useState(false);
  const [configs, setConfigs] = useState([]);
  const [apps, setApps] = useState([]);
  const [tweakState, setTweakState] = useState({});
  const [dns, setDns] = useState([]);
  const [modes, setModes] = useState([]);
  const [plans, setPlans] = useState([]);
  const [selApps, setSelApps] = useState([]);
  const [selTweaks, setSelTweaks] = useState([]);
  const [selDns, setSelDns] = useState("");
  const [selPower, setSelPower] = useState("");
  const [selMode, setSelMode] = useState("");
  const [profileName, setProfileName] = useState("my-profile");
  const [includeSsh, setIncludeSsh] = useState(false);

  const load = useCallback(async () => {
    getConfigs().then(setConfigs).catch(() => {});
    getWingetApps().then(setApps).catch(() => {});
    getTweakState().then(setTweakState).catch(() => {});
    getDnsPresets().then((d) => setDns(d)).catch(() => {});
    getUpdateModes().then((m) => setModes(m)).catch(() => {});
    getPowerPlans().then((p) => setPlans(p)).catch(() => {});
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const runPreflight = async () => {
    setPreflightLoading(true);
    setPreflight(null);
    try {
      setPreflight(await getPreflight("dism"));
    } catch {
      setPreflight({ checks: [], result: false });
    } finally {
      setPreflightLoading(false);
    }
  };

  const toggleApp = (id) =>
    setSelApps((s) => (s.includes(id) ? s.filter((x) => x !== id) : [...s, id]));
  const toggleTweak = (id) =>
    setSelTweaks((s) => (s.includes(id) ? s.filter((x) => x !== id) : [...s, id]));

  const doExport = () => {
    const args = ["-ExportConfig", "-ConfigName", profileName];
    if (selApps.length) args.push("-WingetApps", selApps.join(","));
    if (selTweaks.length) args.push("-Tweak", selTweaks.join(","));
    if (selDns) args.push("-Dns", selDns);
    if (selPower) args.push("-Power", selPower);
    if (selMode) args.push("-UpdateMode", selMode);
    if (includeSsh) args.push("-Ssh");
    run(args);
    toast("Profile exported. See console for the file path.", "info");
  };

  const doImport = (cfg) => {
    run(["-ImportConfig", "-ConfigName", cfg.name]);
  };

  const allChecksOk = preflight && preflight.result;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="section-title">Power-User Profiles</h2>
        <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
          One-click presets, a safety pre-flight gate, and shareable JSON profiles.
        </p>
      </div>

      <Card icon={ShieldAlert} title="Pre-Flight Check" desc="Anti-brick gate: verifies disk space, battery and admin before heavy ops">
        <div className="flex flex-wrap items-center gap-3">
          <button onClick={runPreflight} disabled={running || preflightLoading} className="btn-primary">
            <RefreshCw size={15} className={preflightLoading ? "animate-spin" : ""} />
            {preflightLoading ? "Checking…" : "Run Pre-Flight Check"}
          </button>
          {preflight && (
            <span
              className={`inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-semibold ${
                allChecksOk
                  ? "border-emerald-600/30 bg-emerald-600/10 text-emerald-700 dark:border-emerald-600/40 dark:text-emerald-400"
                  : "border-red-600/30 bg-red-600/10 text-red-700 dark:border-red-600/40 dark:text-red-400"
              }`}
            >
              {allChecksOk ? <CheckCircle2 size={13} /> : <XCircle size={13} />}
              {allChecksOk ? "Safe to run heavy operations" : "Blocked — review failures"}
            </span>
          )}
        </div>
        {preflight && (
          <ul className="mt-3 space-y-1.5">
            {preflight.checks.map((c) => (
              <li
                key={c.check}
                className={`flex items-start gap-2 rounded-lg border px-3 py-2 font-mono text-xs ${
                  c.ok
                    ? "border-emerald-600/30 bg-emerald-600/10 text-emerald-700 dark:text-emerald-400"
                    : "border-red-600/40 bg-red-600/10 text-red-700 dark:text-red-400"
                }`}
              >
                <span className="mt-0.5 shrink-0">{c.ok ? <CheckCircle2 size={13} /> : <XCircle size={13} />}</span>
                <span>
                  <span className="font-bold uppercase tracking-wider">{c.check}</span> — {c.detail}
                </span>
              </li>
            ))}
          </ul>
        )}
        <p className="mt-3 text-[11px] text-slate-400 dark:text-slate-500">
          Heavy operations (DISM repairs, ISO creation, deep debloat, bulk installs) re-run this
          gate automatically and abort safely if a check fails.
        </p>
      </Card>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        {PROFILES.map((p) => {
          const Icon = p.icon;
          return (
            <button
              key={p.id}
              onClick={() => run(["-Profile", p.id])}
              disabled={running}
              className="card group overflow-hidden p-0 text-left transition-all duration-200 hover:-translate-y-0.5 hover:border-teal-600 hover:shadow-md disabled:opacity-40"
            >
              <div className="flex items-center justify-between border-b border-slate-200 px-4 py-3 dark:border-slate-700">
                <span className={`rounded-md p-2 ${p.tone}`}>
                  <Icon size={18} />
                </span>
                <span className="text-xs font-semibold uppercase tracking-wider text-slate-400 dark:text-slate-500">
                  {p.id}
                </span>
              </div>
              <div className="p-4">
                <p className="text-sm font-bold text-slate-900 dark:text-slate-100">{p.title}</p>
                <p className="mt-1 text-xs leading-relaxed text-slate-500 dark:text-slate-400">{p.desc}</p>
              </div>
            </button>
          );
        })}
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
        <Card icon={Save} title="Export Profile" desc="Capture your choices as a shareable JSON file">
          <div className="mb-3">
            <label className="label">Profile name</label>
            <input
              value={profileName}
              onChange={(e) => setProfileName(e.target.value)}
              placeholder="my-profile"
              className="input"
            />
          </div>

          <p className="label">WinGet apps</p>
          <div className="mb-3 max-h-32 overflow-y-auto rounded-lg border border-slate-200 p-2 dark:border-slate-700">
            {apps.length === 0 ? (
              <p className="p-2 text-xs text-slate-400 dark:text-slate-500">Loading catalog…</p>
            ) : (
              <div className="grid grid-cols-1 gap-0.5 md:grid-cols-2">
                {apps.map((a) => (
                  <label key={a.id} className="flex cursor-pointer items-center gap-2 rounded px-2 py-1 hover:bg-slate-100 dark:hover:bg-slate-700/50">
                    <input type="checkbox" checked={selApps.includes(a.id)} onChange={() => toggleApp(a.id)} className="accent-teal-600" />
                    <span className="truncate text-xs text-slate-700 dark:text-slate-300">{a.name}</span>
                  </label>
                ))}
              </div>
            )}
          </div>

          <p className="label">Tweaks</p>
          <div className="mb-3 grid grid-cols-1 gap-0.5 md:grid-cols-2">
            {Object.keys(tweakState).map((t) => (
              <label key={t} className="flex cursor-pointer items-center gap-2 rounded px-2 py-1 hover:bg-slate-100 dark:hover:bg-slate-700/50">
                <input type="checkbox" checked={selTweaks.includes(t)} onChange={() => toggleTweak(t)} className="accent-teal-600" />
                <span className="text-xs capitalize text-slate-700 dark:text-slate-300">{t}</span>
              </label>
            ))}
          </div>

          <div className="grid grid-cols-3 gap-3">
            <div>
              <label className="label">DNS</label>
              <select value={selDns} onChange={(e) => setSelDns(e.target.value)} className="input">
                <option value="">—</option>
                {dns.map((d) => (
                  <option key={d.id} value={d.id}>{d.label}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Power</label>
              <select value={selPower} onChange={(e) => setSelPower(e.target.value)} className="input">
                <option value="">—</option>
                {["Ultimate", "HighPerformance", "Balanced", "PowerSaver"].map((p) => (
                  <option key={p} value={p}>{p}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Updates</label>
              <select value={selMode} onChange={(e) => setSelMode(e.target.value)} className="input">
                <option value="">—</option>
                {modes.map((m) => (
                  <option key={m.id} value={m.id}>{m.id}</option>
                ))}
              </select>
            </div>
          </div>

          <div className="mb-3">
            <label className="flex cursor-pointer items-center gap-2 rounded px-1 py-1">
              <input type="checkbox" checked={includeSsh} onChange={(e) => setIncludeSsh(e.target.checked)} className="accent-teal-600" />
              <span className="text-xs text-slate-700 dark:text-slate-300">Enable OpenSSH server on this machine</span>
            </label>
          </div>

          <button onClick={doExport} disabled={running || !profileName.trim()} className="btn-primary mt-4 w-full">
            <Save size={15} /> Export Profile JSON
          </button>
        </Card>

        <Card icon={Upload} title="Import Profile" desc="Apply a saved JSON profile to this machine">
          <div className="mb-3 flex items-center justify-between">
            <button onClick={load} disabled={running} className="btn-secondary !px-3 !py-1.5 text-xs">
              <RefreshCw size={13} className={running ? "animate-spin" : ""} /> Refresh list
            </button>
          </div>
          {configs.length === 0 ? (
            <p className="rounded-lg border border-slate-200 p-4 text-center text-sm text-slate-400 dark:border-slate-700 dark:text-slate-500">
              No saved profiles yet. Export one first — it lands in Documents\Win-Optimizer-Pro.
            </p>
          ) : (
            <ul className="space-y-2">
              {configs.map((c) => (
                <li key={c.path} className="flex items-center justify-between gap-3 rounded-lg border border-slate-200 p-3 dark:border-slate-700">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium text-slate-900 dark:text-slate-100">{c.name}</p>
                    <p className="truncate font-mono text-[11px] text-slate-400 dark:text-slate-500">{c.path}</p>
                    <p className="text-[11px] text-slate-400 dark:text-slate-500">{c.modified}</p>
                  </div>
                  <button onClick={() => doImport(c)} disabled={running} className="btn-secondary shrink-0 !px-3 !py-1.5 text-xs">
                    <Download size={13} /> Apply
                  </button>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
}
