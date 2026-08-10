import { useEffect, useState } from "react";
import {
  Boxes,
  Globe,
  ListRestart,
  Menu,
  MonitorCog,
  Power,
  RefreshCw,
  RotateCcw,
  Server,
  Settings2,
  SlidersHorizontal,
  Wrench,
} from "lucide-react";
import { useApp } from "../lib/app-context";
import {
  getDnsPresets,
  getFixes,
  getLegacyPanels,
  getPowerPlans,
  getStartupItems,
  getUpdateModes,
  getWinFeatures,
} from "../lib/backend";
import Toggle from "./Toggle";
import InfoTip from "./InfoTip";

function Section({ icon: Icon, title, subtitle, children, right }) {
  return (
    <section className="card overflow-hidden">
      <header className="flex items-center justify-between border-b border-slate-200 bg-slate-50 px-4 py-3 dark:border-slate-700 dark:bg-slate-800/60">
        <div className="flex items-center gap-2.5">
          <span className="rounded-md bg-teal-600/10 p-1.5 text-teal-700 dark:bg-teal-600/15 dark:text-teal-400">
            <Icon size={15} />
          </span>
          <div>
            <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">{title}</h3>
            {subtitle && <p className="text-[11px] text-slate-500 dark:text-slate-400">{subtitle}</p>}
          </div>
        </div>
        {right}
      </header>
      <div className="p-4">{children}</div>
    </section>
  );
}

