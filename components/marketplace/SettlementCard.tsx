import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";

export function SettlementCard({ amount }: { amount: string }) {
  return (
    <Card>
      <StatusBadge status="Settlement Due" />
      <p className="mt-4 text-sm text-[var(--color-muted)]">Supplier must settle Risellar share.</p>
      <p className="mt-2 text-2xl font-bold text-[var(--color-primary)]">{amount}</p>
    </Card>
  );
}
