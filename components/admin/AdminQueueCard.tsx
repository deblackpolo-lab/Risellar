import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";

export function AdminQueueCard({ title, count, status = "Pending" }: { title: string; count: number; status?: string }) {
  return (
    <Card>
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-bold">{title}</h3>
        <StatusBadge status={status} />
      </div>
      <p className="mt-4 text-3xl font-bold text-[var(--color-primary)]">{count}</p>
    </Card>
  );
}
