import type { TextareaHTMLAttributes } from "react";
import { cn } from "@/lib/utils/cn";

type TextareaState = "default" | "error" | "success";

const stateClasses: Record<TextareaState, string> = {
  default: "border-[var(--color-border)] focus:border-[var(--color-primary)] focus:ring-[var(--color-primary-soft)]",
  error: "border-[var(--color-danger)] focus:border-[var(--color-danger)] focus:ring-[var(--color-danger-soft)]",
  success: "border-[var(--color-success)] focus:border-[var(--color-success)] focus:ring-[var(--color-success-soft)]"
};

export function Textarea({
  className,
  state = "default",
  ...props
}: TextareaHTMLAttributes<HTMLTextAreaElement> & { state?: TextareaState }) {
  return (
    <textarea
      className={cn(
        "min-h-28 w-full rounded-[var(--radius-md)] border bg-white px-4 py-3 text-sm text-[var(--color-charcoal)] outline-none focus:ring-2 disabled:cursor-not-allowed disabled:bg-[var(--color-muted-soft)] disabled:text-[var(--color-muted)]",
        stateClasses[state],
        className
      )}
      {...props}
    />
  );
}
