import { useState } from "react";
import {
  LayoutDashboard,
  SprayCan,
  AppWindow,
  SlidersHorizontal,
  Zap,
  Download,
  Wrench,
  Rocket,
} from "lucide-react";

const NAV = [
  { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { id: "install", label: "Install", icon: Download },
  { id: "clean", label: "Deep Clean", icon: SprayCan },
  { id: "debloat", label: "Debloater", icon: AppWindow },
  { id: "tweaks", label: "System Tweaks", icon: SlidersHorizontal },
  { id: "tuning", label: "Tuning", icon: Wrench },
  { id: "profiles", label: "Profiles", icon: Rocket },
];

export default function Sidebar({ tab, onTab, running }) {
  const [hover, setHover] = useState(null);
  return (
    <aside className="flex w-60 shrink-0 flex-col border-r border-slate-200 bg-white dark:border-slate-700 dark:bg-slate-900">
      <div className="flex items-center gap-3 px-5 py-5">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-teal-600">
          <Zap size={18} className="text-white" strokeWidth={2} />
        </div>
        <div>
          <p className="text-sm font-bold tracking-tight text-slate-900 dark:text-slate-100">
            Win-Optimizer-Pro
          </p>
          <p className="text-[11px] text-slate-500 dark:text-slate-400">Power-user suite</p>
        </div>
      </div>

      <nav className="mt-2 flex flex-col gap-1 px-3">
        {NAV.map((item) => {
          const Icon = item.icon;
          const active = tab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => onTab(item.id)}
              onMouseEnter={() => setHover(item.id)}
              onMouseLeave={() => setHover(null)}
              className={`nav-item ${active ? "nav-item-active" : ""} ${
                hover === item.id && !active ? "translate-x-0.5" : ""
              }`}
            >
              <Icon size={17} strokeWidth={2} className={active ? "text-teal-600 dark:text-teal-400" : ""} />
              {item.label}
            </button>
          );
        })}
      </nav>

      <div className="mt-auto px-5 py-4">
        <div className="rounded-lg border border-slate-200 bg-slate-50 p-3 text-[11px] text-slate-500 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-400">
          <p className="font-semibold text-slate-700 dark:text-slate-300">v2.1.4</p>
          <p className="mt-0.5">
            {running ? "Operation running…" : "Idle · waiting for input"}
          </p>
        </div>
      </div>
    </aside>
  );
}
