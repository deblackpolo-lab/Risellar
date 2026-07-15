import type { ButtonHTMLAttributes, ReactNode } from "react";
import { cn } from "@/lib/utils/cn";

type ButtonVariant = "primary" | "secondary" | "outline" | "ghost" | "danger" | "soft-warning";
type ButtonSize = "large" | "normal" | "compact" | "table-action";

const variants: Record<ButtonVariant, string> = {
  primary:
    "bg-[var(--color-primary)] text-white shadow-[var(--shadow-sm)] hover:bg-[var(--color-primary-hover)] active:bg-[var(--color-primary-active)]",
  secondary:
    "bg-[var(--color-accent)] text-[var(--color-charcoal)] shadow-[var(--shadow-sm)] hover:brightness-95 active:brightness-90",
  outline:
    "border border-[var(--color-primary)] bg-white text-[var(--color-primary)] hover:bg-[var(--color-primary-subtle)] active:bg-[var(--color-primary-soft)]",
  ghost: "bg-transparent text-[var(--color-primary)] hover:bg-[var(--color-primary-subtle)] active:bg-[var(--color-primary-soft)]",
  danger: "bg-[var(--color-danger)] text-white shadow-[var(--shadow-sm)] hover:brightness-95 active:brightness-90",
  "soft-warning":
    "border border-[var(--color-warning)]/30 bg-[var(--color-warning-soft)] text-[#8A5A00] hover:bg-[var(--color-accent-soft)] active:brightness-95"
};

const sizes: Record<ButtonSize, string> = {
  large: "h-12 px-6 text-base",
  normal: "h-11 px-5 text-sm",
  compact: "h-9 px-4 text-sm",
  "table-action": "h-8 px-3 text-xs"
};

export function Button({
  children,
  className,
  disabled,
  loading = false,
  size = "normal",
  variant = "primary",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  children: ReactNode;
  loading?: boolean;
  size?: ButtonSize;
  variant?: ButtonVariant;
}) {
  return (
    <button
      aria-busy={loading || undefined}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-[var(--radius-md)] font-semibold transition-[var(--transition-fast)] disabled:cursor-not-allowed disabled:opacity-60",
        variants[variant],
        sizes[size],
        className
      )}
      disabled={disabled || loading}
      {...props}
    >
      {loading ? (
        <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-t-transparent" aria-hidden="true" />
      ) : null}
      {children}
    </button>
  );
}
