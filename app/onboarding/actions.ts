"use server";

import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import {
  buildRoleOnboardingSafeErrorMetadata,
  buildRoleOnboardingSubmissionPayload,
  getRoleOnboardingRequestConfig,
  mapRoleOnboardingRpcError,
  type RoleOnboardingRequestKind
} from "@/lib/auth/role-onboarding";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

async function submitRoleOnboardingRequest(requestKind: RoleOnboardingRequestKind, formData: FormData) {
  const config = getRoleOnboardingRequestConfig(requestKind);
  let hasClerkUser = false;
  let profileSyncSucceeded = false;
  let hasSupabaseToken = false;

  try {
    const { getToken, userId } = await auth();
    hasClerkUser = Boolean(userId);

    if (!userId) {
      throw new Error("AUTH_REQUIRED");
    }

    const profile = await getCurrentSyncedProfile();
    profileSyncSucceeded = Boolean(profile);

    if (!profile) {
      throw new Error("PROFILE_SYNC_FAILED");
    }

    const accessToken = await getToken({ template: "supabase" });
    hasSupabaseToken = Boolean(accessToken);

    if (!accessToken) {
      throw new Error("SUPABASE_AUTH_TOKEN_MISSING");
    }

    const payload = buildRoleOnboardingSubmissionPayload(requestKind, {
      businessName: formData.get("business_name")?.toString(),
      contactPhone: formData.get("contact_phone")?.toString(),
      notes: formData.get("notes")?.toString()
    });
    const supabase = createSupabaseUserServerClient(accessToken);
    const { error } = await supabase.rpc("submit_role_onboarding_request", {
      p_requested_role: payload.requestedRole,
      p_business_name: payload.businessName,
      p_contact_phone: payload.contactPhone,
      p_notes: payload.notes
    });

    if (error) {
      throw error;
    }
  } catch (error) {
    const mapped = mapRoleOnboardingRpcError(error);

    if (process.env.NODE_ENV === "development") {
      console.warn(
        "Role onboarding submit failed",
        buildRoleOnboardingSafeErrorMetadata({
          error,
          hasClerkUser,
          profileSyncSucceeded,
          hasSupabaseToken
        })
      );
    }

    redirect(`${getRoleOnboardingRequestConfig(requestKind).requestKind === "supplier" ? "/onboarding/supplier" : "/onboarding/reseller"}?error=${mapped.code}`);
  }

  redirect(config.pendingHref);
}

export async function submitResellerRoleOnboardingRequest(formData: FormData) {
  await submitRoleOnboardingRequest("reseller", formData);
}

export async function submitSupplierRoleOnboardingRequest(formData: FormData) {
  await submitRoleOnboardingRequest("supplier", formData);
}
