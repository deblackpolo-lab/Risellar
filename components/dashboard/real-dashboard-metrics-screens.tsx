import Link from "next/link";
import type { ComponentType } from "react";
import { ArrowUpRight, BadgeDollarSign, Bell, PackageCheck, ReceiptText, ShieldCheck, ShoppingBag, UserRound, Wallet } from "lucide-react";
import { AdminShell } from "@/components/admin/AdminSidebar";
import { BottomNav, MobileShell } from "@/components/layout";
import { Card, StatusBadge } from "@/components/ui";
import type {
  AdminDashboardSummary,
  CustomerDashboardSummary,
  DashboardLoadState,
  DashboardPeriod,
  ResellerDashboardSummary,
  SupplierDashboardSummary
} from "@/lib/dashboard/real-dashboard-metrics";
import type { AdminFinanceSettlement, AdminFinanceWithdrawal } from "@/lib/admin/finance/admin-finance";
import type { CustomerOrderHistoryItem } from "@/lib/orders/customer-order-history";
import type { ResellerEarning, ResellerWithdrawalHistory } from "@/lib/reseller/finance/reseller-finance";
import type { SupplierOrderSafe } from "@/lib/orders/supplier-order-shared";
import type { SupplierSettlementHistory } from "@/lib/supplier/finance/supplier-finance";

export function formatDashboardMoney(amount: number | null | undefined, currencyCode = "GHS") {
  return new Intl.NumberFormat("en-GH", {
    style: "currency",
    currency: currencyCode,
    maximumFractionDigits: 2
  }).format(Number(amount ?? 0));
}

function formatDashboardDate(value: string | null | undefined) {
  if (!value) return "Not recorded";
  return new Intl.DateTimeFormat("en-GH", { dateStyle: "medium" }).format(new Date(value));
}

function DashboardError({ state }: { state: DashboardLoadState }) {
  if (state.code === "OK") return null;

  return (
    <Card className="border-[var(--color-danger)]/30 bg-[var(--color-danger-soft)]">
      <p className="text-sm font-semibold">We could not load this dashboard. Please refresh and try again.</p>
    </Card>
  );
}

function MetricCard({ detail, label, value }: { detail: string; label: string; value: string }) {
  return (
    <Card>
      <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 break-words text-2xl font-extrabold text-[var(--color-charcoal)]">{value}</p>
      <p className="mt-1 text-xs leading-5 text-[var(--color-muted)]">{detail}</p>
    </Card>
  );
}

function PeriodLinks({ basePath, period }: { basePath: string; period: DashboardPeriod }) {
  const periods: Array<[DashboardPeriod, string]> = [
    ["last_7_days", "Last 7 days"],
    ["last_30_days", "Last 30 days"],
    ["this_month", "This month"],
    ["this_year", "This year"]
  ];

  return (
    <div className="flex flex-wrap gap-2" aria-label="Dashboard period">
      {periods.map(([value, label]) => (
        <Link
          className={value === period
            ? "rounded-[var(--radius-md)] border border-[var(--color-primary)] bg-[var(--color-primary)] px-3 py-2 text-sm font-bold text-white"
            : "rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-3 py-2 text-sm font-semibold text-[var(--color-charcoal)]"}
          href={`${basePath}?period=${value}`}
          key={value}
        >
          {label}
        </Link>
      ))}
    </div>
  );
}

function EmptyRecent() {
  return <p className="text-sm text-[var(--color-muted)]">No recent activity yet.</p>;
}

