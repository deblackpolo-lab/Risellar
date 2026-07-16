import type { HTMLAttributes, ReactNode } from "react";
import { cn } from "@/lib/utils/cn";

export function ScrollableChipRow({
  children,
  className,
  ...props
}: HTMLAttributes<HTMLDivElement> & { children: ReactNode }) {
  return (
    <div
      className={cn(
        "scrollbar-none flex max-w-full gap-2 overflow-x-auto overflow-y-hidden overscroll-x-contain pb-1",
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
}
