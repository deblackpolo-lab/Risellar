import { cn } from "@/lib/utils/cn";

export function Tabs({ items, active }: { items: string[]; active: string }) {
  return (
    <div className="flex flex-wrap gap-2">
      {items.map((item) => (
        <button
          className={cn(
            "rounded-full border px-4 py-2 text-sm font-medium",
            item === active
              ? "border-[var(--color-primary)] bg-[var(--color-primary)] text-white"
              : "border-[var(--color-border)] bg-white text-[var(--color-muted)]"
          )}
          key={item}
          type="button"
        >
          {item}
        </button>
      ))}
    </div>
  );
}
