import { Card } from "@/components/ui/Card";

export function PriceBreakdownCard({
  supplierBasePrice,
  platformMargin,
  resellerMargin,
  customerPrice,
  labels
}: {
  supplierBasePrice: string;
  platformMargin: string;
  resellerMargin: string;
  customerPrice: string;
  labels?: {
    supplierBasePrice?: string;
    platformMargin?: string;
    resellerMargin?: string;
    customerPrice?: string;
  };
}) {
  const rows = [
    [labels?.supplierBasePrice ?? "Supplier base price", supplierBasePrice],
    [labels?.platformMargin ?? "Risellar margin", platformMargin],
    [labels?.resellerMargin ?? "Reseller margin", resellerMargin],
    [labels?.customerPrice ?? "Customer price", customerPrice]
  ];

  return (
    <Card title="Price Breakdown">
      <div className="space-y-3 text-sm">
        {rows.map(([label, value]) => (
          <div className="flex items-start justify-between gap-4" key={label}>
            <span className="text-[var(--color-muted)]">{label}</span>
            <span className="max-w-[56%] text-right font-bold text-[var(--color-charcoal)]">{value}</span>
          </div>
        ))}
      </div>
    </Card>
  );
}
