import type { InputHTMLAttributes } from "react";
import { cn } from "@/lib/utils/cn";

type InputState = "default" | "error" | "success";

const stateClasses: Record<InputState, string> = {
  default: "border-[var(--color-border)] focus:border-[var(--color-primary)] focus:ring-[var(--color-primary-soft)]",
  error: "border-[var(--color-danger)] focus:border-[var(--color-danger)] focus:ring-[var(--color-danger-soft)]",
  success: "border-[var(--color-success)] focus:border-[var(--color-success)] focus:ring-[var(--color-success-soft)]"
};

export function Input({ className, state = "default", ...props }: InputHTMLAttributes<HTMLInputElement> & { state?: InputState }) {
  return (
    <input
      className={cn(
        "h-11 w-full rounded-[var(--radius-md)] border bg-white px-4 text-sm text-[var(--color-charcoal)] outline-none transition focus:ring-2 disabled:cursor-not-allowed disabled:bg-[var(--color-muted-soft)] disabled:text-[var(--color-muted)]",
        stateClasses[state],
        className
      )}
      {...props}
    />
  );
}
