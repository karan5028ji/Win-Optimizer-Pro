import { Cpu, Gauge, HardDrive, MemoryStick, MonitorSmartphone, Play, RefreshCw } from "lucide-react";
import { useApp } from "../lib/app-context";

function StatCard({ icon: Icon, label, value }) {
  return (
    <div className="card group p-5">
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-zinc-500">
        <Icon
          size={15}
          className="text-zinc-500 transition-colors duration-200 group-hover:text-accent-400"
        />
        {label}
      </div>
      <p className="mt-3 text-sm font-medium leading-snug text-zinc-100">{value}</p>
    </div>
  );
}

export default function Dashboard() {
  const { sysInfo, run, running, elevated } = useApp();

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="section-title">System Overview</h2>
          <p className="mt-1 text-sm text-zinc-500">
            Hardware and software summary, plus a one-click health scan.
          </p>
        </div>
        <button
          onClick={() => run(["-All"])}
          disabled={running}
          className="btn-accent"
        >
          {running ? (
            <RefreshCw size={15} className="animate-spin" />
          ) : (
            <Play size={15} />
          )}
          {running ? "Scanning…" : "Quick Scan"}
        </button>
      </div>

      {!elevated && (
        <div className="rounded-lg border border-amber-600/40 bg-amber-600/10 px-4 py-3 text-sm text-amber-300">
          App is not elevated — debloating and tweaks will not apply. Restart the
          app and accept the UAC prompt.
        </div>
      )}

      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard icon={Cpu} label="CPU" value={sysInfo?.cpu || "…"} />
        <StatCard icon={MemoryStick} label="Memory" value={sysInfo?.ram || "…"} />
        <StatCard icon={MonitorSmartphone} label="OS" value={sysInfo?.os || "…"} />
        <StatCard icon={HardDrive} label="Architecture" value={sysInfo?.arch || "…"} />
      </div>

      <div className="card p-5">
        <div className="flex items-center gap-2">
          <Gauge size={16} className="text-accent-500" />
          <h3 className="text-sm font-semibold text-zinc-100">What Quick Scan does</h3>
        </div>
        <ul className="mt-3 space-y-1.5 text-sm text-zinc-400">
          <li>· Cleans temp folders (%temp%, Windows Temp, Prefetch)</li>
          <li>· Flushes DNS and browser caches</li>
          <li>· Lists removable bloatware (preview)</li>
          <li>· Lists applicable system tweaks (preview)</li>
        </ul>
        <p className="mt-3 text-xs text-zinc-600">
          Quick Scan runs in preview mode — nothing is modified while dry-run is on.
        </p>
      </div>
    </div>
  );
}
