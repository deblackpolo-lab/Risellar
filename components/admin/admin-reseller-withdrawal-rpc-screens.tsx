import Link from "next/link";
import { markResellerWithdrawalPaidFormAction } from "@/app/admin/withdrawals/actions";
import { AdminShell } from "@/components/admin/AdminSidebar";
import { Button, Card, StatusBadge } from "@/components/ui";
import type { AdminResellerWithdrawal, AdminWithdrawalState } from "@/lib/admin/withdrawals/admin-reseller-withdrawal";

function formatGhc(amount: number | null | undefined) {
  return `GH₵${Number(amount ?? 0).toLocaleString("en-GH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function stateMessage(code?: string | null) {
  if (!code) return null;
  const messages: Record<string, string> = {
    paid: "Withdrawal marked as paid.",
    FINANCE_ADMIN_REQUIRED: "You do not have permission to manage withdrawals.",
    WITHDRAWAL_NOT_FOUND: "This withdrawal is unavailable.",
    WITHDRAWAL_NOT_PENDING: "This withdrawal can no longer be marked paid.",
    PAYOUT_REFERENCE_REQUIRED: "Enter the payout reference.",
    BALANCE_STATE_INCONSISTENT: "The reseller balance is inconsistent. Contact support before continuing.",
    CONFLICTING_PAYOUT_RETRY: "This withdrawal was already paid with different details. Refresh the page.",
    UNKNOWN: "We could not confirm the result. Refresh before trying again."
  };

  return messages[code] ?? messages.UNKNOWN;
}

export function AdminResellerWithdrawalListScreen({
  errorCode,
  state,
  withdrawals
}: {
  errorCode?: string | null;
  state?: AdminWithdrawalState | null;
  withdrawals: AdminResellerWithdrawal[];
}) {
  const message = state?.code && state.code !== "OK" ? state.message : stateMessage(errorCode);

  return (
    <AdminShell searchPlaceholder="Search withdrawal requests, resellers...">
      <div className="mx-auto w-full max-w-6xl space-y-5">
        <header>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--color-primary)]">Finance</p>
          <h1 className="mt-2 text-3xl font-bold">Reseller withdrawals</h1>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--color-muted)]">
            Review reserved reseller withdrawal requests. Risellar does not send money automatically in this phase.
          </p>
        </header>

        {message ? (
          <Card className="border-[var(--color-danger)]/30 bg-[var(--color-danger-soft)]">
            <p className="text-sm font-semibold">{message}</p>
          </Card>
        ) : null}

        <Card title="Pending manual payouts">
          <div className="space-y-3">
            {withdrawals.length ? withdrawals.map((withdrawal, index) => (
              <Link className="block rounded-[var(--radius-md)] border border-[var(--color-border)] p-4 transition hover:border-[var(--color-primary)]" href={`/admin/withdrawals/${withdrawal.withdrawalId}`} key={`${withdrawal.withdrawalId}:${index}`}>
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="font-bold">{withdrawal.requestReference ?? "Withdrawal request"}</p>
                    <p className="mt-1 text-sm text-[var(--color-muted)]">{withdrawal.resellerDisplayName} • {withdrawal.resellerEmailMasked ?? "masked email"}</p>
                    <p className="mt-1 text-sm text-[var(--color-muted)]">{withdrawal.payoutMethod ?? "payout"} • {withdrawal.payoutAccountMasked ?? "masked account"}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-xl font-bold">{formatGhc(withdrawal.requestedAmount)}</p>
                    <StatusBadge status={withdrawal.withdrawalStatus === "requested" ? "Pending" : withdrawal.withdrawalStatus} />
                  </div>
                </div>
              </Link>
            )) : (
              <p className="text-sm text-[var(--color-muted)]">No pending withdrawal requests.</p>
            )}
          </div>
        </Card>
      </div>
    </AdminShell>
  );
}

export function AdminResellerWithdrawalDetailScreen({
  errorCode,
  success,
  withdrawal
}: {
  errorCode?: string | null;
  success?: boolean;
  withdrawal: AdminResellerWithdrawal | null;
}) {
  const message = success ? stateMessage("paid") : stateMessage(errorCode);

  return (
    <AdminShell searchPlaceholder="Search withdrawal requests, resellers...">
      <div className="mx-auto w-full max-w-4xl space-y-5">
        <header>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--color-primary)]">Manual payout</p>
          <h1 className="mt-2 text-3xl font-bold">{withdrawal?.requestReference ?? "Withdrawal request"}</h1>
          <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
            Mark this request paid only after you have manually sent the full amount to the reseller.
          </p>
        </header>

        {message ? (
          <Card className={success ? "border-[var(--color-success)]/30 bg-[var(--color-success-soft)]" : "border-[var(--color-danger)]/30 bg-[var(--color-danger-soft)]"}>
            <p className="text-sm font-semibold">{message}</p>
          </Card>
        ) : null}

        {withdrawal ? (
          <>
            <Card title="Trusted withdrawal details">
              <div className="grid gap-3 text-sm md:grid-cols-2">
                <InfoRow label="Reseller" value={withdrawal.resellerDisplayName} />
                <InfoRow label="Email" value={withdrawal.resellerEmailMasked ?? "masked"} />
                <InfoRow label="Amount" value={formatGhc(withdrawal.requestedAmount)} />
                <InfoRow label="Currency" value={withdrawal.currencyCode} />
                <InfoRow label="Status" value={withdrawal.withdrawalStatus === "requested" ? "Pending" : withdrawal.withdrawalStatus} />
                <InfoRow label="Payout account" value={withdrawal.payoutAccountMasked ?? "masked"} />
                <InfoRow label="Available balance" value={formatGhc(withdrawal.resellerAvailableAmount)} />
                <InfoRow label="Pending withdrawal" value={formatGhc(withdrawal.resellerPendingWithdrawalAmount)} />
                <InfoRow label="Withdrawn total" value={formatGhc(withdrawal.resellerWithdrawnAmount)} />
              </div>
            </Card>

            {withdrawal.canMarkPaid ? (
              <Card title="Record manual payout">
                <form action={markResellerWithdrawalPaidFormAction} className="grid gap-3">
                  <input name="withdrawal_id" type="hidden" value={withdrawal.withdrawalId} />
                  <input name="idempotency_key" type="hidden" value={crypto.randomUUID()} />
                  <label className="grid gap-1 text-sm font-semibold">
                    Payout reference
                    <input className="h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 font-normal" name="payout_reference" required />
                  </label>
                  <label className="grid gap-1 text-sm font-semibold">
                    Private admin note
                    <textarea className="min-h-24 rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 font-normal" name="admin_private_note" />
                  </label>
                  <label className="flex items-start gap-3 text-sm">
                    <input className="mt-1" name="manual_payout_acknowledgement" required type="checkbox" value="confirmed" />
                    <span>I confirm that the withdrawal amount was sent manually to the reseller's payout account.</span>
                  </label>
                  <Button type="submit">Mark as paid</Button>
                </form>
              </Card>
            ) : (
              <Card>
                <p className="text-sm font-semibold">No payment control is available for this withdrawal.</p>
              </Card>
            )}
          </>
        ) : (
          <Card>
            <p className="text-sm text-[var(--color-muted)]">This withdrawal is unavailable.</p>
          </Card>
        )}
      </div>
    </AdminShell>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3">
      <p className="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--color-muted)]">{label}</p>
      <p className="mt-1 font-bold">{value}</p>
    </div>
  );
}
