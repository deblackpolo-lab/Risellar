"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  buildVerifySupplierSettlementPayload,
  mapAdminSettlementRpcError
} from "@/lib/admin/settlements/admin-supplier-settlement";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

const settlementsPath = "/admin/settlements";

export async function verifySupplierSettlementFormAction(formData: FormData) {
  const orderId = formData.get("order_id")?.toString();
  let redirectTarget = orderId ? `${settlementsPath}/${orderId}?error=UNKNOWN` : `${settlementsPath}?error=UNKNOWN`;

  try {
    const { getToken, userId } = await auth();

    if (!userId) {
      throw new Error("AUTH_REQUIRED");
    }

    const accessToken = await getToken();

    if (!accessToken) {
      throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
    }

    const payload = buildVerifySupplierSettlementPayload({
      orderId,
      settlementReference: formData.get("settlement_reference")?.toString(),
      adminNote: formData.get("admin_note")?.toString(),
      acknowledgement: formData.get("settlement_acknowledgement")?.toString(),
      idempotencyKey: formData.get("idempotency_key")?.toString()
    });

    const supabase = createSupabaseUserServerClient(accessToken);
    const { error } = await supabase.rpc("admin_verify_supplier_settlement", payload);

    if (error) {
      throw error;
    }

    revalidatePath(settlementsPath);
    revalidatePath(`${settlementsPath}/${payload.p_order_id}`);
    revalidatePath("/admin/commissions");
    revalidatePath("/reseller/wallet");
    revalidatePath("/customer/orders");
    revalidatePath("/supplier/orders");
    redirectTarget = `${settlementsPath}/${payload.p_order_id}?status=verified`;
  } catch (error) {
    const mapped = mapAdminSettlementRpcError(error);
    redirectTarget = orderId ? `${settlementsPath}/${orderId}?error=${mapped.code}` : `${settlementsPath}?error=${mapped.code}`;
  }

  redirect(redirectTarget);
}
