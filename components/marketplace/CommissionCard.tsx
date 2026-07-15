import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";

export function CommissionCard({ amount }: { amount: string }) {
  return (
    <Card>
      <StatusBadge status="Commission Pending" />
      <p className="mt-4 text-2xl font-bold text-[var(--color-primary)]">{amount}</p>
      <p className="mt-1 text-sm text-[var(--color-muted)]">Available after settlement verification.</p>
    </Card>
  );
}