function OptPills({ options, value, onSelect }) {
  return (
    <div className="flex flex-wrap gap-2">
      {options.map((o) => (
        <button
          key={o.id}
          onClick={() => onSelect(o)}
          disabled={o.disabled}
          className={`!px-3 !py-1.5 text-xs ${
            value === o.id ? "btn-primary" : "btn-secondary"
          }`}
          title={o.label}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export default function Tuning() {
  const { running, run } = useApp();
  const [dns, setDns] = useState([]);
  const [dnsActive, setDnsActive] = useState("Default");
  const [modes, setModes] = useState([]);
  const [modeActive, setModeActive] = useState(null);
  const [plans, setPlans] = useState([]);
  const [planActive, setPlanActive] = useState(null);
  const [features, setFeatures] = useState([]);
  const [fixes, setFixes] = useState([]);
  const [panels, setPanels] = useState([]);
  const [sshOn, setSshOn] = useState(false);
  const [startup, setStartup] = useState([]);
  const [ctxClassic, setCtxClassic] = useState(false);

  useEffect(() => {
    getDnsPresets().then(setDns).catch(() => {});
    getUpdateModes().then(setModes).catch(() => {});
    getPowerPlans().then((p) => {
      setPlans(p);
      const active = p.find((x) => x.active);
      if (active) setPlanActive(active.name);
    }).catch(() => {});
    getWinFeatures().then(setFeatures).catch(() => {});
    getFixes().then(setFixes).catch(() => {});
    getLegacyPanels().then(setPanels).catch(() => {});
    refreshStartup();
  }, []);

  const refreshStartup = () => {
    getStartupItems().then((s) => {
      setStartup(s);
      setCtxClassic(false);
    }).catch(() => {});
  };

  const toggleStartup = (item, enable) => {
    const arg = enable ? "-EnableStartup" : "-DisableStartup";
    run(["-SetStartup", item.id, arg]);
    setTimeout(refreshStartup, 1500);
  };

  const toggleFeature = (f, enable) => {
    const arg = enable ? "-EnableFeature" : "-DisableFeature";
    run(["-SetFeature", arg, "-Feature", f.id]);
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="section-title">Tuning &amp; Config</h2>
        <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
          DNS, Windows Update, power plans, optional features, repairs and legacy panels.
        </p>
      </div>

      <Section
        icon={Globe}
        title="DNS"
        subtitle="Switch DNS servers for all active adapters (IPv4 + IPv6)"
      >
        <OptPills
          options={dns.map((d) => ({ id: d.id, label: d.label }))}
          value={dnsActive}
          onSelect={(o) => {
            setDnsActive(o.id);
            run(["-SetDNS", o.id]);
          }}
        />
      </Section>

      <Section
        icon={Settings2}
        title="Windows Update"
        subtitle="Pick an update servicing policy"
      >
        <OptPills
          options={modes.map((m) => ({ id: m.id, label: m.label }))}
          value={modeActive}
          onSelect={(o) => {
            setModeActive(o.id);
            run(["-SetUpdateMode", o.id]);
          }}
        />
        <p className="mt-2 text-[11px] text-slate-400 dark:text-slate-500">
          Security delays feature updates by 365 days and quality updates by 4 days.
          Disabling all updates is only for isolated machines.
        </p>
      </Section>

      <Section
        icon={MonitorCog}
        title="Power Plan"
        subtitle="Activate a Windows power scheme"
      >
        <OptPills
          options={[
            { id: "Ultimate", label: "Ultimate Performance" },
            { id: "HighPerformance", label: "High Performance" },
            { id: "Balanced", label: "Balanced" },
            { id: "PowerSaver", label: "Power Saver" },
          ]}
          value={planActive}
          onSelect={(o) => {
            setPlanActive(o.id);
            run(["-SetPower", o.id]);
          }}
        />
        <p className="mt-2 text-[11px] text-slate-400 dark:text-slate-500">
          Active plan:{" "}
          {plans.filter((p) => p.active).map((p) => p.name).join(", ") || "unknown"}
        </p>
      </Section>

      <Section
        icon={Boxes}
        title="Windows Features"
        subtitle="Enable or disable optional Windows components (needs admin)"
      >
        <div className="grid grid-cols-1 gap-2 md:grid-cols-2">
          {features.map((f) => (
            <div key={f.id} className="rounded-lg border border-slate-200 p-3 dark:border-slate-700">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <p className="text-sm font-medium text-slate-900 dark:text-slate-100">{f.label}</p>
                  <p className="truncate font-mono text-[11px] text-slate-400 dark:text-slate-500">{f.id}</p>
                </div>
                {f.enabled ? (
                  <span className="badge-ok shrink-0">Enabled</span>
                ) : f.enabled === false ? (
                  <span className="badge-neutral shrink-0">Disabled</span>
                ) : (
                  <span className="badge-warn shrink-0">Needs admin</span>
                )}
              </div>
              <div className="mt-2 flex gap-2">
                <button
                  onClick={() => toggleFeature(f, true)}
                  disabled={running || f.enabled === true}
                  className="btn-ghost !px-2.5 !py-1 text-[11px]"
                >
                  Enable
                </button>
                <button
                  onClick={() => toggleFeature(f, false)}
                  disabled={running || f.enabled === false}
                  className="btn-ghost !px-2.5 !py-1 text-[11px]"
                >
                  Disable
                </button>
              </div>
            </div>
          ))}
        </div>
      </Section>

      <Section
        icon={Wrench}
        title="Fixes"
        subtitle="One-click repairs for common system problems"
      >
        <div className="grid grid-cols-1 gap-2 md:grid-cols-2 xl:grid-cols-3">
          {fixes.map((f) => (
            <button
              key={f.id}
              onClick={() => run(["-RunFix", f.id])}
              disabled={running}
              className="flex items-center gap-2.5 rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-left transition-colors hover:border-teal-600 hover:text-teal-700 disabled:opacity-40 dark:border-slate-700 dark:bg-slate-800 dark:hover:border-teal-600 dark:hover:text-teal-400"
              title={f.label}
            >
              <span className="truncate text-sm font-medium">{f.label}</span>
            </button>
          ))}
        </div>
      </Section>

      <Section
        icon={Server}
        title="OpenSSH Server"
        subtitle="Allow remote access over SSH (port 22)"
        right={
          <Toggle
            checked={sshOn}
            onChange={(v) => {
              setSshOn(v);
              run(v ? ["-EnableSsh"] : ["-DisableSsh"]);
            }}
            size="sm"
          />
        }
      >
        <p className="text-xs text-slate-500 dark:text-slate-400">
          Enables the built-in OpenSSH server and opens firewall port 22.
        </p>
      </Section>

      <Section
        icon={RotateCcw}
        title="Undo Tweaks"
        subtitle="Revert registry/service changes applied by System Tweaks"
      >
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => run(["-UndoTweaks"])}
            disabled={running}
            className="btn-ghost"
            title="Undo every applied tweak"
          >
            <RotateCcw size={15} /> Undo All Tweaks
          </button>
          <button
            onClick={() => run(["-Restore"])}
            disabled={running}
            className="btn-ghost"
            title="Re-register provisioned apps removed by the debloater"
          >
            <SlidersHorizontal size={15} /> Restore Removed Apps
          </button>
        </div>
      </Section>

      <Section
        icon={MonitorCog}
        title="Legacy Windows Panels"
        subtitle="Open classic control panels"
      >
        <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
          {panels.map((p) => (
            <button
              key={p.id}
              onClick={() => run(["-OpenPanel", p.id])}
              className="btn-ghost !px-2.5 !py-2 text-xs"
            >
              {p.label}
            </button>
          ))}
        </div>
      </Section>

      <Section
        icon={Menu}
        title="Windows 11 Context Menu"
        subtitle="Bypass the compact Win11 right-click menu"
        right={
          <span className="flex items-center gap-1.5">
            <InfoTip text="Creates HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32 with an empty default value, then restarts Explorer. Deleting the key restores the modern menu." />
            <Toggle
              checked={ctxClassic}
              onChange={(v) => {
                setCtxClassic(v);
                run(["-SetContextMenu", v ? "Classic" : "Default"]);
                setTimeout(() => setCtxClassic(false), 2000);
              }}
              size="sm"
            />
          </span>
        }
      >
        <p className="text-xs text-slate-500 dark:text-slate-400">
          On — restores the full Windows 10-style context menu. Off — back to the default Win11
          compact menu. Explorer restarts to apply.
        </p>
      </Section>

      <Section
        icon={ListRestart}
        title="Startup Manager"
        subtitle="Control what launches at boot"
        right={
          <button onClick={refreshStartup} className="btn-ghost !px-2.5 !py-1.5 text-xs" title="Refresh startup list">
            <RefreshCw size={13} /> Refresh
          </button>
        }
      >
        {startup.length === 0 ? (
          <p className="rounded-lg border border-slate-200 p-4 text-center text-sm text-slate-400 dark:border-slate-700 dark:text-slate-500">
            Loading startup entries…
          </p>
        ) : (
          <ul className="divide-y divide-slate-200 dark:divide-slate-700">
            {startup.map((s) => (
              <li key={s.id} className="flex items-center justify-between gap-3 py-2">
                <div className="min-w-0">
                  <p className="flex items-center gap-2 text-sm font-medium text-slate-900 dark:text-slate-100">
                    <Power size={13} className={s.enabled ? "text-emerald-500 dark:text-emerald-400" : "text-slate-300 dark:text-slate-600"} />
                    <span className="truncate">{s.name}</span>
                    <span className="badge-neutral shrink-0 px-1.5 py-px text-[9px]">
                      {s.scope}
                    </span>
                  </p>
                  <p className="truncate font-mono text-[11px] text-slate-400 dark:text-slate-500">{s.command}</p>
                </div>
                <div className="flex shrink-0 gap-1.5">
                  <button
                    onClick={() => toggleStartup(s, true)}
                    disabled={running || s.enabled}
                    className="btn-ghost !px-2.5 !py-1 text-[11px]"
                    title="Enable at startup"
                  >
                    Enable
                  </button>
                  <button
                    onClick={() => toggleStartup(s, false)}
                    disabled={running || !s.enabled}
                    className="btn-ghost !px-2.5 !py-1 text-[11px]"
                    title="Disable at startup"
                  >
                    Disable
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </Section>
    </div>
  );
}
