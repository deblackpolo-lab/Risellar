import "server-only";

import { createSupabaseUserServerClient } from "@/lib/supabase/server";
import type { RoleOnboardingAdminAccess, RoleOnboardingProfile } from "./role-onboarding";

export async function getRoleOnboardingAdminAccess(input: {
  accessToken: string;
  profile: RoleOnboardingProfile | null;
}): Promise<RoleOnboardingAdminAccess> {
  if (!input.profile) {
    return {
      profile: null,
      hasActiveAdminStaff: false
    };
  }

  const supabase = createSupabaseUserServerClient(input.accessToken);
  const { data, error } = await supabase.rpc("has_admin_role", {
    required_role: "admin"
  });

  if (error) {
    return {
      profile: input.profile,
      hasActiveAdminStaff: false
    };
  }

  return {
    profile: input.profile,
    hasActiveAdminStaff: data === true
  };
}
