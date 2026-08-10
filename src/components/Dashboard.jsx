import { useEffect, useState } from "react";
import {
  Cpu,
  Gauge,
  HardDrive,
  MemoryStick,
  MonitorSmartphone,
  Play,
  RefreshCw,
} from "lucide-react";
import { useApp } from "../lib/app-context";
import { getBloatApps, getStartupItems, getTweakState, getWingetApps } from "../lib/backend";
import RadialRing from "./RadialRing";

function StatCard({ icon: Icon, label, value }) {
  return (
    <div className="card p-5">
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
        <Icon size={15} strokeWidth={2} className="text-teal-600 dark:text-teal-400" />
        {label}
      </div>
      <p className="mt-3 text-xl font-bold leading-snug tracking-tight text-slate-900 dark:text-slate-100">
        {value}
      </p>
    </div>
  );
}

function MetricRing({ label, detail, value, loading, tone }) {
  return (
    <div className="card flex items-center gap-4 p-5">
      <RadialRing value={value} size={72} stroke={5} tone={tone} />
      <div className="min-w-0">
        <p className="text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
          {label}
        </p>
        <p className="mt-1 text-sm font-semibold text-slate-900 dark:text-slate-100">
          {loading ? "Loading…" : detail}
        </p>
      </div>
    </div>
  );
}

export default function Dashboard() {
  const { sysInfo, run, running, elevated, statusLine } = useApp();
  const [metrics, setMetrics] = useState(null);

  useEffect(() => {
    let mounted = true;
    Promise.allSettled([getBloatApps(), getWingetApps(), getTweakState(), getStartupItems()])
      .then(([bloat, winget, tweak, startup]) => {
        if (!mounted) return;
        const bloatApps = bloat.status === "fulfilled" ? bloat.value : [];
        const wingetApps = winget.status === "fulfilled" ? winget.value : [];
        const tweakState = tweak.status === "fulfilled" ? tweak.value : {};
        const startupItems = startup.status === "fulfilled" ? startup.value : [];
        setMetrics({
          wingetTotal: wingetApps.length,
          wingetInstalled: wingetApps.filter((a) => a.installed).length,
          tweakTotal: Object.keys(tweakState).length,
          tweakApplied: Object.values(tweakState).filter(Boolean).length,
          bloatCount: bloatApps.length,
          startupTotal: startupItems.length,
          startupEnabled: startupItems.filter((s) => s.enabled).length,
        });
      });
    return () => {
      mounted = false;
    };
  }, []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="section-title">System Overview</h2>
          <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
            Hardware and software summary, plus a fast read-only health scan.
          </p>
        </div>
        <button
          onClick={() => run(["-QuickScan"])}
          disabled={running}
          className="btn-primary"
        >
          {running ? (
            <RefreshCw size={15} strokeWidth={2} className="animate-spin" />
          ) : (
            <Play size={15} strokeWidth={2} />
          )}
          {running ? "Scanning…" : "Quick Scan"}
        </button>
      </div>

      {!elevated && (
        <div className="rounded-lg border border-amber-600/30 bg-amber-600/10 px-4 py-3 text-sm text-amber-700 dark:border-amber-600/40 dark:text-amber-400">
          App is not elevated — debloating and tweaks will not apply. Use{" "}
          <span className="font-semibold">Restart as Admin</span> in the top-right
          corner and accept the UAC prompt.
        </div>
      )}

      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard icon={Cpu} label="CPU" value={sysInfo?.cpu || "…"} />
        <StatCard icon={MemoryStick} label="Memory" value={sysInfo?.ram || "…"} />
        <StatCard icon={MonitorSmartphone} label="OS" value={sysInfo?.os || "…"} />
        <StatCard icon={HardDrive} label="Architecture" value={sysInfo?.arch || "…"} />
      </div>

      {metrics && (
        <div>
          <h3 className="mb-3 flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
            System readiness
            <span className="font-normal normal-case text-slate-400 dark:text-slate-500">
              · {metrics.bloatCount} removable apps in catalog
            </span>
          </h3>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3 xl:grid-cols-3">
            <MetricRing
              label="Winget catalog"
              detail={`${metrics.wingetInstalled} of ${metrics.wingetTotal} installed`}
              value={metrics.wingetTotal ? (metrics.wingetInstalled / metrics.wingetTotal) * 100 : 0}
              loading={!metrics}
              tone="text-teal-600 dark:text-teal-400"
            />
            <MetricRing
              label="Tweaks applied"
              detail={`${metrics.tweakApplied} of ${metrics.tweakTotal} applied`}
              value={metrics.tweakTotal ? (metrics.tweakApplied / metrics.tweakTotal) * 100 : 0}
              loading={!metrics}
              tone="text-teal-600 dark:text-teal-400"
            />
            <MetricRing
              label="Startup enabled"
              detail={`${metrics.startupEnabled} of ${metrics.startupTotal} entries`}
              value={metrics.startupTotal ? (metrics.startupEnabled / metrics.startupTotal) * 100 : 0}
              loading={!metrics}
              tone="text-teal-600 dark:text-teal-400"
            />
          </div>
        </div>
      )}

      {running && statusLine && (
        <div className="card flex items-center gap-2.5 border-teal-600/40 bg-teal-600/5 p-3">
          <RefreshCw size={14} strokeWidth={2} className="shrink-0 animate-spin text-teal-600 dark:text-teal-400" />
          <span className="truncate font-mono text-xs text-teal-700 dark:text-teal-400">{statusLine}</span>
        </div>
      )}

      <div className="card p-5">
        <div className="flex items-center gap-2">
          <Gauge size={16} strokeWidth={2} className="text-teal-600 dark:text-teal-400" />
          <h3 className="text-sm font-semibold text-slate-900 dark:text-slate-100">
            What Quick Scan checks
          </h3>
        </div>
        <ul className="mt-3 space-y-1.5 text-sm text-slate-500 dark:text-slate-400">
          <li>· Temp folders — how many items are waiting to be cleaned</li>
          <li>· DNS resolver cache — how many entries are cached</li>
          <li>· Bloatware — how many removable pre-installed apps are installed</li>
          <li>· Tweaks — how many recommended tweaks are still not applied</li>
        </ul>
        <p className="mt-3 text-xs text-slate-400 dark:text-slate-500">
          Quick Scan is read-only and finishes in a few seconds — nothing is modified.
          The console below streams each step live.
        </p>
      </div>
    </div>
  );
}