export function CustomerDashboardMetricsScreen({
  orders,
  state,
  summary
}: {
  orders: CustomerOrderHistoryItem[];
  state: DashboardLoadState;
  summary: CustomerDashboardSummary;
}) {
  return (
    <MobileShell title="Customer dashboard">
      <div className="space-y-4">
        <header className="rounded-[var(--radius-lg)] bg-[var(--color-primary)] p-5 text-white shadow-[var(--shadow-md)]">
          <p className="text-sm font-semibold text-[var(--color-accent)]">Customer account</p>
          <h1 className="mt-1 text-[28px] font-bold leading-tight">Your dashboard</h1>
          <p className="mt-2 text-sm leading-6 text-white/85">Read-only order progress. Checkout, payment, delivery changes, cancellation, and refund actions stay separate.</p>
        </header>
        <DashboardError state={state} />
        <div className="grid grid-cols-2 gap-3">
          <MetricCard label="Active orders" value={String(summary.current.activeOrdersCount)} detail="Orders still moving through fulfilment." />
          <MetricCard label="Completed orders" value={String(summary.current.completedOrdersCount)} detail="Orders completed after verified flow." />
          <MetricCard label="Rejected orders" value={String(summary.current.rejectedOrdersCount)} detail="Orders cancelled, failed, or supplier-rejected." />
          <MetricCard label="All orders" value={String(summary.current.totalOrdersCount)} detail="Your total visible order history." />
        </div>
        <Card title="Latest active order">
          {summary.latestActiveOrder.orderId ? (
            <div className="space-y-3">
              <StatusBadge tone="warning">{summary.latestActiveOrder.statusLabel ?? "Active"}</StatusBadge>
              <div>
                <p className="font-bold">{summary.latestActiveOrder.productName}</p>
                <p className="mt-1 text-sm text-[var(--color-muted)]">{summary.latestActiveOrder.orderNumber} - {formatDashboardMoney(summary.latestActiveOrder.amount, summary.latestActiveOrder.currencyCode ?? "GHS")}</p>
              </div>
              <Link className="inline-flex items-center gap-1 text-sm font-bold text-[var(--color-primary)]" href={summary.latestActiveOrder.href ?? "/customer/orders"}>
                View order <ArrowUpRight className="h-4 w-4" aria-hidden />
              </Link>
            </div>
          ) : <EmptyRecent />}
        </Card>
        <Card title="Recent orders">
          <div className="space-y-3">
            {orders.length ? orders.map((order) => (
              <Link className="block rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" href={order.detailHref} key={order.orderId}>
                <p className="font-bold">{order.productName}</p>
                <p className="mt-1 text-sm text-[var(--color-muted)]">{order.orderNumber} - {formatDashboardMoney(order.totalPayableAmount, order.currencyCode)}</p>
                <p className="mt-1 text-xs text-[var(--color-muted)]">{order.orderStatusLabel}</p>
              </Link>
            )) : <EmptyRecent />}
          </div>
        </Card>
      </div>
    </MobileShell>
  );
}

