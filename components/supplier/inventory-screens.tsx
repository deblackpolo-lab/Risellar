"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { useMemo, useState } from "react";
import { Button, Card, Input, StatusBadge, Textarea } from "@/components/ui";
import { MobileShell } from "@/components/layout";
import { formatGhc } from "@/lib/mock/supplier-core";
import {
  getInventoryProduct,
  getInventorySummary,
  getInventoryVariants,
  supplierInventoryMock,
  type InventoryActivity,
  type InventoryProduct,
  type StockMovement
} from "@/lib/mock/supplier-inventory";
import { cn } from "@/lib/utils/cn";

type InventoryNavKey = "home" | "products" | "inventory" | "orders" | "more";

const navItems: Array<{ key: InventoryNavKey; label: string; href: string; icon: string }> = [
  { key: "home", label: "Home", href: "/supplier/dashboard", icon: "H" },
  { key: "products", label: "Products", href: "/supplier/products", icon: "P" },
  { key: "inventory", label: "Inventory", href: "/supplier/inventory", icon: "I" },
  { key: "orders", label: "Orders", href: "/supplier/orders", icon: "O" },
  { key: "more", label: "More", href: "/supplier/settings", icon: "M" }
];

function InventoryShell({ children, title }: { children: ReactNode; title?: string }) {
  return (
    <MobileShell title={title} footer={<InventoryBottomNav />}>
      {children}
    </MobileShell>
  );
}

function InventoryBottomNav() {
  return (
    <nav aria-label="Supplier inventory navigation" className="fixed inset-x-0 bottom-0 z-20 border-t border-[var(--color-border)] bg-white/95 px-3 py-2 backdrop-blur">
      <div className="mx-auto grid max-w-md grid-cols-5 gap-1">
        {navItems.map((item) => (
          <Link
            key={item.key}
            href={item.href}
            className={cn(
              "flex min-h-12 flex-col items-center justify-center gap-1 rounded-[var(--radius-md)] text-[11px] font-semibold text-[var(--color-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-soft)]",
              item.key === "inventory" && "bg-[var(--color-primary-subtle)] text-[var(--color-primary)]"
            )}
          >
            <span
              aria-hidden="true"
              className={cn(
                "grid h-5 w-5 place-items-center rounded-full border border-[var(--color-border)] text-[10px]",
                item.key === "inventory" && "border-[var(--color-primary)] bg-[var(--color-primary)] text-white"
              )}
            >
              {item.icon}
            </span>
            {item.label}
          </Link>
        ))}
      </div>
    </nav>
  );
}

function InventoryHeader({ title, description }: { title: string; description?: string }) {
  return (
    <header className="mb-5 space-y-2">
      <p className="text-xs font-bold uppercase text-[var(--color-primary)]">Supplier inventory</p>
      <h1 className="text-2xl font-extrabold tracking-normal text-[var(--color-charcoal)]">{title}</h1>
      {description ? <p className="text-sm leading-6 text-[var(--color-muted)]">{description}</p> : null}
    </header>
  );
}

function ProductImageTile({ product, className }: { product: Pick<InventoryProduct, "imageLabel" | "name">; className?: string }) {
  return (
    <div
      aria-label={`${product.name} image placeholder`}
      className={cn(
        "grid aspect-square place-items-center rounded-[var(--radius-lg)] bg-[linear-gradient(135deg,var(--color-primary-subtle),var(--color-accent-soft))] text-lg font-extrabold text-[var(--color-primary)]",
        className
      )}
    >
      {product.imageLabel}
    </div>
  );
}

function StockStatusBadge({ status }: { status: string }) {
  const tone = status === "Out of Stock" ? "danger" : status === "Low Stock" || status === "Only 1 left" || status === "Needs Review" || status === "Price Change Pending" ? "warning" : "success";
  return <StatusBadge tone={tone}>{status}</StatusBadge>;
}

function InventoryDashboardCard({ title, children }: { title: string; children: ReactNode }) {
  return <Card title={title}>{children}</Card>;
}

