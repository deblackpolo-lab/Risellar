import { BottomNav, MobileShell } from "@/components/layout";
import { PriceBreakdownCard, ProductDetailHero, StockStatusCard } from "@/components/marketplace";
import { Button, Card, Input, StatusBadge } from "@/components/ui";
import { pilotProduct } from "@/lib/mock/pilot-screens";

export function ProductDetailPilot({ id }: { id: string }) {
  const product = id === pilotProduct.id ? pilotProduct : pilotProduct;

  return (
    <MobileShell footer={<BottomNav active="Shop" />} title="Product detail pilot">
      <ProductDetailHero
        category={product.category}
        customerPrice={product.suggestedSellingPrice}
        costLabel="Reseller cost"
        name={product.name}
        resellerMargin={product.resellerMargin}
        status="Sponsored"
        stock={product.stock}
        supplierBasePrice={product.resellerCost}
      />

      <section className="mt-4 grid gap-4">
        <Card title="Profit calculator">
          <div className="space-y-3 text-sm">
            <Row label="Reseller cost" value={product.resellerCost} />
            <Row label="Suggested selling price" value={product.suggestedSellingPrice} />
            <Row label="Max allowed selling price" value={product.maxAllowedPrice} />
            <label className="block">
              <span className="mb-2 block text-sm font-semibold">Reseller margin input</span>
              <Input aria-label="Reseller margin input" defaultValue={product.resellerMargin} />
            </label>
            <div className="rounded-[var(--radius-lg)] bg-[var(--color-primary-subtle)] p-4">
              <p className="text-xs font-semibold text-[var(--color-muted)]">Expected profit</p>
              <p className="mt-1 text-2xl font-bold text-[var(--color-primary)]">{product.expectedProfit}</p>
            </div>
          </div>
        </Card>

        <PriceBreakdownCard
          customerPrice={product.customerPrice}
          labels={{
            supplierBasePrice: "Reseller cost",
            platformMargin: "Platform margin",
            resellerMargin: "Your margin",
            customerPrice: "Customer price"
          }}
          platformMargin="Included in reseller cost"
          resellerMargin={product.resellerMargin}
          supplierBasePrice={product.resellerCost}
        />

        <Card title="Stock and variant">
          <div className="space-y-3 text-sm">
            <Row label="Stock status" value={product.stock} badge={product.stock} />
            <Row label="Variant" value={product.variant} />
          </div>
          <div className="mt-4">
            <StockStatusCard />
          </div>
        </Card>

        <Card title="Delivery and settlement note">
          <p className="text-sm leading-6 text-[var(--color-muted)]">{product.deliveryNote}</p>
          <div className="mt-3 rounded-[var(--radius-md)] border border-[var(--color-warning)]/30 bg-[var(--color-warning-soft)] p-3 text-sm text-[#8A5A00]">
            {product.settlementNote}
          </div>
        </Card>

        <div className="grid grid-cols-2 gap-3">
          <Button>Add to My Shop</Button>
          <Button variant="outline">Share Product</Button>
        </div>
      </section>
    </MobileShell>
  );
}

function Row({ badge, label, value }: { badge?: string; label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-[var(--color-muted)]">{label}</span>
      <span className="flex items-center gap-2 font-bold">
        {value}
        {badge ? <StatusBadge status={badge} /> : null}
      </span>
    </div>
  );
}
