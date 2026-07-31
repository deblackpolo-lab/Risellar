import Link from "next/link";
import { Card, StatusBadge } from "@/components/ui";
import type { AdminFinanceSettlement, AdminFinanceSummary, AdminFinanceWithdrawal } from "@/lib/admin/finance/admin-finance";
import type { ResellerEarning, ResellerFinanceSummary, ResellerWithdrawalHistory } from "@/lib/reseller/finance/reseller-finance";
import type { SupplierFinanceSummary, SupplierSettlementHistory } from "@/lib/supplier/finance/supplier-finance";

export function formatMoney(amount: number | null | undefined, currencyCode = "GHS") {
  return new Intl.NumberFormat("en-GH", {
    style: "currency",
    currency: currencyCode,
    maximumFractionDigits: 2
  }).format(Number(amount ?? 0));
}

export function formatFinanceDate(value: string | null | undefined) {
  if (!value) return "Not recorded";
  return new Intl.DateTimeFormat("en-GH", { dateStyle: "medium" }).format(new Date(value));
}

export function FinanceFilterLinks({
  basePath,
  statuses
}: {
  basePath: string;
  statuses: { hrefStatus?: string; label: string }[];
}) {
  return (
    <div className="flex flex-wrap gap-2">
      <Link className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-3 py-2 text-sm font-semibold" href={basePath}>
        All
      </Link>
      {statuses.map((status) => (
        <Link
          className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-3 py-2 text-sm font-semibold"
          href={`${basePath}?status=${status.hrefStatus ?? status.label.toLowerCase()}`}
          key={status.label}
        >
          {status.label}
        </Link>
      ))}
    </div>
  );
}

export function MetricCard({ detail, label, value }: { detail: string; label: string; value: string }) {
  return (
    <Card>
      <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 text-2xl font-extrabold">{value}</p>
      <p className="mt-1 text-xs leading-5 text-[var(--color-muted)]">{detail}</p>
    </Card>
  );
}

export function ResellerFinanceSummaryCards({ summaries }: { summaries: ResellerFinanceSummary[] }) {
  const summary = summaries[0];

  return (
    <div className="grid grid-cols-2 gap-3">
      <MetricCard label="Locked commission" value={formatMoney(summary?.lockedCommissionAmount, summary?.currencyCode)} detail="Waiting for supplier settlement verification." />
      <MetricCard label="Available balance" value={formatMoney(summary?.availableBalanceAmount, summary?.currencyCode)} detail="Current amount available to request." />
      <MetricCard label="Pending withdrawal" value={formatMoney(summary?.pendingWithdrawalAmount, summary?.currencyCode)} detail="Requested but not yet paid." />
      <MetricCard label="Withdrawn total" value={formatMoney(summary?.withdrawnAmount, summary?.currencyCode)} detail="Current lifetime paid withdrawals." />
      <MetricCard label="Period earnings" value={formatMoney(summary?.periodCommissionEarnedAmount, summary?.currencyCode)} detail="Commission rows created in the selected period." />
      <MetricCard label="Completed sales" value={String(summary?.completedSalesCount ?? 0)} detail="Completed orders in the selected period." />
    </div>
  );
}

export function ResellerEarningsList({ earnings }: { earnings: ResellerEarning[] }) {
  return (
    <Card title="Earnings history">
      <div className="space-y-3">
        {earnings.length ? earnings.map((earning) => (
          <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={earning.commissionId}>
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-bold">{earning.productName}</p>
                <p className="mt-1 text-sm text-[var(--color-muted)]">{earning.orderNumber} - {earning.resellerShopName}</p>
                <p className="mt-1 text-xs text-[var(--color-muted)]">Earned {formatFinanceDate(earning.earnedAt)}</p>
              </div>
              <div className="text-right">
                <p className="font-extrabold">{formatMoney(earning.commissionAmount, earning.currencyCode)}</p>
                <StatusBadge status={earning.commissionStatus === "awaiting_supplier_settlement" ? "Locked" : earning.commissionStatus === "withdrawal_requested" ? "Pending withdrawal" : earning.commissionStatus} />
              </div>
            </div>
          </div>
        )) : (
          <p className="text-sm text-[var(--color-muted)]">No earnings found for this period.</p>
        )}
      </div>
      <p className="mt-4 text-xs leading-5 text-[var(--color-muted)]">
        Withdrawal allocation by commission row is deferred, so withdrawn totals are shown at wallet level only.
      </p>
    </Card>
  );
}