export function ResellerDashboardMetricsScreen({
  earnings,
  period,
  state,
  summaries,
  withdrawals
}: {
  earnings: ResellerEarning[];
  period: DashboardPeriod;
  state: DashboardLoadState;
  summaries: ResellerDashboardSummary[];
  withdrawals: ResellerWithdrawalHistory[];
}) {
  const summary = summaries[0];
  const currency = summary?.current.currencyCode ?? "GHS";

  return (
    <MobileShell footer={<BottomNav active="Home" />} className="pb-36">
      <div className="space-y-5">
        <header className="flex items-start justify-between gap-4">
          <div>
            <p className="text-sm text-[var(--color-muted)]">Welcome back</p>
            <h1 className="mt-1 text-2xl font-bold leading-tight text-[var(--color-charcoal)]">Your reseller home</h1>
            <p className="mt-1 text-sm leading-6 text-[var(--color-muted)]">Live wallet and sales metrics for your approved reseller account.</p>
          </div>
          <div className="flex shrink-0 items-center gap-2">
            <Link
              aria-label="Notifications"
              className="grid h-11 w-11 place-items-center rounded-full border border-[var(--color-border)] bg-white text-[var(--color-charcoal)] shadow-[var(--shadow-sm)]"
              href="/reseller/notifications"
            >
              <Bell className="h-5 w-5" aria-hidden />
            </Link>
            <Link
              aria-label="Profile"
              className="grid h-11 w-11 place-items-center rounded-full bg-[var(--color-primary)] text-white shadow-[var(--shadow-sm)]"
              href="/reseller/settings"
            >
              <UserRound className="h-5 w-5" aria-hidden />
            </Link>
          </div>
        </header>
        <DashboardError state={state} />

        <section className="rounded-[var(--radius-xl)] bg-[var(--color-primary)] p-5 text-white shadow-[var(--shadow-md)]">
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm text-white/80">Available balance</p>
              <p className="mt-1 break-words text-3xl font-extrabold">{formatDashboardMoney(summary?.current.availableBalanceAmount, currency)}</p>
            </div>
            <Wallet className="h-8 w-8 text-white/80" aria-hidden />
          </div>
          <p className="mt-3 text-xs leading-5 text-white/75">Locked commission stays separate until supplier settlement is verified.</p>
          <div className="mt-4 grid gap-2 rounded-[var(--radius-lg)] bg-white/10 p-3 text-xs sm:grid-cols-3">
            <WalletMiniStat label="Locked" value={formatDashboardMoney(summary?.current.lockedCommissionAmount, currency)} />
            <WalletMiniStat label="Pending withdrawal" value={formatDashboardMoney(summary?.current.pendingWithdrawalAmount, currency)} />
            <WalletMiniStat label="Withdrawn" value={formatDashboardMoney(summary?.current.withdrawnAmount, currency)} />
          </div>
        </section>

        <section>
          <div className="mb-3 flex items-center justify-between gap-3">
            <h2 className="text-base font-bold">Quick actions</h2>
            <StatusBadge tone="neutral">Real routes</StatusBadge>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <QuickActionLink href="/reseller/products" icon={ShoppingBag} label="Browse products" />
            <QuickActionLink href="/reseller/orders" icon={ReceiptText} label="View orders" />
            <QuickActionLink href="/reseller/withdraw" icon={Wallet} label="Request withdrawal" />
            <QuickActionLink href="/reseller/wallet" icon={BadgeDollarSign} label="View wallet" />
          </div>
        </section>

        <Card title="Selected period">
          <PeriodLinks basePath="/reseller/dashboard" period={period} />
          <div className="mt-4 grid grid-cols-2 gap-3">
            <CompactMetric label="Sales" value={String(summary?.period.completedSalesCount ?? 0)} />
            <CompactMetric label="Commission earned" value={formatDashboardMoney(summary?.period.commissionEarnedAmount, currency)} />
            <CompactMetric label="Orders attributed" value={String(summary?.period.attributedOrdersCount ?? 0)} />
            <CompactMetric label="Rejected orders" value={String(summary?.period.rejectedOrdersCount ?? 0)} />
          </div>
        </Card>

        <Card title="Recent activity">
          <div className="space-y-3">
            {earnings.slice(0, 3).map((earning) => (
              <Link className="block rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-3 transition hover:border-[var(--color-primary)]" href="/reseller/earnings" key={earning.commissionId}>
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="break-words text-sm font-bold">{earning.productName}</p>
                    <p className="mt-1 text-xs text-[var(--color-muted)]">{earning.orderNumber}</p>
                  </div>
                  <p className="shrink-0 text-sm font-extrabold text-[var(--color-primary)]">{formatDashboardMoney(earning.commissionAmount, earning.currencyCode)}</p>
                </div>
              </Link>
            ))}
            {withdrawals.slice(0, 2).map((withdrawal) => (
              <Link className="block rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-3 transition hover:border-[var(--color-primary)]" href={`/reseller/withdrawals/${withdrawal.withdrawalId}`} key={withdrawal.withdrawalId}>
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="break-words text-sm font-bold">{withdrawal.requestReference ?? "Withdrawal request"}</p>
                    <p className="mt-1 text-xs text-[var(--color-muted)]">{withdrawal.withdrawalStatus}</p>
                  </div>
                  <p className="shrink-0 text-sm font-extrabold text-[var(--color-charcoal)]">{formatDashboardMoney(withdrawal.requestedAmount, withdrawal.currencyCode)}</p>
                </div>
              </Link>
            ))}
            {!earnings.length && !withdrawals.length ? <EmptyRecent /> : null}
          </div>
        </Card>

        <Card className="bg-[var(--color-accent-soft)] p-4">
          <div className="flex gap-3">
            <ShieldCheck className="mt-0.5 h-5 w-5 flex-none text-[var(--color-primary)]" aria-hidden />
            <p className="text-sm leading-6 text-[var(--color-muted)]">Dashboard viewing is read-only. Locked commission is not available for withdrawal, and pending withdrawals stay separate from paid withdrawals.</p>
          </div>
        </Card>
      </div>
    </MobileShell>
  );
}

function WalletMiniStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="min-w-0">
      <p className="text-white/70">{label}</p>
      <p className="mt-1 break-words font-extrabold text-white">{value}</p>
    </div>
  );
}

function CompactMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-3">
      <p className="text-xs font-semibold text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 break-words text-lg font-extrabold text-[var(--color-charcoal)]">{value}</p>
    </div>
  );
}

function QuickActionLink({
  href,
  icon: Icon,
  label
}: {
  href: string;
  icon: ComponentType<{ className?: string; "aria-hidden"?: boolean }>;
  label: string;
}) {
  return (
    <Link
      className="flex min-h-14 items-center gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-3 text-sm font-bold text-[var(--color-charcoal)] shadow-[var(--shadow-sm)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--color-focus-ring)]"
      href={href}
    >
      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] text-[var(--color-primary)]">
        <Icon className="h-4 w-4" aria-hidden />
      </span>
      <span className="min-w-0 break-words">{label}</span>
    </Link>
  );
}

