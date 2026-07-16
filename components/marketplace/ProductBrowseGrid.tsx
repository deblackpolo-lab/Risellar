import type { ReactNode } from "react";
import { cn } from "@/lib/utils/cn";

export function ProductBrowseGrid({
  children,
  ariaLabel,
  className
}: {
  children: ReactNode;
  ariaLabel: string;
  className?: string;
}) {
  return (
    <div
      aria-label={ariaLabel}
      className={cn("grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4", className)}
      role="list"
    >
      {children}
    </div>
  );
}
