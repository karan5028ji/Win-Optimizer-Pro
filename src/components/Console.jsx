import { useEffect, useRef, useState } from "react";
import { ChevronDown, ChevronUp, Eraser, Square, Terminal } from "lucide-react";
import { useApp } from "../lib/app-context";

export default function Console({ running, progress, onCancel }) {
  const { logs, statusLine, clearLogs } = useApp();
  const [expanded, setExpanded] = useState(true);
  const [height, setHeight] = useState(48);
  const [elapsed, setElapsed] = useState(0);
  const bodyRef = useRef(null);
  const startRef = useRef(null);

  useEffect(() => {
    if (bodyRef.current) {
      bodyRef.current.scrollTop = bodyRef.current.scrollHeight;
    }
  }, [logs]);

  useEffect(() => {
    if (running) {
      startRef.current = Date.now();
      setElapsed(0);
      const id = setInterval(
        () => setElapsed(Math.floor((Date.now() - startRef.current) / 1000)),
        1000
      );
      return () => clearInterval(id);
    }
    setElapsed(0);
  }, [running]);

  const fmt = (s) => {
    if (s < 60) return `${s}s`;
    return `${Math.floor(s / 60)}m${String(s % 60).padStart(2, "0")}s`;
  };

  return (
    <section className="shrink-0 border-t border-slate-200 bg-white dark:border-slate-700 dark:bg-slate-900">
      <div className="flex h-9 items-center gap-2 px-4">
        <button
          onClick={() => {
            setExpanded(!expanded);
            setHeight(expanded ? 0 : 48);
          }}
          className="flex items-center gap-2 rounded px-2 py-1 text-xs font-semibold text-slate-500 transition-colors hover:text-slate-900 dark:text-slate-400 dark:hover:text-slate-100"
        >
          <Terminal size={14} strokeWidth={2} className="text-teal-600 dark:text-teal-400" />
          Console
          {expanded ? <ChevronDown size={14} /> : <ChevronUp size={14} />}
        </button>

        <div className="mx-3 h-4 w-px bg-slate-200 dark:bg-slate-700" />

        <div className="flex min-w-0 flex-1 items-center gap-2">
          {running ? (
            <>
              <div className="relative h-1 w-40 shrink-0 overflow-hidden rounded-full bg-slate-200 dark:bg-slate-700">
                {progress?.pct != null ? (
                  <div
                    className="absolute inset-y-0 left-0 rounded-full bg-teal-600 transition-[width] duration-300 ease-smooth"
                    style={{ width: `${progress.pct}%` }}
                  />
                ) : (
                  <div className="animate-bar absolute inset-y-0 w-1/3 rounded-full bg-teal-600" />
                )}
              </div>
              <span className="min-w-0 flex-1 truncate font-mono text-xs text-teal-700 dark:text-teal-400">
                <span className="font-semibold">
                  Running —{" "}
                  {progress?.pct != null ? `${progress.pct}%` : "…"}
                </span>
                {progress?.message || statusLine
                  ? ` · ${progress?.message || statusLine}`
                  : ""}
              </span>
              <span className="shrink-0 font-mono text-[10px] tabular-nums text-slate-400 dark:text-slate-500">
                {fmt(elapsed)}
              </span>
              <button
                onClick={onCancel}
                className="btn-danger !px-2.5 !py-1 text-xs"
              >
                <Square size={11} /> Stop
              </button>
            </>
          ) : (
            <span className="text-xs text-slate-400 dark:text-slate-500">
              {logs.length > 0 ? "Finished" : "Ready"}
            </span>
          )}
        </div>

        <button
          onClick={clearLogs}
          className="btn-ghost !px-2 !py-1 text-xs"
          title="Clear"
        >
          <Eraser size={13} />
        </button>
      </div>

      <div
        style={{ height }}
        className="overflow-hidden transition-all duration-300 ease-smooth"
      >
        <pre
          ref={bodyRef}
          className="h-full overflow-y-auto border-t border-slate-200 bg-slate-50 px-4 py-3 font-mono text-[12px] leading-relaxed text-slate-500 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-400"
        >
          {logs.length === 0 ? "Waiting for output…\n" : logs.slice(-300).join("")}
        </pre>
      </div>
    </section>
  );
}