function StockMetricCard({ label, value, detail, tone = "neutral" }: { label: string; value: string; detail: string; tone?: "success" | "warning" | "danger" | "info" | "neutral" }) {
  const toneClasses = {
    success: "border-[var(--color-success)]/20 bg-[var(--color-success-soft)]",
    warning: "border-[var(--color-warning)]/25 bg-[var(--color-warning-soft)]",
    danger: "border-[var(--color-danger)]/20 bg-[var(--color-danger-soft)]",
    info: "border-[var(--color-info)]/20 bg-[var(--color-info-soft)]",
    neutral: "border-[var(--color-border)] bg-white"
  };

  return (
    <Card className={cn("p-4", toneClasses[tone])}>
      <p className="text-xs font-bold uppercase text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 text-2xl font-extrabold text-[var(--color-charcoal)]">{value}</p>
      <p className="mt-1 text-xs leading-5 text-[var(--color-muted)]">{detail}</p>
    </Card>
  );
}

function InventoryProductCard({ product }: { product: InventoryProduct }) {
  return (
    <Card className="p-4">
      <div className="flex gap-3">
        <ProductImageTile product={product} className="h-20 w-20 shrink-0" />
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-2">
            <div>
              <h3 className="text-base font-bold leading-5 text-[var(--color-charcoal)]">{product.name}</h3>
              <p className="mt-1 text-xs text-[var(--color-muted)]">{product.category}</p>
            </div>
            <StockStatusBadge status={product.stockStatus} />
          </div>
          <dl className="mt-3 grid grid-cols-3 gap-2 text-sm">
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Total</dt>
              <dd className="font-bold">{product.totalStock}</dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Reserved</dt>
              <dd className="font-bold">{product.reservedStock}</dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Available</dt>
              <dd className="font-bold text-[var(--color-primary)]">{product.availableStock}</dd>
            </div>
          </dl>
          <div className="mt-3 flex items-center justify-between">
            <p className="text-sm font-bold text-[var(--color-primary)]">{formatGhc(product.supplierBasePrice)}</p>
            <Link href={`/supplier/inventory/${product.id}`} className="text-sm font-bold text-[var(--color-primary)]">
              View stock
            </Link>
          </div>
        </div>
      </div>
    </Card>
  );
}

function StockStateGuide({ children, tone = "warning" }: { children: ReactNode; tone?: "warning" | "success" | "danger" }) {
  const className =
    tone === "success"
      ? "border-[var(--color-success)]/25 bg-[var(--color-success-soft)] text-[var(--color-primary)]"
      : tone === "danger"
        ? "border-[var(--color-danger)]/25 bg-[var(--color-danger-soft)] text-[var(--color-danger)]"
        : "border-[var(--color-warning)]/25 bg-[var(--color-warning-soft)] text-[#7A5300]";
  return <div className={cn("rounded-[var(--radius-md)] border p-3 text-sm font-semibold leading-6", className)}>{children}</div>;
}

function VariantStockTable({ productId }: { productId: string }) {
  const variants = getInventoryVariants(productId);

  return (
    <Card title="Variant stock">
      <div className="space-y-3">
        {variants.map((variant) => (
          <div key={variant.id} className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3">
            <div className="flex items-start justify-between gap-2">
              <div>
                <h3 className="font-bold text-[var(--color-charcoal)]">{variant.label}</h3>
                <p className="text-xs text-[var(--color-muted)]">{variant.color} · {variant.model}</p>
              </div>
              <StockStatusBadge status={variant.status} />
            </div>
            <dl className="mt-3 grid grid-cols-4 gap-2 text-xs">
              <div>
                <dt className="text-[var(--color-muted)]">Total</dt>
                <dd className="font-bold">{variant.totalStock}</dd>
              </div>
              <div>
                <dt className="text-[var(--color-muted)]">Reserved</dt>
                <dd className="font-bold">{variant.reservedStock}</dd>
              </div>
              <div>
                <dt className="text-[var(--color-muted)]">Available</dt>
                <dd className="font-bold text-[var(--color-primary)]">{variant.availableStock}</dd>
              </div>
              <div>
                <dt className="text-[var(--color-muted)]">Threshold</dt>
                <dd className="font-bold">{variant.lowStockThreshold}</dd>
              </div>
            </dl>
          </div>
        ))}
      </div>
    </Card>
  );
}