export function SupplierDashboardMetricsScreen({
  orders,
  period,
  settlements,
  state,
  summaries
}: {
  orders: SupplierOrderSafe[];
  period: DashboardPeriod;
  settlements: SupplierSettlementHistory[];
  state: DashboardLoadState;
  summaries: SupplierDashboardSummary[];
}) {
  const summary = summaries[0];
  const currency = summary?.current.currencyCode ?? "GHS";
  const statusCards = [
    ["New orders", summary?.current.placedPendingConfirmationCount],
    ["Confirmed", summary?.current.supplierConfirmedCount],
    ["Preparing", summary?.current.supplierPreparingCount],
    ["Ready", summary?.current.readyForDeliveryCount],
    ["Delivery arranged", summary?.current.deliveryArrangedCount],
    ["Out for delivery", summary?.current.outForDeliveryCount],
    ["Delivered", summary?.current.deliveredCount],
    ["Payment reported", summary?.current.paymentReportedCount],
    ["Completed", summary?.current.completedCount],
    ["Rejected", summary?.current.supplierRejectedCount]
  ];

  return (
    <MobileShell title="Supplier dashboard">
      <div className="space-y-4">
        <header className="rounded-[var(--radius-lg)] bg-[var(--color-primary)] p-5 text-white shadow-[var(--shadow-md)]">
          <p className="text-sm font-semibold text-[var(--color-accent)]">Supplier account</p>
          <h1 className="mt-1 text-[28px] font-bold leading-tight">Orders and settlement dashboard</h1>
          <p className="mt-2 text-sm leading-6 text-white/85">Read-only counts for your supplier orders and settlement state.</p>
        </header>
        <DashboardError state={state} />
        <div className="grid grid-cols-2 gap-3">
          {statusCards.map(([label, value]) => (
            <MetricCard detail="Current order state." key={String(label)} label={String(label)} value={String(value ?? 0)} />
          ))}
        </div>
        <Card title="Selected period">
          <PeriodLinks basePath="/supplier/dashboard" period={period} />
          <div className="mt-4 grid grid-cols-2 gap-3">
            <MetricCard label="Pending settlement" value={formatDashboardMoney(summary?.current.pendingSettlementAmount, currency)} detail={`${summary?.current.pendingSettlementCount ?? 0} pending settlement(s).`} />
            <MetricCard label="Payments reported" value={formatDashboardMoney(summary?.period.customerPaymentsReportedAmount, currency)} detail="Supplier-reported customer payments in the selected period." />
            <MetricCard label="Settlement verified" value={formatDashboardMoney(summary?.period.verifiedSettlementAmount, currency)} detail="Finance-verified settlements in the selected period." />
            <MetricCard label="Completed orders" value={String(summary?.period.completedOrdersCount ?? 0)} detail="Completed supplier orders in the selected period." />
          </div>
        </Card>
        <Card title="Recent orders">
          <div className="space-y-3">
            {orders.length ? orders.slice(0, 5).map((order) => (
              <Link className="block rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" href={`/supplier/orders/${order.orderId}`} key={order.orderId}>
                <p className="font-bold">{order.productName}</p>
                <p className="mt-1 text-sm text-[var(--color-muted)]">{order.orderNumber} - {order.orderStatusLabel}</p>
              </Link>
            )) : <EmptyRecent />}
          </div>
        </Card>
        <Card title="Recent settlements">
          <div className="space-y-3">
            {settlements.length ? settlements.slice(0, 3).map((settlement) => (
              <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={settlement.settlementId}>
                <p className="font-bold">{settlement.orderNumber}</p>
                <p className="text-sm text-[var(--color-muted)]">{formatDashboardMoney(settlement.totalSettlementDue, settlement.currencyCode)} - {settlement.settlementStatus}</p>
              </div>
            )) : <EmptyRecent />}
          </div>
        </Card>
      </div>
    </MobileShell>
  );
}

