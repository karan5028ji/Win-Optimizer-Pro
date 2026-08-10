import { useCallback, useEffect, useRef, useState } from "react";
import {
  CheckCircle2,
  Info,
  Moon,
  ShieldAlert,
  ShieldCheck,
  Sun,
  XCircle,
  Zap,
} from "lucide-react";
import Sidebar from "./components/Sidebar";
import Console from "./components/Console";
import Dashboard from "./components/Dashboard";
import DeepClean from "./components/DeepClean";
import Debloater from "./components/Debloater";
import Tweaks from "./components/Tweaks";
import Install from "./components/Install";
import Tuning from "./components/Tuning";
import Profiles from "./components/Profiles";
import Toggle from "./components/Toggle";
import { AppContext } from "./lib/app-context";
import {
  getSystemInfo,
  isElevated,
  onDone,
  onLog,
  relaunchElevated,
  runOptimizer,
  stopOptimizer,
} from "./lib/backend";

const TABS = {
  dashboard: { label: "Dashboard", component: Dashboard },
  install: { label: "Install", component: Install },
  clean: { label: "Deep Clean", component: DeepClean },
  debloat: { label: "Debloater", component: Debloater },
  tweaks: { label: "System Tweaks", component: Tweaks },
  tuning: { label: "Tuning", component: Tuning },
  profiles: { label: "Profiles", component: Profiles },
};

function Toasts({ toasts }) {
  return (
    <div className="pointer-events-none fixed bottom-16 right-4 z-50 flex w-80 flex-col gap-2">
      {toasts.map((t) => (
        <div
          key={t.id}
          className={`pointer-events-auto flex items-start gap-2.5 rounded-lg border px-4 py-3 text-sm shadow-md ${
            t.type === "error"
              ? "border-red-600/30 bg-white text-red-700 dark:border-red-600/50 dark:bg-slate-800 dark:text-red-300"
              : t.type === "success"
                ? "border-emerald-600/30 bg-white text-emerald-700 dark:border-emerald-600/50 dark:bg-slate-800 dark:text-emerald-300"
                : "border-slate-200 bg-white text-slate-700 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200"
          }`}
        >
          {t.type === "error" ? (
            <XCircle size={16} className="mt-0.5 shrink-0 text-red-500 dark:text-red-400" />
          ) : t.type === "success" ? (
            <CheckCircle2 size={16} className="mt-0.5 shrink-0 text-emerald-500 dark:text-emerald-400" />
          ) : (
            <Info size={16} className="mt-0.5 shrink-0 text-teal-600 dark:text-teal-400" />
          )}
          <span className="min-w-0 break-words">{t.text}</span>
        </div>
      ))}
    </div>
  );
}

