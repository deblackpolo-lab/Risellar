import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { ResellerDashboardMetricsScreen } from "@/components/dashboard/real-dashboard-metrics-screens";
import { getDashboardPeriodFromSearchParams, getResellerDashboardMetricsSafeWithClient } from "@/lib/dashboard/real-dashboard-metrics";
import { listResellerEarningsHistorySafeWithClient, listResellerWithdrawalHistorySafeWithClient } from "@/lib/reseller/finance/reseller-finance";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export default async function ResellerDashboardPage({
  searchParams
}: {
  searchParams?: Promise<{ period?: string }>;
}) {
  const params = await searchParams;
  const period = getDashboardPeriodFromSearchParams(params);
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent("/reseller/dashboard")}`);
  }

  const accessToken = await getToken();

  if (!accessToken) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent("/reseller/dashboard")}`);
  }

  const client = createSupabaseUserServerClient(accessToken);
  const filters = { status: null, dateFrom: null, dateTo: null };
  const [summaryResult, earningsResult, withdrawalResult] = await Promise.all([
    getResellerDashboardMetricsSafeWithClient(client, period),
    listResellerEarningsHistorySafeWithClient(client, filters),
    listResellerWithdrawalHistorySafeWithClient(client, filters)
  ]);

  return (
    <ResellerDashboardMetricsScreen
      earnings={earningsResult.earnings}
      period={period}
      state={summaryResult.state}
      summaries={summaryResult.summaries}
      withdrawals={withdrawalResult.withdrawals}
    />
  );
}
