import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";

export function OrderCard({ id, status, total }: { id: string; status: string; total: string }) {
  return (
    <Card>
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-xs text-[var(--color-muted)]">Order ID</p>
          <h3 className="text-sm font-bold">{id}</h3>
        </div>
        <StatusBadge tone="warning">{status}</StatusBadge>
      </div>
      <p className="mt-4 text-lg font-bold text-[var(--color-primary)]">{total}</p>
    </Card>
  );
}
