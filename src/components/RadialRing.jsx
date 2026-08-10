import { useEffect, useState } from "react";

export default function RadialRing({
  value = 0,
  size = 72,
  stroke = 5,
  tone = "text-teal-600",
  label,
}) {
  const [v, setV] = useState(0);

  useEffect(() => {
    const raf = requestAnimationFrame(() => setV(value));
    return () => cancelAnimationFrame(raf);
  }, [value]);

  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const clamped = Math.max(0, Math.min(100, v));

  return (
    <div
      className={`relative inline-flex shrink-0 items-center justify-center ${tone}`}
      style={{ width: size, height: size }}
    >
      <svg width={size} height={size} className="-rotate-90">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          strokeWidth={stroke}
          className="fill-none stroke-slate-200 dark:stroke-slate-700"
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          strokeWidth={stroke}
          strokeLinecap="round"
          stroke="currentColor"
          strokeDasharray={c}
          strokeDashoffset={c - (clamped / 100) * c}
          className="fill-none transition-[stroke-dashoffset] duration-700 ease-out"
        />
      </svg>
      <span className="absolute text-sm font-bold text-slate-900 dark:text-slate-100">
        {Math.round(clamped)}%
      </span>
      {label && (
        <span className="absolute -bottom-5 left-1/2 -translate-x-1/2 whitespace-nowrap text-[10px] font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
          {label}
        </span>
      )}
    </div>
  );
}
