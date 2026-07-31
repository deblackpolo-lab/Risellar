import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { AdminResellerWithdrawalListScreen } from "@/components/admin/admin-reseller-withdrawal-rpc-screens";
import { listAdminResellerWithdrawalsSafeWithClient } from "@/lib/admin/withdrawals/admin-reseller-withdrawal";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export default async function AdminWithdrawalsPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect("/sign-in");
  }

  const accessToken = await getToken();

  if (!accessToken) {
    redirect("/admin/dashboard?error=SUPABASE_AUTH_TOKEN_MISSING");
  }

  const supabase = createSupabaseUserServerClient(accessToken);
  const { state, withdrawals } = await listAdminResellerWithdrawalsSafeWithClient(supabase);

  return <AdminResellerWithdrawalListScreen errorCode={params?.error} state={state} withdrawals={withdrawals} />;
}
