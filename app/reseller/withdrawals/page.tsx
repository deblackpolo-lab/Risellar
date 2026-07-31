import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { ResellerWithdrawalScreen } from "@/components/reseller/reseller-withdrawal-rpc-screens";
import {
  getResellerWalletSafeWithClient,
  listResellerPayoutAccountsSafeWithClient,
  listResellerWithdrawalsSafeWithClient
} from "@/lib/reseller/withdrawals/reseller-withdrawal";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export default async function ResellerWithdrawalsPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; status?: string }>;
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

  const supabase = createSupabaseUserServerClient(accessToken);
  const [walletResult, payoutResult, withdrawalResult] = await Promise.all([
    getResellerWalletSafeWithClient(supabase),
    listResellerPayoutAccountsSafeWithClient(supabase),
    listResellerWithdrawalsSafeWithClient(supabase)
  ]);

  return (
    <ResellerWithdrawalScreen
      errorCode={params?.error}
      payoutAccounts={payoutResult.payoutAccounts}
      state={walletResult.state.code === "OK" ? payoutResult.state : walletResult.state}
      success={params?.status}
      wallet={walletResult.wallet}
      withdrawals={withdrawalResult.withdrawals}
    />
  );
}