export function ResellerWithdrawalHistoryList({ withdrawals }: { withdrawals: ResellerWithdrawalHistory[] }) {
  return (
    <Card title="Withdrawal history">
      <div className="space-y-3">
        {withdrawals.length ? withdrawals.map((withdrawal) => (
          <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={withdrawal.withdrawalId}>
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-bold">{withdrawal.requestReference ?? "Withdrawal request"}</p>
                <p className="mt-1 text-sm text-[var(--color-muted)]">{withdrawal.payoutMethod ?? "payout"} - {withdrawal.payoutAccountMasked ?? "masked account"}</p>
                <p className="mt-1 text-xs text-[var(--color-muted)]">Requested {formatFinanceDate(withdrawal.requestedAt)}</p>
              </div>
              <div className="text-right">
                <p className="font-extrabold">{formatMoney(withdrawal.requestedAmount, withdrawal.currencyCode)}</p>
                <StatusBadge status={withdrawal.withdrawalStatus === "requested" ? "Pending" : withdrawal.withdrawalStatus} />
              </div>
            </div>
          </div>
        )) : (
          <p className="text-sm text-[var(--color-muted)]">No withdrawal requests found for this period.</p>
        )}
      </div>
    </Card>
  );
}

export function SupplierFinanceSummaryCards({ summaries }: { summaries: SupplierFinanceSummary[] }) {
  const summary = summaries[0];

  return (
    <div className="grid grid-cols-2 gap-3">
      <MetricCard label="Pending settlement" value={formatMoney(summary?.pendingSettlementAmount, summary?.currencyCode)} detail="Money still owed to Risellar." />
      <MetricCard label="Customer payments reported" value={formatMoney(summary?.customerPaymentsReportedAmount, summary?.currencyCode)} detail="Supplier-reported customer payments in the period." />
      <MetricCard label="Settlement verified" value={formatMoney(summary?.verifiedSettlementAmount, summary?.currencyCode)} detail="Settlement verified by Risellar finance." />
      <MetricCard label="Completed orders" value={String(summary?.completedOrderCount ?? 0)} detail="Orders completed after finance verification." />
    </div>
  );
}

export function SupplierSettlementHistoryList({ settlements }: { settlements: SupplierSettlementHistory[] }) {
  return (
    <Card title="Settlement history">
      <div className="space-y-3">
        {settlements.length ? settlements.map((settlement) => (
          <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={settlement.settlementId}>
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-bold">{settlement.orderNumber}</p>
                <p className="mt-1 text-sm text-[var(--color-muted)]">Customer paid {formatMoney(settlement.customerTotalAmount, settlement.currencyCode)}</p>
                <p className="mt-1 text-xs text-[var(--color-muted)]">Reported {formatFinanceDate(settlement.paymentReportedAt)}</p>
              </div>
              <StatusBadge status={settlement.settlementStatus === "paid" ? "Verified" : "Pending"} />
            </div>
            <dl className="mt-3 grid grid-cols-2 gap-2 text-sm">
              <Info label="Supplier keeps" value={formatMoney(settlement.supplierAmount, settlement.currencyCode)} />
              <Info label="Platform amount" value={formatMoney(settlement.platformAmountDue, settlement.currencyCode)} />
              <Info label="Reseller commission" value={formatMoney(settlement.resellerCommissionDue, settlement.currencyCode)} />
              <Info label="Total settlement" value={formatMoney(settlement.totalSettlementDue, settlement.currencyCode)} />
            </dl>
          </div>
        )) : (
          <p className="text-sm text-[var(--color-muted)]">No settlements found for this period.</p>
        )}
      </div>
    </Card>
  );
}

