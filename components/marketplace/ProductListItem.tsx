import { StatusBadge } from "@/components/ui/StatusBadge";

export function ProductListItem({ name, price, stock }: { name: string; price: string; stock: string }) {
  return (
    <div className="flex items-center gap-4 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4 shadow-[var(--shadow-sm)]">
      <div className="h-14 w-14 rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)]" />
      <div className="min-w-0 flex-1">
        <h3 className="truncate text-sm font-bold">{name}</h3>
        <p className="text-sm font-semibold text-[var(--color-primary)]">{price}</p>
      </div>
      <StatusBadge tone={stock.includes("Out") ? "danger" : "success"}>{stock}</StatusBadge>
    </div>
  );
}
