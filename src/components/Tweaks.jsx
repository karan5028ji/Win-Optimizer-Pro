import { useCallback, useEffect, useState } from "react";
import { CheckCircle2, RefreshCw, SlidersHorizontal } from "lucide-react";
import { useApp } from "../lib/app-context";
import { getTweakRegistryInfo, getTweakState } from "../lib/backend";
import Toggle from "./Toggle";
import ConfirmModal from "./ConfirmModal";
import InfoTip from "./InfoTip";

const TWEAKS = [
  {
    id: "telemetry",
    label: "Disable Telemetry",
    desc: "Stop DiagTrack & dmwappushservice, block data collection",
    risk: "essential",
  },
  {
    id: "backgroundapps",
    label: "Block Background Apps",
    desc: "Deny apps from running in the background by default",
    risk: "essential",
  },
  {
    id: "hibernation",
    label: "Disable Hibernation",
    desc: "powercfg /h off — reclaims hiberfil.sys",
    risk: "advanced",
  },
  {
    id: "faststartup",
    label: "Disable Fast Startup",
    desc: "Hybrid boot off for a cleaner shutdown",
    risk: "advanced",
  },
  {
    id: "gamebar",
    label: "Disable Game Bar",
    desc: "Xbox Game DVR overlay off",
    risk: "advanced",
  },
  {
    id: "cortana",
    label: "Disable Cortana",
    desc: "Turn off the Cortana assistant",
    risk: "advanced",
  },
  {
    id: "tips",
    label: "Disable Tips & Suggestions",
    desc: "Remove lock-screen tips and consumer suggestions",
    risk: "essential",
  },
  {
    id: "searchweb",
    label: "Disable Bing Web Results",
    desc: "Start search stops pulling Bing results",
    risk: "essential",
  },
];

const PRESETS = {
  Standard: ["telemetry", "backgroundapps", "tips", "searchweb"],
  Minimal: ["telemetry", "searchweb"],
  Advanced: TWEAKS.map((t) => t.id),
};

function RiskBadge({ risk }) {
  return risk === "essential" ? (
    <span className="badge-ok">Recommended</span>
  ) : (
    <span className="badge-warn">Advanced</span>
  );
}

function StateBadge({ applied }) {
  if (applied === null)
    return <span className="text-[10px] font-medium text-slate-400 dark:text-slate-500">checking…</span>;
  return applied ? (
    <span className="badge-neutral">Applied</span>
  ) : (
    <span className="badge-neutral">Not applied</span>
  );
}

