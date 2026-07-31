"use client";

import Link from "next/link";
import { useFormStatus } from "react-dom";
import { CheckCircle2, LockKeyhole, ReceiptText, ShieldCheck, WalletCards } from "lucide-react";
import { verifySupplierSettlementFormAction } from "@/app/admin/settlements/actions";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { cn } from "@/lib/utils/cn";
import type { AdminSettlementCode, AdminSupplierSettlement } from "@/lib/admin/settlements/admin-supplier-settlement";

const errorMessages: Partial<Record<AdminSettlementCode, string>> = {
  AUTH_REQUIRED: "Sign in to verify settlements.",
  FINANCE_ADMIN_REQUIRED: "You do not have permission to verify settlements.",
  ORDER_NOT_FOUND: "This settlement is unavailable.",
  ORDER_NOT_PAYMENT_REPORTED: "The supplier has not reported payment for this order.",
  SETTLEMENT_NOT_FOUND: "The settlement obligation is unavailable.",
  COMMISSION_NOT_FOUND: "The reseller commission record is unavailable.",
  SETTLEMENT_ALREADY_VERIFIED: "This settlement has already been verified.",
  COMMISSION_ALREADY_AVAILABLE: "This commission is already available.",
  FINANCIAL_AMOUNT_MISMATCH: "The settlement amounts do not match the order records.",
  CURRENCY_MISMATCH: "The settlement currency does not match the order.",
  STOCK_STATE_INCONSISTENT: "Stock finalization is incomplete or inconsistent.",
  FIELD_TOO_LONG: "Shorten the information and try again.",
  CONFLICTING_RETRY: "This settlement was already verified with different details. Refresh the page.",
  VALIDATION_ERROR: "Confirm the settlement details before verifying.",
  SUPABASE_AUTH_TOKEN_MISSING: "We could not prepare your secure admin session. Please sign in again.",
  UNKNOWN: "We could not confirm the result. Refresh before trying again."
};

function formatMoney(value: number | null | undefined, currencyCode = "GHS") {
  if (typeof value !== "number") {
    return `${currencyCode} --`;
  }

  return new Intl.NumberFormat("en-GH", {
    style: "currency",
    currency: currencyCode,
    maximumFractionDigits: 2
  }).format(value);
}

