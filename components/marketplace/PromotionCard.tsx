import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";

export function PromotionCard() {
  return (
    <Card>
      <StatusBadge tone="warning">Sponsored</StatusBadge>
      <h3 className="mt-3 text-sm font-bold">Boost product</h3>
      <p className="mt-1 text-sm text-[var(--color-muted)]">Promotion request placeholder for later mock actions.</p>
    </Card>
  );
}
