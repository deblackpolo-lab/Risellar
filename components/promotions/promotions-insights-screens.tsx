"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { BarChart3, ClipboardList, Copy, Home, Lock, Megaphone, Package, UserRound } from "lucide-react";
import { AdminShell } from "@/components/admin/AdminSidebar";
import { BottomNav, MobileShell } from "@/components/layout";
import { ProductImageFrame } from "@/components/marketplace";
import { Button, Card, Input, StatusBadge } from "@/components/ui";
import {
  captionTemplates,
  formatGhc,
  getPromotion,
  insightProducts,
  promotionEligibilityChecks,
  promotionPackages,
  promotions,
  supplierPromotionSummary,
  type InsightProduct,
  type Promotion
} from "@/lib/mock/promotions-insights";
import { cn } from "@/lib/utils/cn";

type InsightType = "top-selling" | "high-profit" | "low-competition";

function SupplierNav({ active }: { active: string }) {
  const items = [
    { label: "Home", href: "/supplier/dashboard", icon: Home },
    { label: "Products", href: "/supplier/products", icon: Package },
    { label: "Orders", href: "/supplier/orders", icon: ClipboardList },
    { label: "Promos", href: "/supplier/promotions", icon: Megaphone },
    { label: "Account", href: "/supplier/settings", icon: UserRound }
  ];

  return (
    <nav aria-label="Supplier navigation" className="fixed inset-x-0 bottom-0 z-20 border-t border-[var(--color-border)] bg-white/95 px-3 py-2 backdrop-blur">
      <div className="mx-auto grid max-w-md grid-cols-5 gap-1">
        {items.map((item) => {
          const Icon = item.icon;
          const selected = item.label === active;

          return (
            <Link
              aria-current={selected ? "page" : undefined}
              aria-label={item.label}
              className={cn("flex min-h-12 flex-col items-center justify-center rounded-[var(--radius-md)] text-[11px] font-semibold text-[var(--color-muted)]", selected && "bg-[var(--color-primary-subtle)] text-[var(--color-primary)]")}
              href={item.href}
              key={item.label}
            >
              <Icon className="mb-1 h-4 w-4" aria-hidden />
              <span className="truncate">{item.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}

function SupplierShell({ children, title }: { children: ReactNode; title: string }) {
  return (
    <MobileShell footer={<SupplierNav active="Promos" />} title="Supplier growth">
      <PageHeader eyebrow="Promotions" title={title} description="Boost visibility with mock-only promotion tools. Real payment and approval systems are not connected." />
      {children}
    </MobileShell>
  );
}

function ResellerShell({ children, title }: { children: ReactNode; title: string }) {
  return (
    <MobileShell footer={<BottomNav active="Shop" />} title="Growth tools">
      <PageHeader eyebrow="Insights" title={title} description="Find products to sell today with clear profit, stock, and trust signals." />
      {children}
    </MobileShell>
  );
}

function PageHeader({ eyebrow, title, description }: { eyebrow: string; title: string; description?: string }) {
  return (
    <header className="mb-5">
      <p className="text-xs font-bold uppercase text-[var(--color-primary)]">{eyebrow}</p>
      <h1 className="mt-1 text-2xl font-extrabold text-[var(--color-charcoal)]">{title}</h1>
      {description ? <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">{description}</p> : null}
    </header>
  );
}

function MetricCard({ label, value, note }: { label: string; value: string; note: string }) {
  return (
    <Card className="p-4">
      <p className="text-xs font-bold uppercase text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 text-2xl font-extrabold">{value}</p>
      <p className="mt-1 text-xs leading-5 text-[var(--color-muted)]">{note}</p>
    </Card>
  );
}

function ProductTile({ product }: { product: Pick<InsightProduct, "name" | "imageLabel" | "images" | "imageAlt"> }) {
  return (
    <ProductImageFrame
      className="h-20 w-20 shrink-0 rounded-[var(--radius-md)]"
      imageAlt={product.imageAlt}
      images={product.images}
      productName={product.name}
    />
  );
}

export function PromotionEligibilityChecklist({ compact = false }: { compact?: boolean }) {
  return (
    <Card title={compact ? "Eligibility" : "Eligibility checklist"}>
      <div className="space-y-3">
        {promotionEligibilityChecks.map((check) => (
          <div className="flex items-center justify-between gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={check.label}>
            <span className="text-sm font-semibold">{check.label}</span>
            <StatusBadge tone={check.passed ? "success" : "danger"}>{check.passed ? "Pass" : "Blocked"}</StatusBadge>
          </div>
        ))}
      </div>
      {!compact ? <p className="mt-4 rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-sm font-bold text-[#8A5A00]">Paid promotion must not override trust and safety.</p> : null}
    </Card>
  );
}

export function PromotionPackageCard({ pack }: { pack: (typeof promotionPackages)[number] }) {
  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h3 className="font-bold">{pack.name}</h3>
          <p className="mt-1 text-sm text-[var(--color-muted)]">{pack.duration}</p>
        </div>
        <p className="text-xl font-extrabold text-[var(--color-primary)]">{formatGhc(pack.price)}</p>
      </div>
      <dl className="mt-4 space-y-2 text-sm">
        <div><dt className="text-xs font-bold uppercase text-[var(--color-muted)]">Placement</dt><dd>{pack.placement}</dd></div>
        <div><dt className="text-xs font-bold uppercase text-[var(--color-muted)]">Eligibility</dt><dd>{pack.eligibility}</dd></div>
      </dl>
      <Button className="mt-4 w-full" type="button" variant={pack.name === "3-Day Boost" ? "secondary" : "outline"}>Choose Package</Button>
    </Card>
  );
}

export function ProductOpportunityCard({ product }: { product: InsightProduct }) {
  return (
    <Card className="p-4">
      <div className="flex gap-3">
        <ProductTile product={product} />
        <div className="min-w-0 flex-1">
          <h3 className="text-base font-bold leading-5">{product.name}</h3>
          <p className="mt-1 text-xs text-[var(--color-muted)]">{product.category} - {product.location}</p>
          <div className="mt-2 flex flex-wrap gap-1.5">
            {product.labels.slice(0, 3).map((label) => <StatusBadge key={label} status={label} />)}
          </div>
        </div>
      </div>
      <dl className="mt-4 grid grid-cols-3 gap-2 text-sm">
        <div><dt className="text-xs text-[var(--color-muted)]">Reseller cost</dt><dd className="font-bold">{formatGhc(product.resellerCost)}</dd></div>
        <div><dt className="text-xs text-[var(--color-muted)]">Suggested</dt><dd className="font-bold">{formatGhc(product.suggestedPrice)}</dd></div>
        <div><dt className="text-xs text-[var(--color-muted)]">Profit</dt><dd className="font-bold text-[var(--color-primary)]">{formatGhc(product.expectedProfit)}</dd></div>
      </dl>
      <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">{product.insight}</p>
      <div className="mt-3 flex flex-wrap gap-2">
        <StatusBadge status={product.stockState}>{product.stockState}</StatusBadge>
        <StatusBadge tone="success">{product.trust}</StatusBadge>
      </div>
      <div className="mt-4 grid grid-cols-2 gap-2">
        <Button type="button" size="compact">Add to Shop</Button>
        <Button type="button" size="compact" variant="outline">Share</Button>
      </div>
    </Card>
  );
}

export function SponsoredProductCard({ product }: { product: InsightProduct }) {
  return (
    <ProductOpportunityCard product={{ ...product, labels: Array.from(new Set(["Sponsored", ...product.labels])) }} />
  );
}

export function ProInsightLockedCard() {
  return (
    <Card className="border-[var(--color-primary)]/20 bg-[var(--color-primary-subtle)]">
      <Lock className="h-8 w-8 text-[var(--color-primary)]" aria-hidden="true" />
      <h3 className="mt-3 text-lg font-extrabold">Pro insights</h3>
      <div className="mt-3 space-y-2 text-sm text-[var(--color-muted)]">
        {["top-selling by area", "best product captions", "early access to hot products", "low competition alerts", "advanced profit analytics"].map((item) => <p key={item}>{item}</p>)}
      </div>
      <Button className="mt-4 w-full" type="button" variant="secondary">Unlock Placeholder</Button>
      <p className="mt-3 rounded-[var(--radius-md)] bg-white p-3 text-sm font-bold text-[var(--color-primary)]">complete 3 successful orders to unlock trial</p>
    </Card>
  );
}

export function SupplierPromotionsOverviewScreen() {
  const rows = promotions.slice(0, 3);
  return (
    <SupplierShell title="Supplier Promotions">
      <section className="space-y-4">
        <Card>
          <p className="text-sm text-[var(--color-muted)]">Supplier business name</p>
          <h2 className="mt-1 text-xl font-extrabold">{supplierPromotionSummary.businessName}</h2>
          <Link className="mt-4 inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] px-5 text-sm font-bold text-white" href="/supplier/promotions/new">Promote Product</Link>
        </Card>
        <div className="grid grid-cols-2 gap-3">
          <MetricCard label="Active promotions" value={`${supplierPromotionSummary.active}`} note="Currently visible" />
          <MetricCard label="Pending approval" value={`${supplierPromotionSummary.pending}`} note="Admin review" />
          <MetricCard label="Paused" value={`${supplierPromotionSummary.paused}`} note="Needs attention" />
          <MetricCard label="Total spent this month" value={formatGhc(supplierPromotionSummary.totalSpentThisMonth)} note="Mock spend" />
          <MetricCard label="Product views" value={supplierPromotionSummary.productViews.toLocaleString()} note="Views generated" />
          <MetricCard label="Resellers reached" value={`${supplierPromotionSummary.resellersReached}`} note="Mock reach" />
          <MetricCard label="Orders influenced" value={`${supplierPromotionSummary.ordersInfluenced}`} note="Estimated influence" />
          <MetricCard label="Completed promotions" value={`${supplierPromotionSummary.completed}`} note="Past boosts" />
        </div>
        <Card title="Promotion performance summary">
          <p className="text-sm leading-6 text-[var(--color-muted)]">Featured placements generated 1,240 product views and helped 34 Pay on Delivery orders get influenced this month.</p>
        </Card>
        <p className="rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-sm font-bold text-[#8A5A00]">{supplierPromotionSummary.warning}</p>
        <Card title="Promotion list">
          <div className="space-y-3">
            {rows.map((promotion) => <PromotionRow key={promotion.id} promotion={promotion} href={`/supplier/promotions/${promotion.id}`} />)}
          </div>
        </Card>
      </section>
    </SupplierShell>
  );
}

function PromotionRow({ promotion, href }: { promotion: Promotion; href: string }) {
  return (
    <Link className="block rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" href={href}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-bold">{promotion.name}</p>
          <p className="mt-1 text-xs text-[var(--color-muted)]">{promotion.product}</p>
        </div>
        <StatusBadge status={promotion.status} />
      </div>
    </Link>
  );
}

export function SupplierPromotionsNewScreen() {
  return (
    <SupplierShell title="Promote Product">
      <section className="space-y-4">
        <Card title="Select product">
          <div className="space-y-3">
            {["Jean Paul Gaultier Le Male EDT 125ml", "Nike Air Force 1 '07 Green & White", "Oraimo Power Bank"].map((item) => (
              <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm font-bold" key={item}>{item}</div>
            ))}
          </div>
        </Card>
        <PromotionEligibilityChecklist compact />
        <Card title="Choose target">
          <div className="grid grid-cols-2 gap-2 text-sm">
            {["All resellers", "Accra", "Legon", "KNUST", "Madina", "Beauty category", "Phones category"].map((target) => <Button key={target} type="button" size="table-action" variant={target === "Legon" ? "primary" : "outline"}>{target}</Button>)}
          </div>
        </Card>
        <Card title="Choose package">
          <PromotionPackageCard pack={promotionPackages[2]} />
        </Card>
        <Card title="Preview placement">
          <p className="text-sm leading-6 text-[var(--color-muted)]">Sponsored placement preview for Legon resellers. Estimated reach: 180-240 resellers.</p>
          <p className="mt-2 font-bold">Estimated reach</p>
        </Card>
        <Button className="w-full" type="button">Continue</Button>
      </section>
    </SupplierShell>
  );
}

export function SupplierPromotionPackagesScreen() {
  return (
    <SupplierShell title="Boost Packages">
      <div className="space-y-3">{promotionPackages.map((pack) => <PromotionPackageCard key={pack.id} pack={pack} />)}</div>
    </SupplierShell>
  );
}

export function SupplierPromotionDetailScreen({ promotionId }: { promotionId: string }) {
  const promotion = getPromotion(promotionId);
  return (
    <SupplierShell title={promotion.name}>
      <section className="space-y-4">
        <Card>
          <div className="flex items-start justify-between gap-3"><h2 className="text-lg font-extrabold">{promotion.product}</h2><StatusBadge status={promotion.status} /></div>
          <InfoGrid rows={[["Package", promotion.packageName], ["Target", promotion.target], ["Start date", promotion.startDate], ["End date", promotion.endDate], ["Amount", formatGhc(promotion.amount)], ["Payment status", promotion.paymentStatus], ["Eligibility status", promotion.eligibilityStatus]]} />
          {promotion.pauseReason ? <p className="mt-4 rounded-[var(--radius-md)] bg-[var(--color-danger-soft)] p-3 text-sm font-bold text-[var(--color-danger)]">{promotion.pauseReason}</p> : null}
        </Card>
        <div className="grid gap-2">
          <Link className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] px-5 text-sm font-bold text-white" href={`/supplier/promotions/${promotion.id}/performance`}>View Performance</Link>
          <Button type="button" variant="outline">Copy Product Link</Button>
          <Button type="button" variant="outline">Contact Support</Button>
          <Button disabled type="button" variant="danger">Cancel Promotion</Button>
        </div>
      </section>
    </SupplierShell>
  );
}

function InfoGrid({ rows }: { rows: Array<[string, string]> }) {
  return (
    <dl className="mt-4 grid gap-3 text-sm">
      {rows.map(([label, value]) => <div className="flex justify-between gap-4 border-b border-[var(--color-border)] pb-2 last:border-0" key={label}><dt className="text-[var(--color-muted)]">{label}</dt><dd className="font-bold text-right">{value}</dd></div>)}
    </dl>
  );
}

export function SupplierPromotionPerformanceScreen({ promotionId }: { promotionId: string }) {
  const promotion = getPromotion(promotionId);
  return (
    <SupplierShell title="Promotion Performance">
      <section className="space-y-4">
        <Card title={promotion.name}>
          <div className="grid grid-cols-2 gap-3">
            <MetricCard label="Product views" value="620" note="Mock views" />
            <MetricCard label="Added to shops" value="38" note="Reseller saves" />
            <MetricCard label="Shares" value="92" note="Copy/share actions" />
            <MetricCard label="Orders influenced" value="12" note="Estimated orders" />
            <MetricCard label="Estimated supplier sales" value={formatGhc(3600)} note="Mock sales signal" />
            <MetricCard label="Promotion cost" value={formatGhc(20)} note="Manual payment" />
          </div>
          <p className="mt-4 font-bold">Cost per order influenced</p>
        </Card>
        <Card title="Trend chart placeholder"><BarChart3 className="h-12 w-12 text-[var(--color-primary)]" aria-hidden="true" /><p className="mt-3 text-sm text-[var(--color-muted)]">No real analytics are connected.</p></Card>
        <InfoGrid rows={[["Top areas", "Legon, Madina, UPSA"], ["Top reseller categories", "Beauty plugs, campus sellers"], ["Performance notes", "Sponsored products are marked clearly."]]} />
      </section>
    </SupplierShell>
  );
}

export function SupplierPromotionHistoryScreen() {
  return (
    <SupplierShell title="Promotion History">
      <Card title="Completed promotions">
        <div className="space-y-3">{promotions.filter((item) => item.status === "Completed").map((promotion) => <PromotionRow key={promotion.id} promotion={promotion} href={`/supplier/promotions/${promotion.id}/performance`} />)}</div>
      </Card>
    </SupplierShell>
  );
}

export function SupplierPromotionEligibilityScreen() {
  return (
    <SupplierShell title="Promotion Eligibility">
      <PromotionEligibilityChecklist />
    </SupplierShell>
  );
}

export function SupplierPromotionPaymentProofScreen() {
  return (
    <SupplierShell title="Promotion Payment Proof">
      <section className="space-y-4">
        <Card title="Selected package">
          <InfoGrid rows={[["Package", "Campus/Area Push"], ["Amount to pay", formatGhc(20)], ["Instructions", "Manual payment instructions placeholder"]]} />
        </Card>
        <Card title="Upload proof placeholder">
          <label className="block text-sm font-bold text-[var(--color-charcoal)]" htmlFor="promotion-reference-number">Reference number</label>
          <Input className="mt-2" id="promotion-reference-number" placeholder="PROMO-REF-00021" />
          <Button className="mt-4 w-full" type="button">Submit Proof Mock</Button>
        </Card>
        <p className="rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-sm font-bold text-[#8A5A00]">Admin must approve promotion payment before boost becomes active.</p>
        <p className="rounded-[var(--radius-md)] bg-[var(--color-danger-soft)] p-3 text-sm font-bold text-[var(--color-danger)]">No real payment is processed in this prototype.</p>
      </section>
    </SupplierShell>
  );
}

export function ResellerTrendingScreen() {
  return (
    <ResellerShell title="Trending Products">
      <section className="space-y-4">
        <Card><h2 className="text-xl font-extrabold">What should I sell today?</h2><p className="mt-2 text-sm text-[var(--color-muted)]">Hot products, sponsored picks, and profit signals for Ghana resellers.</p></Card>
        <div className="flex flex-wrap gap-2">{["All", "Beauty", "Phones", "Fashion", "Hostel Essentials", "Sponsored", "High Profit"].map((filter) => <Button key={filter} type="button" size="table-action" variant={filter === "All" ? "primary" : "outline"}>{filter}</Button>)}</div>
        {insightProducts.slice(0, 5).map((product) => <ProductOpportunityCard key={product.id} product={product} />)}
      </section>
    </ResellerShell>
  );
}

export function ResellerInsightsOverviewScreen() {
  return (
    <ResellerShell title="Reseller Insights">
      <section className="space-y-4">
        <Card title="Top opportunities">
          <div className="space-y-3 text-sm text-[var(--color-muted)]">
            <p>Beauty products are trending in Legon this week.</p>
            <p>Phone accessories have high repeat demand.</p>
            <p>Sponsored products are marked clearly.</p>
          </div>
        </Card>
        <section className="space-y-3" aria-labelledby="high-profit-products-heading">
          <h2 id="high-profit-products-heading" className="text-lg font-extrabold">High profit products</h2>
          <ProductOpportunityCard product={insightProducts[1]} />
        </section>
        <section className="space-y-3" aria-labelledby="low-competition-products-heading">
          <h2 id="low-competition-products-heading" className="text-lg font-extrabold">Low competition products</h2>
          <ProductOpportunityCard product={insightProducts[3]} />
        </section>
        <section className="space-y-3" aria-labelledby="nearby-products-heading">
          <h2 id="nearby-products-heading" className="text-lg font-extrabold">Products trending near reseller location</h2>
          <ProductOpportunityCard product={insightProducts[2]} />
        </section>
        <section className="space-y-3" aria-labelledby="whatsapp-picks-heading">
          <h2 id="whatsapp-picks-heading" className="text-lg font-extrabold">WhatsApp-ready picks</h2>
          <ProductOpportunityCard product={insightProducts[0]} />
        </section>
        <ProInsightLockedCard />
        <Card title="Performance tips"><p className="text-sm text-[var(--color-muted)]">Share products with clear price, Pay on Delivery trust copy, and stock urgency. Do not make false product claims.</p></Card>
      </section>
    </ResellerShell>
  );
}

const insightTitle: Record<InsightType, string> = {
  "top-selling": "Top-Selling Products",
  "high-profit": "High-Profit Products",
  "low-competition": "Low-Competition Products"
};

export function ResellerInsightListScreen({ type }: { type: InsightType }) {
  const products = type === "high-profit" ? [...insightProducts].sort((a, b) => b.expectedProfit - a.expectedProfit) : type === "low-competition" ? insightProducts.filter((item) => item.labels.includes("Low Competition")) : insightProducts;
  return (
    <ResellerShell title={insightTitle[type]}>
      <section className="space-y-4">
        {type === "top-selling" ? <Card title="Safe aggregated metrics"><div className="flex flex-wrap gap-2">{["High demand", "Fast moving", "Popular in Accra", "Good for students"].map((label) => <StatusBadge key={label}>{label}</StatusBadge>)}</div></Card> : null}
        {type === "high-profit" ? <Card title="Profit rules"><p className="font-bold">Max allowed price</p><p className="mt-1 text-sm text-[var(--color-muted)]">Reseller cost, max allowed price, stock state, and trust indicators stay visible.</p></Card> : null}
        {type === "low-competition" ? <Card title="Opportunity badge"><p className="text-sm text-[var(--color-muted)]">Products with fewer resellers promoting and clear profit potential.</p></Card> : null}
        {products.map((product) => <ProductOpportunityCard key={product.id} product={product} />)}
      </section>
    </ResellerShell>
  );
}

export function ResellerProInsightsScreen() {
  return (
    <ResellerShell title="Pro Insights">
      <ProInsightLockedCard />
    </ResellerShell>
  );
}

export function ResellerCaptionsScreen() {
  return (
    <ResellerShell title="WhatsApp Captions">
      <section className="space-y-4">
        <section className="space-y-3" aria-labelledby="caption-preview-card-heading">
          <h2 id="caption-preview-card-heading" className="text-lg font-extrabold">Preview card</h2>
          <ProductOpportunityCard product={insightProducts[0]} />
        </section>
        {captionTemplates.map((template) => (
          <Card title={template.title} key={template.title}>
            <StatusBadge>{template.category}</StatusBadge>
            <p className="mt-3 rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] p-3 text-sm leading-6">{template.caption}</p>
            <div className="mt-4 grid grid-cols-2 gap-2">
              <Button type="button" size="compact" variant="outline"><Copy className="h-4 w-4" aria-hidden="true" />Copy Caption</Button>
              <Button type="button" size="compact">Share Mock</Button>
            </div>
          </Card>
        ))}
      </section>
    </ResellerShell>
  );
}

export function ResellerSponsoredProductsScreen() {
  const sponsored = insightProducts.filter((item) => item.labels.includes("Sponsored"));
  return (
    <ResellerShell title="Sponsored Products">
      <section className="space-y-4">
        <Card>
          <p className="text-sm font-bold text-[var(--color-primary)]">Sponsored means supplier paid for visibility.</p>
          <p className="mt-2 text-sm text-[var(--color-muted)]">Product still passed Risellar trust checks.</p>
        </Card>
        {sponsored.map((product) => <SponsoredProductCard key={product.id} product={product} />)}
        <Card title="Supplier trust indicator"><p className="text-sm text-[var(--color-muted)]">Every sponsored product still shows stock state, supplier trust, and clear profit opportunity.</p></Card>
      </section>
    </ResellerShell>
  );
}

export function AdminPromotionsScreen() {
  return (
    <AdminShell>
      <PageHeader eyebrow="Promotion approval queue" title="Admin Promotions" description="Review boost requests, payment proof placeholders, eligibility, and safety signals." />
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
        <MetricCard label="Promotion requests" value="6" note="Needs review" />
        <MetricCard label="Active promotions" value="2" note="Live boosts" />
        <MetricCard label="Paused promotions" value="1" note="Risk or stock issue" />
        <MetricCard label="Completed promotions" value="5" note="Historical" />
        <MetricCard label="Payment proof pending" value="3" note="Mock upload review" />
      </div>
      <AdminPromotionTable />
    </AdminShell>
  );
}

export function AdminPromotionTable() {
  return (
    <Card title="Promotion requests table">
      <div className="overflow-x-auto">
        <table className="min-w-[920px] w-full text-left text-sm">
          <thead className="bg-[var(--color-muted-soft)] text-xs uppercase text-[var(--color-muted)]"><tr>{["Promotion", "Supplier status", "Product stock status", "Eligibility", "Amount", "Actions"].map((column) => <th className="px-4 py-3" key={column}>{column}</th>)}</tr></thead>
          <tbody>
            {promotions.slice(0, 3).map((promotion) => (
              <tr className="border-t border-[var(--color-border)]" key={promotion.id}>
                <td className="px-4 py-3"><Link className="font-bold text-[var(--color-primary)]" href={`/admin/promotions/${promotion.id}`}>{promotion.name}</Link><p className="text-xs text-[var(--color-muted)]">{promotion.product}</p></td>
                <td className="px-4 py-3">Verified supplier</td>
                <td className="px-4 py-3">In stock</td>
                <td className="px-4 py-3"><StatusBadge status={promotion.status} /></td>
                <td className="px-4 py-3 font-bold">{formatGhc(promotion.amount)}</td>
                <td className="px-4 py-3"><div className="flex flex-wrap gap-2"><Button disabled size="table-action" type="button">Approve Boost</Button><Button size="table-action" type="button" variant="outline">Reject</Button><Button size="table-action" type="button" variant="soft-warning">Pause</Button><Button size="table-action" type="button" variant="outline">View Product</Button><Button size="table-action" type="button" variant="outline">View Supplier</Button></div></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

export function AdminPromotionDetailScreen({ promotionId }: { promotionId: string }) {
  const promotion = getPromotion(promotionId);
  return (
    <AdminShell>
      <PageHeader eyebrow="Promotion detail" title={promotion.name} description="Mock-only promotion approval surface." />
      <div className="grid gap-5 xl:grid-cols-[1.1fr_0.9fr]">
        <Card title="Promotion request">
          <InfoGrid rows={[["Supplier", promotion.supplier], ["Product", promotion.product], ["Package", promotion.packageName], ["Amount", formatGhc(promotion.amount)], ["Status", promotion.status], ["Payment proof placeholder", "Screenshot placeholder only"]]} />
        </Card>
        <PromotionEligibilityChecklist />
        <Card title="Risk flags"><p className="text-sm text-[var(--color-muted)]">Overdue settlement, stock, complaint rate, and supplier restriction checks are displayed only.</p></Card>
        <Card title="Performance summary"><p className="text-sm text-[var(--color-muted)]">620 views, 38 added to shops, 12 orders influenced. No real analytics are connected.</p></Card>
        <Card title="Audit preview"><p className="text-sm text-[var(--color-muted)]">Approve/reject/pause actions must be audited in a future backend phase.</p></Card>
      </div>
    </AdminShell>
  );
}

export function AdminPromotionPackagesScreen() {
  return (
    <AdminShell>
      <PageHeader eyebrow="Admin package settings" title="Promotion Packages" description="Prices and durations are static mock data." />
      <Card title="Promotion packages table">
        <div className="overflow-x-auto">
          <table className="min-w-[760px] w-full text-left text-sm">
            <thead className="bg-[var(--color-muted-soft)] text-xs uppercase text-[var(--color-muted)]"><tr>{["Package", "Price", "Duration", "Placement", "Status", "Action"].map((column) => <th className="px-4 py-3" key={column}>{column}</th>)}</tr></thead>
            <tbody>{promotionPackages.map((pack) => <tr className="border-t border-[var(--color-border)]" key={pack.id}><td className="px-4 py-3 font-bold">{pack.name.replace("Campus/Area Push", "Campus Push")}</td><td className="px-4 py-3">{formatGhc(pack.price)}</td><td className="px-4 py-3">{pack.duration}</td><td className="px-4 py-3">{pack.placement}</td><td className="px-4 py-3"><StatusBadge status="Active" /></td><td className="px-4 py-3"><Button disabled size="table-action" type="button" variant="outline">Edit placeholder only</Button></td></tr>)}</tbody>
          </table>
        </div>
      </Card>
    </AdminShell>
  );
}
