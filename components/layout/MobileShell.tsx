import type { ReactNode } from "react";
import { cn } from "@/lib/utils/cn";

export function MobileShell({
  children,
  className,
  footer,
  title
}: {
  children: ReactNode;
  className?: string;
  footer?: ReactNode;
  title?: string;
}) {
  return (
    <main className="min-h-screen overflow-x-hidden bg-[var(--color-page)] text-[var(--color-charcoal)]">
      <div className={cn("mx-auto min-h-screen w-full max-w-md px-4 pb-32 pt-5", className)}>
        {title ? <p className="mb-4 text-xs font-bold uppercase text-[var(--color-primary)]">{title}</p> : null}
        {children}
      </div>
      {footer}
    </main>
  );
}
