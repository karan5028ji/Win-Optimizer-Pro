import { useEffect, useMemo, useState } from "react";
import { PackageX, RefreshCw, RotateCcw } from "lucide-react";
import { useApp } from "../lib/app-context";
import { getBloatApps } from "../lib/backend";
import Toggle from "./Toggle";

export default function Debloater() {
  const { running, run } = useApp();
  const [apps, setApps] = useState([]);
  const [loading, setLoading] = useState(true);
  const [enabled, setEnabled] = useState({});

  const load = async () => {
    setLoading(true);
    try {
      const rows = await getBloatApps();
      setApps(rows);
      setEnabled({});
    } catch {
      setApps([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const grouped = useMemo(() => {
    const map = {};
    for (const app of apps) {
      (map[app.category] = map[app.category] || []).push(app);
    }
    return map;
  }, [apps]);

  const selectedNames = Object.entries(enabled)
    .filter(([, v]) => v)
    .map(([k]) => k);

  const removeSelected = () => {
    if (!selectedNames.length) return;
    run(["-Debloat", "-Package", selectedNames.join(",")]);
  };

  const categoryAllOn = (cat) =>
    grouped[cat].every((a) => enabled[a.name]);

  const toggleCategory = (cat) => {
    const next = !categoryAllOn(cat);
    setEnabled((e) => {
      const copy = { ...e };
      grouped[cat].forEach((a) => (copy[a.name] = next));
      return copy;
    });
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="section-title">Debloater</h2>
          <p className="mt-1 text-sm text-zinc-500">
            Toggle individual pre-installed apps to remove.
          </p>
        </div>
        <div className="flex gap-2">
          <button onClick={load} disabled={loading} className="btn-ghost">
            <RefreshCw size={15} className={loading ? "animate-spin" : ""} />
            Refresh
          </button>
          <button
            onClick={() => run(["-Restore"])}
            disabled={running}
            className="btn-ghost"
          >
            <RotateCcw size={15} /> Restore Apps
          </button>
          <button
            onClick={removeSelected}
            disabled={running || selectedNames.length === 0}
            className="btn-danger"
          >
            <PackageX size={15} /> Remove Selected ({selectedNames.length})
          </button>
        </div>
      </div>

      {loading ? (
        <div className="card flex items-center justify-center p-12 text-sm text-zinc-500">
          Loading installed apps…
        </div>
      ) : Object.keys(grouped).length === 0 ? (
        <div className="card p-12 text-center text-sm text-zinc-500">
          No matching bloatware found on this system.
        </div>
      ) : (
        Object.keys(grouped).map((cat) => (
          <section key={cat} className="card overflow-hidden">
            <header className="flex items-center justify-between border-b border-panel-border bg-zinc-950/60 px-4 py-2.5">
              <h3 className="text-sm font-bold uppercase tracking-wider text-accent-400">
                {cat}
              </h3>
              <button
                onClick={() => toggleCategory(cat)}
                className="text-xs font-medium text-zinc-500 transition-colors hover:text-accent-300"
              >
                {categoryAllOn(cat) ? "Deselect all" : "Select all"}
              </button>
            </header>
            <div className="grid grid-cols-1 gap-1 p-2 md:grid-cols-2 xl:grid-cols-3">
              {grouped[cat].map((app) => (
                <Toggle
                  key={app.name}
                  checked={!!enabled[app.name]}
                  onChange={(v) => setEnabled((e) => ({ ...e, [app.name]: v }))}
                  label={app.display}
                  description={app.name}
                />
              ))}
            </div>
          </section>
        ))
      )}
    </div>
  );
}