export default function App() {
  const [tab, setTab] = useState("dashboard");
  const [dryRun, setDryRun] = useState(true);
  const [restorePoint, setRestorePoint] = useState(true);
  const [elevated, setElevated] = useState(false);
  const [running, setRunning] = useState(false);
  const [logs, setLogs] = useState([]);
  const [statusLine, setStatusLine] = useState("");
  const [sysInfo, setSysInfo] = useState(null);
  const [toasts, setToasts] = useState([]);
  const [dark, setDark] = useState(() =>
    document.documentElement.classList.contains("dark")
  );
  const runningRef = useRef(false);
  const logRef = useRef([]);
  const toastIdRef = useRef(0);
  const shownRef = useRef(new Set());

  useEffect(() => {
    document.documentElement.classList.toggle("dark", dark);
    localStorage.setItem("theme", dark ? "dark" : "light");
  }, [dark]);

  const toast = useCallback((text, type = "info") => {
    const id = ++toastIdRef.current;
    setToasts((t) => [...t, { id, text, type }].slice(-4));
    setTimeout(() => {
      setToasts((t) => t.filter((x) => x.id !== id));
    }, 5000);
  }, []);

  useEffect(() => {
    isElevated().then(setElevated).catch(() => setElevated(false));
    getSystemInfo().then(setSysInfo).catch(() => {});
    const unLog = onLog((line) => {
      const clean = line.trim();
      logRef.current = [...logRef.current, line].slice(-3000);
      setLogs(logRef.current);
      if (clean) setStatusLine(clean);
      const pfFail = clean.match(/^PRE\|([^|]+)\|fail\|(.+)/);
      if (pfFail) {
        const key = `preflight:${pfFail[1]}:${pfFail[2]}`;
        if (!shownRef.current.has(key)) {
          shownRef.current.add(key);
          toast(`Anti-brick: ${pfFail[2]}`, "error");
        }
      }
    });
    const unDone = onDone(() => {
      const wasRunning = runningRef.current;
      runningRef.current = false;
      setRunning(false);
      setStatusLine("Finished.");
      if (wasRunning) toast("Operation finished.", "success");
    });
    return () => {
      unLog.then((f) => f());
      unDone.then((f) => f());
    };
  }, [toast]);

  const pushLine = useCallback((line) => {
    logRef.current = [...logRef.current, line].slice(-3000);
    setLogs(logRef.current);
  }, []);

  const run = useCallback(
    async (args) => {
      if (runningRef.current) return;
      const flags = dryRun ? [...args, "-DryRun"] : [...args];
      runningRef.current = true;
      setRunning(true);
      setStatusLine("");
      logRef.current = [];
      setLogs([]);
      pushLine(`> powershell optimizer.ps1 ${flags.join(" ")} -NoElevate\n`);
      try {
        await runOptimizer([...flags, "-NoElevate"]);
      } catch (err) {
        pushLine(`[error] ${err}\n`);
        runningRef.current = false;
        setRunning(false);
        setStatusLine("Failed.");
        toast(String(err), "error");
      }
    },
    [dryRun, pushLine, toast]
  );

  const cancel = useCallback(() => {
    stopOptimizer().catch(() => {});
  }, []);

  const restartAsAdmin = useCallback(() => {
    relaunchElevated().catch(() => toast("Could not relaunch elevated.", "error"));
  }, [toast]);

  const TabComponent = TABS[tab].component;

  return (
    <AppContext.Provider
      value={{
        dryRun,
        setDryRun,
        restorePoint,
        setRestorePoint,
        running,
        run,
        cancel,
        logs,
        statusLine,
        pushLine,
        toast,
        clearLogs: () => {
          logRef.current = [];
          setLogs([]);
        },
        sysInfo,
        elevated,
      }}
    >
      <div className="flex h-full">
        <Sidebar tab={tab} onTab={setTab} running={running} />
        <div className="flex min-w-0 flex-1 flex-col">
          <header className="flex h-16 shrink-0 items-center justify-between gap-4 border-b border-slate-200 bg-white px-6 dark:border-slate-700 dark:bg-slate-900">
            <div className="flex min-w-0 items-center gap-3">
              <h1 className="section-title">{TABS[tab].label}</h1>
              {elevated ? (
                <span className="badge-ok">
                  <ShieldCheck size={12} /> Elevated
                </span>
              ) : (
                <span className="badge-warn">
                  <ShieldAlert size={12} /> Not elevated
                </span>
              )}
            </div>
            <div className="flex shrink-0 items-center gap-4">
              {!elevated && (
                <button
                  onClick={restartAsAdmin}
                  className="btn-secondary !px-3 !py-1.5 text-xs"
                  title="Restart with administrator rights"
                >
                  <Zap size={13} /> Restart as Admin
                </button>
              )}
              <div className="flex items-center gap-2">
                <span className="text-xs text-slate-500 dark:text-slate-400" title="Create a System Restore point before debloating or applying tweaks">
                  Restore point
                </span>
                <Toggle checked={restorePoint} onChange={setRestorePoint} size="sm" />
              </div>
              <div className="flex items-center gap-2">
                <span className="text-xs text-slate-500 dark:text-slate-400">Dry-run</span>
                <Toggle checked={dryRun} onChange={setDryRun} size="sm" />
                <span
                  className={`hidden w-44 text-right text-xs xl:inline ${
                    dryRun ? "text-teal-600 dark:text-teal-400" : "text-red-600 dark:text-red-400"
                  }`}
                >
                  {dryRun ? "Preview only · nothing changes" : "Changes will be applied"}
                </span>
              </div>
              <button
                onClick={() => setDark((d) => !d)}
                className="btn-ghost !px-2.5 !py-1.5"
                title={dark ? "Switch to light mode" : "Switch to dark mode"}
              >
                {dark ? <Sun size={16} /> : <Moon size={16} />}
              </button>
            </div>
          </header>

          <main className="min-h-0 flex-1 overflow-y-auto p-6">
            <TabComponent />
          </main>

          <Console running={running} onCancel={cancel} />
        </div>
      </div>
      <Toasts toasts={toasts} />
    </AppContext.Provider>
  );
}
