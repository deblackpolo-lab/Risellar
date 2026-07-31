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

export async function getFinanceSettlementAdminAccess(input: {
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
  const { data, error } = await supabase.rpc("admin_can_verify_supplier_settlements");

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

export async function getFinanceDashboardAdminAccess(input: {
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
    required_role: "finance_staff"
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

export async function getFinanceWithdrawalAdminAccess(input: {
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
  const { data, error } = await supabase.rpc("admin_can_manage_reseller_withdrawals");

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
