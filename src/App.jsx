import { useCallback, useEffect, useRef, useState } from "react";
import { ShieldAlert, ShieldCheck } from "lucide-react";
import Sidebar from "./components/Sidebar";
import Console from "./components/Console";
import Dashboard from "./components/Dashboard";
import DeepClean from "./components/DeepClean";
import Debloater from "./components/Debloater";
import Tweaks from "./components/Tweaks";
import Toggle from "./components/Toggle";
import { AppContext } from "./lib/app-context";
import {
  getSystemInfo,
  isElevated,
  onDone,
  onLog,
  runOptimizer,
  stopOptimizer,
} from "./lib/backend";

const TABS = {
  dashboard: { label: "Dashboard", component: Dashboard },
  clean: { label: "Deep Clean", component: DeepClean },
  debloat: { label: "Debloater", component: Debloater },
  tweaks: { label: "System Tweaks", component: Tweaks },
};

export default function App() {
  const [tab, setTab] = useState("dashboard");
  const [dryRun, setDryRun] = useState(true);
  const [elevated, setElevated] = useState(false);
  const [running, setRunning] = useState(false);
  const [logs, setLogs] = useState([]);
  const [sysInfo, setSysInfo] = useState(null);
  const runningRef = useRef(false);
  const logRef = useRef([]);

  useEffect(() => {
    isElevated().then(setElevated).catch(() => setElevated(false));
    getSystemInfo().then(setSysInfo).catch(() => {});
    const unLog = onLog((line) => {
      logRef.current = [...logRef.current, line].slice(-3000);
      setLogs(logRef.current);
    });
    const unDone = onDone(() => {
      runningRef.current = false;
      setRunning(false);
    });
    return () => {
      unLog.then((f) => f());
      unDone.then((f) => f());
    };
  }, []);

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
      logRef.current = [];
      setLogs([]);
      pushLine(`> powershell optimizer.ps1 ${flags.join(" ")} -NoElevate\n`);
      try {
        await runOptimizer([...flags, "-NoElevate"]);
      } catch (err) {
        pushLine(`[error] ${err}\n`);
        runningRef.current = false;
        setRunning(false);
      }
    },
    [dryRun, pushLine]
  );

  const cancel = useCallback(() => {
    stopOptimizer().catch(() => {});
  }, []);

  const TabComponent = TABS[tab].component;

  return (
    <AppContext.Provider
      value={{
        dryRun,
        setDryRun,
        running,
        run,
        cancel,
        logs,
        pushLine,
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
          <header className="flex h-16 shrink-0 items-center justify-between border-b border-panel-border px-6">
            <div className="flex items-center gap-3">
              <h1 className="section-title">{TABS[tab].label}</h1>
              {elevated ? (
                <span className="inline-flex items-center gap-1 rounded-full border border-emerald-600/40 bg-emerald-600/10 px-2.5 py-0.5 text-xs font-medium text-emerald-400">
                  <ShieldCheck size={13} /> Elevated
                </span>
              ) : (
                <span className="inline-flex items-center gap-1 rounded-full border border-amber-600/40 bg-amber-600/10 px-2.5 py-0.5 text-xs font-medium text-amber-400">
                  <ShieldAlert size={13} /> Not elevated
                </span>
              )}
            </div>
            <div className="flex items-center gap-3">
              <span className="text-xs text-zinc-500">Dry-run</span>
              <Toggle checked={dryRun} onChange={setDryRun} size="sm" />
              <span
                className={`text-xs ${
                  dryRun ? "text-accent-400" : "text-red-400"
                }`}
              >
                {dryRun ? "Preview only · nothing changes" : "Changes will be applied"}
              </span>
            </div>
          </header>

          <main className="min-h-0 flex-1 overflow-y-auto p-6">
            <TabComponent />
          </main>

          <Console running={running} onCancel={cancel} />
        </div>
      </div>
    </AppContext.Provider>
  );
}
