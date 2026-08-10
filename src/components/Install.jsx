import { useEffect, useMemo, useState } from "react";
import { Download, PackagePlus, RefreshCw, Search, Trash2, Upload } from "lucide-react";
import { useApp } from "../lib/app-context";
import { getWingetApps } from "../lib/backend";

export default function Install() {
  const { running, run } = useApp();
  const [apps, setApps] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState({});
  const [query, setQuery] = useState("");

  const load = async () => {
    setLoading(true);
    try {
      const rows = await getWingetApps();
      setApps(rows);
      setSelected({});
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
      (a) => a.name.toLowerCase().includes(q) || a.id.toLowerCase().includes(q)
    );
  }, [apps, query]);

  const grouped = useMemo(() => {
    const map = {};
    for (const app of filtered) {
      (map[app.category] = map[app.category] || []).push(app);
    }
    return map;
  }, [filtered]);

  const selectedIds = Object.entries(selected)
    .filter(([, v]) => v)
    .map(([k]) => k);
  const selectedInstalled = selectedIds.filter((id) => apps.find((a) => a.id === id)?.installed);
  const selectedMissing = selectedIds.filter((id) => !apps.find((a) => a.id === id)?.installed);

  const doAction = (action) => {
    const ids = action === "upgrade" ? selectedInstalled : selectedMissing;
    if (!ids.length) return;
    run([
      action === "install" ? "-WingetInstall" : action === "upgrade" ? "-WingetUpgrade" : "-WingetUninstall",
      "-App",
      ids.join(","),
    ]);
  };

  const toggleCat = (cat, on) => {
    setSelected((s) => {
      const copy = { ...s };
      grouped[cat].forEach((a) => (copy[a.id] = on));
      return copy;
    });
  };

  const allOn = (cat) => grouped[cat].every((a) => selected[a.id]);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="section-title">Install Software</h2>
          <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
            Install, upgrade or uninstall popular apps through WinGet.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button onClick={load} disabled={loading} className="btn-secondary">
            <RefreshCw size={15} strokeWidth={2} className={loading ? "animate-spin" : ""} />
            Refresh
          </button>
          <button
            onClick={() => run(["-WingetUpgradeAll"])}
            disabled={running}
            className="btn-secondary"
            title="Upgrade every installed app"
          >
            <Upload size={15} strokeWidth={2} /> Upgrade All
          </button>
          <button
            onClick={() => doAction("uninstall")}
            disabled={running || selectedInstalled.length === 0}
            className="btn-ghost"
            title="Uninstall selected installed apps"
          >
            <Trash2 size={15} strokeWidth={2} /> Uninstall ({selectedInstalled.length})
          </button>
          <button
            onClick={() => doAction("upgrade")}
            disabled={running || selectedInstalled.length === 0}
            className="btn-ghost"
          >
            <PackagePlus size={15} strokeWidth={2} /> Upgrade Selected ({selectedInstalled.length})
          </button>
          <button
            onClick={() => doAction("install")}
            disabled={running || selectedMissing.length === 0}
            className="btn-primary"
          >
            <Download size={15} strokeWidth={2} /> Install Selected ({selectedMissing.length})
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
          Loading WinGet catalog…
        </div>
      ) : Object.keys(grouped).length === 0 ? (
        <div className="card p-12 text-center text-sm text-slate-500 dark:text-slate-400">
          {query ? "No apps match your search." : "WinGet catalog is empty."}
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
                onClick={() => toggleCat(cat, !allOn(cat))}
                className="text-xs font-medium text-slate-500 transition-colors hover:text-teal-700 dark:text-slate-400 dark:hover:text-teal-400"
              >
                {allOn(cat) ? "Deselect all" : "Select all"}
              </button>
            </header>
            <div className="grid grid-cols-1 gap-1 p-2 md:grid-cols-2 xl:grid-cols-3">
              {grouped[cat].map((app) => {
                const isSel = !!selected[app.id];
                return (
                  <button
                    key={app.id}
                    onClick={() => setSelected((s) => ({ ...s, [app.id]: !s[app.id] }))}
                    className={`flex items-start gap-2.5 rounded-lg px-2 py-1.5 text-left transition-colors duration-150 ${
                      isSel ? "bg-teal-600/10" : "hover:bg-slate-100 dark:hover:bg-slate-700/50"
                    }`}
                  >
                    <span
                      className={`mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded border transition-colors ${
                        isSel
                          ? "border-teal-600 bg-teal-600"
                          : "border-slate-300 bg-white dark:border-slate-600 dark:bg-slate-800"
                      }`}
                    >
                      {isSel && (
                        <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                          <path d="M2 5l2 2 4-4" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                        </svg>
                      )}
                    </span>
                    <span className="min-w-0">
                      <span className="block truncate text-sm font-medium text-slate-900 dark:text-slate-100">
                        {app.name}
                        {app.installed && (
                          <span className="badge-ok ml-1.5 align-middle">installed</span>
                        )}
                      </span>
                      <span className="block truncate font-mono text-[11px] text-slate-500 dark:text-slate-400">
                        {app.id}
                      </span>
                    </span>
                  </button>
                );
              })}
            </div>
          </section>
        ))
      )}
    </div>
  );
}
