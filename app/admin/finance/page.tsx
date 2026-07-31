import { auth } from "@clerk/nextjs/server";
import { AdminShell } from "@/components/admin/AdminSidebar";
import { AdminFinanceSummaryCards, AdminSettlementHistoryList, AdminWithdrawalHistoryList, FinanceFilterLinks } from "@/components/finance/finance-ui";
import { Card } from "@/components/ui";
import { getAdminFinanceSummarySafeWithClient, listAdminSettlementHistorySafeWithClient, listAdminWithdrawalHistorySafeWithClient } from "@/lib/admin/finance/admin-finance";
import { normalizeFinanceDate, normalizeFinanceStatus } from "@/lib/finance/filters";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export default async function AdminFinancePage({
  searchParams
}: {
  searchParams?: Promise<{ status?: string; from?: string; to?: string }>;
}) {
  const params = await searchParams;
  const filters = {
    status: normalizeFinanceStatus(params?.status, ["pending", "verified", "paid", "rejected", "cancelled"]),
    dateFrom: normalizeFinanceDate(params?.from),
    dateTo: normalizeFinanceDate(params?.to)
  };
  let summaryResult: Awaited<ReturnType<typeof getAdminFinanceSummarySafeWithClient>> = { summaries: [], state: { code: "AUTH_REQUIRED", message: "Sign in to view finance." } };
  let settlementResult: Awaited<ReturnType<typeof listAdminSettlementHistorySafeWithClient>> = { settlements: [], state: { code: "AUTH_REQUIRED", message: "Sign in to view finance." } };
  let withdrawalResult: Awaited<ReturnType<typeof listAdminWithdrawalHistorySafeWithClient>> = { withdrawals: [], state: { code: "AUTH_REQUIRED", message: "Sign in to view finance." } };

  try {
    const { getToken, userId } = await auth();

    if (!userId) {
      throw new Error("AUTH_REQUIRED");
    }

    const accessToken = await getToken();

    if (!accessToken) {
      throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
    }

    const client = createSupabaseUserServerClient(accessToken);
    [summaryResult, settlementResult, withdrawalResult] = await Promise.all([
      getAdminFinanceSummarySafeWithClient(client, filters),
      listAdminSettlementHistorySafeWithClient(client, filters),
      listAdminWithdrawalHistorySafeWithClient(client, filters)
    ]);
  } catch {
    summaryResult = { summaries: [], state: { code: "AUTH_REQUIRED", message: "Sign in with a finance admin account." } };
  }

  const errorMessage = summaryResult.state.code !== "OK"
    ? summaryResult.state.message
    : settlementResult.state.code !== "OK"
      ? settlementResult.state.message
      : withdrawalResult.state.code !== "OK"
        ? withdrawalResult.state.message
        : null;

  return (
    <AdminShell searchPlaceholder="Search finance history...">
      <div className="mx-auto w-full max-w-7xl space-y-5">
        <header>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--color-primary)]">Finance history</p>
          <h1 className="mt-2 text-3xl font-bold">Finance dashboard</h1>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--color-muted)]">
            Read-only history for verified platform revenue, supplier settlements, and reseller withdrawals. Gross sales stay separate from platform revenue.
          </p>
        </header>

        {errorMessage ? (
          <Card className="border-[var(--color-danger)]/30 bg-[var(--color-danger-soft)]">
            <p className="text-sm font-semibold">{errorMessage}</p>
          </Card>
        ) : null}

        <FinanceFilterLinks basePath="/admin/finance" statuses={[{ hrefStatus: "pending", label: "Pending" }, { hrefStatus: "verified", label: "Verified" }, { hrefStatus: "paid", label: "Paid" }]} />
        <AdminFinanceSummaryCards summaries={summaryResult.summaries} />
        <div className="grid gap-5 xl:grid-cols-2">
          <AdminSettlementHistoryList settlements={settlementResult.settlements} />
          <AdminWithdrawalHistoryList withdrawals={withdrawalResult.withdrawals} />
        </div>
      </div>
    </AdminShell>
  );
}
