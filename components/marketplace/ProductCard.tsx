import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";

export function ProductCard({ name, price, status }: { name: string; price: string; status: string }) {
  return (
    <Card>
      <div className="aspect-[4/3] rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)]" />
      <div className="mt-3 flex items-start justify-between gap-3">
        <div>
          <h3 className="text-sm font-bold">{name}</h3>
          <p className="mt-1 text-lg font-bold text-[var(--color-primary)]">{price}</p>
        </div>
        <StatusBadge status={status} />
      </div>
    </Card>
  );
}
