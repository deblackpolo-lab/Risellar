import type { ReactNode } from "react";
import { cn } from "@/lib/utils/cn";

export function Card({ title, children, className }: { title?: string; children: ReactNode; className?: string }) {
  return (
    <section className={cn("rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)]", className)}>
      {title ? <h3 className="mb-3 text-base font-bold text-[var(--color-charcoal)]">{title}</h3> : null}
      {children}
    </section>
  );
}
