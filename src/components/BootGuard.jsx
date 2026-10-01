import { useEffect, useMemo, useState } from "react";
import {
  BatteryCharging,
  CalendarClock,
  FolderOpen,
  Ghost,
  KeyRound,
  RefreshCw,
  RotateCcw,
  Server,
  ShieldCheck,
  Zap,
} from "lucide-react";
import { useApp } from "../lib/app-context";
import { getBootGuardItems, onDone } from "../lib/backend";

const KIND_META = {
  REGISTRY: { label: "Registry Run Keys", icon: KeyRound, scopeLabel: "HKCU + HKLM (64/32-bit)" },
  FOLDER: { label: "Startup Folders", icon: FolderOpen, scopeLabel: "shell:startup" },
  TASK: { label: "Scheduled Tasks", icon: CalendarClock, scopeLabel: "Logon / Boot triggers" },
  SERVICE: { label: "Background Services", icon: Server, scopeLabel: "Auto-start daemons" },
};

const IMPACT_STYLE = {
  high: { badge: "badge-danger", dot: "bg-red-500", label: "High" },
  medium: { badge: "badge-warn", dot: "bg-amber-500", label: "Medium" },
  low: { badge: "badge-ok", dot: "bg-emerald-500", label: "Low" },
};

const fmtRam = (mb) => {
  if (!mb) return "~0 MB";
  if (mb >= 1000) return `~${(mb / 1000).toFixed(1)} GB`;
  return `~${mb} MB`;
};

function ImpactBadge({ impact, ram, safe }) {
  if (safe) {
    return (
      <span className="badge-ok" title="Whitelisted: driver, security or kernel service - kept at boot by design">
        <ShieldCheck size={10} /> Safe
      </span>
    );
  }
  const style = IMPACT_STYLE[impact] || IMPACT_STYLE.low;
  return (
    <span className={`${style.badge} !rounded-md`} title={`Boot impact: ${style.label}`}>
      <span className={`${style.dot} h-1.5 w-1.5 rounded-full`} />
      {style.label} {ram ? `· ${fmtRam(ram)}` : ""}
    </span>
  );
}

function StatCard({ icon: Icon, label, value, tone }) {
  return (
    <div className="card p-4">
      <div className="flex items-center gap-2 text-[11px] font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
        <span
          className={`rounded-md p-1 ${tone}`}
        >
          <Icon size={13} />
        </span>
        {label}
      </div>
      <p className="mt-2 text-xl font-bold tracking-tight text-slate-900 dark:text-slate-100">{value}</p>
    </div>
  );
}

