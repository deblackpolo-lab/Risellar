import { AlertTriangle, CheckCircle2, Info } from "lucide-react";
import { cn } from "@/lib/utils/cn";
import type { StatusTone } from "@/lib/status/status-tones";

const toneStyles: Record<StatusTone, string> = {
  success: "border-[var(--color-success)]/20 bg-[var(--color-success-soft)] text-[var(--color-success)]",
  warning: "border-[var(--color-warning)]/30 bg-[var(--color-warning-soft)] text-[#8A5A00]",
  danger: "border-[var(--color-danger)]/20 bg-[var(--color-danger-soft)] text-[var(--color-danger)]",
  info: "border-[var(--color-info)]/20 bg-[var(--color-info-soft)] text-[var(--color-info)]",
  neutral: "border-[var(--color-border)] bg-white text-[var(--color-muted)]"
};

export function Alert({ title, tone = "info" }: { title: string; tone?: StatusTone }) {
  const Icon = tone === "success" ? CheckCircle2 : tone === "warning" || tone === "danger" ? AlertTriangle : Info;
  return (
    <div className={cn("flex items-center gap-3 rounded-[var(--radius-md)] border p-4 text-sm", toneStyles[tone])}>
      <Icon className="h-5 w-5 shrink-0" aria-hidden />
      <span className="font-semibold">{title}</span>
    </div>
  );
}
