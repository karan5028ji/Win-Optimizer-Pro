import { AlertTriangle, X } from "lucide-react";

export default function ConfirmModal({ title, children, confirmLabel, onConfirm, onClose }) {
  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/60 p-4 dark:bg-black/60">
      <div className="w-full max-w-md rounded-xl border border-slate-200 bg-white p-5 shadow-lg dark:border-slate-700 dark:bg-slate-800 dark:shadow-none">
        <div className="flex items-start justify-between gap-4">
          <div className="flex items-center gap-2.5">
            <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-red-600/10 text-red-600 dark:text-red-400">
              <AlertTriangle size={18} strokeWidth={2} />
            </span>
            <h3 className="text-base font-semibold text-slate-900 dark:text-slate-100">{title}</h3>
          </div>
          <button
            onClick={onClose}
            className="rounded-md p-1 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-900 dark:text-slate-500 dark:hover:bg-slate-700 dark:hover:text-slate-100"
          >
            <X size={16} strokeWidth={2} />
          </button>
        </div>
        <div className="mt-3 text-sm leading-relaxed text-slate-500 dark:text-slate-400">{children}</div>
        <div className="mt-5 flex justify-end gap-2">
          <button onClick={onClose} className="btn-secondary">
            Cancel
          </button>
          <button onClick={onConfirm} className="btn-danger">
            {confirmLabel || "Confirm"}
          </button>
        </div>
      </div>
    </div>
  );
}
