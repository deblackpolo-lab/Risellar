import Link from "next/link";
import type { ComponentType } from "react";
import {
  Activity,
  ArrowUpRight,
  BadgeDollarSign,
  Bell,
  PackageCheck,
  ReceiptText,
  ShieldAlert,
  ShoppingBag,
  Store,
  TrendingUp,
  Users,
  WalletCards
} from "lucide-react";
import { AdminShell } from "@/components/admin/AdminSidebar";
import { ProductImageFrame } from "@/components/marketplace";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";
import {
  adminCommissions,
  adminCustomers,
  adminMetrics,
  adminOrders,
  adminProducts,
  adminResellers,
  adminSettlements,
  adminSuppliers,
  adminSupportTickets,
  adminWithdrawals,
  formatGhc,
  getAdminCustomer,
  getAdminOrder,
  getAdminProduct,
  getAdminReseller,
  getAdminSupplier,
  recentAdminActivity,
  type AdminFinanceRow,
  type AdminOrder,
  type AdminProduct,
  type MoneyBreakdown
} from "@/lib/mock/admin-core";

const orderFilters = ["All", "Pending Confirmation", "Preparing", "Delivery Quote Pending", "Completed", "Settlement Due"];

type IconComponent = ComponentType<{ className?: string; "aria-hidden"?: boolean }>;

const metricIcons: Record<string, IconComponent> = {
  "Active resellers": Users,
  "Active suppliers": Store,
  "Overdue settlements": ShieldAlert,
  "Pending confirmations": Bell,
  "Pending reseller commissions": BadgeDollarSign,
  "Products pending approval": PackageCheck,
  "Settlement due": WalletCards,
  "Total orders": ShoppingBag
};

const recentActivityDetails = recentAdminActivity.map((title, index) => {
  const variants = [
    { icon: ShoppingBag, status: "New", tone: "primary", time: "12 min ago", detail: "Customer checkout entered the admin queue." },
    { icon: ShieldAlert, status: "Overdue", tone: "danger", time: "28 min ago", detail: "Settlement follow-up is required before restrictions escalate." },
    { icon: BadgeDollarSign, status: "Pending", tone: "warning", time: "42 min ago", detail: "Commission remains locked until supplier settlement is verified." },
    { icon: PackageCheck, status: "Review", tone: "warning", time: "1 hr ago", detail: "Catalog approval queue needs a product quality check." }
  ];

  return { title, ...variants[index % variants.length] };
});

const revenueStats = [
  ["Gross order value", "GH₵84,620", "Mock month to date"],
  ["Platform margin", "GH₵7,480", "Visible to admin only"],
  ["Delivery estimates", "GH₵5,230", "Before dispatch confirmation"]
];

function AdminPageHeader({ title, eyebrow, children }: { title: string; eyebrow: string; children?: React.ReactNode }) {
  return (
    <div className="relative overflow-hidden rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-6 shadow-[0_14px_36px_rgba(18,28,28,0.05)]">
      <div className="pointer-events-none absolute right-0 top-0 h-28 w-72 rounded-bl-full bg-[var(--color-primary-subtle)] opacity-70" aria-hidden />
      <div className="relative flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
      <div>
        <p className="text-xs font-bold uppercase tracking-[0.08em] text-[var(--color-primary)]">{eyebrow}</p>
        <h1 className="mt-1 text-[1.75rem] font-bold leading-tight text-[var(--color-charcoal)]">{title}</h1>
      </div>
      {children}
      </div>
    </div>
  );
}

