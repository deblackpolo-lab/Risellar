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

export async function getRootAdminDashboardAccess(input: {
  accessToken: string;
  profile: RoleOnboardingProfile | null;
}) {
  if (!input.profile) {
    return {
      profile: null,
      hasSupportStaff: false,
      hasFinanceStaff: false,
      hasAdmin: false,
      hasActiveAdminStaff: false
    };
  }

  const supabase = createSupabaseUserServerClient(input.accessToken);
  const [supportResult, financeResult, adminResult] = await Promise.all([
    supabase.rpc("has_admin_role", { required_role: "support_staff" }),
    supabase.rpc("has_admin_role", { required_role: "finance_staff" }),
    supabase.rpc("has_admin_role", { required_role: "admin" })
  ]);
  const hasSupportStaff = !supportResult.error && supportResult.data === true;
  const hasFinanceStaff = !financeResult.error && financeResult.data === true;
  const hasAdmin = !adminResult.error && adminResult.data === true;

  return {
    profile: input.profile,
    hasSupportStaff,
    hasFinanceStaff,
    hasAdmin,
    hasActiveAdminStaff: hasSupportStaff || hasFinanceStaff || hasAdmin
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
