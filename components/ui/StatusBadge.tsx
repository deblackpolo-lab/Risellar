import { cn } from "@/lib/utils/cn";
import { statusToneClasses, type StatusTone } from "@/lib/status/status-tones";
import { getStatusTone } from "@/lib/status/status-definitions";

export function StatusBadge({ children, status, tone }: { children?: string; status?: string; tone?: StatusTone }) {
  const label = status ?? children ?? "";
  const resolvedTone = tone ?? getStatusTone(label);

  return (
    <span className={cn("inline-flex rounded-full border px-3 py-1 text-xs font-semibold", statusToneClasses[resolvedTone])}>
      {label}
    </span>
  );
}
