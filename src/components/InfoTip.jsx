import { HelpCircle } from "lucide-react";

export default function InfoTip({ text }) {
  return (
    <span className="group/tiptip relative inline-flex">
      <HelpCircle
        size={13}
        strokeWidth={2}
        className="cursor-help text-slate-400 transition-colors group-hover/tiptip:text-teal-600 dark:text-slate-500 dark:group-hover/tiptip:text-teal-400"
      />
      <span className="pointer-events-none absolute bottom-full left-1/2 z-50 mb-2 hidden w-72 -translate-x-1/2 group-hover/tiptip:block">
        <span className="block rounded-lg border border-slate-200 bg-white px-3 py-2 text-[11px] font-medium leading-relaxed text-slate-700 shadow-md dark:border-slate-600 dark:bg-slate-700 dark:text-slate-200">
          {text}
        </span>
      </span>
    </span>
  );
}
