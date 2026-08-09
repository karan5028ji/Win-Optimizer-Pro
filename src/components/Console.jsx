import { useEffect, useRef, useState } from "react";
import { ChevronDown, ChevronUp, Eraser, Square, Terminal } from "lucide-react";
import { useApp } from "../lib/app-context";

export default function Console({ running, onCancel }) {
  const { logs, clearLogs } = useApp();
  const [expanded, setExpanded] = useState(true);
  const [height, setHeight] = useState(48);
  const bodyRef = useRef(null);

  useEffect(() => {
    if (bodyRef.current) {
      bodyRef.current.scrollTop = bodyRef.current.scrollHeight;
    }
  }, [logs]);

  return (
    <section className="shrink-0 border-t border-panel-border bg-zinc-950">
      <div className="flex h-9 items-center gap-2 px-4">
        <button
          onClick={() => {
            setExpanded(!expanded);
            setHeight(expanded ? 0 : 48);
          }}
          className="flex items-center gap-2 rounded px-2 py-1 text-xs font-semibold text-zinc-400 transition-colors hover:text-zinc-100"
        >
          <Terminal size={14} className="text-accent-500" />
          Console
          {expanded ? <ChevronDown size={14} /> : <ChevronUp size={14} />}
        </button>

        <div className="mx-3 h-4 w-px bg-panel-border" />

        <div className="flex flex-1 items-center gap-2">
          {running ? (
            <>
              <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-zinc-900">
                <div className="h-full w-full origin-left animate-pulse rounded-full bg-gradient-to-r from-accent-700 via-accent-500 to-accent-400" />
              </div>
              <button
                onClick={onCancel}
                className="flex items-center gap-1.5 rounded-md border border-red-600/40 bg-red-600/10 px-2 py-1 text-xs font-semibold text-red-400 transition-colors hover:bg-red-600/20"
              >
                <Square size={11} /> Stop
              </button>
            </>
          ) : (
            <span className="text-xs text-zinc-600">
              {logs.length > 0 ? "Finished" : "Ready"}
            </span>
          )}
        </div>

        <button
          onClick={clearLogs}
          className="flex items-center gap-1.5 rounded-md px-2 py-1 text-xs font-semibold text-zinc-500 transition-colors hover:text-zinc-200"
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
          className="h-full overflow-y-auto border-t border-panel-border bg-[#0a0a0c] px-4 py-3 font-mono text-[12px] leading-relaxed text-zinc-400"
        >
          {logs.length === 0 ? "Waiting for output…\n" : logs.join("")}
        </pre>
      </div>
    </section>
  );
}
