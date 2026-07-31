import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { AdminDashboardMetricsScreen } from "@/components/dashboard/real-dashboard-metrics-screens";
import { listAdminSettlementHistorySafeWithClient, listAdminWithdrawalHistorySafeWithClient } from "@/lib/admin/finance/admin-finance";
import { getAdminDashboardMetricsSafeWithClient, getDashboardPeriodFromSearchParams } from "@/lib/dashboard/real-dashboard-metrics";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export default async function AdminDashboardPage({
  searchParams
}: {
  searchParams?: Promise<{ period?: string }>;
}) {
  const params = await searchParams;
  const period = getDashboardPeriodFromSearchParams(params);
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent("/admin/dashboard")}`);
  }

  const accessToken = await getToken();

  if (!accessToken) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent("/admin/dashboard")}`);
  }

  const client = createSupabaseUserServerClient(accessToken);
  const filters = { status: null, dateFrom: null, dateTo: null };
  const [summaryResult, settlementResult, withdrawalResult] = await Promise.all([
    getAdminDashboardMetricsSafeWithClient(client, period),
    listAdminSettlementHistorySafeWithClient(client, filters),
    listAdminWithdrawalHistorySafeWithClient(client, filters)
  ]);

  return (
    <AdminDashboardMetricsScreen
      period={period}
      settlements={settlementResult.settlements}
      state={summaryResult.state}
      summaries={summaryResult.summaries}
      withdrawals={withdrawalResult.withdrawals}
    />
  );
}
