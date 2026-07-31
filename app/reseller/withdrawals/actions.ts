"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  buildRequestWithdrawalPayload,
  buildSavePayoutAccountPayload,
  mapWithdrawalRpcError
} from "@/lib/reseller/withdrawals/reseller-withdrawal";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

const withdrawalsPath = "/reseller/withdrawals";

export async function saveResellerPayoutAccountFormAction(formData: FormData) {
  let redirectTarget = `${withdrawalsPath}?error=UNKNOWN`;

  try {
    const { getToken, userId } = await auth();

    if (!userId) {
      throw new Error("AUTH_REQUIRED");
    }

    const accessToken = await getToken();

    if (!accessToken) {
      throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
    }

    const payload = buildSavePayoutAccountPayload({
      accountName: formData.get("account_name")?.toString(),
      mobileMoneyNetwork: formData.get("mobile_money_network")?.toString(),
      phoneNumber: formData.get("phone_number")?.toString(),
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    const supabase = createSupabaseUserServerClient(accessToken);
    const { error } = await supabase.rpc("reseller_upsert_payout_account", payload);

    if (error) {
      throw error;
    }

    revalidatePath(withdrawalsPath);
    revalidatePath("/reseller/wallet");
    redirectTarget = `${withdrawalsPath}?status=account-saved`;
  } catch (error) {
    const mapped = mapWithdrawalRpcError(error);
    redirectTarget = `${withdrawalsPath}?error=${mapped.code}`;
  }

  redirect(redirectTarget);
}

export async function requestResellerWithdrawalFormAction(formData: FormData) {
  let redirectTarget = `${withdrawalsPath}?error=UNKNOWN`;

  try {
    const { getToken, userId } = await auth();

    if (!userId) {
      throw new Error("AUTH_REQUIRED");
    }

    const accessToken = await getToken();

    if (!accessToken) {
      throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
    }

    const payload = buildRequestWithdrawalPayload({
      amount: formData.get("amount")?.toString(),
      payoutAccountId: formData.get("payout_account_id")?.toString(),
      acknowledgement: formData.get("withdrawal_acknowledgement")?.toString(),
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    const supabase = createSupabaseUserServerClient(accessToken);
    const { error } = await supabase.rpc("reseller_request_withdrawal", payload);

    if (error) {
      throw error;
    }

    revalidatePath(withdrawalsPath);
    revalidatePath("/reseller/wallet");
    redirectTarget = `${withdrawalsPath}?status=requested`;
  } catch (error) {
    const mapped = mapWithdrawalRpcError(error);
    redirectTarget = `${withdrawalsPath}?error=${mapped.code}`;
  }

  redirect(redirectTarget);
}
