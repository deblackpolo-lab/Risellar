"use server";

import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import {
  buildRoleOnboardingReviewPayload,
  canReviewRoleOnboardingRequests,
  mapRoleOnboardingReviewRpcError
} from "@/lib/auth/role-onboarding";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

const reviewPath = "/admin/onboarding-requests";

export async function reviewRoleOnboardingRequestAction(formData: FormData) {
  let redirectTarget = `${reviewPath}?error=UNKNOWN`;

  try {
    const { getToken, userId } = await auth();

    if (!userId) {
      throw new Error("AUTH_REQUIRED");
    }

    const profile = await getCurrentSyncedProfile();

    if (!canReviewRoleOnboardingRequests(profile)) {
      throw new Error("ADMIN_REQUIRED");
    }

    const accessToken = await getToken();

    if (!accessToken) {
      throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
    }

    const payload = buildRoleOnboardingReviewPayload({
      requestId: formData.get("request_id")?.toString(),
      decision: formData.get("decision")?.toString(),
      reviewNotes: formData.get("review_notes")?.toString()
    });
    const supabase = createSupabaseUserServerClient(accessToken);
    const { error } = await supabase.rpc("review_role_onboarding_request", {
      p_request_id: payload.requestId,
      p_decision: payload.decision,
      p_review_notes: payload.reviewNotes
    });

    if (error) {
      throw error;
    }

    revalidatePath(reviewPath);
    redirectTarget = `${reviewPath}?status=${payload.decision}`;
  } catch (error) {
    const mapped = mapRoleOnboardingReviewRpcError(error);
    redirectTarget = `${reviewPath}?error=${mapped.code}`;
  }

  redirect(redirectTarget);
}
