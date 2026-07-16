"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { useMemo, useState } from "react";
import { Bell, ClipboardList, Home, Package, UserRound } from "lucide-react";
import { ProductImageFrame, ProductImageGallery, ProductImagePreviewGrid } from "@/components/marketplace";
import { Button, Card, Checkbox, Input, ScrollableChipRow, StatusBadge, Textarea } from "@/components/ui";
import { MobileShell } from "@/components/layout";
import {
  formatGhc,
  getSupplierOrder,
  getSupplierProduct,
  supplierCoreMock,
  type SupplierOrder,
  type SupplierProduct
} from "@/lib/mock/supplier-core";
import { cn } from "@/lib/utils/cn";

type OnboardingStep = "welcome" | "business" | "category" | "verification" | "payout" | "agreement" | "pending" | "rejected";
type SupplierNavKey = "home" | "products" | "orders" | "alerts" | "account";

const navItems = [
  { key: "home" as const, label: "Home", href: "/supplier/dashboard", icon: Home },
  { key: "products" as const, label: "Products", href: "/supplier/products", icon: Package },
  { key: "orders" as const, label: "Orders", href: "/supplier/orders", icon: ClipboardList },
  { key: "alerts" as const, label: "Alerts", href: "/supplier/notifications", icon: Bell },
  { key: "account" as const, label: "Account", href: "/supplier/settings", icon: UserRound }
];

