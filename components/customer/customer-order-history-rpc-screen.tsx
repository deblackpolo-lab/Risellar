import Link from "next/link";
import { CalendarDays, Clock3, CreditCard, PackageCheck, Search, ShieldCheck, Truck } from "lucide-react";
import { MobileShell } from "@/components/layout";
import { Card } from "@/components/ui/Card";
import { Input } from "@/components/ui/Input";
import { StatusBadge } from "@/components/ui/StatusBadge";
import type { CustomerOrderHistoryGroup, CustomerOrderHistoryItem, CustomerOrderSummary } from "@/lib/orders/customer-order-history";

function formatMoney(value: number | null, currencyCode: string | null) {
  if (value === null) {
    return "Amount pending";
  }

  const currency = currencyCode || "GHS";
  const prefix = currency === "GHS" ? "GHS " : `${currency} `;
  return `${prefix}${value.toLocaleString("en-GH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function formatDateTime(value: string | null) {
  if (!value) {
    return "Not set";
  }

  return new Intl.DateTimeFormat("en-GH", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

function activeLinkClass(active: boolean) {
  return active
    ? "inline-flex h-10 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] bg-[var(--color-primary)] px-4 text-sm font-bold text-white"
    : "inline-flex h-10 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-4 text-sm font-bold text-[var(--color-charcoal)]";
}

function groupTone(group: CustomerOrderHistoryGroup) {
  if (group === "completed") {
    return "success" as const;
  }

  if (group === "rejected") {
    return "danger" as const;
  }

  return "warning" as const;
}

function OrderCard({ order }: { order: CustomerOrderHistoryItem }) {
  const primaryAlt = typeof order.productImageSnapshot.primary_alt === "string" ? order.productImageSnapshot.primary_alt : order.productName;

  return (
    <Card className="p-4">
      <div className="flex gap-4">
        <div className="grid h-16 w-16 shrink-0 place-items-center rounded-[var(--radius-md)] bg-[var(--color-muted-soft)] text-[var(--color-primary)]">
          <PackageCheck className="h-7 w-7" aria-label={primaryAlt} />
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-start justify-between gap-2">
            <div>
              <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-muted)]">{order.orderNumber}</p>
              <h2 className="mt-1 text-base font-extrabold text-[var(--color-charcoal)]">{order.productName}</h2>
            </div>
            <StatusBadge tone={groupTone(order.orderStatusGroup)}>{order.orderStatusLabel}</StatusBadge>
          </div>
          <div className="mt-3 grid gap-2 text-sm text-[var(--color-muted)]">
            <p className="flex items-center gap-2">
              <CalendarDays className="h-4 w-4" aria-hidden="true" />
              {formatDateTime(order.createdAt)}
            </p>
            <p className="flex items-center gap-2">
              <CreditCard className="h-4 w-4" aria-hidden="true" />
              {order.paymentMethodLabel} - {order.paymentCollectionLabel}
            </p>
            <p className="flex items-center gap-2">
              <Truck className="h-4 w-4" aria-hidden="true" />
              {order.deliveryStatusLabel}
            </p>
          </div>
          <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
            <p className="text-sm font-bold text-[var(--color-charcoal)]">
              {order.quantity} item{order.quantity === 1 ? "" : "s"} - {formatMoney(order.totalPayableAmount, order.currencyCode)}
            </p>
            <Link
              className="inline-flex h-10 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] bg-white px-4 text-sm font-bold text-[var(--color-primary)]"
              href={order.detailHref}
            >
              View details
            </Link>
          </div>
        </div>
      </div>
    </Card>
  );
}

function SummaryCard({ summary }: { summary: CustomerOrderSummary }) {
  const items = [
    ["All", summary.totalOrderCount],
    ["Active", summary.activeOrderCount],
    ["Completed", summary.completedOrderCount],
    ["Rejected", summary.rejectedOrderCount]
  ];

  return (
    <Card title="Order summary">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {items.map(([label, value]) => (
          <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-3" key={label}>
            <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-muted)]">{label}</p>
            <p className="mt-1 text-2xl font-extrabold text-[var(--color-charcoal)]">{value}</p>
          </div>
        ))}
      </div>
      {summary.latestOrderNumber ? (
        <p className="mt-4 flex items-center gap-2 text-sm text-[var(--color-muted)]">
          <Clock3 className="h-4 w-4" aria-hidden="true" />
          Latest order {summary.latestOrderNumber}: {summary.latestOrderStatusLabel} - {formatMoney(summary.latestTotalPayableAmount, summary.currencyCode)}
        </p>
      ) : null}
    </Card>
  );
}

export function CustomerOrderHistoryRpcScreen({
  activeGroup,
  orders,
  search,
  summary
}: {
  activeGroup: CustomerOrderHistoryGroup;
  orders: CustomerOrderHistoryItem[];
  search: string;
  summary: CustomerOrderSummary;
}) {
  const groups: Array<[CustomerOrderHistoryGroup, string]> = [
    ["all", "All"],
    ["active", "Active"],
    ["completed", "Completed"],
    ["rejected", "Rejected"]
  ];

  return (
    <MobileShell>
      <header className="grid gap-3 rounded-[var(--radius-lg)] bg-[var(--color-primary)] p-5 text-white shadow-[var(--shadow-md)]">
        <p className="text-sm font-semibold text-[var(--color-accent)]">Customer account</p>
        <h1 className="text-[28px] font-bold leading-tight">Your orders</h1>
        <p className="text-sm leading-6 text-white/85">
          View Pay on Delivery order progress. Checkout edits, cancellation, refunds, online payments, and delivery changes are not connected here.
        </p>
      </header>

      <SummaryCard summary={summary} />

      <Card title="Filter orders">
        <div className="flex flex-wrap gap-2">
          {groups.map(([group, label]) => (
            <Link className={activeLinkClass(group === activeGroup)} href={group === "all" ? "/customer/orders" : `/customer/orders?group=${group}`} key={group}>
              {label}
            </Link>
          ))}
        </div>
        <form className="mt-4 grid gap-3 sm:grid-cols-[1fr_auto]" method="get">
          {activeGroup !== "all" ? <input name="group" type="hidden" value={activeGroup} /> : null}
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Search orders
            <Input defaultValue={search} name="search" placeholder="Order number, product, or shop" />
          </label>
          <button className="inline-flex h-11 items-center justify-center gap-2 self-end rounded-[var(--radius-md)] bg-[var(--color-primary)] px-5 text-sm font-bold text-white" type="submit">
            <Search className="h-4 w-4" aria-hidden="true" />
            Search
          </button>
        </form>
      </Card>

      {orders.length ? (
        <section className="grid gap-3" aria-label="Customer orders">
          {orders.map((order) => <OrderCard key={order.orderId} order={order} />)}
        </section>
      ) : (
        <Card className="p-5 text-center">
          <PackageCheck className="mx-auto h-8 w-8 text-[var(--color-primary)]" aria-hidden="true" />
          <h2 className="mt-3 text-lg font-extrabold text-[var(--color-charcoal)]">No orders found</h2>
          <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">Try another filter or search term. Order creation and checkout actions remain separate from this read-only view.</p>
        </Card>
      )}

      <Card className="bg-[var(--color-accent-soft)] p-4">
        <div className="flex gap-3">
          <ShieldCheck className="h-5 w-5 flex-none text-[var(--color-primary)]" aria-hidden="true" />
          <div>
            <p className="text-sm font-bold text-[var(--color-charcoal)]">Read-only history</p>
            <p className="mt-1 text-sm leading-6 text-[var(--color-muted)]">
              This page does not create orders, collect payment, reserve stock, arrange delivery, issue refunds, or start finance workflows.
            </p>
          </div>
        </div>
      </Card>
    </MobileShell>
  );
}
