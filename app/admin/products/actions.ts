"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getRoleOnboardingAdminAccess } from "@/lib/auth/admin-access";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import {
  buildAdminProductReviewPayload,
  canReviewSupplierProducts,
  mapAdminProductReviewRpcError
} from "@/lib/admin/product-approval";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

const productReviewPath = "/admin/products";

export async function reviewSupplierProductAction(formData: FormData) {
  const productId = formData.get("product_id")?.toString();
  let redirectTarget = productId ? `${productReviewPath}/${productId}?error=UNKNOWN` : `${productReviewPath}?error=UNKNOWN`;

  try {
    const { getToken, userId } = await auth();

    if (!userId) {
      throw new Error("AUTH_REQUIRED");
    }

    const profile = await getCurrentSyncedProfile();
    const accessToken = await getToken();

    if (!accessToken) {
      throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
    }

    const adminAccess = await getRoleOnboardingAdminAccess({
      accessToken,
      profile
    });

    if (!canReviewSupplierProducts(adminAccess)) {
      throw new Error("ADMIN_REQUIRED");
    }

    const payload = buildAdminProductReviewPayload({
      productId,
      decision: formData.get("decision")?.toString(),
      reviewNotes: formData.get("review_notes")?.toString()
    });
    const supabase = createSupabaseUserServerClient(accessToken);
    const { error } = await supabase.rpc("review_supplier_product", {
      p_product_id: payload.productId,
      p_decision: payload.decision,
      p_review_notes: payload.reviewNotes
    });

    if (error) {
      throw error;
    }

    revalidatePath(productReviewPath);
    revalidatePath(`${productReviewPath}/${payload.productId}`);
    revalidatePath("/admin/operations/product-approvals");
    redirectTarget = `${productReviewPath}/${payload.productId}?status=${payload.decision}`;
  } catch (error) {
    const mapped = mapAdminProductReviewRpcError(error);
    redirectTarget = productId ? `${productReviewPath}/${productId}?error=${mapped.code}` : `${productReviewPath}?error=${mapped.code}`;
  }

  redirect(redirectTarget);
}