function SupplierBottomNav({ active }: { active: SupplierNavKey }) {
  return (
    <nav aria-label="Supplier navigation" className="fixed inset-x-0 bottom-0 z-20 border-t border-[var(--color-border)] bg-white/95 px-3 py-2 backdrop-blur">
      <div className="mx-auto grid max-w-md grid-cols-5 gap-1">
        {navItems.map((item) => {
          const Icon = item.icon;
          const selected = active === item.key;

          return (
            <Link
              aria-current={selected ? "page" : undefined}
              aria-label={item.label}
              className={cn(
                "flex min-h-12 flex-col items-center justify-center gap-1 rounded-[var(--radius-md)] text-[11px] font-semibold text-[var(--color-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-soft)]",
                selected && "bg-[var(--color-primary-subtle)] text-[var(--color-primary)]"
              )}
              href={item.href}
              key={item.key}
            >
              <Icon className="h-4 w-4" aria-hidden />
              <span className="truncate">{item.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}

function SupplierMobileShell({
  active,
  children,
  title
}: {
  active: SupplierNavKey;
  children: ReactNode;
  title?: string;
}) {
  return (
    <MobileShell title={title} footer={<SupplierBottomNav active={active} />}>
      {children}
    </MobileShell>
  );
}

function SupplierHeader({ eyebrow, title, description }: { eyebrow?: string; title: string; description?: string }) {
  return (
    <header className="mb-5 space-y-2">
      {eyebrow ? <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-primary)]">{eyebrow}</p> : null}
      <h1 className="text-2xl font-extrabold tracking-normal text-[var(--color-charcoal)]">{title}</h1>
      {description ? <p className="text-sm leading-6 text-[var(--color-muted)]">{description}</p> : null}
    </header>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="space-y-2 text-sm font-semibold text-[var(--color-charcoal)]">
      <span>{label}</span>
      {children}
    </label>
  );
}

function ProductImageTile({ product, className }: { product: Pick<SupplierProduct, "imageLabel" | "name">; className?: string }) {
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

function SupplierStatusCard({ label, value, detail, tone = "neutral" }: { label: string; value: string; detail: string; tone?: "success" | "warning" | "danger" | "info" | "neutral" }) {
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

function ProductApprovalBanner({ children, tone = "warning" }: { children: React.ReactNode; tone?: "warning" | "success" | "danger" }) {
  const className =
    tone === "success"
      ? "border-[var(--color-success)]/25 bg-[var(--color-success-soft)] text-[var(--color-primary)]"
      : tone === "danger"
        ? "border-[var(--color-danger)]/25 bg-[var(--color-danger-soft)] text-[var(--color-danger)]"
        : "border-[var(--color-warning)]/25 bg-[var(--color-warning-soft)] text-[#7A5300]";
  return <div className={cn("rounded-[var(--radius-md)] border p-3 text-sm font-semibold leading-6", className)}>{children}</div>;
}

function SupplierProductCard({ product, compact = false }: { product: SupplierProduct; compact?: boolean }) {
  const stockTone = product.stock === 0 ? "danger" : product.stock <= product.lowStockThreshold ? "warning" : "success";

  return (
    <Card className="overflow-hidden p-4">
      <div className="flex items-start gap-3">
        <ProductImageFrame
          className="h-20 w-20 flex-none shrink-0 rounded-[var(--radius-md)]"
          imageAlt={product.imageAlt}
          images={product.images}
          productName={product.name}
        />
        <div className="min-w-0 flex-1">
          <div className="flex min-w-0 items-start justify-between gap-2">
            <div className="min-w-0">
              <h3 className="line-clamp-2 text-base font-bold leading-5 text-[var(--color-charcoal)]">{product.name}</h3>
              <p className="mt-1 text-xs text-[var(--color-muted)]">{product.category}</p>
            </div>
            <div className="shrink-0">
              <StatusBadge status={product.status} />
            </div>
          </div>
          <dl className="mt-3 grid grid-cols-2 gap-3 text-sm">
            <div className="min-w-0">
              <dt className="text-xs text-[var(--color-muted)]">Supplier base price</dt>
              <dd className="font-bold text-[var(--color-primary)]">{formatGhc(product.basePrice)}</dd>
            </div>
            <div className="min-w-0">
              <dt className="text-xs text-[var(--color-muted)]">Stock</dt>
              <dd className="font-bold text-[var(--color-charcoal)]">Stock {product.stock}</dd>
            </div>
          </dl>
          {!compact ? (
            <div className="mt-3 flex flex-wrap items-center justify-between gap-2">
              <StatusBadge tone={stockTone}>{product.stock === 0 ? "Out of Stock" : product.stock <= product.lowStockThreshold ? "Low Stock" : "In Stock"}</StatusBadge>
              <Link
                className="inline-flex min-h-10 items-center text-sm font-bold text-[var(--color-primary)]"
                href={`/supplier/products/${product.id}`}
              >
                View
              </Link>
            </div>
          ) : null}
        </div>
      </div>
    </Card>
  );
}

function SupplierOrderCard({ order }: { order: SupplierOrder }) {
  const product = getSupplierProduct(order.productId);

  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-bold text-[var(--color-charcoal)]">{order.id}</p>
          <p className="mt-1 text-sm text-[var(--color-muted)]">{product.name}</p>
        </div>
        <StatusBadge status={order.status === "Ready" ? "Preparing" : order.status} tone={order.status === "Ready" ? "info" : undefined} />
      </div>
      <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
        <div>
          <dt className="text-xs text-[var(--color-muted)]">Customer</dt>
          <dd className="font-semibold text-[var(--color-charcoal)]">{order.customerName}</dd>
        </div>
        <div>
          <dt className="text-xs text-[var(--color-muted)]">Base amount</dt>
          <dd className="font-bold text-[var(--color-primary)]">{formatGhc(order.supplierBaseAmount)}</dd>
        </div>
        <div>
          <dt className="text-xs text-[var(--color-muted)]">Payment</dt>
          <dd className="font-semibold text-[var(--color-charcoal)]">POD confirmed</dd>
        </div>
        <div>
          <dt className="text-xs text-[var(--color-muted)]">Delivery</dt>
          <dd className="font-semibold text-[var(--color-charcoal)]">{order.deliveryArea}</dd>
        </div>
      </dl>
      <div className="mt-4 grid grid-cols-2 gap-2">
        <Link href={`/supplier/orders/${order.id}`} className="inline-flex h-10 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">
          View
        </Link>
        <Link href={`/supplier/orders/${order.id}/prepare`} className="inline-flex h-10 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] text-sm font-bold text-white">
          Prepare
        </Link>
      </div>
    </Card>
  );
}

function SupplierAgreementCard() {
  return (
    <Card title="Supplier rules">
      <ul className="space-y-3 text-sm leading-6 text-[var(--color-charcoal)]">
        <li>Resellers may sell products above supplier base price after approval.</li>
        <li>You keep your base price when a customer pays successfully.</li>
        <li>After customer payment, settle Risellar share immediately.</li>
        <li>Keep stock accurate and prepare confirmed orders on time.</li>
        <li>Do not contact customers outside the approved order process.</li>
      </ul>
    </Card>
  );
}

function PreparationChecklist() {
  return (
    <Card title="Preparation checklist">
      <div className="space-y-3">
        {["Check product", "Confirm variant and quantity", "Package item"].map((label) => (
          <label key={label} className="flex min-h-11 items-center gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 text-sm font-semibold">
            <Checkbox aria-label={label} />
            {label}
          </label>
        ))}
      </div>
      <p className="mt-4 rounded-[var(--radius-md)] border border-dashed border-[var(--color-border)] bg-[var(--color-page)] p-3 text-sm text-[var(--color-muted)]">
        Packing proof placeholder. Photo upload and storage arrive in a later integration phase.
      </p>
    </Card>
  );
}

export function SupplierOnboardingScreen({ step }: { step: OnboardingStep }) {
  const [agreed, setAgreed] = useState(false);
  const supplier = supplierCoreMock.supplier;

  if (step === "welcome") {
    return (
      <SupplierMobileShell active="home" title="Supplier onboarding">
        <SupplierHeader title="Welcome to Risellar Supplier" description="List products. Reach resellers. Grow sales." />
        <Card>
          <ProductImageTile product={{ imageLabel: "R", name: "Risellar supplier" }} className="mx-auto mb-5 h-28 w-28" />
          <p className="text-sm leading-6 text-[var(--color-charcoal)]">
            You keep your base price while trusted resellers help move your products across Ghana.
          </p>
          <Button className="mt-5 w-full">Get Started</Button>
        </Card>
      </SupplierMobileShell>
    );
  }

  if (step === "business") {
    return (
      <SupplierMobileShell active="account" title="Business profile">
        <SupplierHeader title="Tell us about your business" description="This profile helps Risellar review and present your supplier account." />
        <Card>
          <div className="space-y-4">
            <Field label="Business name">
              <Input aria-label="Business name" defaultValue={supplier.businessName} />
            </Field>
            <Field label="Owner name">
              <Input aria-label="Owner name" defaultValue={supplier.ownerName} />
            </Field>
            <Field label="Location">
              <Input aria-label="Location" defaultValue={supplier.location} />
            </Field>
            <Button className="w-full">Continue</Button>
          </div>
        </Card>
      </SupplierMobileShell>
    );
  }

  if (step === "category") {
    const categories = ["Phones & Accessories", "Skincare / Perfume", "Fashion", "Home & Living"];
    return (
      <SupplierMobileShell active="products" title="Category">
        <SupplierHeader title="What do you supply?" description="Choose the closest product category for approval routing." />
        <div className="space-y-3">
          {categories.map((category, index) => (
            <Card key={category} className={cn("p-4", index === 0 && "border-[var(--color-primary)] bg-[var(--color-primary-subtle)]")}>
              <div className="flex items-center justify-between">
                <p className="font-bold text-[var(--color-charcoal)]">{category}</p>
                {index === 0 ? <StatusBadge tone="success">Selected</StatusBadge> : <span className="h-5 w-5 rounded-full border border-[var(--color-border)]" aria-hidden="true" />}
              </div>
            </Card>
          ))}
        </div>
      </SupplierMobileShell>
    );
  }

  if (step === "verification") {
    return (
      <SupplierMobileShell active="account" title="Verification">
        <SupplierHeader title="Verify your identity" description="Identity review keeps supplier ownership clear before your products go live." />
        <Card title="Ghana Card">
          <div className="space-y-3">
            <div className="rounded-[var(--radius-md)] border border-dashed border-[var(--color-border)] bg-[var(--color-page)] p-4 text-center text-sm text-[var(--color-muted)]">
              Front and back upload placeholder
            </div>
            <ProductApprovalBanner>Verification protects customers and resellers by making supplier ownership clear.</ProductApprovalBanner>
            <Button className="w-full">Continue</Button>
          </div>
        </Card>
      </SupplierMobileShell>
    );
  }

  if (step === "payout") {
    return (
      <SupplierMobileShell active="account" title="Payout setup">
        <SupplierHeader title="Set up your payouts" description="Add where supplier payments should be sent after settlement checks." />
        <Card>
          <div className="space-y-4">
            <Field label="Mobile Money provider">
              <Input aria-label="Mobile Money provider" defaultValue="MTN MoMo" />
            </Field>
            <Field label="MoMo number">
              <Input aria-label="MoMo number" defaultValue={supplier.phone} />
            </Field>
            <ProductApprovalBanner>Bank option placeholder. Bank payout support will be connected in a later backend phase.</ProductApprovalBanner>
            <Button className="w-full">Save & Continue</Button>
          </div>
        </Card>
      </SupplierMobileShell>
    );
  }

  if (step === "agreement") {
    return (
      <SupplierMobileShell active="account" title="Agreement">
        <SupplierHeader title="Keep it fair and trusted" description="Review the operating rules before your supplier account is submitted." />
        <SupplierAgreementCard />
        <label className="mt-4 flex items-start gap-3 text-sm font-semibold text-[var(--color-charcoal)]">
          <Checkbox aria-label="I agree to the supplier rules" checked={agreed} onChange={(event) => setAgreed(event.currentTarget.checked)} />
          I agree to the supplier rules.
        </label>
        <Button className="mt-4 w-full" disabled={!agreed}>
          Continue
        </Button>
      </SupplierMobileShell>
    );
  }

  if (step === "pending") {
    return (
      <SupplierMobileShell active="home" title="Pending approval">
        <Card className="text-center">
          <ProductImageTile product={{ imageLabel: "OK", name: "Pending approval" }} className="mx-auto mb-5 h-24 w-24" />
          <h1 className="text-xl font-extrabold text-[var(--color-charcoal)]">Your supplier account is under review.</h1>
          <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">Review usually takes 1-2 business days. We will notify you when your account is approved.</p>
          <Button className="mt-5 w-full">Go to Dashboard</Button>
        </Card>
      </SupplierMobileShell>
    );
  }

  return (
    <SupplierMobileShell active="account" title="More info required">
      <Card className="text-center">
        <ProductImageTile product={{ imageLabel: "!", name: "More information required" }} className="mx-auto mb-5 h-24 w-24" />
        <h1 className="text-xl font-extrabold text-[var(--color-charcoal)]">More information required</h1>
        <p className="mt-3 rounded-[var(--radius-md)] bg-[var(--color-danger-soft)] p-3 text-sm leading-6 text-[var(--color-danger)]">Reason: Ghana Card image is not clear.</p>
        <Button className="mt-5 w-full">Update Information</Button>
      </Card>
    </SupplierMobileShell>
  );
}

export function SupplierDashboardScreen() {
  const activeProducts = supplierCoreMock.products.filter((product) => product.status === "Active").length;
  const pendingOrders = supplierCoreMock.orders.filter((order) => ["Customer Confirmed", "Preparing", "Ready"].includes(order.status)).length;
  const settlementDue = supplierCoreMock.orders.reduce((sum, order) => sum + (order.status === "Settlement Due" ? order.settlementDue : 0), 0);
  const lowStock = supplierCoreMock.products.filter((product) => product.stock <= product.lowStockThreshold).length;

  return (
    <SupplierMobileShell active="home" title="Supplier dashboard">
      <SupplierHeader title={supplierCoreMock.supplier.businessName} description={`${supplierCoreMock.supplier.location} · ${supplierCoreMock.supplier.category}`} />
      <div className="mb-4 flex items-center justify-between rounded-[var(--radius-lg)] bg-[var(--color-primary)] p-4 text-white">
        <div>
          <p className="text-sm font-semibold text-white/80">Good morning, {supplierCoreMock.supplier.ownerName}</p>
          <p className="mt-1 text-2xl font-extrabold">Supplier Core</p>
        </div>
        <StatusBadge tone="success">Verified Supplier</StatusBadge>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <SupplierStatusCard label="Active products" value={String(activeProducts)} detail="Approved for reseller selling" tone="success" />
        <SupplierStatusCard label="Pending orders" value={String(pendingOrders)} detail="Need preparation updates" tone="warning" />
        <SupplierStatusCard label="Settlement due" value={formatGhc(settlementDue)} detail="Pay after customer collection" tone="warning" />
        <SupplierStatusCard label="Low stock" value={String(lowStock)} detail="Stock management deepens later" tone="info" />
      </div>
      <Card title="Quick actions" className="mt-4">
        <div className="grid grid-cols-2 gap-2">
          <Button>Add Product</Button>
          <Button variant="outline">View Orders</Button>
          <Button variant="outline">View Products</Button>
          <Button variant="outline">View Settings</Button>
        </div>
      </Card>
      <ProductApprovalBanner>
        Supplier settlements must be paid immediately after customer payment. Settlement details arrive in Phase 8.
      </ProductApprovalBanner>
      <ProductApprovalBanner tone="success">Inventory tools arrive in Phase 7. This dashboard only shows stock summaries for now.</ProductApprovalBanner>
      <Card title="Recent orders" className="mt-4">
        <div className="space-y-3">
          {supplierCoreMock.orders.slice(0, 2).map((order) => (
            <SupplierOrderCard key={order.id} order={order} />
          ))}
        </div>
      </Card>
      <Card title="Product approval summary" className="mt-4">
        <div className="space-y-2 text-sm text-[var(--color-charcoal)]">
          <p>Active: {activeProducts}</p>
          <p>Pending Approval: {supplierCoreMock.products.filter((product) => product.status === "Pending Approval").length}</p>
          <p>Needs Changes: {supplierCoreMock.products.filter((product) => product.status === "Needs Changes").length}</p>
        </div>
      </Card>
    </SupplierMobileShell>
  );
}

export function SupplierProductsScreen() {
  const [query, setQuery] = useState("");
  const filteredProducts = useMemo(
    () => supplierCoreMock.products.filter((product) => product.name.toLowerCase().includes(query.toLowerCase())),
    [query]
  );
  const filters = ["Active", "Pending Approval", "Low Stock", "Out of Stock", "Needs Review"];

  return (
    <SupplierMobileShell active="products" title="Supplier products">
      <SupplierHeader title="Products" description="Manage product visibility, approval status, stock summary, and supplier base prices." />
      <Input
        aria-label="Search supplier products"
        type="search"
        placeholder="Search supplier products"
        value={query}
        onChange={(event) => setQuery(event.currentTarget.value)}
      />
      <ScrollableChipRow className="mt-3">
        {filters.map((filter) => (
          <Button className="flex-none px-5" key={filter} variant={filter === "Active" ? "primary" : "outline"} size="compact">
            {filter}
          </Button>
        ))}
      </ScrollableChipRow>
      <Button className="mt-4 w-full">Add Product</Button>
      <div className="mt-4 space-y-3">
        {filteredProducts.map((product) => (
          <SupplierProductCard key={product.id} product={product} />
        ))}
      </div>
    </SupplierMobileShell>
  );
}

export function SupplierAddProductScreen() {
  const [saved, setSaved] = useState(false);

  return (
    <SupplierMobileShell active="products" title="New product">
      <SupplierHeader title="Add product" description="Create a supplier product draft. Approval is required before resellers can sell it." />
      {saved ? <ProductApprovalBanner tone="success">Product saved for approval.</ProductApprovalBanner> : null}
      <Card>
        <div className="space-y-4">
          <Field label="Product name">
            <Input defaultValue="Samsung Galaxy A14" />
          </Field>
          <Field label="Category">
            <Input defaultValue="Mobile Phones" />
          </Field>
          <Field label="Supplier base price">
            <Input defaultValue="GH₵300" />
          </Field>
          <Field label="Stock quantity">
            <Input defaultValue="18" />
          </Field>
          <ProductImagePreviewGrid
            imageAlt={supplierCoreMock.products[0].imageAlt}
            images={supplierCoreMock.products[0].images}
            productName="Samsung Galaxy A14"
          />
          <ProductApprovalBanner>Your base price is what you expect to receive before Risellar and reseller selling amounts are calculated.</ProductApprovalBanner>
          <ProductApprovalBanner>Admin must approve products before resellers can sell them.</ProductApprovalBanner>
          <ProductApprovalBanner tone="success">Variant setup is a placeholder in this phase. Detailed inventory arrives in Phase 7.</ProductApprovalBanner>
          <Button className="w-full" onClick={() => setSaved(true)}>
            Save Product
          </Button>
        </div>
      </Card>
    </SupplierMobileShell>
  );
}

export function SupplierProductDetailScreen({ id }: { id: string }) {
  const product = getSupplierProduct(id);

  return (
    <SupplierMobileShell active="products" title="Product detail">
      <ProductImageGallery
        className="mb-4"
        imageAlt={product.imageAlt}
        images={product.images}
        productName={product.name}
      />
      <div className="mb-4 flex items-start justify-between gap-3">
        <h1 className="text-2xl font-extrabold text-[var(--color-charcoal)]">{product.name}</h1>
        <StatusBadge status={product.status} />
      </div>
      <Card>
        <dl className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <dt className="text-xs text-[var(--color-muted)]">Supplier base price</dt>
            <dd className="font-bold text-[var(--color-primary)]">{formatGhc(product.basePrice)}</dd>
          </div>
          <div>
            <dt className="text-xs text-[var(--color-muted)]">Stock status</dt>
            <dd className="font-bold text-[var(--color-charcoal)]">{product.stock} units</dd>
          </div>
          <div>
            <dt className="text-xs text-[var(--color-muted)]">Active resellers</dt>
            <dd className="font-bold text-[var(--color-charcoal)]">{product.activeResellers}</dd>
          </div>
          <div>
            <dt className="text-xs text-[var(--color-muted)]">Orders this month</dt>
            <dd className="font-bold text-[var(--color-charcoal)]">{product.ordersThisMonth}</dd>
          </div>
        </dl>
      </Card>
      <Card title="Performance summary" className="mt-4">
        <p className="text-sm leading-6 text-[var(--color-muted)]">{product.notes}</p>
      </Card>
      <div className="mt-4 space-y-2">
        <Button className="w-full">Edit Product</Button>
        <Button className="w-full" variant="outline">
          View Orders
        </Button>
        <Button className="w-full" variant="outline" disabled>
          Manage Inventory
        </Button>
      </div>
      <ProductApprovalBanner tone="success">Coming in Phase 7: detailed inventory, stock movements, and variant controls.</ProductApprovalBanner>
    </SupplierMobileShell>
  );
}

export function SupplierEditProductScreen({ id }: { id: string }) {
  const product = getSupplierProduct(id);
  const [saved, setSaved] = useState(false);

  return (
    <SupplierMobileShell active="products" title="Edit product">
      <SupplierHeader title="Edit product" description={product.name} />
      {saved ? <ProductApprovalBanner tone="success">Product changes saved for review.</ProductApprovalBanner> : null}
      <Card>
        <div className="space-y-4">
          <Field label="Product name">
            <Input defaultValue={product.name} />
          </Field>
          <Field label="Supplier base price">
            <Input defaultValue={formatGhc(product.basePrice)} />
          </Field>
          <Field label="Stock summary">
            <Input defaultValue={`${product.stock} units available`} />
          </Field>
          <Field label="Approval status">
            <Input defaultValue={product.status} />
          </Field>
          <ProductImagePreviewGrid
            imageAlt={product.imageAlt}
            images={product.images}
            productName={product.name}
          />
          <ProductApprovalBanner>Price changes may require admin approval before resellers can use the updated amount.</ProductApprovalBanner>
          <ProductApprovalBanner>Existing orders keep their original price.</ProductApprovalBanner>
          <Button className="w-full" onClick={() => setSaved(true)}>
            Save Changes
          </Button>
        </div>
      </Card>
    </SupplierMobileShell>
  );
}

export function SupplierOrdersScreen() {
  const filters = ["Customer Confirmed", "Preparing", "Ready", "Delivered", "Settlement Due"];

  return (
    <SupplierMobileShell active="orders" title="Supplier orders">
      <SupplierHeader title="Orders" description="Prepare confirmed orders and track settlement-sensitive payment states." />
      <Card className="mb-4 p-4">
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <p className="font-bold text-[var(--color-charcoal)]">Payment model</p>
            <p className="font-bold text-[var(--color-primary)]">Pay on Delivery</p>
          </div>
          <div className="flex items-center justify-between">
            <p className="font-bold text-[var(--color-charcoal)]">Amount label</p>
            <p className="font-bold text-[var(--color-primary)]">Supplier base amount</p>
          </div>
        </div>
      </Card>
      <ScrollableChipRow>
        {filters.map((filter, index) => (
          <Button className="flex-none px-5" key={filter} variant={index === 0 ? "primary" : "outline"} size="compact">
            {filter}
          </Button>
        ))}
      </ScrollableChipRow>
      <div className="mt-4 space-y-3">
        {supplierCoreMock.orders.map((order) => (
          <SupplierOrderCard key={order.id} order={order} />
        ))}
      </div>
    </SupplierMobileShell>
  );
}

export function SupplierOrderDetailScreen({ id }: { id: string }) {
  const order = getSupplierOrder(id);
  const product = getSupplierProduct(order.productId);
  const [status, setStatus] = useState(order.status);

  return (
    <SupplierMobileShell active="orders" title="Order detail">
      <SupplierHeader title={order.id} description={`${product.name} · Qty ${order.quantity}`} />
      <StatusBadge status={status === "Ready" ? "Preparing" : status} tone={status === "Ready" ? "info" : undefined} />
      <Card title="Customer delivery snapshot" className="mt-4">
        <dl className="space-y-3 text-sm">
          <div className="flex justify-between gap-3">
            <dt className="text-[var(--color-muted)]">Customer</dt>
            <dd className="font-semibold text-[var(--color-charcoal)]">{order.customerName}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-[var(--color-muted)]">Phone</dt>
            <dd className="font-semibold text-[var(--color-charcoal)]">{order.customerPhone}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-[var(--color-muted)]">Area</dt>
            <dd className="font-semibold text-[var(--color-charcoal)]">{order.deliveryArea}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-[var(--color-muted)]">Payment</dt>
            <dd className="font-semibold text-[var(--color-charcoal)]">{order.paymentMethod}</dd>
          </div>
        </dl>
      </Card>
      <Card title="Supplier amount" className="mt-4">
        <dl className="space-y-3 text-sm">
          <div className="flex justify-between">
            <dt>Supplier base amount</dt>
            <dd className="font-bold text-[var(--color-primary)]">{formatGhc(order.supplierBaseAmount)}</dd>
          </div>
          <div className="flex justify-between">
            <dt>Settlement due later</dt>
            <dd className="font-bold text-[var(--color-warning)]">{formatGhc(order.settlementDue)}</dd>
          </div>
        </dl>
      </Card>
      <PreparationChecklist />
      <ProductApprovalBanner>After customer pays, settle Risellar share immediately to avoid restrictions.</ProductApprovalBanner>
      <div className="mt-4 grid grid-cols-2 gap-2">
        <Button onClick={() => setStatus("Preparing")}>Mark Preparing</Button>
        <Button variant="outline" onClick={() => setStatus("Ready")}>
          Mark Ready
        </Button>
      </div>
    </SupplierMobileShell>
  );
}

export function SupplierPrepareOrderScreen({ id }: { id: string }) {
  const order = getSupplierOrder(id);
  const product = getSupplierProduct(order.productId);
  const [ready, setReady] = useState(false);

  return (
    <SupplierMobileShell active="orders" title="Prepare order">
      <SupplierHeader title="Prepare order" description={`${order.id} · ${product.name}`} />
      <PreparationChecklist />
      {ready ? (
        <div role="status" className="mt-4 rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] p-3 text-sm font-semibold text-[var(--color-primary)]">
          <p>Order ready for delivery arrangement.</p>
        </div>
      ) : null}
      <Button className="mt-4 w-full" onClick={() => setReady(true)}>
        Mark as Ready
      </Button>
    </SupplierMobileShell>
  );
}

export function SupplierNotificationsScreen() {
  return (
    <SupplierMobileShell active="alerts" title="Supplier notifications">
      <SupplierHeader title="Notifications" description="Operational updates for products, orders, verification, and settlements." />
      <div className="space-y-3">
        {supplierCoreMock.notifications.map((notification) => (
          <Card key={notification} className="p-4">
            <p className="text-sm leading-6 text-[var(--color-charcoal)]">{notification}</p>
          </Card>
        ))}
      </div>
    </SupplierMobileShell>
  );
}

export function SupplierSettingsScreen() {
  const settings = [
    ["Business profile", supplierCoreMock.supplier.businessName],
    ["Payout details summary", supplierCoreMock.supplier.payoutMethod],
    ["Agreement and rules", "Supplier operating terms"],
    ["Notifications", "Order and settlement alerts"],
    ["Logout placeholder", "Auth arrives in a later integration phase"]
  ];

  return (
    <SupplierMobileShell active="account" title="Supplier settings">
      <SupplierHeader title="Settings" description="Review supplier profile details without backend account changes." />
      <div className="space-y-3">
        {settings.map(([title, detail]) => (
          <Card key={title} className="p-4">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h3 className="font-bold text-[var(--color-charcoal)]">{title}</h3>
                <p className="mt-1 text-sm text-[var(--color-muted)]">{detail}</p>
              </div>
              <span className="text-[var(--color-muted)]" aria-hidden="true">
                &gt;
              </span>
            </div>
          </Card>
        ))}
      </div>
    </SupplierMobileShell>
  );
}

export function SupplierSupportScreen() {
  const [sent, setSent] = useState(false);
  const topics = ["Product approval", "Settlement", "Orders & Preparation", "Verification", "Payout Details"];

  return (
    <SupplierMobileShell active="account" title="Support">
      <SupplierHeader title="Supplier support" description="Mock support capture for supplier operational issues." />
      <Card title="Choose a topic">
        <div className="flex flex-wrap gap-2">
          {topics.map((topic) => (
            <StatusBadge key={topic} tone={topic === "Settlement" ? "warning" : "info"}>
              {topic}
            </StatusBadge>
          ))}
        </div>
      </Card>
      <Card title="Support request" className="mt-4">
        <Textarea placeholder="Tell Risellar support what you need help with." aria-label="Support message" />
        {sent ? <ProductApprovalBanner tone="success">Support request saved.</ProductApprovalBanner> : null}
        <Button className="mt-4 w-full" onClick={() => setSent(true)}>
          Send Support Request
        </Button>
      </Card>
    </SupplierMobileShell>
  );
}
