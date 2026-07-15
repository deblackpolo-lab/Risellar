import { Card } from "@/components/ui/Card";

export function StockStatusCard() {
  return (
    <Card title="Stock Status">
      <div className="grid grid-cols-2 gap-3 text-sm">
        <Metric label="Total" value="50" />
        <Metric label="Reserved" value="6" />
        <Metric label="Available" value="44" />
        <Metric label="Low threshold" value="3" />
      </div>
    </Card>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] p-3">
      <div className="text-xs text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-lg font-bold text-[var(--color-primary)]">{value}</div>
    </div>
  );
}
