"use server";

import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import {
  buildRoleOnboardingSubmissionPayload,
  getRoleOnboardingRequestConfig,
  mapRoleOnboardingRpcError,
  type RoleOnboardingRequestKind
} from "@/lib/auth/role-onboarding";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";

async function submitRoleOnboardingRequest(requestKind: RoleOnboardingRequestKind, formData: FormData) {
  const config = getRoleOnboardingRequestConfig(requestKind);

  try {
    const { getToken, userId } = await auth();

    if (!userId) {
      throw new Error("UNAUTHENTICATED");
    }

    await getCurrentSyncedProfile();

    const accessToken = await getToken({ template: "supabase" });

    if (!accessToken) {
      throw new Error("PROFILE_SYNC_REQUIRED");
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
      throw new Error(error.message);
    }
  } catch (error) {
    const mapped = mapRoleOnboardingRpcError(error);
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