function AdminSummaryCard({ label, value, note }: { label: string; value: string; note: string }) {
  const Icon = metricIcons[label] ?? Activity;
  const needsAttention = /overdue|pending|due|review|follow-up|awaiting/i.test(`${label} ${note}`);

  return (
    <div className="min-h-[136px] rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-5 shadow-[0_10px_26px_rgba(18,28,28,0.045)] transition hover:-translate-y-0.5 hover:border-[var(--color-primary-soft)] hover:shadow-[0_16px_34px_rgba(18,28,28,0.07)]">
      <div className="flex items-start justify-between gap-3">
        <span className="grid h-10 w-10 place-items-center rounded-full bg-[var(--color-primary-subtle)] text-[var(--color-primary)]">
          <Icon className="h-5 w-5" aria-hidden />
        </span>
        <span className={`rounded-full px-2.5 py-1 text-[11px] font-bold ${needsAttention ? "bg-[var(--color-warning-soft)] text-[#8A5A00]" : "bg-[var(--color-success-soft)] text-[var(--color-primary)]"}`}>
          {needsAttention ? "Review" : "Healthy"}
        </span>
      </div>
      <p className="mt-4 text-sm font-medium text-[var(--color-muted)]">{label}</p>
      <p className="mt-1 text-3xl font-extrabold leading-none tracking-normal">{value}</p>
      <p className="mt-3 text-xs font-bold text-[var(--color-primary)]">{note}</p>
    </div>
  );
}

function AdminStatusTabs({ items }: { items: string[] }) {
  return (
    <div className="flex flex-wrap gap-2">
      {items.map((item) => (
        <Button key={item} size="table-action" type="button" variant={item === "All" ? "primary" : "outline"}>
          {item}
        </Button>
      ))}
    </div>
  );
}

function AdminProductThumbnail({ product, size = "sm" }: { product: AdminProduct; size?: "sm" | "md" }) {
  return (
    <ProductImageFrame
      className={size === "md" ? "h-20 w-20 shrink-0 rounded-[12px]" : "h-14 w-14 shrink-0 rounded-[12px]"}
      imageAlt={product.imageAlt}
      images={product.images}
      productName={product.name}
    />
  );
}

function AdminProductInline({ product }: { product: AdminProduct }) {
  return (
    <div className="flex min-w-[220px] items-center gap-3">
      <AdminProductThumbnail product={product} />
      <div className="min-w-0">
        <p className="line-clamp-2 text-sm font-semibold leading-5 text-[var(--color-charcoal)]">{product.name}</p>
        <p className="mt-0.5 text-xs text-[var(--color-muted)]">{product.category}</p>
      </div>
    </div>
  );
}

