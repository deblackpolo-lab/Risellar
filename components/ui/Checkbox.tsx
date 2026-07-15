import type { InputHTMLAttributes } from "react";
import { cn } from "@/lib/utils/cn";

export function Checkbox({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      type="checkbox"
      className={cn("h-4 w-4 rounded border-[var(--color-border)] accent-[var(--color-primary)]", className)}
      {...props}
    />
  );
}
