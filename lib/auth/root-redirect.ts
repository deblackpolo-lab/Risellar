import { getDefaultRedirect, type OnboardingStatus, type RisellarRole } from "./role-policy";

export type RootRedirectProfile = {
  primaryRole?: string | null;
  accountStatus?: string | null;
  onboardingStatus?: OnboardingStatus | null;
};

export type RootAdminAccess = {
  hasSupportStaff?: boolean;
  hasFinanceStaff?: boolean;
  hasAdmin?: boolean;
};

export type RootRedirectInput = {
  isAuthenticated: boolean;
  profile?: RootRedirectProfile | null;
  adminAccess?: RootAdminAccess | null;
};

const accountStatusRedirects: Record<string, string> = {
  pending: "/edge-cases/account-pending",
  inactive: "/edge-cases/account-restricted",
  restricted: "/edge-cases/account-restricted",
  suspended: "/edge-cases/account-suspended",
  closed: "/edge-cases/account-suspended"
};

function isOnboardingStatus(value: string | null | undefined): value is OnboardingStatus {
  return value === "not_started" || value === "in_progress" || value === "pending_review" || value === "complete";
}

function isWorkspaceRole(value: string | null | undefined): value is Exclude<RisellarRole, "admin"> {
  return value === "customer" || value === "reseller" || value === "supplier_owner" || value === "supplier_inventory_manager";
}

function completeRoleRedirect(role: RisellarRole) {
  if (role === "customer") {
    return "/customer/dashboard";
  }

  if (role === "admin") {
    return "/admin/dashboard";
  }

  return getDefaultRedirect(role, "complete");
}

export function getRootAuthRedirectPath(input: RootRedirectInput) {
  if (!input.isAuthenticated) {
    return "/sign-in";
  }

  const profile = input.profile;

  if (!profile) {
    return "/auth/qa-profile-sync";
  }

  const accountStatus = profile.accountStatus ?? "active";

  if (accountStatus !== "active") {
    return accountStatusRedirects[accountStatus] ?? "/edge-cases/account-restricted";
  }

  // Root role precedence follows the existing route guard: active admin_staff wins over
  // primary_role so mixed QA accounts never fall through to customer-only workflows.
  if (input.adminAccess?.hasSupportStaff || input.adminAccess?.hasFinanceStaff || input.adminAccess?.hasAdmin) {
    return "/admin/dashboard";
  }

  if (!isWorkspaceRole(profile.primaryRole)) {
    return "/sign-in";
  }

  const onboardingStatus = isOnboardingStatus(profile.onboardingStatus) ? profile.onboardingStatus : "complete";

  if (onboardingStatus !== "complete") {
    return getDefaultRedirect(profile.primaryRole, onboardingStatus);
  }

  return completeRoleRedirect(profile.primaryRole);
}
