import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { CustomerReportProblemScreen } from "@/components/customer/customer-dispute-rpc-screens";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import { listCustomerOrderItemsForDisputeSafeWithClient } from "@/lib/customer/disputes";
import { getCustomerOrderSafeWithClient } from "@/lib/orders/customer-order-read";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

async function getCustomerOrderForReportProblem(orderId: string) {
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect(`/sign-in?redirect_url=/customer/orders/${orderId}/report-problem`);
  }

  const profile = await getCurrentSyncedProfile();

  if (!profile) {
    return null;
  }

  const accessToken = await getToken();

  if (!accessToken) {
    return null;
  }

  const supabase = createSupabaseUserServerClient(accessToken);
  const [orderResult, orderItemResult] = await Promise.all([
    getCustomerOrderSafeWithClient(supabase, orderId),
    listCustomerOrderItemsForDisputeSafeWithClient(supabase, orderId)
  ]);

  return {
    order: orderResult.order,
    orderItems: orderItemResult.orderItems,
    orderItemsState: orderItemResult.state
  };
}

export default async function CustomerReportProblemPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const result = await getCustomerOrderForReportProblem(id);

  if (!result?.order) {
    redirect("/customer/orders");
  }

  return <CustomerReportProblemScreen order={result.order} orderItems={result.orderItems} orderItemsState={result.orderItemsState} />;
}
