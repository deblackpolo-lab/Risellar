import type { SelectHTMLAttributes } from "react";
import { cn } from "@/lib/utils/cn";

type SelectState = "default" | "error" | "success";

const stateClasses: Record<SelectState, string> = {
  default: "border-[var(--color-border)] focus:border-[var(--color-primary)] focus:ring-[var(--color-primary-soft)]",
  error: "border-[var(--color-danger)] focus:border-[var(--color-danger)] focus:ring-[var(--color-danger-soft)]",
  success: "border-[var(--color-success)] focus:border-[var(--color-success)] focus:ring-[var(--color-success-soft)]"
};

export function Select({
  className,
  children,
  state = "default",
  ...props
}: SelectHTMLAttributes<HTMLSelectElement> & { state?: SelectState }) {
  return (
    <select
      className={cn(
        "h-11 w-full rounded-[var(--radius-md)] border bg-white px-4 text-sm text-[var(--color-charcoal)] outline-none focus:ring-2 disabled:cursor-not-allowed disabled:bg-[var(--color-muted-soft)] disabled:text-[var(--color-muted)]",
        stateClasses[state],
        className
      )}
      {...props}
    >
      {children}
    </select>
  );
}
