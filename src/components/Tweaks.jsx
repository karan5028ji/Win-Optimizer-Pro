import { useState } from "react";
import { CheckCircle2, SlidersHorizontal } from "lucide-react";
import { useApp } from "../lib/app-context";
import Toggle from "./Toggle";

const TWEAKS = [
  {
    id: "telemetry",
    label: "Disable Telemetry",
    desc: "Stop DiagTrack & dmwappushservice, block data collection",
  },
  {
    id: "backgroundapps",
    label: "Block Background Apps",
    desc: "Deny apps from running in the background by default",
  },
  {
    id: "hibernation",
    label: "Disable Hibernation",
    desc: "powercfg /h off — reclaims hiberfil.sys",
  },
  {
    id: "faststartup",
    label: "Disable Fast Startup",
    desc: "Hybrid boot off for a cleaner shutdown",
  },
  {
    id: "gamebar",
    label: "Disable Game Bar",
    desc: "Xbox Game DVR overlay off",
  },
  {
    id: "cortana",
    label: "Disable Cortana",
    desc: "Turn off the Cortana assistant",
  },
  {
    id: "tips",
    label: "Disable Tips & Suggestions",
    desc: "Remove lock-screen tips and consumer suggestions",
  },
  {
    id: "searchweb",
    label: "Disable Bing Web Results",
    desc: "Start search stops pulling Bing results",
  },
];

export default function Tweaks() {
  const { running, run } = useApp();
  const [enabled, setEnabled] = useState(
    Object.fromEntries(TWEAKS.map((t) => [t.id, false]))
  );

  const count = Object.values(enabled).filter(Boolean).length;
  const allOn = count === TWEAKS.length;

  const applySelected = () => {
    const ids = TWEAKS.filter((t) => enabled[t.id]).map((t) => t.id);
    if (ids.length) run(["-Tweaks", "-Tweak", ids.join(",")]);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="section-title">System Tweaks</h2>
          <p className="mt-1 text-sm text-zinc-500">
            Registry &amp; service tweaks for a leaner Windows.
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setEnabled(Object.fromEntries(TWEAKS.map((t) => [t.id, !allOn])))}
            className="btn-ghost"
          >
            {allOn ? "Clear All" : "Select All"}
          </button>
          <button onClick={applySelected} disabled={running || count === 0} className="btn-accent">
            <SlidersHorizontal size={15} /> Apply Selected ({count})
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        {TWEAKS.map((t) => (
          <div
            key={t.id}
            className={`card group p-4 transition-all duration-200 ${
              enabled[t.id] ? "border-accent-700 shadow-accent-glow" : "hover:border-zinc-700"
            }`}
          >
            <div className="mb-1.5 flex items-center justify-between">
              <p className="flex items-center gap-2 text-sm font-medium text-zinc-200">
                <CheckCircle2
                  size={15}
                  className={`transition-colors duration-200 ${
                    enabled[t.id] ? "text-accent-400" : "text-zinc-600 group-hover:text-accent-400"
                  }`}
                />
                {t.label}
              </p>
            </div>
            <p className="mb-2 pl-7 text-xs text-zinc-500">{t.desc}</p>
            <div className="pl-7">
              <Toggle
                checked={enabled[t.id]}
                onChange={(v) => setEnabled((e) => ({ ...e, [t.id]: v }))}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
