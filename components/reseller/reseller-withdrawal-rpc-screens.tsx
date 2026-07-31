import Link from "next/link";
import { Wallet } from "lucide-react";
import { requestResellerWithdrawalFormAction, saveResellerPayoutAccountFormAction } from "@/app/reseller/withdrawals/actions";
import { AccountSignOutButton } from "@/components/auth/AccountSignOutButton";
import { BottomNav, MobileShell } from "@/components/layout";
import { Button, Card, StatusBadge } from "@/components/ui";
import type {
  ResellerPayoutAccountSafe,
  ResellerWalletSafe,
  ResellerWithdrawalSafe,
  WithdrawalState
} from "@/lib/reseller/withdrawals/reseller-withdrawal";

function formatGhc(amount: number | null | undefined) {
  return `GH₵${Number(amount ?? 0).toLocaleString("en-GH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function stateMessage(code?: string | null) {
  if (!code) return null;
  const messages: Record<string, string> = {
    requested: "Withdrawal requested. Money has not been sent yet.",
    "account-saved": "Payout account saved.",
    RESELLER_REQUIRED: "Use an active reseller account.",
    PAYOUT_ACCOUNT_REQUIRED: "Save a valid payout account first.",
    PAYOUT_ACCOUNT_NOT_FOUND: "Choose a valid payout account.",
    INVALID_AMOUNT: "Enter a valid withdrawal amount.",
    BELOW_MINIMUM: "Enter at least the minimum withdrawal amount.",
    INSUFFICIENT_AVAILABLE_BALANCE: "Your available balance is not enough for this withdrawal.",
    WITHDRAWAL_ALREADY_PENDING: "You already have a pending withdrawal request.",
    CONFLICTING_RETRY: "This withdrawal was already requested with different details. Refresh the page.",
    UNKNOWN: "We could not confirm the result. Refresh before trying again."
  };

  return messages[code] ?? messages.UNKNOWN;
}

export function ResellerWithdrawalScreen({
  errorCode,
  payoutAccounts,
  state,
  success,
  wallet,
  withdrawals
}: {
  errorCode?: string | null;
  payoutAccounts: ResellerPayoutAccountSafe[];
  state?: WithdrawalState | null;
  success?: string | null;
  wallet: ResellerWalletSafe | null;
  withdrawals: ResellerWithdrawalSafe[];
}) {
  const activeAccount = payoutAccounts[0] ?? null;
  const available = wallet?.availableBalanceAmount ?? 0;
  const hasPending = Boolean(wallet?.hasPendingWithdrawal);
  const disabled = !activeAccount || hasPending || available <= 0;
  const message = state?.code && state.code !== "OK" ? state.message : stateMessage(errorCode ?? success);

  return (
    <MobileShell footer={<BottomNav active="Support" />} title="Withdrawals">
      <div className="space-y-4">
        <section className="rounded-[var(--radius-xl)] bg-[var(--color-primary)] p-5 text-white shadow-[var(--shadow-sm)]">
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm text-white/80">Available commission</p>
              <p className="mt-1 text-3xl font-bold">{formatGhc(available)}</p>
              <p className="mt-2 text-sm text-white/80">Only available commission can be withdrawn.</p>
            </div>
            <Wallet className="h-8 w-8 text-white/80" aria-hidden />
          </div>
        </section>

        {message ? (
          <Card className={errorCode ? "border-[var(--color-danger)]/30 bg-[var(--color-danger-soft)]" : "border-[var(--color-success)]/30 bg-[var(--color-success-soft)]"}>
            <p className="text-sm font-semibold">{message}</p>
          </Card>
        ) : null}

        <div className="grid grid-cols-2 gap-3">
          <Card>
            <p className="text-xs font-semibold text-[var(--color-muted)]">Locked commission</p>
            <p className="mt-1 text-xl font-bold">{formatGhc(wallet?.lockedCommissionAmount)}</p>
          </Card>
          <Card>
            <p className="text-xs font-semibold text-[var(--color-muted)]">Pending withdrawal</p>
            <p className="mt-1 text-xl font-bold">{formatGhc(wallet?.pendingWithdrawalAmount)}</p>
          </Card>
          <Card>
            <p className="text-xs font-semibold text-[var(--color-muted)]">Withdrawn total</p>
            <p className="mt-1 text-xl font-bold">{formatGhc(wallet?.withdrawnAmount)}</p>
          </Card>
          <Card>
            <p className="text-xs font-semibold text-[var(--color-muted)]">Minimum</p>
            <p className="mt-1 text-xl font-bold">{formatGhc(wallet?.minimumWithdrawalAmount)}</p>
          </Card>
        </div>

        <Card title="Payout account">
          {activeAccount ? (
            <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm">
              <p className="font-bold">{activeAccount.accountName}</p>
              <p className="mt-1 text-[var(--color-muted)]">
                {activeAccount.mobileMoneyNetwork ?? activeAccount.payoutMethod} • {activeAccount.phoneNumberMasked ?? "masked"}
              </p>
            </div>
          ) : (
            <p className="text-sm text-[var(--color-muted)]">Save a development payout account before requesting a withdrawal.</p>
          )}

          <form action={saveResellerPayoutAccountFormAction} className="mt-4 grid gap-3">
            <input name="idempotency_key" type="hidden" value={crypto.randomUUID()} />
            <label className="grid gap-1 text-sm font-semibold">
              Account name
              <input className="h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 font-normal" name="account_name" required />
            </label>
            <label className="grid gap-1 text-sm font-semibold">
              Mobile Money network
              <select className="h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 font-normal" name="mobile_money_network" required>
                <option value="mtn_momo">MTN MoMo</option>
                <option value="telecel_cash">Telecel Cash</option>
                <option value="airteltigo_money">AirtelTigo Money</option>
              </select>
            </label>
            <label className="grid gap-1 text-sm font-semibold">
              Phone number
              <input className="h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 font-normal" name="phone_number" required />
            </label>
            <Button type="submit" variant="outline">Save payout account</Button>
          </form>
        </Card>

        <Card title="Withdrawal request">
          <p className="text-sm leading-6 text-[var(--color-muted)]">
            Money is not sent immediately. Risellar will review and process the request manually.
          </p>
          <form action={requestResellerWithdrawalFormAction} className="mt-4 grid gap-3">
            <input name="idempotency_key" type="hidden" value={crypto.randomUUID()} />
            <input name="payout_account_id" type="hidden" value={activeAccount?.payoutAccountId ?? ""} />
            <label className="grid gap-1 text-sm font-semibold">
              Amount
              <input className="h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 font-normal" min={wallet?.minimumWithdrawalAmount ?? 10} name="amount" required step="0.01" type="number" />
            </label>
            <label className="flex items-start gap-3 text-sm">
              <input className="mt-1" name="withdrawal_acknowledgement" required type="checkbox" value="confirmed" />
              <span>I understand that this creates a withdrawal request. Money has not been sent yet.</span>
            </label>
            <Button disabled={disabled} type="submit">Request withdrawal</Button>
          </form>
        </Card>

        <Card title="Withdrawal history">
          <div className="space-y-3">
            {withdrawals.length ? withdrawals.map((withdrawal) => (
              <Link className="block rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" href={`/reseller/withdrawals/${withdrawal.withdrawalId}`} key={withdrawal.withdrawalId}>
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="font-bold">{withdrawal.requestReference ?? "Withdrawal"}</p>
                    <p className="mt-1 text-sm text-[var(--color-muted)]">{formatGhc(withdrawal.requestedAmount)} • {withdrawal.payoutAccountMasked ?? "masked account"}</p>
                  </div>
                  <StatusBadge status={withdrawal.withdrawalStatus === "requested" ? "Pending" : withdrawal.withdrawalStatus} />
                </div>
              </Link>
            )) : (
              <p className="text-sm text-[var(--color-muted)]">No withdrawal requests yet.</p>
            )}
          </div>
        </Card>

        <AccountSignOutButton className="w-full" />
      </div>
    </MobileShell>
  );
}

export function ResellerWalletRpcScreen(props: Omit<Parameters<typeof ResellerWithdrawalScreen>[0], "success" | "errorCode">) {
  return <ResellerWithdrawalScreen {...props} />;
}

export function ResellerWithdrawalDetailScreen({ withdrawal }: { withdrawal: ResellerWithdrawalSafe | null }) {
  return (
    <MobileShell footer={<BottomNav active="Support" />} title="Withdrawal">
      {withdrawal ? (
        <Card title={withdrawal.requestReference ?? "Withdrawal"}>
          <div className="space-y-3 text-sm">
            <InfoRow label="Amount" value={formatGhc(withdrawal.requestedAmount)} />
            <InfoRow label="Status" value={withdrawal.withdrawalStatus === "requested" ? "Pending" : withdrawal.withdrawalStatus} />
            <InfoRow label="Payout account" value={withdrawal.payoutAccountMasked ?? "Masked account"} />
            <InfoRow label="Requested" value={withdrawal.requestedAt ?? "Unavailable"} />
            <InfoRow label="Paid" value={withdrawal.paidAt ?? "Not paid yet"} />
          </div>
          <p className="mt-4 rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-sm text-[#8A5A00]">
            Money has not been sent yet unless this withdrawal is marked paid by Risellar finance.
          </p>
        </Card>
      ) : (
        <Card>
          <p className="text-sm text-[var(--color-muted)]">This withdrawal is unavailable.</p>
        </Card>
      )}
    </MobileShell>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-[var(--color-muted)]">{label}</span>
      <span className="text-right font-semibold">{value}</span>
    </div>
  );
}