export function AdminFinanceSummaryCards({ summaries }: { summaries: AdminFinanceSummary[] }) {
  return (
    <div className="grid gap-3 md:grid-cols-3">
      {summaries.map((summary) => (
        <div className="grid gap-3 md:col-span-3 md:grid-cols-3" key={summary.currencyCode}>
          <MetricCard label={`Pending settlements ${summary.currencyCode}`} value={formatMoney(summary.pendingSupplierSettlementAmount, summary.currencyCode)} detail={`${summary.pendingSupplierSettlementCount} pending supplier settlement(s).`} />
          <MetricCard label={`Pending withdrawals ${summary.currencyCode}`} value={formatMoney(summary.pendingResellerWithdrawalAmount, summary.currencyCode)} detail={`${summary.pendingResellerWithdrawalCount} pending reseller withdrawal(s).`} />
          <MetricCard label={`Verified platform revenue ${summary.currencyCode}`} value={formatMoney(summary.verifiedPlatformRevenueAmount, summary.currencyCode)} detail="Paid supplier settlements only." />
          <MetricCard label="Gross completed sales" value={formatMoney(summary.grossCompletedSalesAmount, summary.currencyCode)} detail="Separate from platform revenue." />
          <MetricCard label="Commission unlocked" value={formatMoney(summary.resellerCommissionUnlockedAmount, summary.currencyCode)} detail="Unlocked after finance verification." />
          <MetricCard label="Withdrawals paid" value={formatMoney(summary.resellerWithdrawalPaidAmount, summary.currencyCode)} detail="Manual payouts marked paid." />
        </div>
      ))}
    </div>
  );
}

export function AdminSettlementHistoryList({ settlements }: { settlements: AdminFinanceSettlement[] }) {
  return (
    <Card title="Supplier settlement history">
      <div className="space-y-3">
        {settlements.length ? settlements.map((settlement) => (
          <Link className="block rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" href={`/admin/settlements/${settlement.orderId}`} key={settlement.settlementId}>
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p className="font-bold">{settlement.orderNumber}</p>
                <p className="mt-1 text-sm text-[var(--color-muted)]">{settlement.supplierBusinessName} - {settlement.resellerDisplayName}</p>
              </div>
              <div className="text-right">
                <p className="font-extrabold">{formatMoney(settlement.totalSettlementAmount, settlement.currencyCode)}</p>
                <StatusBadge status={settlement.settlementStatus === "paid" ? "Verified" : "Pending"} />
              </div>
            </div>
          </Link>
        )) : (
          <p className="text-sm text-[var(--color-muted)]">No supplier settlements found.</p>
        )}
      </div>
    </Card>
  );
}

export function AdminWithdrawalHistoryList({ withdrawals }: { withdrawals: AdminFinanceWithdrawal[] }) {
  return (
    <Card title="Reseller withdrawal history">
      <div className="space-y-3">
        {withdrawals.length ? withdrawals.map((withdrawal) => (
          <Link className="block rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" href={`/admin/withdrawals/${withdrawal.withdrawalId}`} key={withdrawal.withdrawalId}>
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p className="font-bold">{withdrawal.requestReference ?? "Withdrawal request"}</p>
                <p className="mt-1 text-sm text-[var(--color-muted)]">{withdrawal.resellerDisplayName} - {withdrawal.resellerEmailMasked ?? "masked email"}</p>
                <p className="mt-1 text-xs text-[var(--color-muted)]">{withdrawal.payoutMethod ?? "payout"} - {withdrawal.payoutAccountMasked ?? "masked account"}</p>
              </div>
              <div className="text-right">
                <p className="font-extrabold">{formatMoney(withdrawal.requestedAmount, withdrawal.currencyCode)}</p>
                <StatusBadge status={withdrawal.withdrawalStatus === "requested" ? "Pending" : withdrawal.withdrawalStatus} />
              </div>
            </div>
          </Link>
        )) : (
          <p className="text-sm text-[var(--color-muted)]">No reseller withdrawals found.</p>
        )}
      </div>
    </Card>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs text-[var(--color-muted)]">{label}</dt>
      <dd className="font-bold">{value}</dd>
    </div>
  );
}
