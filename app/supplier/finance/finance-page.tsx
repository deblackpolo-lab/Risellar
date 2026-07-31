import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { FinanceFilterLinks, SupplierFinanceSummaryCards, SupplierSettlementHistoryList } from "@/components/finance/finance-ui";
import { MobileShell } from "@/components/layout";
import { Card } from "@/components/ui";
import { normalizeFinanceDate, normalizeFinanceStatus } from "@/lib/finance/filters";
import { getSupplierFinanceSummarySafeWithClient, listSupplierSettlementHistorySafeWithClient } from "@/lib/supplier/finance/supplier-finance";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export async function SupplierFinanceRpcPage({
  searchParams,
  title = "Supplier finance"
}: {
  searchParams?: Promise<{ status?: string; from?: string; to?: string }>;
  title?: string;
}) {
  const params = await searchParams;
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect("/sign-in");
  }

  const accessToken = await getToken();

  if (!accessToken) {
    redirect("/supplier/dashboard?error=SUPABASE_AUTH_TOKEN_MISSING");
  }

  const filters = {
    status: normalizeFinanceStatus(params?.status, ["pending", "verified", "paid"]),
    dateFrom: normalizeFinanceDate(params?.from),
    dateTo: normalizeFinanceDate(params?.to)
  };
  const client = createSupabaseUserServerClient(accessToken);
  const [summaryResult, settlementResult] = await Promise.all([
    getSupplierFinanceSummarySafeWithClient(client, filters),
    listSupplierSettlementHistorySafeWithClient(client, filters)
  ]);

  return (
    <MobileShell title={title}>
      <div className="space-y-4">
        <header>
          <h1 className="text-2xl font-extrabold">{title}</h1>
          <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
            Track customer payments reported and settlement obligations. Self-verification is not available.
          </p>
        </header>

        {summaryResult.state.code !== "OK" || settlementResult.state.code !== "OK" ? (
          <Card className="border-[var(--color-danger)]/30 bg-[var(--color-danger-soft)]">
            <p className="text-sm font-semibold">{summaryResult.state.code !== "OK" ? summaryResult.state.message : settlementResult.state.message}</p>
          </Card>
        ) : null}

        <FinanceFilterLinks basePath="/supplier/settlements" statuses={[{ hrefStatus: "pending", label: "Pending" }, { hrefStatus: "verified", label: "Verified" }]} />
        <SupplierFinanceSummaryCards summaries={summaryResult.summaries} />
        <SupplierSettlementHistoryList settlements={settlementResult.settlements} />
      </div>
    </MobileShell>
  );
}
