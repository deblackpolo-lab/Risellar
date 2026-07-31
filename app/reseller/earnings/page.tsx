import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { BottomNav, MobileShell } from "@/components/layout";
import { Card } from "@/components/ui";
import { FinanceFilterLinks, ResellerEarningsList, ResellerFinanceSummaryCards } from "@/components/finance/finance-ui";
import { normalizeFinanceDate, normalizeFinanceStatus } from "@/lib/finance/filters";
import { getResellerFinanceSummarySafeWithClient, listResellerEarningsHistorySafeWithClient } from "@/lib/reseller/finance/reseller-finance";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export default async function ResellerEarningsPage({
  searchParams
}: {
  searchParams?: Promise<{ status?: string; from?: string; to?: string }>;
}) {
  const params = await searchParams;
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect("/sign-in");
  }

  const accessToken = await getToken();

  if (!accessToken) {
    redirect("/reseller/dashboard?error=SUPABASE_AUTH_TOKEN_MISSING");
  }

  const filters = {
    status: normalizeFinanceStatus(params?.status, ["locked", "available", "pending_withdrawal", "withdrawn"]),
    dateFrom: normalizeFinanceDate(params?.from),
    dateTo: normalizeFinanceDate(params?.to)
  };
  const client = createSupabaseUserServerClient(accessToken);
  const [summaryResult, earningsResult] = await Promise.all([
    getResellerFinanceSummarySafeWithClient(client, filters),
    listResellerEarningsHistorySafeWithClient(client, filters)
  ]);

  return (
    <MobileShell footer={<BottomNav active="Support" />} title="Reseller earnings">
      <div className="space-y-4">
        <header>
          <h1 className="text-2xl font-extrabold">Earnings</h1>
          <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
            Current wallet balances are separate from selected-period activity.
          </p>
        </header>

        {summaryResult.state.code !== "OK" || earningsResult.state.code !== "OK" ? (
          <Card className="border-[var(--color-danger)]/30 bg-[var(--color-danger-soft)]">
            <p className="text-sm font-semibold">{summaryResult.state.code !== "OK" ? summaryResult.state.message : earningsResult.state.message}</p>
          </Card>
        ) : null}

        <FinanceFilterLinks
          basePath="/reseller/earnings"
          statuses={[
            { hrefStatus: "locked", label: "Locked" },
            { hrefStatus: "available", label: "Available" },
            { hrefStatus: "pending_withdrawal", label: "Pending withdrawal" },
            { hrefStatus: "withdrawn", label: "Withdrawn" }
          ]}
        />
        <ResellerFinanceSummaryCards summaries={summaryResult.summaries} />
        <ResellerEarningsList earnings={earningsResult.earnings} />
      </div>
    </MobileShell>
  );
}
