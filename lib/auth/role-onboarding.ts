import type { RisellarRole } from "./role-policy";

export type RoleOnboardingRequestKind = "reseller" | "supplier";
export type RoleOnboardingRequestStatus = "draft" | "pending";
export type RoleOnboardingRequestedRole = Extract<RisellarRole, "reseller" | "supplier_owner">;
export type RoleOnboardingSubmissionErrorCode =
  | "UNAUTHENTICATED"
  | "PROFILE_SYNC_REQUIRED"
  | "DUPLICATE_PENDING_REQUEST"
  | "INVALID_REQUESTED_ROLE"
  | "NOT_ALLOWED"
  | "UNKNOWN";

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

export type RoleOnboardingSubmissionPayload = {
  requestedRole: RoleOnboardingRequestedRole;
  businessName: string | null;
  contactPhone: string | null;
  notes: string | null;
};

export type RoleOnboardingRequestConfig = {
  requestKind: RoleOnboardingRequestKind;
  requestedRole: RoleOnboardingRequestedRole;
  pendingHref: string;
};

export type RoleOnboardingSubmissionError = {
  code: RoleOnboardingSubmissionErrorCode;
  message: string;
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

export function getRoleOnboardingRequestConfig(value: string): RoleOnboardingRequestConfig {
  if (!isRoleOnboardingRequestKind(value)) {
    throw new Error("Unsupported role onboarding request type");
  }

  return {
    requestKind: value,
    requestedRole: roleOnboardingTargetRoles[value],
    pendingHref: `${getRoleOnboardingPendingPath(value)}&status=submitted`
  };
}

export function buildRoleOnboardingSubmissionPayload(
  requestKind: string,
  input: {
    businessName?: string | null;
    contactPhone?: string | null;
    notes?: string | null;
  }
): RoleOnboardingSubmissionPayload {
  const config = getRoleOnboardingRequestConfig(requestKind);

  return {
    requestedRole: config.requestedRole,
    businessName: normalizeOptionalText(input.businessName),
    contactPhone: normalizeOptionalText(input.contactPhone),
    notes: normalizeOptionalText(input.notes)
  };
}

export function mapRoleOnboardingRpcError(error: unknown): RoleOnboardingSubmissionError {
  const message = error instanceof Error ? error.message : String(error ?? "");
  const normalized = message.toLowerCase();

  if (message === "UNAUTHENTICATED" || normalized.includes("sign in")) {
    return {
      code: "UNAUTHENTICATED",
      message: "Sign in before submitting a role onboarding request."
    };
  }

  if (
    message === "PROFILE_SYNC_REQUIRED"
    || normalized.includes("failed to create risellar profile")
    || normalized.includes("failed to read risellar profile")
  ) {
    return {
      code: "PROFILE_SYNC_REQUIRED",
      message: "We could not prepare your customer profile. Please try again before submitting."
    };
  }

  if (normalized.includes("pending onboarding request already exists")) {
    return {
      code: "DUPLICATE_PENDING_REQUEST",
      message: "You already have a pending request for this role."
    };
  }

  if (normalized.includes("not eligible for self-service onboarding") || normalized.includes("unsupported role onboarding")) {
    return {
      code: "INVALID_REQUESTED_ROLE",
      message: "That role cannot be requested from this page."
    };
  }

  if (normalized.includes("only customer profiles can request")) {
    return {
      code: "NOT_ALLOWED",
      message: "Only customer profiles can request reseller or supplier access."
    };
  }

  return {
    code: "UNKNOWN",
    message: "We could not submit this request. Please try again."
  };
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
    status: "pending",
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
