import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { CustomerOrderHistoryRpcScreen } from "@/components/customer/customer-order-history-rpc-screen";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import {
  getCustomerOrderSummarySafeWithClient,
  listCustomerOrdersSafeWithClient,
  type CustomerOrderHistoryGroup
} from "@/lib/orders/customer-order-history";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

function firstParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

function safeGroup(value: string | undefined): CustomerOrderHistoryGroup {
  return value === "active" || value === "completed" || value === "rejected" ? value : "all";
}

export default async function CustomerOrdersPage({
  searchParams
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent("/customer/orders")}`);
  }

  const profile = await getCurrentSyncedProfile();

  if (!profile) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent("/customer/orders")}`);
  }

  const accessToken = await getToken();

  if (!accessToken) {
    redirect(`/sign-in?redirect_url=${encodeURIComponent("/customer/orders")}`);
  }

  const query = await searchParams;
  const group = safeGroup(firstParam(query?.group));
  const search = firstParam(query?.search)?.trim() ?? "";
  const supabase = createSupabaseUserServerClient(accessToken);
  const [historyResult, summaryResult] = await Promise.all([
    listCustomerOrdersSafeWithClient(supabase, {
      group,
      search,
      limit: 20
    }),
    getCustomerOrderSummarySafeWithClient(supabase)
  ]);

  return (
    <CustomerOrderHistoryRpcScreen
      activeGroup={group}
      orders={historyResult.orders}
      search={search}
      summary={summaryResult.summary}
    />
  );
}
