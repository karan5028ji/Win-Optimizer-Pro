import { useState } from "react";
import {
  LayoutDashboard,
  SprayCan,
  AppWindow,
  SlidersHorizontal,
  Zap,
} from "lucide-react";

const NAV = [
  { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { id: "clean", label: "Deep Clean", icon: SprayCan },
  { id: "debloat", label: "Debloater", icon: AppWindow },
  { id: "tweaks", label: "System Tweaks", icon: SlidersHorizontal },
];

export default function Sidebar({ tab, onTab, running }) {
  const [hover, setHover] = useState(null);
  return (
    <aside className="flex w-60 shrink-0 flex-col border-r border-panel-border bg-panel/40">
      <div className="flex items-center gap-3 px-5 py-5">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-accent-600 shadow-accent-glow">
          <Zap size={18} className="text-white" />
        </div>
        <div>
          <p className="text-sm font-bold tracking-tight text-zinc-100">PC Optimizer</p>
          <p className="text-[11px] text-zinc-500">Power-user suite</p>
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
              <Icon size={17} className={active ? "text-accent-400" : ""} />
              {item.label}
            </button>
          );
        })}
      </nav>

      <div className="mt-auto px-5 py-4">
        <div className="rounded-lg border border-panel-border bg-zinc-950/60 p-3 text-[11px] text-zinc-500">
          <p className="font-semibold text-zinc-400">v0.1.0</p>
          <p className="mt-0.5">
            {running ? "Operation running…" : "Idle · waiting for input"}
          </p>
        </div>
      </div>
    </aside>
  );
}
