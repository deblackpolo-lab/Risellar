import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { ResellerWithdrawalDetailScreen } from "@/components/reseller/reseller-withdrawal-rpc-screens";
import { getResellerWithdrawalSafeWithClient } from "@/lib/reseller/withdrawals/reseller-withdrawal";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export default async function ResellerWithdrawalDetailPage({
  params
}: {
  params: Promise<{ withdrawalId: string }>;
}) {
  const { withdrawalId } = await params;
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect("/sign-in");
  }

  const accessToken = await getToken();

  if (!accessToken) {
    redirect("/reseller/dashboard?error=SUPABASE_AUTH_TOKEN_MISSING");
  }

  const supabase = createSupabaseUserServerClient(accessToken);
  const { withdrawal } = await getResellerWithdrawalSafeWithClient(supabase, withdrawalId);

  return <ResellerWithdrawalDetailScreen withdrawal={withdrawal} />;
}
