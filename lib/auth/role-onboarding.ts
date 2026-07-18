import type { RisellarRole } from "./role-policy";

export type RoleOnboardingRequestKind = "reseller" | "supplier";
export type RoleOnboardingRequestStatus = "draft" | "pending";
export type RoleOnboardingRequestedRole = Extract<RisellarRole, "reseller" | "supplier_owner">;
export type RoleOnboardingSubmissionErrorCode =
  | "AUTH_REQUIRED"
  | "PROFILE_SYNC_FAILED"
  | "PROFILE_NOT_FOUND"
  | "DUPLICATE_PENDING_REQUEST"
  | "INVALID_ROLE"
  | "RPC_PERMISSION_DENIED"
  | "RPC_VALIDATION_FAILED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
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

export type RoleOnboardingSafeErrorMetadata = {
  code: RoleOnboardingSubmissionErrorCode;
  errorCode: string | null;
  messageSummary: string;
  rpcName: "submit_role_onboarding_request";
  hasClerkUser: boolean;
  profileSyncSucceeded: boolean;
  hasSupabaseToken: boolean;
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

function getErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  if (typeof error === "object" && error !== null && "message" in error) {
    const message = (error as { message?: unknown }).message;

    if (typeof message === "string") {
      return message;
    }
  }

  return String(error ?? "");
}

function getErrorCode(error: unknown) {
  if (typeof error === "object" && error !== null && "code" in error) {
    const code = (error as { code?: unknown }).code;

    if (typeof code === "string") {
      return code;
    }
  }

  return null;
}

export function mapRoleOnboardingRpcError(error: unknown): RoleOnboardingSubmissionError {
  const message = getErrorMessage(error);
  const normalized = message.toLowerCase();
  const errorCode = getErrorCode(error);

  if (message === "AUTH_REQUIRED" || message === "UNAUTHENTICATED" || normalized.includes("sign in")) {
    return {
      code: "AUTH_REQUIRED",
      message: "Sign in before submitting a role onboarding request."
    };
  }

  if (
    message === "SUPABASE_AUTH_TOKEN_MISSING"
    || normalized.includes("missing supabase user access token")
    || (errorCode === "api_response_error" && normalized.includes("not found"))
  ) {
    return {
      code: "SUPABASE_AUTH_TOKEN_MISSING",
      message: "We could not prepare your secure Supabase session. Please sign in again."
    };
  }

  if (
    message === "PROFILE_SYNC_FAILED"
    || message === "PROFILE_SYNC_REQUIRED"
    || normalized.includes("failed to create risellar profile")
    || normalized.includes("failed to read risellar profile")
  ) {
    return {
      code: "PROFILE_SYNC_FAILED",
      message: "We could not prepare your customer profile. Please try again before submitting."
    };
  }

  if (
    normalized.includes("authenticated active profile is required")
    || normalized.includes("profile is required to submit role onboarding requests")
  ) {
    return {
      code: "PROFILE_NOT_FOUND",
      message: "We could not match your signed-in user to an active Risellar customer profile."
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
      code: "INVALID_ROLE",
      message: "That role cannot be requested from this page."
    };
  }

  if (normalized.includes("only customer profiles can request")) {
    return {
      code: "RPC_VALIDATION_FAILED",
      message: "Only customer profiles can request reseller or supplier access."
    };
  }

  if (errorCode === "42501" || normalized.includes("permission denied")) {
    return {
      code: "RPC_PERMISSION_DENIED",
      message: "Your signed-in session is not allowed to submit this onboarding request yet."
    };
  }

  if (
    errorCode === "22P02"
    || normalized.includes("invalid input value")
    || normalized.includes("violates check constraint")
  ) {
    return {
      code: "RPC_VALIDATION_FAILED",
      message: "The onboarding request failed validation."
    };
  }

  return {
    code: "UNKNOWN",
    message: "We could not submit this request. Please try again."
  };
}

export function buildRoleOnboardingSafeErrorMetadata(input: {
  error: unknown;
  hasClerkUser: boolean;
  profileSyncSucceeded: boolean;
  hasSupabaseToken: boolean;
}): RoleOnboardingSafeErrorMetadata {
  const mapped = mapRoleOnboardingRpcError(input.error);
  const message = getErrorMessage(input.error).replace(/\s+/g, " ").trim();

  return {
    code: mapped.code,
    errorCode: getErrorCode(input.error),
    messageSummary: message.slice(0, 180),
    rpcName: "submit_role_onboarding_request",
    hasClerkUser: input.hasClerkUser,
    profileSyncSucceeded: input.profileSyncSucceeded,
    hasSupabaseToken: input.hasSupabaseToken
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