export default function BootGuard() {
  const { running, run } = useApp();
  const [items, setItems] = useState(null);
  const [loading, setLoading] = useState(true);

  const refresh = () => {
    getBootGuardItems()
      .then((list) => {
        setItems(list);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  };

  useEffect(() => {
    refresh();
    const un = onDone(() => refresh());
    return () => {
      un.then((f) => f());
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const stats = useMemo(() => {
    if (!items) return { total: 0, heavy: 0, reclaim: 0, disabled: 0 };
    const enabled = items.filter((i) => i.enabled);
    const heavy = enabled.filter((i) => !i.safe && i.impact !== "low");
    return {
      total: items.length,
      heavy: heavy.length,
      reclaim: heavy.reduce((sum, i) => sum + i.ram, 0),
      disabled: items.length - enabled.length,
    };
  }, [items]);

  const toggle = (item, enable) => {
    const arg = enable ? "-EnableBootGuard" : "-DisableBootGuard";
    run(["-SetBootGuard", item.id, arg]);
    setTimeout(refresh, 1500);
  };

  const runPreset = () => {
    run(["-BootGuardPreset"]);
    setTimeout(refresh, 4000);
  };

  const restore = () => {
    run(["-RestoreBootGuard"]);
    setTimeout(refresh, 4000);
  };

  const groups = useMemo(() => {
    if (!items) return [];
    return Object.keys(KIND_META)
      .map((kind) => ({ kind, meta: KIND_META[kind], rows: items.filter((i) => i.kind === kind) }))
      .filter((g) => g.rows.length > 0);
  }, [items]);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="section-title flex items-center gap-2">
          <Ghost size={19} className="text-teal-600 dark:text-teal-400" />
          Deep Boot Guard
        </h2>
        <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
          Ghost Startup Inspector - finds &amp; disables the startup apps Task Manager hides from you:
          scheduled-task launchers, updaters and background daemons.
        </p>
      </div>

      {/* Preset */}
      <div className="card overflow-hidden">
        <div className="flex flex-col items-stretch gap-4 border-b border-slate-200 bg-gradient-to-r from-teal-600/10 to-transparent p-5 dark:border-slate-700 lg:flex-row lg:items-center lg:justify-between">
          <div className="min-w-0">
            <h3 className="flex items-center gap-2 text-sm font-bold text-slate-900 dark:text-slate-100">
              <BatteryCharging size={16} className="text-teal-600 dark:text-teal-400" />
              Instant 5-Second Boot
            </h3>
            <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
              One click disables every non-essential heavy launcher
              {stats.heavy ? ` (${stats.heavy} found, ~${fmtRam(stats.reclaim)} reclaimable)` : ""}.
              Audio drivers, Windows Security and kernel services stay untouched.
              A backup is saved before any change so you can undo instantly.
            </p>
          </div>
          <div className="flex shrink-0 flex-wrap gap-2">
            <button onClick={runPreset} disabled={running || loading || stats.heavy === 0} className="btn-primary !py-2 text-xs">
              <Zap size={14} />
              {stats.heavy === 0 && !loading ? "Nothing to disable" : "Optimize Boot Sequence"}
            </button>
            <button onClick={restore} disabled={running || loading} className="btn-secondary !py-2 text-xs">
              <RotateCcw size={14} />
              Restore from backup
            </button>
          </div>
        </div>

        {/* Stats + legend */}
        <div className="grid grid-cols-2 gap-3 p-5 md:grid-cols-4">
          <StatCard
            icon={Ghost}
            label="Boot entries"
            value={loading ? "…" : stats.total}
            tone="bg-teal-600/10 text-teal-700 dark:text-teal-400"
          />
          <StatCard
            icon={Zap}
            label="Heavy launchers"
            value={loading ? "…" : stats.heavy}
            tone="bg-red-600/10 text-red-700 dark:text-red-400"
          />
          <StatCard
            icon={BatteryCharging}
            label="Est. RAM reclaim"
            value={loading ? "…" : fmtRam(stats.reclaim)}
            tone="bg-amber-600/10 text-amber-700 dark:text-amber-400"
          />
          <StatCard
            icon={Server}
            label="Disabled"
            value={loading ? "…" : stats.disabled}
            tone="bg-slate-600/10 text-slate-700 dark:text-slate-300"
          />
        </div>
      </div>

      {/* Legend */}
      <div className="flex flex-wrap items-center gap-3 text-[11px] text-slate-500 dark:text-slate-400">
        <span>Impact:</span>
        <ImpactBadge impact="high" ram={2600} safe={false} />
        <ImpactBadge impact="medium" ram={350} safe={false} />
        <ImpactBadge impact="low" ram={80} safe={false} />
        <ImpactBadge impact="low" ram={0} safe />
        <button
          onClick={refresh}
          disabled={running}
          className="btn-ghost !px-2.5 !py-1 text-xs"
          title="Rescan all boot sources"
        >
          <RefreshCw size={13} /> Rescan
        </button>
      </div>

      {loading ? (
        <p className="rounded-lg border border-slate-200 p-6 text-center text-sm text-slate-400 dark:border-slate-700 dark:text-slate-500">
          Ghost-scanning registry, startup folders, scheduled tasks and services…
        </p>
      ) : groups.length === 0 ? (
        <p className="rounded-lg border border-slate-200 p-6 text-center text-sm text-slate-400 dark:border-slate-700 dark:text-slate-500">
          No startup entries found.
        </p>
      ) : (
        groups.map(({ kind, meta, rows }) => {
          const Icon = meta.icon;
          return (
            <section key={kind} className="card overflow-hidden">
              <header className="flex items-center justify-between border-b border-slate-200 bg-slate-50 px-4 py-3 dark:border-slate-700 dark:bg-slate-800/60">
                <div className="flex items-center gap-2.5">
                  <span className="rounded-md bg-teal-600/10 p-1.5 text-teal-700 dark:bg-teal-600/15 dark:text-teal-400">
                    <Icon size={15} />
                  </span>
                  <div>
                    <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">{meta.label}</h3>
                    <p className="text-[11px] text-slate-500 dark:text-slate-400">{meta.scopeLabel}</p>
                  </div>
                </div>
                <span className="badge-neutral">{rows.length}</span>
              </header>

              <ul className="divide-y divide-slate-200 dark:divide-slate-700">
                {rows.map((row) => (
                  <li key={row.id} className="flex items-center justify-between gap-3 px-4 py-2.5">
                    <div className="min-w-0">
                      <p className="flex flex-wrap items-center gap-2 text-sm font-medium text-slate-900 dark:text-slate-100">
                        <span className="truncate">{row.name}</span>
                        <ImpactBadge impact={row.impact} ram={row.ram} safe={row.safe} />
                        {row.scope && row.kind !== "SERVICE" && (
                          <span className="badge-neutral px-1.5 py-px text-[9px]">{row.scope}</span>
                        )}
                      </p>
                      <p className="mt-0.5 truncate font-mono text-[11px] text-slate-400 dark:text-slate-500">
                        {row.command}
                      </p>
                    </div>
                    <div className="flex shrink-0 gap-1.5">
                      <button
                        onClick={() => toggle(row, true)}
                        disabled={running || row.enabled}
                        className="btn-ghost !px-2.5 !py-1 text-[11px]"
                        title="Enable at boot"
                      >
                        Enable
                      </button>
                      <button
                        onClick={() => toggle(row, false)}
                        disabled={running || !row.enabled || row.safe}
                        className="btn-ghost !px-2.5 !py-1 text-[11px]"
                        title={row.safe ? "Whitelisted - kept at boot" : "Disable at boot"}
                      >
                        Disable
                      </button>
                    </div>
                  </li>
                ))}
              </ul>
            </section>
          );
        })
      )}
    </div>
  );
}