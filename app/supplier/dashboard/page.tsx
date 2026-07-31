import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { SupplierDashboardMetricsScreen } from "@/components/dashboard/real-dashboard-metrics-screens";
import { getDashboardPeriodFromSearchParams, getSupplierDashboardMetricsSafeWithClient } from "@/lib/dashboard/real-dashboard-metrics";
import { listSupplierOrdersSafeWithClient } from "@/lib/orders/supplier-order-read";
import { listSupplierSettlementHistorySafeWithClient } from "@/lib/supplier/finance/supplier-finance";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export default async function SupplierDashboardPage({
  searchParams
}: {
  searchParams?: Promise<{ period?: string }>;
}) {
  const params = await searchParams;
  const period = getDashboardPeriodFromSearchParams(params);
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent("/supplier/dashboard")}`);
  }

  const accessToken = await getToken();

  if (!accessToken) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent("/supplier/dashboard")}`);
  }

  const client = createSupabaseUserServerClient(accessToken);
  const [summaryResult, orderResult, settlementResult] = await Promise.all([
    getSupplierDashboardMetricsSafeWithClient(client, period),
    listSupplierOrdersSafeWithClient(client, { limit: 5 }),
    listSupplierSettlementHistorySafeWithClient(client, { status: null, dateFrom: null, dateTo: null })
  ]);

  return (
    <SupplierDashboardMetricsScreen
      orders={orderResult.orders}
      period={period}
      settlements={settlementResult.settlements}
      state={summaryResult.state}
      summaries={summaryResult.summaries}
    />
  );
}
