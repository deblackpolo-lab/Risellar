import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { ResellerWithdrawalScreen } from "@/components/reseller/reseller-withdrawal-rpc-screens";
import {
  getResellerWalletSafeWithClient,
  listResellerPayoutAccountsSafeWithClient
} from "@/lib/reseller/withdrawals/reseller-withdrawal";
import { normalizeFinanceDate, normalizeFinanceStatus } from "@/lib/finance/filters";
import { listResellerWithdrawalHistorySafeWithClient } from "@/lib/reseller/finance/reseller-finance";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export default async function ResellerWithdrawalsPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string; status?: string; from?: string; to?: string }>;
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
  const filters = {
    status: normalizeFinanceStatus(params?.status, ["pending", "paid", "rejected", "cancelled"]),
    dateFrom: normalizeFinanceDate(params?.from),
    dateTo: normalizeFinanceDate(params?.to)
  };
  const [walletResult, payoutResult, withdrawalResult] = await Promise.all([
    getResellerWalletSafeWithClient(supabase),
    listResellerPayoutAccountsSafeWithClient(supabase),
    listResellerWithdrawalHistorySafeWithClient(supabase, filters)
  ]);

  return (
    <ResellerWithdrawalScreen
      errorCode={params?.error}
      payoutAccounts={payoutResult.payoutAccounts}
      state={walletResult.state.code === "OK" ? payoutResult.state : walletResult.state}
      success={params?.status === "requested" ? "requested" : undefined}
      wallet={walletResult.wallet}
      withdrawals={withdrawalResult.withdrawals}
    />
  );
}
