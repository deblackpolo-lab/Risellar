import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { CustomerDashboardMetricsScreen } from "@/components/dashboard/real-dashboard-metrics-screens";
import { getCustomerDashboardMetricsSafeWithClient } from "@/lib/dashboard/real-dashboard-metrics";
import { listCustomerOrdersSafeWithClient } from "@/lib/orders/customer-order-history";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export default async function CustomerDashboardPage() {
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent("/customer/dashboard")}`);
  }

  const accessToken = await getToken();

  if (!accessToken) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent("/customer/dashboard")}`);
  }

  const client = createSupabaseUserServerClient(accessToken);
  const [summaryResult, ordersResult] = await Promise.all([
    getCustomerDashboardMetricsSafeWithClient(client),
    listCustomerOrdersSafeWithClient(client, { limit: 5 })
  ]);

  return (
    <CustomerDashboardMetricsScreen
      orders={ordersResult.orders}
      state={summaryResult.state.code === "OK" && ordersResult.state.code !== "OK"
        ? { code: "UNKNOWN", message: "We could not load this dashboard. Please refresh and try again." }
        : summaryResult.state}
      summary={summaryResult.summary}
    />
  );
}