function RestockForm({ product }: { product: InventoryProduct }) {
  const [quantity, setQuantity] = useState(12);
  const [saved, setSaved] = useState(false);
  const newTotal = product.totalStock + quantity;

  return (
    <Card title="Restock details">
      <div className="space-y-4">
        <div className="grid grid-cols-2 gap-3">
          <StockMetricCard label="Current stock" value={String(product.totalStock)} detail="Before restock" />
          <StockMetricCard label="New stock total preview" value={String(newTotal)} detail="Mock preview only" tone="success" />
        </div>
        <label className="space-y-2 text-sm font-semibold">
          <span>Quantity to add</span>
          <Input aria-label="Quantity to add" type="number" value={quantity} onChange={(event) => setQuantity(Number(event.currentTarget.value))} />
        </label>
        <label className="space-y-2 text-sm font-semibold">
          <span>Restock note</span>
          <Textarea aria-label="Restock note" defaultValue="Received fresh supplier stock." />
        </label>
        <label className="space-y-2 text-sm font-semibold">
          <span>Batch or source note</span>
          <Input aria-label="Batch or source note" defaultValue="Batch AF1-0726 from KNUST shop" />
        </label>
        {saved ? (
          <div role="status" className="rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] p-3 text-sm font-semibold text-[var(--color-primary)]">
            Restock recorded for this mock session.
          </div>
        ) : null}
        <Button className="w-full" onClick={() => setSaved(true)}>
          Confirm Restock
        </Button>
      </div>
    </Card>
  );
}

function StockMovementTimeline({ movements }: { movements: StockMovement[] }) {
  return (
    <Card title="Movement timeline">
      <div className="space-y-3">
        {movements.map((movement) => (
          <div key={movement.id} className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3">
            <div className="flex items-start justify-between gap-3">
              <div>
                <StatusBadge tone={movement.quantityChange.startsWith("+") ? "success" : "warning"}>{movement.type}</StatusBadge>
                <p className="mt-2 font-bold text-[var(--color-charcoal)]">{movement.actor}</p>
                <p className="text-xs text-[var(--color-muted)]">{movement.role} · {movement.timestamp}</p>
              </div>
              <p className={cn("text-lg font-extrabold", movement.quantityChange.startsWith("+") ? "text-[var(--color-primary)]" : "text-[var(--color-danger)]")}>{movement.quantityChange}</p>
            </div>
            <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">{movement.note}</p>
            {movement.relatedOrderId ? <p className="mt-2 text-xs font-bold text-[var(--color-primary)]">{movement.relatedOrderId}</p> : null}
          </div>
        ))}
      </div>
    </Card>
  );
}

function PriceChangeRequestCard({ product }: { product: InventoryProduct }) {
  const [submitted, setSubmitted] = useState(false);

  return (
    <Card title="Price change request">
      <div className="space-y-4">
        <div className="rounded-[var(--radius-md)] bg-[var(--color-page)] p-3">
          <p className="text-xs text-[var(--color-muted)]">Current supplier base price</p>
          <p className="text-xl font-extrabold text-[var(--color-primary)]">{formatGhc(product.supplierBasePrice)}</p>
        </div>
        <label className="space-y-2 text-sm font-semibold">
          <span>New requested base price</span>
          <Input aria-label="New requested base price" defaultValue="GH₵330" />
        </label>
        <label className="space-y-2 text-sm font-semibold">
          <span>Effective date</span>
          <Input aria-label="Effective date" type="date" defaultValue="2026-07-25" />
        </label>
        <label className="space-y-2 text-sm font-semibold">
          <span>Reason for change</span>
          <Textarea aria-label="Reason for change" defaultValue="Supplier price increase and new batch pricing." />
        </label>
        <StockStateGuide>Existing orders keep their original price.</StockStateGuide>
        <StockStateGuide>Price changes may require admin approval.</StockStateGuide>
        <StockStateGuide>Reseller listings may require review after price changes.</StockStateGuide>
        <div className="flex items-center justify-between">
          <span className="text-sm font-bold">Request status</span>
          <StatusBadge tone="warning">Needs Review</StatusBadge>
        </div>
        {submitted ? (
          <div role="status" className="rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] p-3 text-sm font-semibold text-[var(--color-primary)]">
            Price change request submitted for review.
          </div>
        ) : null}
        <Button className="w-full" onClick={() => setSubmitted(true)}>
          Submit Price Change Request
        </Button>
      </div>
    </Card>
  );
}

