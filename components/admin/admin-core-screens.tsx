import Link from "next/link";
import { AdminShell } from "@/components/admin/AdminSidebar";
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
  type MoneyBreakdown
} from "@/lib/mock/admin-core";

const orderFilters = ["All", "Pending Confirmation", "Preparing", "Delivery Quote Pending", "Completed", "Settlement Due"];

function AdminPageHeader({ title, eyebrow, children }: { title: string; eyebrow: string; children?: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)] lg:flex-row lg:items-center lg:justify-between">
      <div>
        <p className="text-xs font-bold uppercase tracking-[0.08em] text-[var(--color-primary)]">{eyebrow}</p>
        <h1 className="mt-1 text-2xl font-bold text-[var(--color-charcoal)]">{title}</h1>
      </div>
      {children}
    </div>
  );
}

function AdminSummaryCard({ label, value, note }: { label: string; value: string; note: string }) {
  return (
    <Card>
      <p className="text-sm text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 text-2xl font-bold">{value}</p>
      <p className="mt-1 text-xs font-semibold text-[var(--color-primary)]">{note}</p>
    </Card>
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

function DataTable({ columns, rows }: { columns: string[]; rows: React.ReactNode[][] }) {
  return (
    <div className="overflow-x-auto rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white shadow-[var(--shadow-sm)]">
      <table className="min-w-[920px] w-full text-left text-sm">
        <thead className="bg-[var(--color-muted-soft)] text-xs uppercase text-[var(--color-muted)]">
          <tr>
            {columns.map((column) => (
              <th className="px-4 py-3 font-bold" key={column}>{column}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr className="border-t border-[var(--color-border)]" key={rowIndex}>
              {row.map((cell, cellIndex) => (
                <td className="px-4 py-3 align-top" key={cellIndex}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
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

function EntityList({ title, rows }: { title: string; rows: Array<{ label: string; value: string; href: string; status: string; meta: string }> }) {
  return (
    <Card title={title}>
      <div className="grid gap-3 lg:grid-cols-2 xl:grid-cols-3">
        {rows.map((row) => (
          <Link aria-label={row.label} className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-4 transition hover:border-[var(--color-primary)] hover:bg-[var(--color-primary-subtle)]" href={row.href} key={row.href}>
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-bold">{row.label}</p>
                <p className="mt-1 text-sm text-[var(--color-muted)]">{row.meta}</p>
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
          <Link className="rounded-[var(--radius-md)] bg-[var(--color-primary)] px-4 py-2 text-sm font-bold text-white" href="/admin/orders">Review orders</Link>
          <Link className="rounded-[var(--radius-md)] border border-[var(--color-primary)] px-4 py-2 text-sm font-bold text-[var(--color-primary)]" href="/admin/settlements">View settlements</Link>
        </div>
      </AdminPageHeader>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {adminMetrics.map((metric) => (
          <AdminSummaryCard key={metric.label} label={metric.label} note={metric.trend} value={metric.value} />
        ))}
      </div>
      <div className="grid gap-5 xl:grid-cols-[1.4fr_0.8fr]">
        <Card title="Revenue and platform margin">
          <div className="grid gap-3 md:grid-cols-3">
            {[
              ["Gross order value", "GH₵84,620", "Mock month to date"],
              ["Platform margin", "GH₵7,480", "Visible to admin only"],
              ["Delivery estimates", "GH₵5,230", "Before dispatch confirmation"]
            ].map(([label, value, note]) => (
              <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-4" key={label}>
                <p className="text-sm text-[var(--color-muted)]">{label}</p>
                <p className="mt-2 text-2xl font-bold">{value}</p>
                <p className="mt-1 text-xs font-semibold text-[var(--color-primary)]">{note}</p>
              </div>
            ))}
          </div>
        </Card>
        <Card title="Recent activity">
          <div className="space-y-3">
            {recentAdminActivity.map((item) => <p className="rounded-[var(--radius-md)] bg-[var(--color-muted-soft)] p-3 text-sm" key={item}>{item}</p>)}
          </div>
        </Card>
      </div>
      <div className="grid gap-5 xl:grid-cols-3">
        <OrdersTable compact />
        <FinanceMiniSummary title="Supplier settlement summary" rows={adminSettlements} />
        <Card title="Product approval summary">
          <p className="text-3xl font-bold">14 products</p>
          <p className="mt-1 text-sm text-[var(--color-muted)]">Products pending approval review.</p>
          <Link className="mt-4 inline-flex text-sm font-bold text-[var(--color-primary)]" href="/admin/products">View product queue</Link>
        </Card>
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
          rows={adminOrders.map((order) => [
            order.displayId,
            order.customer,
            order.reseller,
            order.supplier,
            order.product,
            formatGhc(order.financials.totalPayOnDelivery),
            order.payment,
            <StatusBadge key={`${order.id}-status`} status={order.status} />,
            <StatusBadge key={`${order.id}-settlement`} status={order.settlement} />,
            <Link className="font-bold text-[var(--color-primary)]" href={`/admin/orders/${order.id}`} key={order.id}>View {order.id}</Link>
          ])}
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
  return (
    <AdminShell active="Orders">
      <AdminPageHeader eyebrow="Order detail" title={order.displayId}>
        <StatusBadge status={order.status} />
      </AdminPageHeader>
      <DetailGrid>
        <div className="space-y-5">
          <Card title="Order summary">
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
        rows={adminProducts.map((product) => ({ label: product.name, value: `${formatGhc(product.price.customerProductPrice)} customer price`, href: `/admin/products/${product.id}`, status: product.approval, meta: `${product.supplier} • ${product.category} • ${product.stock} in stock` }))}
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
          <div className="flex items-center justify-between gap-3" key={row.id}>
            <div>
              <p className="text-sm font-bold">{row.party}</p>
              <p className="text-xs text-[var(--color-muted)]">{row.orderId}</p>
            </div>
            <div className="text-right">
              <p className="font-bold">{formatGhc(row.amount)}</p>
              <StatusBadge status={row.status} />
            </div>
          </div>
        ))}
      </div>
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
