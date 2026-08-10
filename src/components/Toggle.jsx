export default function Toggle({
  checked,
  onChange,
  label,
  description,
  disabled = false,
  size = "md",
}) {
  const dims = size === "sm" ? "h-5 w-9" : "h-6 w-11";
  const knob = size === "sm" ? "h-3.5 w-3.5" : "h-4 w-4";
  const shift = size === "sm" ? "translate-x-[18px]" : "translate-x-6";

  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={`group flex w-full items-start gap-3 rounded-lg px-2 py-1.5 text-left transition-all duration-200 ${
        disabled
          ? "cursor-not-allowed opacity-40"
          : "hover:-translate-y-0.5 hover:bg-slate-100 dark:hover:bg-slate-700/50"
      }`}
    >
      <span
        className={`relative ${dims} mt-0.5 shrink-0 rounded-full border transition-colors duration-200 ${
          checked
            ? "border-teal-600 bg-teal-600"
            : "border-slate-300 bg-slate-200 dark:border-slate-600 dark:bg-slate-700"
        }`}
      >
        <span
          className={`absolute left-0.5 top-1/2 -translate-y-1/2 ${knob} rounded-full bg-white shadow-sm transition-transform duration-200 ease-smooth ${
            checked ? shift : "translate-x-0"
          }`}
        />
      </span>
      {(label || description) && (
        <span className="min-w-0">
          {label && (
            <span className="block text-sm font-medium text-slate-900 dark:text-slate-100">
              {label}
            </span>
          )}
          {description && (
            <span className="block text-xs text-slate-500 dark:text-slate-400">
              {description}
            </span>
          )}
        </span>
      )}
    </button>
  );
}