function InventoryActivityItem({ activity }: { activity: InventoryActivity }) {
  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-bold text-[var(--color-charcoal)]">{activity.actor}</p>
          <p className="mt-1 text-xs text-[var(--color-muted)]">{activity.role} · {activity.timestamp}</p>
        </div>
        <StatusBadge tone={activity.type === "Reservation" ? "info" : activity.type === "Restock" ? "success" : "warning"}>{activity.type}</StatusBadge>
      </div>
      <p className="mt-3 text-sm leading-6 text-[var(--color-charcoal)]">{activity.action}</p>
      <p className="text-xs font-semibold text-[var(--color-muted)]">{activity.product}</p>
      <p className="mt-2 text-sm font-bold text-[var(--color-primary)]">{activity.beforeAfter}</p>
    </Card>
  );
}

function LowStockAlertCard({ product, outOfStock = false }: { product: InventoryProduct; outOfStock?: boolean }) {
  return (
    <Card className="p-4">
      <div className="flex gap-3">
        <ProductImageTile product={product} className="h-16 w-16 shrink-0" />
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-2">
            <h3 className="font-bold text-[var(--color-charcoal)]">{product.name}</h3>
            <StockStatusBadge status={product.stockStatus} />
          </div>
          <dl className="mt-3 grid grid-cols-2 gap-2 text-sm">
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Available</dt>
              <dd className="font-bold">{product.availableStock}</dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Affected reseller listings</dt>
              <dd className="font-bold">{product.affectedListings}</dd>
            </div>
          </dl>
          {outOfStock ? <p className="mt-2 text-sm font-semibold text-[var(--color-danger)]">This product cannot receive new customer orders.</p> : null}
          <Link href={`/supplier/inventory/${product.id}/restock`} className="mt-3 inline-flex h-10 w-full items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] text-sm font-bold text-white">
            Restock
          </Link>
        </div>
      </div>
    </Card>
  );
}

