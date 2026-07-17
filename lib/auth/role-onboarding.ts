import type { RisellarRole } from "./role-policy";

export type RoleOnboardingRequestKind = "reseller" | "supplier";
export type RoleOnboardingRequestStatus = "draft" | "pending_review";
export type RoleOnboardingRequestedRole = Extract<RisellarRole, "reseller" | "supplier_owner">;

export type RoleOnboardingProfile = {
  id: string;
  primary_role: RisellarRole;
};

export type RoleOnboardingRequestInput = {
  requestKind: RoleOnboardingRequestKind;
  businessName?: string | null;
  contactPhone?: string | null;
  notes?: string | null;
};

export type RoleOnboardingRequestDraft = {
  profile_id: string;
  requested_role: RoleOnboardingRequestedRole;
  status: RoleOnboardingRequestStatus;
  business_name: string | null;
  contact_phone: string | null;
  notes: string | null;
};

export const roleOnboardingRequestKinds: RoleOnboardingRequestKind[] = ["reseller", "supplier"];

export const roleOnboardingTargetRoles: Record<RoleOnboardingRequestKind, RoleOnboardingRequestedRole> = {
  reseller: "reseller",
  supplier: "supplier_owner"
};

export function isRoleOnboardingRequestKind(value: string): value is RoleOnboardingRequestKind {
  return roleOnboardingRequestKinds.includes(value as RoleOnboardingRequestKind);
}

export function canRequestRoleOnboarding(profile: RoleOnboardingProfile | null) {
  return profile?.primary_role === "customer";
}

function normalizeOptionalText(value?: string | null) {
  const normalized = value?.trim();

  return normalized ? normalized : null;
}

export function buildRoleOnboardingRequestDraft(
  profile: RoleOnboardingProfile,
  input: RoleOnboardingRequestInput
): RoleOnboardingRequestDraft {
  if (!canRequestRoleOnboarding(profile)) {
    throw new Error("Only customer profiles can request reseller or supplier onboarding");
  }

  if (!isRoleOnboardingRequestKind(input.requestKind)) {
    throw new Error("Unsupported role onboarding request type");
  }

  return {
    profile_id: profile.id,
    requested_role: roleOnboardingTargetRoles[input.requestKind],
    status: "pending_review",
    business_name: normalizeOptionalText(input.businessName),
    contact_phone: normalizeOptionalText(input.contactPhone),
    notes: normalizeOptionalText(input.notes)
  };
}

export function getRoleOnboardingStartPath(requestKind: RoleOnboardingRequestKind) {
  return `/onboarding/${requestKind}`;
}

export function getRoleOnboardingPendingPath(requestKind: RoleOnboardingRequestKind) {
  return `/onboarding/pending?request=${requestKind}`;
}