function formatDate(value: string | null | undefined) {
  if (!value) return "Not recorded";
  return new Intl.DateTimeFormat("en-GH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

function SettlementSummary({ settlement }: { settlement: AdminSupplierSettlement }) {
  return (
    <div className="grid gap-3 md:grid-cols-4">
      <div className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4">
        <p className="text-xs font-bold uppercase tracking-[0.06em] text-[var(--color-muted)]">Platform amount</p>
        <p className="mt-2 text-xl font-extrabold">{formatMoney(settlement.platformAmountDue, settlement.currencyCode)}</p>
      </div>
      <div className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4">
        <p className="text-xs font-bold uppercase tracking-[0.06em] text-[var(--color-muted)]">Reseller commission</p>
        <p className="mt-2 text-xl font-extrabold">{formatMoney(settlement.resellerCommissionDue, settlement.currencyCode)}</p>
      </div>
      <div className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4">
        <p className="text-xs font-bold uppercase tracking-[0.06em] text-[var(--color-muted)]">Total settlement</p>
        <p className="mt-2 text-xl font-extrabold">{formatMoney(settlement.totalSettlementDue, settlement.currencyCode)}</p>
      </div>
      <div className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4">
        <p className="text-xs font-bold uppercase tracking-[0.06em] text-[var(--color-muted)]">Customer paid supplier</p>
        <p className="mt-2 text-xl font-extrabold">{formatMoney(settlement.customerTotalAmount, settlement.currencyCode)}</p>
      </div>
    </div>
  );
}

function VerifyButton() {
  const { pending } = useFormStatus();

  return (
    <Button disabled={pending} type="submit">
      {pending ? "Verifying settlement..." : "Verify settlement"}
    </Button>
  );
}

export function AdminSettlementListScreen({
  settlements,
  errorCode,
  success
}: {
  settlements: AdminSupplierSettlement[];
  errorCode?: AdminSettlementCode | null;
  success?: boolean;
}) {
  return (
    <div className="space-y-5">
      <div className="rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-6 shadow-[0_14px_36px_rgba(18,28,28,0.05)]">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.08em] text-[var(--color-primary)]">Finance queue</p>
            <h1 className="mt-1 text-[1.75rem] font-bold leading-tight">Supplier settlement verification</h1>
            <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--color-muted)]">
              Verify only after confirming Risellar received the full platform amount and reseller commission from the supplier.
            </p>
          </div>
          <span className="inline-flex items-center gap-2 rounded-full bg-[var(--color-primary-subtle)] px-3 py-2 text-sm font-bold text-[var(--color-primary)]">
            <ShieldCheck className="h-4 w-4" aria-hidden />
            Finance only
          </span>
        </div>
      </div>

      {errorCode ? (
        <div className="rounded-[var(--radius-lg)] border border-[var(--color-danger-soft)] bg-[var(--color-danger-soft)] p-4 text-sm font-semibold text-[var(--color-danger)]">
          {errorMessages[errorCode] ?? errorMessages.UNKNOWN}
        </div>
      ) : null}

      {success ? (
        <div className="rounded-[var(--radius-lg)] border border-[var(--color-success-soft)] bg-[var(--color-success-soft)] p-4 text-sm font-semibold text-[var(--color-primary)]">
          Settlement verified - commission available.
        </div>
      ) : null}

      {settlements.length === 0 ? (
        <Card title="No pending settlements">
          <div className="flex items-start gap-3 text-sm text-[var(--color-muted)]">
            <LockKeyhole className="mt-0.5 h-5 w-5 text-[var(--color-primary)]" aria-hidden />
            <p>There are no supplier-reported Pay on Delivery settlements waiting for finance verification.</p>
          </div>
        </Card>
      ) : (
        <div className="space-y-3">
          {settlements.map((settlement, index) => (
            <div className="rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-5 shadow-[0_10px_28px_rgba(18,28,28,0.045)]" key={`${settlement.orderId}:${index}`}>
              <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <h2 className="text-lg font-extrabold">{settlement.orderNumber}</h2>
                    <StatusBadge status="Settlement due" />
                    <StatusBadge status={settlement.commissionStatus === "awaiting_supplier_settlement" ? "Commission locked" : settlement.commissionStatus} />
                  </div>
                  <p className="mt-2 text-sm text-[var(--color-muted)]">
                    {settlement.supplierBusinessName} to {settlement.resellerDisplayName}
                  </p>
                  <p className="mt-1 text-xs font-semibold text-[var(--color-muted)]">Supplier reported: {formatDate(settlement.supplierReportedAt)}</p>
                </div>
                <div className="grid min-w-[320px] gap-3 sm:grid-cols-3">
                  <div>
                    <p className="text-xs font-bold uppercase tracking-[0.06em] text-[var(--color-muted)]">Platform</p>
                    <p className="font-extrabold">{formatMoney(settlement.platformAmountDue, settlement.currencyCode)}</p>
                  </div>
                  <div>
                    <p className="text-xs font-bold uppercase tracking-[0.06em] text-[var(--color-muted)]">Commission</p>
                    <p className="font-extrabold">{formatMoney(settlement.resellerCommissionDue, settlement.currencyCode)}</p>
                  </div>
                  <div>
                    <p className="text-xs font-bold uppercase tracking-[0.06em] text-[var(--color-muted)]">Total due</p>
                    <p className="font-extrabold">{formatMoney(settlement.totalSettlementDue, settlement.currencyCode)}</p>
                  </div>
                </div>
              </div>
              <div className="mt-4">
                <Link
                  className={cn(
                    "inline-flex h-8 items-center justify-center gap-2 whitespace-nowrap rounded-[var(--radius-md)] bg-[var(--color-primary)] px-3 text-xs font-semibold text-white shadow-[var(--shadow-sm)] transition-[var(--transition-fast)] hover:bg-[var(--color-primary-hover)]"
                  )}
                  href={`/admin/settlements/${settlement.orderId}`}
                >
                  Review
                </Link>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export function AdminSettlementDetailScreen({
  settlement,
  errorCode,
  success
}: {
  settlement: AdminSupplierSettlement | null;
  errorCode?: AdminSettlementCode | null;
  success?: boolean;
}) {
  if (!settlement) {
    return (
      <Card title="Settlement unavailable">
        <p className="text-sm text-[var(--color-muted)]">This supplier settlement is unavailable or your account cannot review it.</p>
      </Card>
    );
  }

  const isVerified = settlement.settlementStatus === "paid" || settlement.orderStatus === "completed" || settlement.paymentCollectionStatus === "settlement_verified";
  const canVerify = settlement.canVerify && !isVerified;

  return (
    <div className="space-y-5">
      <div className="rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-6 shadow-[0_14px_36px_rgba(18,28,28,0.05)]">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.08em] text-[var(--color-primary)]">Settlement review</p>
            <h1 className="mt-1 text-[1.75rem] font-bold leading-tight">{settlement.orderNumber}</h1>
            <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
              Verify only after confirming that Risellar received the full settlement amount for this order.
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <StatusBadge status={isVerified ? "Settlement verified" : "Settlement due"} />
            <StatusBadge status={settlement.commissionStatus === "available" ? "Commission available" : "Commission locked"} />
          </div>
        </div>
      </div>

      {errorCode ? (
        <div className="rounded-[var(--radius-lg)] border border-[var(--color-danger-soft)] bg-[var(--color-danger-soft)] p-4 text-sm font-semibold text-[var(--color-danger)]">
          {errorMessages[errorCode] ?? errorMessages.UNKNOWN}
        </div>
      ) : null}

      {success ? (
        <div className="rounded-[var(--radius-lg)] border border-[var(--color-success-soft)] bg-[var(--color-success-soft)] p-4 text-sm font-semibold text-[var(--color-primary)]">
          Settlement verified - commission available.
        </div>
      ) : null}

      <SettlementSummary settlement={settlement} />

      <div className="grid gap-5 xl:grid-cols-[1fr_420px]">
        <Card title="Finance state">
          <div className="grid gap-3 text-sm md:grid-cols-2">
            <p><span className="font-bold">Supplier:</span> {settlement.supplierBusinessName}</p>
            <p><span className="font-bold">Reseller shop:</span> {settlement.resellerDisplayName}</p>
            <p><span className="font-bold">Order status:</span> {settlement.orderStatus}</p>
            <p><span className="font-bold">Payment status:</span> {settlement.paymentCollectionStatus}</p>
            <p><span className="font-bold">Settlement status:</span> {settlement.settlementStatus}</p>
            <p><span className="font-bold">Commission status:</span> {settlement.commissionStatus}</p>
            <p><span className="font-bold">Reservation:</span> {settlement.reservationStatus ?? "Unavailable"}</p>
            <p><span className="font-bold">Supplier reported:</span> {formatDate(settlement.supplierReportedAt)}</p>
          </div>
          {isVerified ? (
            <div className="mt-5 flex items-start gap-3 rounded-[var(--radius-lg)] border border-[var(--color-success-soft)] bg-[var(--color-success-soft)] p-4 text-sm text-[var(--color-primary)]">
              <CheckCircle2 className="mt-0.5 h-5 w-5" aria-hidden />
              <p>The order is complete and the reseller commission is now available. No withdrawal has been created.</p>
            </div>
          ) : null}
        </Card>

        <Card title="Verify settlement">
          {canVerify ? (
            <form action={verifySupplierSettlementFormAction} className="space-y-4">
              <input name="order_id" type="hidden" value={settlement.orderId} />
              <input name="idempotency_key" type="hidden" value={`admin-settlement-verify:${settlement.orderId}`} />
              <div className="rounded-[var(--radius-lg)] border border-[var(--color-warning-soft)] bg-[var(--color-warning-soft)] p-3 text-sm font-semibold text-[#8A5A00]">
                Verify only after confirming that Risellar received the full platform amount and reseller commission from the supplier.
              </div>
              <label className="block text-sm font-bold">
                Settlement reference
                <input
                  className="mt-2 w-full rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 py-2 text-sm"
                  maxLength={100}
                  name="settlement_reference"
                  placeholder="Optional bank or MoMo reference"
                />
              </label>
              <label className="block text-sm font-bold">
                Private admin note
                <textarea
                  className="mt-2 min-h-24 w-full rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 py-2 text-sm"
                  maxLength={500}
                  name="admin_note"
                  placeholder="Optional internal note"
                />
              </label>
              <label className="flex items-start gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] p-3 text-sm font-semibold">
                <input className="mt-1" name="settlement_acknowledgement" type="checkbox" value="confirmed" />
                <span>I confirm that Risellar received the full settlement amount for this order.</span>
              </label>
              <VerifyButton />
            </form>
          ) : (
            <div className="flex items-start gap-3 text-sm text-[var(--color-muted)]">
              <ReceiptText className="mt-0.5 h-5 w-5 text-[var(--color-primary)]" aria-hidden />
              <p>Verification is unavailable because this settlement is already verified or the accounting state is not actionable.</p>
            </div>
          )}
          <div className="mt-4 flex items-start gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-3 text-xs font-semibold text-[var(--color-muted)]">
            <WalletCards className="mt-0.5 h-4 w-4" aria-hidden />
            <p>No withdrawal, supplier payout, payment provider call, stock movement, refund, or delivery action is created here.</p>
          </div>
        </Card>
      </div>
    </div>
  );
}