function DataTable({ columns, rows }: { columns: string[]; rows: React.ReactNode[][] }) {
  return (
    <div className="scrollbar-none overflow-x-auto rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white shadow-[0_10px_28px_rgba(18,28,28,0.045)]">
      <table className="min-w-[920px] w-full text-left text-sm">
        <thead className="bg-[var(--color-muted-soft)] text-[11px] uppercase tracking-[0.05em] text-[var(--color-muted)]">
          <tr>
            {columns.map((column) => (
              <th className="whitespace-nowrap px-4 py-3.5 font-bold" key={column}>{column}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr className="border-t border-[var(--color-border)] transition hover:bg-[var(--color-primary-subtle)]" key={rowIndex}>
              {row.map((cell, cellIndex) => (
                <td className="px-4 py-3.5 align-top" key={cellIndex}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function RevenueAnalyticsCard() {
  return (
    <Card title="Revenue and platform margin">
      <div className="grid gap-5 xl:grid-cols-[1.15fr_0.85fr]">
        <div className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-[linear-gradient(180deg,#FFFFFF,var(--color-page))] p-4">
          <div className="mb-4 flex items-center justify-between gap-3">
            <div>
              <p className="text-sm font-bold">Mock month trend</p>
              <p className="text-xs text-[var(--color-muted)]">Orders, margin, and delivery estimates</p>
            </div>
            <span className="inline-flex items-center gap-1 rounded-full bg-[var(--color-success-soft)] px-2.5 py-1 text-xs font-bold text-[var(--color-primary)]">
              <TrendingUp className="h-3.5 w-3.5" aria-hidden />
              +18.6%
            </span>
          </div>
          <svg aria-label="Revenue trend placeholder" className="h-40 w-full" role="img" viewBox="0 0 520 160">
            <defs>
              <linearGradient id="adminRevenueFill" x1="0" x2="0" y1="0" y2="1">
                <stop offset="0%" stopColor="#11865E" stopOpacity="0.22" />
                <stop offset="100%" stopColor="#11865E" stopOpacity="0" />
              </linearGradient>
            </defs>
            {[38, 72, 54, 96, 82, 118, 68, 132].map((height, index) => (
              <rect fill={index % 2 ? "#11865E" : "#F5B300"} height={height} key={index} opacity={index % 2 ? "0.28" : "0.36"} rx="8" width="22" x={34 + index * 58} y={138 - height} />
            ))}
            <path d="M34 112 C88 82, 116 94, 154 72 S230 62, 266 86 S340 126, 382 84 S444 48, 492 60" fill="none" stroke="#08684F" strokeLinecap="round" strokeWidth="5" />
            <path d="M34 112 C88 82, 116 94, 154 72 S230 62, 266 86 S340 126, 382 84 S444 48, 492 60 L492 146 L34 146 Z" fill="url(#adminRevenueFill)" />
          </svg>
          <div className="mt-3 flex flex-wrap gap-4 text-xs font-semibold text-[var(--color-muted)]">
            <span className="inline-flex items-center gap-2"><span className="h-2.5 w-2.5 rounded-full bg-[var(--color-primary)]" />Order value</span>
            <span className="inline-flex items-center gap-2"><span className="h-2.5 w-2.5 rounded-full bg-[var(--color-accent)]" />Delivery estimate</span>
          </div>
        </div>
        <div className="grid gap-3">
          {revenueStats.map(([label, value, note]) => (
            <div className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4" key={label}>
              <p className="text-sm font-medium text-[var(--color-muted)]">{label}</p>
              <p className="mt-1 text-2xl font-extrabold">{value}</p>
              <p className="mt-1 text-xs font-bold text-[var(--color-primary)]">{note}</p>
            </div>
          ))}
        </div>
      </div>
    </Card>
  );
}

function RecentActivityList() {
  return (
    <Card title="Recent activity">
      <div className="space-y-3">
        {recentActivityDetails.map((item) => {
          const Icon = item.icon;

          return (
            <div className="flex gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-3 transition hover:border-[var(--color-primary-soft)]" key={item.title}>
              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[var(--color-primary-subtle)] text-[var(--color-primary)]">
                <Icon className="h-4 w-4" aria-hidden />
              </span>
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <p className="font-bold leading-snug">{item.title}</p>
                  <StatusBadge status={item.status} />
                </div>
                <p className="mt-1 text-xs leading-5 text-[var(--color-muted)]">{item.detail}</p>
                <p className="mt-2 text-[11px] font-bold uppercase tracking-[0.06em] text-[var(--color-muted)]">{item.time}</p>
              </div>
            </div>
          );
        })}
      </div>
    </Card>
  );
}

function AdminPriceBreakdownPanel({ financials, customerOnly = false }: { financials: MoneyBreakdown; customerOnly?: boolean }) {
  const rows = customerOnly
    ? [
        ["Customer product price", financials.customerProductPrice],
        ["Delivery fee", financials.deliveryFee],
        ["Total Pay on Delivery", financials.totalPayOnDelivery]
      ]
    : [
        ["Supplier base price", financials.supplierBase],
        ["Risellar platform margin", financials.platformMargin],
        ["Reseller margin", financials.resellerMargin],
        ["Customer product price", financials.customerProductPrice],
        ["Delivery fee", financials.deliveryFee],
        ["Total Pay on Delivery", financials.totalPayOnDelivery]
      ];

  return (
    <Card title={customerOnly ? "Customer-facing financial view" : "Admin pricing layers"}>
      <div className="space-y-3">
        {rows.map(([label, amount]) => (
          <div className="flex items-center justify-between gap-4 border-b border-[var(--color-border)] pb-2 last:border-0 last:pb-0" key={label}>
            <span className="text-sm text-[var(--color-muted)]">{label}</span>
            <span className="font-bold">{formatGhc(Number(amount))}</span>
          </div>
        ))}
      </div>
      <p className="mt-4 rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] p-3 text-xs font-semibold text-[var(--color-primary)]">
        {customerOnly ? "Customer only sees product price, delivery fee, and total to pay." : "Admin can view supplier, platform, reseller, customer, and delivery layers."}
      </p>
    </Card>
  );
}

function AdminTimelinePanel({ order }: { order: AdminOrder }) {
  return (
    <Card title="Order timeline">
      <div className="space-y-3">
        {order.timeline.map((item) => (
          <div className="flex gap-3" key={item.label}>
            <span className="mt-1 h-3 w-3 rounded-full bg-[var(--color-primary)]" aria-hidden="true" />
            <div>
              <p className="text-sm font-bold">{item.label}</p>
              <p className="text-xs text-[var(--color-muted)]">{item.value}</p>
              <StatusBadge status={item.status} />
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
}

function AdminNotesPanel() {
  return (
    <Card title="Admin notes placeholder">
      <textarea
        aria-label="Admin notes"
        className="min-h-28 w-full rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm outline-none focus:border-[var(--color-primary)] focus:ring-2 focus:ring-[var(--color-primary-soft)]"
        placeholder="Add internal notes in a future connected workflow."
      />
      <p className="mt-2 text-xs text-[var(--color-muted)]">Notes are not persisted in Phase 9.</p>
    </Card>
  );
}

function DetailGrid({ children }: { children: React.ReactNode }) {
  return <div className="grid gap-5 xl:grid-cols-[1.35fr_0.9fr]">{children}</div>;
}

function EntityList({ title, rows }: { title: string; rows: Array<{ image?: React.ReactNode; label: string; value: string; href: string; status: string; meta: string }> }) {
  return (
    <Card title={title}>
      <div className="grid gap-3 lg:grid-cols-2 xl:grid-cols-3">
        {rows.map((row) => (
          <Link aria-label={row.label} className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-4 transition hover:border-[var(--color-primary)] hover:bg-[var(--color-primary-subtle)]" href={row.href} key={row.href}>
            <div className="flex items-start justify-between gap-3">
              <div className="flex min-w-0 items-start gap-3">
                {row.image}
                <div className="min-w-0">
                  <p className="font-bold">{row.label}</p>
                  <p className="mt-1 text-sm text-[var(--color-muted)]">{row.meta}</p>
                </div>
              </div>
              <StatusBadge status={row.status} />
            </div>
            <p className="mt-3 text-lg font-bold text-[var(--color-primary)]">{row.value}</p>
          </Link>
        ))}
      </div>
    </Card>
  );
}

function FinanceSummaryScreen({ active, title, description, rows }: { active: string; title: string; description: string; rows: AdminFinanceRow[] }) {
  return (
    <AdminShell active={active}>
      <AdminPageHeader eyebrow="Finance operations" title={title}>
        <StatusBadge status="Read Only" />
      </AdminPageHeader>
      <Card title={description}>
        <p className="mb-4 text-sm font-semibold text-[var(--color-primary)]">
          {active === "Settlements" ? "No payment verification workflow is connected." : active === "Withdrawals" ? "Withdrawal approval is not implemented in Phase 9." : "Commission release is displayed only after verified supplier settlement."}
        </p>
        <DataTable
          columns={["Reference", "Party", "Order / Batch", "Amount", "Status", "Note"]}
          rows={rows.map((row) => [
            row.id,
            row.party,
            row.orderId,
            formatGhc(row.amount),
            <StatusBadge key={row.id} status={row.status} />,
            row.note
          ])}
        />
      </Card>
    </AdminShell>
  );
}

export function AdminDashboardScreen() {
  return (
    <AdminShell active="Dashboard">
      <AdminPageHeader eyebrow="Marketplace control center" title="Admin Dashboard">
        <div className="flex flex-wrap gap-2">
          <Link className="inline-flex min-h-10 items-center gap-2 rounded-[var(--radius-md)] bg-[var(--color-primary)] px-4 text-sm font-bold text-white shadow-[var(--shadow-sm)] transition hover:bg-[var(--color-primary-dark)]" href="/admin/orders">Review orders<ArrowUpRight className="h-4 w-4" aria-hidden /></Link>
          <Link className="inline-flex min-h-10 items-center gap-2 rounded-[var(--radius-md)] border border-[var(--color-primary)] bg-white px-4 text-sm font-bold text-[var(--color-primary)] transition hover:bg-[var(--color-primary-subtle)]" href="/admin/settlements">View settlements<ReceiptText className="h-4 w-4" aria-hidden /></Link>
        </div>
      </AdminPageHeader>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {adminMetrics.map((metric) => (
          <AdminSummaryCard key={metric.label} label={metric.label} note={metric.trend} value={metric.value} />
        ))}
      </div>
      <div className="grid gap-5 xl:grid-cols-[1.4fr_0.8fr]">
        <RevenueAnalyticsCard />
        <RecentActivityList />
      </div>
      <div className="grid gap-5 xl:grid-cols-3">
        <OrdersTable compact />
        <FinanceMiniSummary title="Supplier settlement summary" rows={adminSettlements} />
        <ProductApprovalSummary />
      </div>
      <Card title="Support and dispute summary">
        <div className="grid gap-3 md:grid-cols-3">
          {adminSupportTickets.map((ticket) => (
            <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-4" key={ticket.id}>
              <p className="text-sm font-bold">{ticket.title}</p>
              <p className="mt-1 text-xs text-[var(--color-muted)]">{ticket.id} • {ticket.customer}</p>
              <div className="mt-3 flex gap-2"><StatusBadge status={ticket.priority} /><StatusBadge status={ticket.status} /></div>
            </div>
          ))}
        </div>
      </Card>
    </AdminShell>
  );
}

function OrdersTable({ compact = false }: { compact?: boolean }) {
  return (
    <Card title="Recent orders">
      {!compact ? <AdminStatusTabs items={orderFilters} /> : null}
      <div className={compact ? "" : "mt-4"}>
        <DataTable
          columns={["Order ID", "Customer", "Reseller", "Supplier", "Product", "Final Price", "Payment", "Status", "Settlement", "Action"]}
          rows={adminOrders.map((order) => {
            const product = getAdminProduct(order.productId);

            return [
              <span className="block max-w-[132px] truncate font-bold text-[var(--color-charcoal)]" key={`${order.id}-display`}>{order.displayId}</span>,
              <span className="font-semibold" key={`${order.id}-customer`}>{order.customer}</span>,
              <span className="text-[var(--color-muted)]" key={`${order.id}-reseller`}>{order.reseller}</span>,
              <span className="text-[var(--color-muted)]" key={`${order.id}-supplier`}>{order.supplier}</span>,
              <AdminProductInline key={`${order.id}-product`} product={product} />,
              <span className="font-extrabold text-[var(--color-primary)]" key={`${order.id}-amount`}>{formatGhc(order.financials.totalPayOnDelivery)}</span>,
              order.payment,
              <StatusBadge key={`${order.id}-status`} status={order.status} />,
              <StatusBadge key={`${order.id}-settlement`} status={order.settlement} />,
              <Link className="inline-flex items-center gap-1 font-bold text-[var(--color-primary)]" href={`/admin/orders/${order.id}`} key={order.id}>View {order.id}<ArrowUpRight className="h-3.5 w-3.5" aria-hidden /></Link>
            ];
          })}
        />
      </div>
    </Card>
  );
}

export function AdminOrdersScreen() {
  return (
    <AdminShell active="Orders">
      <AdminPageHeader eyebrow="Order operations" title="Orders" />
      <OrdersTable />
    </AdminShell>
  );
}

export function AdminOrderDetailScreen({ orderId }: { orderId: string }) {
  const order = getAdminOrder(orderId);
  const product = getAdminProduct(order.productId);
  return (
    <AdminShell active="Orders">
      <AdminPageHeader eyebrow="Order detail" title={order.displayId}>
        <StatusBadge status={order.status} />
      </AdminPageHeader>
      <DetailGrid>
        <div className="space-y-5">
          <Card title="Order summary">
            <div className="mb-5 flex items-center gap-4 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-[var(--color-page)] p-3">
              <AdminProductThumbnail product={product} size="md" />
              <div className="min-w-0">
                <p className="text-xs font-bold uppercase text-[var(--color-muted)]">Product context</p>
                <p className="line-clamp-2 font-bold leading-5">{product.name}</p>
                <p className="mt-1 text-sm text-[var(--color-muted)]">{product.category} - {product.supplier}</p>
              </div>
            </div>
            <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
              {[
                ["Customer", order.customer],
                ["Reseller", order.reseller],
                ["Supplier", order.supplier],
                ["Product", order.product],
                ["Delivery area", order.location],
                ["Payment", order.payment]
              ].map(([label, value]) => (
                <div key={label}><p className="text-xs font-bold uppercase text-[var(--color-muted)]">{label}</p><p className="mt-1 font-bold">{value}</p></div>
              ))}
            </div>
          </Card>
          <AdminTimelinePanel order={order} />
          <AdminNotesPanel />
        </div>
        <div className="space-y-5">
          <AdminPriceBreakdownPanel financials={order.financials} />
          <p className="rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] p-3 text-sm font-semibold text-[var(--color-primary)]">
            Customer only sees product price, delivery fee, and total to pay.
          </p>
          <Card title="Mock admin actions">
            <div className="grid gap-2">
              {["Send Confirmation Message", "Notify Supplier", "Mark Delivered", "Review Settlement"].map((action) => (
                <Button key={action} type="button" variant="outline">{action}</Button>
              ))}
            </div>
          </Card>
        </div>
      </DetailGrid>
    </AdminShell>
  );
}

export function AdminProductsScreen() {
  return (
    <AdminShell active="Products">
      <AdminPageHeader eyebrow="Catalog governance" title="Products" />
      <EntityList
        title="Product list"
        rows={adminProducts.map((product) => ({ image: <AdminProductThumbnail product={product} />, label: product.name, value: `${formatGhc(product.price.customerProductPrice)} customer price`, href: `/admin/products/${product.id}`, status: product.approval, meta: `${product.supplier} - ${product.category} - ${product.stock} in stock` }))}
      />
    </AdminShell>
  );
}

export function AdminProductDetailScreen({ productId }: { productId: string }) {
  const product = getAdminProduct(productId);
  return (
    <AdminShell active="Products">
      <AdminPageHeader eyebrow="Product detail" title={product.name}><StatusBadge status={product.approval} /></AdminPageHeader>
      <DetailGrid>
        <Card title="Product profile">
          <div className="mb-5 flex items-center gap-4 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-[var(--color-page)] p-3">
            <AdminProductThumbnail product={product} size="md" />
            <div>
              <p className="text-xs font-bold uppercase text-[var(--color-muted)]">Catalog image</p>
              <p className="mt-1 text-sm font-semibold text-[var(--color-primary)]">Mock product gallery preview</p>
            </div>
          </div>
          <dl className="grid gap-4 md:grid-cols-2">
            {[
              ["Supplier", product.supplier],
              ["Category", product.category],
              ["Stock", String(product.stock)],
              ["Active resellers", String(product.activeResellers)],
              ["Risk level", product.risk],
              ["Status", product.status]
            ].map(([label, value]) => <div key={label}><dt className="text-xs font-bold uppercase text-[var(--color-muted)]">{label}</dt><dd className="mt-1 font-bold">{value}</dd></div>)}
          </dl>
          <p className="mt-5 rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-sm font-semibold text-[#8A5A00]">Approval state is mock-only in Phase 9.</p>
        </Card>
        <AdminPriceBreakdownPanel financials={product.price} />
      </DetailGrid>
    </AdminShell>
  );
}

export function AdminSuppliersScreen() {
  return (
    <AdminShell active="Suppliers">
      <AdminPageHeader eyebrow="Supplier management" title="Suppliers" />
      <EntityList title="Supplier list" rows={adminSuppliers.map((supplier) => ({ label: supplier.name, value: formatGhc(supplier.settlementDue), href: `/admin/suppliers/${supplier.id}`, status: supplier.status, meta: `${supplier.location} • ${supplier.products} products • ${supplier.trustScore}` }))} />
    </AdminShell>
  );
}

export function AdminSupplierDetailScreen({ supplierId }: { supplierId: string }) {
  const supplier = getAdminSupplier(supplierId);
  return (
    <AdminShell active="Suppliers">
      <AdminPageHeader eyebrow="Supplier detail" title={supplier.name}><StatusBadge status={supplier.status} /></AdminPageHeader>
      <DetailGrid>
        <Card title="Supplier profile">
          <ProfileRows rows={[["Owner", supplier.owner], ["Location", supplier.location], ["Category", supplier.category], ["Products", String(supplier.products)], ["Trust score", supplier.trustScore]]} />
        </Card>
        <Card title="Settlement visibility">
          <p className="text-sm text-[var(--color-muted)]">Admin can see supplier dues, overdue amount, and linked settlement rows.</p>
          <p className="mt-4 text-2xl font-bold">{formatGhc(supplier.settlementDue)}</p>
          <p className="text-sm text-[var(--color-danger)]">Overdue: {formatGhc(supplier.overdue)}</p>
        </Card>
      </DetailGrid>
    </AdminShell>
  );
}

export function AdminResellersScreen() {
  return (
    <AdminShell active="Resellers">
      <AdminPageHeader eyebrow="Reseller management" title="Resellers" />
      <EntityList title="Reseller list" rows={adminResellers.map((reseller) => ({ label: reseller.name, value: `${formatGhc(reseller.commissionPending)} pending`, href: `/admin/resellers/${reseller.id}`, status: reseller.status, meta: `${reseller.location} • ${reseller.orders} orders • ${reseller.trustScore}` }))} />
    </AdminShell>
  );
}

export function AdminResellerDetailScreen({ resellerId }: { resellerId: string }) {
  const reseller = getAdminReseller(resellerId);
  return (
    <AdminShell active="Resellers">
      <AdminPageHeader eyebrow="Reseller detail" title={reseller.name}><StatusBadge status={reseller.status} /></AdminPageHeader>
      <DetailGrid>
        <Card title="Reseller profile">
          <ProfileRows rows={[["Owner", reseller.owner], ["Location", reseller.location], ["Orders", String(reseller.orders)], ["Trust score", reseller.trustScore]]} />
        </Card>
        <Card title="Commission status">
          <p className="text-sm text-[var(--color-muted)]">Pending commission is not withdrawable until supplier settlement is verified.</p>
          <p className="mt-4 text-2xl font-bold">{formatGhc(reseller.commissionPending)} pending</p>
          <p className="text-sm font-semibold text-[var(--color-primary)]">{formatGhc(reseller.commissionAvailable)} available</p>
        </Card>
      </DetailGrid>
    </AdminShell>
  );
}

export function AdminCustomersScreen() {
  return (
    <AdminShell active="Customers">
      <AdminPageHeader eyebrow="Customer support context" title="Customers" />
      <EntityList title="Customer list" rows={adminCustomers.map((customer) => ({ label: customer.name, value: `${customer.orders} orders`, href: `/admin/customers/${customer.id}`, status: customer.status, meta: `${customer.location} • ${customer.phone} • ${formatGhc(customer.totalPaid)} paid` }))} />
    </AdminShell>
  );
}

export function AdminCustomerDetailScreen({ customerId }: { customerId: string }) {
  const customer = getAdminCustomer(customerId);
  const order = adminOrders.find((item) => item.customerId === customer.id) ?? adminOrders[0];
  return (
    <AdminShell active="Customers">
      <AdminPageHeader eyebrow="Customer detail" title={customer.name}><StatusBadge status={customer.status} /></AdminPageHeader>
      <DetailGrid>
        <Card title="Customer profile">
          <ProfileRows rows={[["Phone", customer.phone], ["Location", customer.location], ["Orders", String(customer.orders)], ["Last order", customer.lastOrder]]} />
        </Card>
        <AdminPriceBreakdownPanel customerOnly financials={order.financials} />
      </DetailGrid>
    </AdminShell>
  );
}

function ProfileRows({ rows }: { rows: Array<[string, string]> }) {
  return (
    <dl className="grid gap-4 md:grid-cols-2">
      {rows.map(([label, value]) => <div key={label}><dt className="text-xs font-bold uppercase text-[var(--color-muted)]">{label}</dt><dd className="mt-1 font-bold">{value}</dd></div>)}
    </dl>
  );
}

function FinanceMiniSummary({ title, rows }: { title: string; rows: AdminFinanceRow[] }) {
  return (
    <Card title={title}>
      <div className="space-y-3">
        {rows.slice(0, 3).map((row) => (
          <div className="flex items-center justify-between gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-3" key={row.id}>
            <div className="min-w-0">
              <p className="truncate text-sm font-bold">{row.party}</p>
              <p className="text-xs text-[var(--color-muted)]">{row.orderId}</p>
              <p className="mt-1 text-[11px] font-semibold text-[var(--color-muted)]">{row.note}</p>
            </div>
            <div className="text-right">
              <p className="font-extrabold">{formatGhc(row.amount)}</p>
              <StatusBadge status={row.status} />
            </div>
          </div>
        ))}
      </div>
      <Link className="mt-4 inline-flex items-center gap-1 text-sm font-bold text-[var(--color-primary)]" href="/admin/settlements">View settlement queue<ArrowUpRight className="h-4 w-4" aria-hidden /></Link>
    </Card>
  );
}

function ProductApprovalSummary() {
  return (
    <Card title="Product approval summary">
      <div className="flex items-end justify-between gap-3">
        <div>
          <p className="text-3xl font-extrabold">14 products</p>
          <p className="mt-1 text-sm text-[var(--color-muted)]">Products pending approval review.</p>
        </div>
        <span className="grid h-11 w-11 place-items-center rounded-full bg-[var(--color-warning-soft)] text-[#8A5A00]">
          <PackageCheck className="h-5 w-5" aria-hidden />
        </span>
      </div>
      <div className="mt-5 space-y-3">
        {adminProducts.map((product) => (
          <div className="flex items-start gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-3" key={product.id}>
            <AdminProductThumbnail product={product} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-bold">{product.name}</p>
              <p className="mt-1 text-xs text-[var(--color-muted)]">{product.supplier} • {product.category}</p>
            </div>
            <StatusBadge status={product.approval} />
          </div>
        ))}
      </div>
      <Link className="mt-4 inline-flex items-center gap-1 text-sm font-bold text-[var(--color-primary)]" href="/admin/products">View product queue<ArrowUpRight className="h-4 w-4" aria-hidden /></Link>
    </Card>
  );
}

export function AdminSettlementsScreen() {
  return <FinanceSummaryScreen active="Settlements" description="Read-only settlement summary for Phase 9." rows={adminSettlements} title="Settlements" />;
}

export function AdminCommissionsScreen() {
  return <FinanceSummaryScreen active="Commissions" description="Pending and released reseller commission summary." rows={adminCommissions} title="Commissions" />;
}

export function AdminWithdrawalsScreen() {
  return <FinanceSummaryScreen active="Withdrawals" description="Mock withdrawal request summary." rows={adminWithdrawals} title="Withdrawals" />;
}

export function AdminSupportScreen() {
  return (
    <AdminShell active="Support">
      <AdminPageHeader eyebrow="Customer and marketplace support" title="Support" />
      <Card title="Support and dispute summary only.">
        <DataTable
          columns={["Ticket", "Issue", "Customer / Party", "Priority", "Status", "Owner"]}
          rows={adminSupportTickets.map((ticket) => [ticket.id, ticket.title, ticket.customer, <StatusBadge key={`${ticket.id}-priority`} status={ticket.priority} />, <StatusBadge key={`${ticket.id}-status`} status={ticket.status} />, ticket.owner])}
        />
      </Card>
    </AdminShell>
  );
}

export function AdminSettingsScreen() {
  const categories = ["Admin profile", "Marketplace rules", "Delivery settings", "Notification templates", "Audit and compliance"];
  return (
    <AdminShell active="Settings">
      <AdminPageHeader eyebrow="Configuration placeholders" title="Settings" />
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {categories.map((category) => (
          <Card key={category} title={category}>
            <p className="text-sm text-[var(--color-muted)]">Placeholder category only. No settings are persisted or connected in Phase 9.</p>
          </Card>
        ))}
      </div>
    </AdminShell>
  );
}
