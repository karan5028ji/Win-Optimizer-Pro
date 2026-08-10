import { useEffect, useMemo, useState } from "react";
import { PackageX, RefreshCw, RotateCcw, Search } from "lucide-react";
import { useApp } from "../lib/app-context";
import { getBloatApps } from "../lib/backend";
import Toggle from "./Toggle";
import ConfirmModal from "./ConfirmModal";

export default function Debloater() {
  const { running, run, restorePoint } = useApp();
  const [apps, setApps] = useState([]);
  const [loading, setLoading] = useState(true);
  const [enabled, setEnabled] = useState({});
  const [query, setQuery] = useState("");
  const [confirmOpen, setConfirmOpen] = useState(false);

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

  const filtered = useMemo(() => {
    if (!query.trim()) return apps;
    const q = query.trim().toLowerCase();
    return apps.filter(
      (a) =>
        a.display.toLowerCase().includes(q) ||
        a.name.toLowerCase().includes(q) ||
        a.category.toLowerCase().includes(q)
    );
  }, [apps, query]);

  const grouped = useMemo(() => {
    const map = {};
    for (const app of filtered) {
      (map[app.category] = map[app.category] || []).push(app);
    }
    return map;
  }, [filtered]);

  const selectedNames = Object.entries(enabled)
    .filter(([, v]) => v)
    .map(([k]) => k);

  const removeSelected = () => {
    if (!selectedNames.length) return;
    const args = ["-Debloat", "-Package", selectedNames.join(",")];
    if (restorePoint) args.unshift("-CreateRestorePoint");
    setConfirmOpen(false);
    run(args);
  };

  const categoryAllOn = (cat) => grouped[cat].every((a) => enabled[a.name]);

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
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="section-title">Debloater</h2>
          <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
            Toggle individual pre-installed apps to remove.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button onClick={load} disabled={loading} className="btn-secondary">
            <RefreshCw size={15} strokeWidth={2} className={loading ? "animate-spin" : ""} />
            Refresh
          </button>
          <button
            onClick={() => run(["-Restore"])}
            disabled={running}
            className="btn-ghost"
            title="Re-register removed apps"
          >
            <RotateCcw size={15} strokeWidth={2} /> Restore Apps
          </button>
          <button
            onClick={() => setConfirmOpen(true)}
            disabled={running || selectedNames.length === 0}
            className="btn-danger"
          >
            <PackageX size={15} strokeWidth={2} /> Remove Selected ({selectedNames.length})
          </button>
        </div>
      </div>

      <div className="relative max-w-sm">
        <Search size={15} strokeWidth={2} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={`Search ${apps.length} apps (Ctrl+F)…`}
          className="input py-2 pl-9"
        />
      </div>

      {loading ? (
        <div className="card flex items-center justify-center p-12 text-sm text-slate-500 dark:text-slate-400">
          Loading installed apps…
        </div>
      ) : Object.keys(grouped).length === 0 ? (
        <div className="card p-12 text-center text-sm text-slate-500 dark:text-slate-400">
          {query ? "No apps match your search." : "No matching bloatware found on this system."}
        </div>
      ) : (
        Object.keys(grouped).map((cat) => (
          <section key={cat} className="card overflow-hidden">
            <header className="flex items-center justify-between border-b border-slate-200 bg-slate-50 px-4 py-2.5 dark:border-slate-700 dark:bg-slate-800/60">
              <h3 className="text-sm font-bold uppercase tracking-wider text-teal-700 dark:text-teal-400">
                {cat}
                <span className="ml-2 text-xs font-medium text-slate-500 dark:text-slate-400">
                  {grouped[cat].length} app{grouped[cat].length === 1 ? "" : "s"}
                </span>
              </h3>
              <button
                onClick={() => toggleCategory(cat)}
                className="text-xs font-medium text-slate-500 transition-colors hover:text-teal-700 dark:text-slate-400 dark:hover:text-teal-400"
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

      {confirmOpen && (
        <ConfirmModal
          title="Remove selected apps?"
          confirmLabel={`Remove ${selectedNames.length}`}
          onConfirm={removeSelected}
          onClose={() => setConfirmOpen(false)}
        >
          <p>
            This will uninstall{" "}
            <span className="font-semibold text-slate-900 dark:text-slate-100">{selectedNames.length}</span>{" "}
            pre-installed app{selectedNames.length === 1 ? "" : "s"}.{" "}
            {restorePoint ? (
              <>
                A <span className="font-semibold text-slate-900 dark:text-slate-100">System Restore point</span> will be
                created first, and you can restore removed apps anytime with
                “Restore Apps”.
              </>
            ) : (
              <>
                You have <span className="font-semibold text-amber-600 dark:text-amber-400">restore point</span>{" "}
                disabled — consider turning it on before removing apps.
              </>
            )}
          </p>
        </ConfirmModal>
      )}
    </div>
  );
}
