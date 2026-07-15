import { cn } from "@/lib/utils/cn";

export function RadioCard({
  title,
  description,
  selected
}: {
  title: string;
  description: string;
  selected?: boolean;
}) {
  return (
    <div
      className={cn(
        "rounded-[var(--radius-lg)] border bg-white p-4 shadow-[var(--shadow-sm)]",
        selected ? "border-[var(--color-primary)] bg-[var(--color-primary-subtle)]" : "border-[var(--color-border)]"
      )}
    >
      <div className="text-sm font-semibold">{title}</div>
      <p className="mt-1 text-sm text-[var(--color-muted)]">{description}</p>
    </div>
  );
}