export function AdminDashboardMetricsScreen({
  period,
  settlements,
  state,
  summaries,
  withdrawals
}: {
  period: DashboardPeriod;
  settlements: AdminFinanceSettlement[];
  state: DashboardLoadState;
  summaries: AdminDashboardSummary[];
  withdrawals: AdminFinanceWithdrawal[];
}) {
  const first = summaries[0];

  return (
    <AdminShell searchPlaceholder="Search live dashboard summaries..." userRole="Finance dashboard">
      <div className="mx-auto w-full max-w-7xl space-y-5">
        <header>
          <p className="text-sm font-bold uppercase tracking-normal text-[var(--color-primary)]">Marketplace control center</p>
          <h1 className="mt-2 text-3xl font-bold">Admin Dashboard</h1>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--color-muted)]">Read-only operational and finance metrics. Gross completed sales stay separate from verified platform revenue.</p>
        </header>
        <DashboardError state={state} />
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
          <MetricCard label="Pending supplier settlements" value={String(first?.current.pendingSupplierSettlementCount ?? 0)} detail="Current supplier settlement queue." />
          <MetricCard label="Pending reseller withdrawals" value={String(first?.current.pendingResellerWithdrawalCount ?? 0)} detail="Current reseller payout queue." />
          <MetricCard label="Orders waiting supplier confirmation" value={String(first?.current.ordersWaitingSupplierConfirmationCount ?? 0)} detail="Current order queue." />
          <MetricCard label="Active suppliers" value={String(first?.current.activeSupplierCount ?? 0)} detail="Approved active suppliers." />
          <MetricCard label="Active resellers" value={String(first?.current.activeResellerCount ?? 0)} detail="Approved active resellers." />
        </div>
        <Card title="Selected period">
          <PeriodLinks basePath="/admin/dashboard" period={period} />
          <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {summaries.map((summary) => (
              <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-4" key={summary.currencyCode}>
                <p className="text-sm font-extrabold">{summary.currencyCode}</p>
                <dl className="mt-3 grid gap-3">
                  <FinanceRow icon={BadgeDollarSign} label="Verified platform revenue" value={formatDashboardMoney(summary.period.verifiedPlatformRevenueAmount, summary.currencyCode)} />
                  <FinanceRow icon={ShoppingBag} label="Gross completed sales" value={formatDashboardMoney(summary.period.grossCompletedSalesAmount, summary.currencyCode)} />
                  <FinanceRow icon={Wallet} label="Commission unlocked" value={formatDashboardMoney(summary.period.resellerCommissionUnlockedAmount, summary.currencyCode)} />
                  <FinanceRow icon={ReceiptText} label="Withdrawals paid" value={formatDashboardMoney(summary.period.withdrawalsPaidAmount, summary.currencyCode)} />
                  <FinanceRow icon={PackageCheck} label="Completed orders" value={String(summary.period.completedOrdersCount)} />
                </dl>
              </div>
            ))}
          </div>
        </Card>
        <div className="grid gap-5 xl:grid-cols-2">
          <Card title="Recent settlement verifications">
            <div className="space-y-3">
              {settlements.length ? settlements.slice(0, 4).map((settlement) => (
                <Link className="block rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" href={`/admin/settlements/${settlement.orderId}`} key={settlement.settlementId}>
                  <p className="font-bold">{settlement.orderNumber}</p>
                  <p className="text-sm text-[var(--color-muted)]">{settlement.supplierBusinessName} - {formatDashboardMoney(settlement.totalSettlementAmount, settlement.currencyCode)}</p>
                  <p className="mt-1 text-xs text-[var(--color-muted)]">{formatDashboardDate(settlement.settlementVerifiedAt ?? settlement.supplierReportedAt)}</p>
                </Link>
              )) : <EmptyRecent />}
            </div>
          </Card>
          <Card title="Recent withdrawal payouts">
            <div className="space-y-3">
              {withdrawals.length ? withdrawals.slice(0, 4).map((withdrawal, index) => (
                <Link className="block rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" href={`/admin/withdrawals/${withdrawal.withdrawalId}`} key={`${withdrawal.withdrawalId}-${index}`}>
                  <p className="font-bold">{withdrawal.requestReference ?? "Withdrawal request"}</p>
                  <p className="text-sm text-[var(--color-muted)]">{withdrawal.resellerDisplayName} - {formatDashboardMoney(withdrawal.requestedAmount, withdrawal.currencyCode)}</p>
                  <p className="mt-1 text-xs text-[var(--color-muted)]">{formatDashboardDate(withdrawal.paidAt ?? withdrawal.requestedAt)}</p>
                </Link>
              )) : <EmptyRecent />}
            </div>
          </Card>
        </div>
        <Card className="bg-[var(--color-accent-soft)] p-4">
          <div className="flex gap-3">
            <ShieldCheck className="h-5 w-5 flex-none text-[var(--color-primary)]" aria-hidden />
            <p className="text-sm leading-6 text-[var(--color-muted)]">Dashboard reads do not verify settlements, pay withdrawals, change orders, reserve stock, collect payment, or start delivery.</p>
          </div>
        </Card>
      </div>
    </AdminShell>
  );
}

function FinanceRow({ icon: Icon, label, value }: { icon: ComponentType<{ className?: string; "aria-hidden"?: boolean }>; label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 text-sm">
      <dt className="flex items-center gap-2 text-[var(--color-muted)]">
        <Icon className="h-4 w-4" aria-hidden />
        {label}
      </dt>
      <dd className="break-words text-right font-extrabold">{value}</dd>
    </div>
  );
}
