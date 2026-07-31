"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  buildMarkWithdrawalPaidPayload,
  mapAdminWithdrawalRpcError
} from "@/lib/admin/withdrawals/admin-reseller-withdrawal";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

const withdrawalsPath = "/admin/withdrawals";

export async function markResellerWithdrawalPaidFormAction(formData: FormData) {
  const withdrawalId = formData.get("withdrawal_id")?.toString();
  let redirectTarget = withdrawalId ? `${withdrawalsPath}/${withdrawalId}?error=UNKNOWN` : `${withdrawalsPath}?error=UNKNOWN`;

  try {
    const { getToken, userId } = await auth();

    if (!userId) {
      throw new Error("AUTH_REQUIRED");
    }

    const accessToken = await getToken();

    if (!accessToken) {
      throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
    }

    const payload = buildMarkWithdrawalPaidPayload({
      withdrawalId,
      payoutReference: formData.get("payout_reference")?.toString(),
      adminNote: formData.get("admin_private_note")?.toString(),
      acknowledgement: formData.get("manual_payout_acknowledgement")?.toString(),
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    const supabase = createSupabaseUserServerClient(accessToken);
    const { error } = await supabase.rpc("admin_mark_reseller_withdrawal_paid", payload);

    if (error) {
      throw error;
    }

    revalidatePath(withdrawalsPath);
    revalidatePath(`${withdrawalsPath}/${payload.p_withdrawal_id}`);
    revalidatePath("/reseller/wallet");
    revalidatePath("/reseller/withdrawals");
    redirectTarget = `${withdrawalsPath}/${payload.p_withdrawal_id}?status=paid`;
  } catch (error) {
    const mapped = mapAdminWithdrawalRpcError(error);
    redirectTarget = withdrawalId ? `${withdrawalsPath}/${withdrawalId}?error=${mapped.code}` : `${withdrawalsPath}?error=${mapped.code}`;
  }

  redirect(redirectTarget);
}
