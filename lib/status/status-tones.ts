export type StatusTone = "success" | "warning" | "danger" | "info" | "neutral";

export const statusToneClasses: Record<StatusTone, string> = {
  success: "bg-[var(--color-success-soft)] text-[var(--color-success)] border-[var(--color-success)]/20",
  warning: "bg-[var(--color-warning-soft)] text-[#8A5A00] border-[var(--color-warning)]/30",
  danger: "bg-[var(--color-danger-soft)] text-[var(--color-danger)] border-[var(--color-danger)]/20",
  info: "bg-[var(--color-info-soft)] text-[var(--color-info)] border-[var(--color-info)]/20",
  neutral: "bg-[var(--color-muted-soft)] text-[var(--color-muted)] border-[var(--color-border)]"
};
