import { useState } from "react";
import { Brush, Globe, Trash2 } from "lucide-react";
import { useApp } from "../lib/app-context";
import Toggle from "./Toggle";

const CLEAN_ITEMS = [
  { id: "UserTemp", label: "%temp%", desc: "Current user temp files", icon: Brush, args: ["-UserTemp"] },
  { id: "WindowsTemp", label: "Windows Temp", desc: "C:\\Windows\\Temp", icon: Brush, args: ["-WindowsTemp"] },
  { id: "Prefetch", label: "Prefetch", desc: "App preload cache", icon: Brush, args: ["-Prefetch"] },
  { id: "FlushDNS", label: "DNS Flush", desc: "ipconfig /flushdns", icon: Globe, args: ["-FlushDNS"] },
  { id: "Chrome", label: "Chrome Cache", desc: "Google Chrome", icon: Globe, args: ["-Chrome"] },
  { id: "Edge", label: "Edge Cache", desc: "Microsoft Edge", icon: Globe, args: ["-Edge"] },
  { id: "Firefox", label: "Firefox Cache", desc: "Mozilla Firefox", icon: Globe, args: ["-Firefox"] },
  { id: "INet", label: "INetCache", desc: "Legacy Internet Explorer", icon: Globe, args: ["-INet"] },
];

const QUICK_CLEAN = ["UserTemp", "WindowsTemp", "FlushDNS"];

export default function DeepClean() {
  const { running, run } = useApp();
  const [selected, setSelected] = useState(() =>
    Object.fromEntries(CLEAN_ITEMS.map((i) => [i.id, false]))
  );

  const toggle = (id) => setSelected((s) => ({ ...s, [id]: !s[id] }));
  const count = Object.values(selected).filter(Boolean).length;
  const allOn = count === CLEAN_ITEMS.length;

  const setAll = () =>
    setSelected(Object.fromEntries(CLEAN_ITEMS.map((i) => [i.id, !allOn])));

  const cleanSelected = () => {
    const args = CLEAN_ITEMS.flatMap((i) => (selected[i.id] ? i.args : []));
    if (args.length) run(args);
  };

  const applyQuickClean = () =>
    setSelected(Object.fromEntries(CLEAN_ITEMS.map((i) => [i.id, QUICK_CLEAN.includes(i.id)])));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="section-title">Deep Clean</h2>
          <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
            Pick exactly what to purge. Locked files are skipped automatically.
          </p>
        </div>
        <div className="flex gap-2">
          <button onClick={applyQuickClean} className="btn-secondary" title="Select %temp%, Windows Temp and DNS flush">
            <Brush size={15} strokeWidth={2} /> Quick Clean
          </button>
          <button onClick={setAll} className="btn-ghost">
            {allOn ? "Clear All" : "Select All"}
          </button>
          <button onClick={cleanSelected} disabled={running || count === 0} className="btn-primary">
            <Trash2 size={15} strokeWidth={2} /> Clean Selected ({count})
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
        {CLEAN_ITEMS.map((item) => {
          const Icon = item.icon;
          return (
            <div
              key={item.id}
              className={`card group p-4 transition-all duration-200 ${
                selected[item.id]
                  ? "border-teal-600 bg-teal-600/5 dark:bg-teal-600/10"
                  : "hover:border-teal-600"
              }`}
            >
              <div className="mb-2 flex items-center gap-2">
                <span
                  className={`rounded-md p-1.5 transition-colors duration-200 ${
                    selected[item.id]
                      ? "bg-teal-600 text-white"
                      : "bg-slate-100 text-slate-500 group-hover:text-teal-600 dark:bg-slate-700 dark:text-slate-400 dark:group-hover:text-teal-400"
                  }`}
                >
                  <Icon size={16} strokeWidth={2} />
                </span>
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-slate-900 dark:text-slate-100">{item.label}</p>
                  <p className="truncate text-xs text-slate-500 dark:text-slate-400">{item.desc}</p>
                </div>
              </div>
              <Toggle
                checked={selected[item.id]}
                onChange={() => toggle(item.id)}
              />
            </div>
          );
        })}
      </div>
    </div>
  );
}
