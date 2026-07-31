import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { AdminResellerWithdrawalDetailScreen } from "@/components/admin/admin-reseller-withdrawal-rpc-screens";
import { getAdminResellerWithdrawalSafeWithClient } from "@/lib/admin/withdrawals/admin-reseller-withdrawal";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

export default async function AdminWithdrawalDetailPage({
  params,
  searchParams
}: {
  params: Promise<{ withdrawalId: string }>;
  searchParams?: Promise<{ error?: string; status?: string }>;
}) {
  const [{ withdrawalId }, query] = await Promise.all([params, searchParams]);
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect("/sign-in");
  }

  const accessToken = await getToken();

  if (!accessToken) {
    redirect("/admin/dashboard?error=SUPABASE_AUTH_TOKEN_MISSING");
  }

  const supabase = createSupabaseUserServerClient(accessToken);
  const { withdrawal } = await getAdminResellerWithdrawalSafeWithClient(supabase, withdrawalId);

  return <AdminResellerWithdrawalDetailScreen errorCode={query?.error} success={query?.status === "paid"} withdrawal={withdrawal} />;
}
