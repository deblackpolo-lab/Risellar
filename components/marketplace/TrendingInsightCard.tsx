import { TrendingUp } from "lucide-react";
import { Card } from "@/components/ui/Card";

export function TrendingInsightCard() {
  return (
    <Card>
      <TrendingUp className="h-5 w-5 text-[var(--color-primary)]" aria-hidden />
      <h3 className="mt-3 text-sm font-bold">Trending in Accra</h3>
      <p className="mt-1 text-sm text-[var(--color-muted)]">Sneakers and phone accessories are moving fast.</p>
    </Card>
  );
}