export function InventoryDashboardScreen() {
  const summary = getInventorySummary();

  return (
    <InventoryShell title="Inventory dashboard">
      <InventoryHeader title="Inventory" description="Manage stock, variants, movement history, and low stock alerts." />
      <Card className="mb-4 bg-[var(--color-primary)] text-white">
        <p className="text-sm font-semibold text-white/80">{supplierInventoryMock.supplier.businessName}</p>
        <p className="mt-1 text-2xl font-extrabold">Stock control center</p>
        <p className="mt-2 text-sm leading-6 text-white/80">Stock accuracy protects customers, resellers, and supplier trust.</p>
      </Card>
      <div className="grid grid-cols-2 gap-3">
        <StockMetricCard label="Inventory value" value={formatGhc(summary.inventoryValue)} detail="Supplier base value" tone="success" />
        <StockMetricCard label="Total products" value={String(summary.totalProducts)} detail="Tracked products" />
        <StockMetricCard label="Available stock" value={String(summary.availableStock)} detail="Can still sell/order" tone="success" />
        <StockMetricCard label="Reserved stock" value={String(summary.reservedStock)} detail="Held for orders" tone="info" />
        <StockMetricCard label="Low stock alerts" value={String(summary.lowStockAlerts)} detail="Below threshold" tone="warning" />
        <StockMetricCard label="Out-of-stock items" value={String(summary.outOfStockItems)} detail="Blocked from orders" tone="danger" />
        <StockMetricCard label="Price change requests" value={String(summary.priceChangeRequests)} detail="Needs review" tone="warning" />
      </div>
      <InventoryDashboardCard title="Quick actions">
        <div className="grid grid-cols-2 gap-2">
          <Button>Add Product</Button>
          <Button variant="outline">Restock</Button>
          <Link href="/supplier/inventory/low-stock" className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">View Low Stock</Link>
          <Link href="/supplier/inventory/out-of-stock" className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">View Out of Stock</Link>
          <Link href="/supplier/inventory/activity" className="col-span-2 inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">Activity Log</Link>
        </div>
      </InventoryDashboardCard>
      <InventoryDashboardCard title="Recent stock activity">
        <div className="space-y-3">
          {supplierInventoryMock.activity.slice(0, 3).map((activity) => (
            <InventoryActivityItem key={activity.id} activity={activity} />
          ))}
        </div>
      </InventoryDashboardCard>
      <InventoryDashboardCard title="Tracked products">
        <div className="space-y-3">
          {supplierInventoryMock.products.map((product) => (
            <InventoryProductCard key={product.id} product={product} />
          ))}
        </div>
      </InventoryDashboardCard>
    </InventoryShell>
  );
}

export function InventoryProductDetailScreen({ productId }: { productId: string }) {
  const product = getInventoryProduct(productId);

  return (
    <InventoryShell title="Product inventory">
      <ProductImageTile product={product} className="mb-4 w-full" />
      <div className="mb-4 flex items-start justify-between gap-3">
        <h1 className="text-2xl font-extrabold text-[var(--color-charcoal)]">{product.name}</h1>
        <StockStatusBadge status={product.stockStatus} />
      </div>
      <Card>
        <p className="text-sm font-semibold text-[var(--color-muted)]">{product.category}</p>
        <dl className="mt-4 grid grid-cols-2 gap-4 text-sm">
          <div><dt className="text-xs text-[var(--color-muted)]">Supplier base price</dt><dd className="font-bold text-[var(--color-primary)]">{formatGhc(product.supplierBasePrice)}</dd></div>
          <div><dt className="text-xs text-[var(--color-muted)]">Status</dt><dd><StatusBadge status={product.status} /></dd></div>
          <div><dt className="text-xs text-[var(--color-muted)]">Total stock</dt><dd className="font-bold">{product.totalStock}</dd></div>
          <div><dt className="text-xs text-[var(--color-muted)]">Reserved stock</dt><dd className="font-bold">{product.reservedStock}</dd></div>
          <div><dt className="text-xs text-[var(--color-muted)]">Available stock</dt><dd className="font-bold text-[var(--color-primary)]">{product.availableStock}</dd></div>
          <div><dt className="text-xs text-[var(--color-muted)]">Sold stock</dt><dd className="font-bold">{product.soldStock}</dd></div>
          <div><dt className="text-xs text-[var(--color-muted)]">Low stock threshold</dt><dd className="font-bold">{product.lowStockThreshold}</dd></div>
          <div><dt className="text-xs text-[var(--color-muted)]">Active resellers</dt><dd className="font-bold">{product.activeResellers}</dd></div>
          <div><dt className="text-xs text-[var(--color-muted)]">Recent orders</dt><dd className="font-bold">{product.recentOrders}</dd></div>
        </dl>
      </Card>
      <StockStateGuide>Reserved stock means stock held for pending/confirmed orders.</StockStateGuide>
      <StockStateGuide tone="success">Available stock is what resellers and customers can still sell or order.</StockStateGuide>
      <div className="mt-4 grid gap-2">
        <Link href={`/supplier/inventory/${product.id}/restock`} className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] text-sm font-bold text-white">Restock</Link>
        <Link href={`/supplier/inventory/${product.id}/variants`} className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">View Variants</Link>
        <Link href={`/supplier/inventory/${product.id}/movements`} className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">Stock Movement History</Link>
        <Link href={`/supplier/inventory/${product.id}/price-change`} className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">Request Price Change</Link>
        <Button variant="soft-warning">Mark Out of Stock</Button>
        <Button variant="outline">Edit Product</Button>
      </div>
    </InventoryShell>
  );
}

