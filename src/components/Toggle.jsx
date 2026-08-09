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
      className={`group flex w-full items-start gap-3 rounded-lg px-2 py-1.5 text-left transition-colors duration-150 ${
        disabled ? "cursor-not-allowed opacity-40" : "hover:bg-zinc-900"
      }`}
    >
      <span
        className={`relative ${dims} mt-0.5 shrink-0 rounded-full border transition-all duration-200 ease-smooth ${
          checked
            ? "border-accent-500 bg-accent-600 shadow-accent-glow"
            : "border-panel-border bg-zinc-800"
        }`}
      >
        <span
          className={`absolute left-0.5 top-1/2 -translate-y-1/2 ${knob} rounded-full bg-white transition-transform duration-200 ease-smooth ${
            checked ? shift : "translate-x-0"
          }`}
        />
      </span>
      {(label || description) && (
        <span className="min-w-0">
          {label && (
            <span className="block text-sm font-medium text-zinc-200 group-hover:text-zinc-100">
              {label}
            </span>
          )}
          {description && (
            <span className="block text-xs text-zinc-500">{description}</span>
          )}
        </span>
      )}
    </button>
  );
}