export default function Tweaks() {
  const { running, run, restorePoint } = useApp();
  const [enabled, setEnabled] = useState(
    Object.fromEntries(TWEAKS.map((t) => [t.id, false]))
  );
  const [state, setState] = useState({});
  const [stateLoading, setStateLoading] = useState(true);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [regInfo, setRegInfo] = useState({});

  const refreshState = useCallback(async () => {
    setStateLoading(true);
    try {
      setState(await getTweakState());
    } catch {
      setState({});
    } finally {
      setStateLoading(false);
    }
  }, []);

  useEffect(() => {
    refreshState();
    getTweakRegistryInfo().then(setRegInfo).catch(() => {});
  }, [refreshState]);

  const count = Object.values(enabled).filter(Boolean).length;
  const allOn = count === TWEAKS.length;

  const applyPreset = (preset) => {
    const next = Object.fromEntries(TWEAKS.map((t) => [t.id, false]));
    PRESETS[preset].forEach((id) => (next[id] = true));
    setEnabled(next);
  };

  const applySelected = () => {
    const ids = TWEAKS.filter((t) => enabled[t.id]).map((t) => t.id);
    if (!ids.length) return;
    const args = ["-Tweaks", "-Tweak", ids.join(",")];
    if (restorePoint) args.unshift("-CreateRestorePoint");
    setConfirmOpen(false);
    run(args);
  };

  const presetButtons = Object.keys(PRESETS).concat("Clear");

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="section-title">System Tweaks</h2>
          <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
            Registry &amp; service tweaks for a leaner Windows. Start with a preset.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button onClick={refreshState} disabled={stateLoading} className="btn-secondary" title="Re-check which tweaks are already applied">
            <RefreshCw size={15} strokeWidth={2} className={stateLoading ? "animate-spin" : ""} />
            Get Installed
          </button>
          <button
            onClick={() => setConfirmOpen(true)}
            disabled={running || count === 0}
            className="btn-primary"
          >
            <SlidersHorizontal size={15} strokeWidth={2} /> Apply Selected ({count})
          </button>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <span className="text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
          Presets
        </span>
        {presetButtons.map((p) => (
          <button
            key={p}
            onClick={() => (p === "Clear" ? setEnabled(Object.fromEntries(TWEAKS.map((t) => [t.id, false]))) : applyPreset(p))}
            className="btn-ghost !px-3 !py-1.5 text-xs"
          >
            {p}
          </button>
        ))}
        <span
          className={`ml-2 text-xs ${
            count === TWEAKS.length ? "text-amber-600 dark:text-amber-400" : "text-slate-400 dark:text-slate-500"
          }`}
        >
          {allOn ? "All tweaks selected — includes advanced changes" : `${count} selected`}
        </span>
      </div>

      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        {TWEAKS.map((t) => (
          <div
            key={t.id}
            className={`card group p-4 transition-all duration-200 ${
              enabled[t.id] ? "border-teal-600 bg-teal-600/5 dark:bg-teal-600/10" : "hover:border-teal-600"
            }`}
          >
            <div className="mb-1.5 flex items-center justify-between gap-2">
              <p className="flex items-center gap-2 text-sm font-medium text-slate-900 dark:text-slate-100">
                <CheckCircle2
                  size={15}
                  strokeWidth={2}
                  className={`transition-colors duration-200 ${
                    enabled[t.id] ? "text-teal-600 dark:text-teal-400" : "text-slate-300 group-hover:text-teal-600 dark:text-slate-600 dark:group-hover:text-teal-400"
                  }`}
                />
                {t.label}
              </p>
              <div className="flex shrink-0 items-center gap-1.5">
                <InfoTip text={regInfo[t.id] || "No registry info available."} />
                <StateBadge applied={state[t.id] ?? null} />
                <RiskBadge risk={t.risk} />
              </div>
            </div>
            <p className="mb-2 pl-7 text-xs text-slate-500 dark:text-slate-400">{t.desc}</p>
            <div className="flex items-center justify-between pl-7">
              <Toggle
                checked={enabled[t.id]}
                onChange={(v) => setEnabled((e) => ({ ...e, [t.id]: v }))}
              />
              {state[t.id] && (
                <span className="text-[10px] text-slate-400 dark:text-slate-500">
                  already applied — re-applying is harmless
                </span>
              )}
            </div>
          </div>
        ))}
      </div>

      {confirmOpen && (
        <ConfirmModal
          title="Apply selected tweaks?"
          confirmLabel={`Apply ${count}`}
          onConfirm={applySelected}
          onClose={() => setConfirmOpen(false)}
        >
          <p>
            This will modify Windows settings for{" "}
            <span className="font-semibold text-slate-900 dark:text-slate-100">{count}</span> tweak
            {count === 1 ? "" : "s"}.{" "}
            {restorePoint ? (
              <>
                A <span className="font-semibold text-slate-900 dark:text-slate-100">System Restore point</span> will be
                created first so you can roll back.
              </>
            ) : (
              <>
                You have <span className="font-semibold text-amber-600 dark:text-amber-400">restore point</span>{" "}
                disabled — consider turning it on first.
              </>
            )}{" "}
            Some tweaks may need a restart to take effect.
          </p>
        </ConfirmModal>
      )}
    </div>
  );
}
