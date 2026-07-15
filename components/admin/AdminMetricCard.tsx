import { Card } from "@/components/ui/Card";

export function AdminMetricCard({ label, value, trend }: { label: string; value: string; trend: string }) {
  return (
    <Card>
      <p className="text-sm text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 text-2xl font-bold">{value}</p>
      <p className="mt-1 text-xs font-semibold text-[var(--color-success)]">{trend}</p>
    </Card>
  );
}