export function VariantStockScreen({ productId }: { productId: string }) {
  const product = getInventoryProduct(productId);

  return (
    <InventoryShell title="Stock variants">
      <InventoryHeader title="Stock variants" description={product.name} />
      <StockStateGuide>Resellers sell from shared supplier stock, so variant stock must stay accurate.</StockStateGuide>
      <VariantStockTable productId={product.id} />
      <div className="mt-4 grid grid-cols-2 gap-2">
        <Button variant="outline">Add Variant</Button>
        <Button>Save Variants</Button>
      </div>
    </InventoryShell>
  );
}

export function RestockProductScreen({ productId }: { productId: string }) {
  const product = getInventoryProduct(productId);

  return (
    <InventoryShell title="Restock product">
      <InventoryHeader title="Restock product" description={product.name} />
      <RestockForm product={product} />
    </InventoryShell>
  );
}

export function StockMovementHistoryScreen({ productId }: { productId: string }) {
  const product = getInventoryProduct(productId);
  const movements = supplierInventoryMock.movements.filter((movement) => movement.productId === product.id);

  return (
    <InventoryShell title="Stock movements">
      <InventoryHeader title="Stock movement history" description={product.name} />
      <StockMovementTimeline movements={movements} />
    </InventoryShell>
  );
}

export function PriceChangeRequestScreen({ productId }: { productId: string }) {
  const product = getInventoryProduct(productId);

  return (
    <InventoryShell title="Price change">
      <InventoryHeader title="Request price change" description={product.name} />
      <PriceChangeRequestCard product={product} />
    </InventoryShell>
  );
}

export function LowStockScreen() {
  const products = supplierInventoryMock.products.filter((product) => product.stockStatus === "Low Stock");

  return (
    <InventoryShell title="Low stock">
      <InventoryHeader title="Low stock alerts" description="Products below their threshold need restock attention." />
      <StockStateGuide>Low stock can reduce reseller sales.</StockStateGuide>
      <StockStateGuide>Thresholds warn the supplier before products stop selling well.</StockStateGuide>
      <div className="mt-4 space-y-3">
        {products.map((product) => (
          <LowStockAlertCard key={product.id} product={product} />
        ))}
      </div>
    </InventoryShell>
  );
}

export function OutOfStockScreen() {
  const products = supplierInventoryMock.products.filter((product) => product.stockStatus === "Out of Stock");

  return (
    <InventoryShell title="Out of stock">
      <InventoryHeader title="Out-of-stock products" description="Products with no available stock are blocked from new orders." />
      <StockStateGuide tone="danger">Out-of-stock products are hidden or blocked from new orders until restocked.</StockStateGuide>
      <div className="mt-4 space-y-3">
        {products.map((product) => (
          <LowStockAlertCard key={product.id} product={product} outOfStock />
        ))}
      </div>
    </InventoryShell>
  );
}

export function InventoryActivityScreen() {
  const filters = ["All", "Restocks", "Reservations", "Price", "Adjustments"];
  const activities = useMemo(() => supplierInventoryMock.activity, []);

  return (
    <InventoryShell title="Activity">
      <InventoryHeader title="Inventory manager activity" description="Audit-style feed for stock, threshold, price, and reservation actions." />
      <div className="flex gap-2 overflow-x-auto pb-1">
        {filters.map((filter, index) => (
          <Button key={filter} variant={index === 0 ? "primary" : "outline"} size="compact">
            {filter}
          </Button>
        ))}
      </div>
      <div className="mt-4 space-y-3">
        {activities.map((activity) => (
          <InventoryActivityItem key={activity.id} activity={activity} />
        ))}
      </div>
    </InventoryShell>
  );
}
