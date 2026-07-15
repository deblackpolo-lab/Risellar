import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";

export function ProductDetailHero({
  category,
  costLabel = "Supplier base",
  customerPrice,
  name,
  resellerMargin,
  status,
  stock,
  supplierBasePrice
}: {
  category: string;
  costLabel?: string;
  customerPrice: string;
  name: string;
  resellerMargin: string;
  status: string;
  stock: string;
  supplierBasePrice: string;
}) {
  return (
    <Card>
      <div className="grid gap-4 sm:grid-cols-[160px_1fr]">
        <div className="grid aspect-[4/3] place-items-center rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)]">
          <div className="h-16 w-28 rounded-full border-8 border-[var(--color-primary)] bg-white shadow-[var(--shadow-sm)]" />
        </div>
        <div>
          <div className="flex flex-wrap gap-2">
            <StatusBadge status={status} />
            <StatusBadge status={stock} />
          </div>
          <p className="mt-3 text-xs font-semibold uppercase text-[var(--color-muted)]">{category}</p>
          <h3 className="mt-1 text-xl font-bold text-[var(--color-charcoal)]">{name}</h3>
          <p className="mt-2 text-2xl font-bold text-[var(--color-primary)]">{customerPrice}</p>
          <div className="mt-4 grid gap-2 text-sm sm:grid-cols-2">
            <DetailRow label={costLabel} value={supplierBasePrice} />
            <DetailRow label="Reseller margin" value={resellerMargin} />
          </div>
        </div>
      </div>
    </Card>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-page)] px-3 py-2">
      <p className="text-xs text-[var(--color-muted)]">{label}</p>
      <p className="font-bold">{value}</p>
    </div>
  );
}
