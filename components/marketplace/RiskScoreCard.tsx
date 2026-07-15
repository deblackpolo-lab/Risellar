import { Card } from "@/components/ui/Card";

export function RiskScoreCard() {
  return (
    <Card title="Trust Score">
      <p className="text-3xl font-bold text-[var(--color-primary)]">88<span className="text-base text-[var(--color-muted)]">/100</span></p>
      <div className="mt-3 h-2 rounded-full bg-[var(--color-muted-soft)]">
        <div className="h-2 w-4/5 rounded-full bg-[var(--color-success)]" />
      </div>
    </Card>
  );
}
