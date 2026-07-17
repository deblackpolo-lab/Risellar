import type { RisellarRole } from "./role-policy";

export type SelfAssignableProfileRole = Extract<RisellarRole, "customer">;

export type ClerkIdentitySource = {
  id: string;
  email?: string | null;
  fullName?: string | null;
  firstName?: string | null;
  lastName?: string | null;
  primaryEmailAddress?: {
    emailAddress?: string | null;
  } | null;
};

export type ClerkProfileIdentity = {
  clerkUserId: string;
  email: string;
  fullName?: string;
};

export type ProfileInsert = {
  clerk_user_id: string;
  email: string;
  full_name?: string;
  primary_role: SelfAssignableProfileRole;
};

export type SyncedProfile = {
  id: string;
  clerk_user_id: string;
  email: string;
  full_name: string | null;
  primary_role: string;
  account_status: string;
};

export type ProfileRepository = {
  findByClerkUserId(clerkUserId: string): Promise<SyncedProfile | null>;
  createProfile(profile: ProfileInsert): Promise<SyncedProfile>;
};

const SELF_ASSIGNABLE_PROFILE_ROLES: SelfAssignableProfileRole[] = ["customer"];

export function isSelfAssignableProfileRole(role: string): role is SelfAssignableProfileRole {
  return SELF_ASSIGNABLE_PROFILE_ROLES.includes(role as SelfAssignableProfileRole);
}

export function normalizeEmail(email: string) {
  const normalized = email.trim().toLowerCase();

  if (!normalized) {
    throw new Error("Clerk user email is required for Risellar profile sync");
  }

  return normalized;
}

export function normalizeClerkIdentity(source: ClerkIdentitySource): ClerkProfileIdentity {
  const email = source.email ?? source.primaryEmailAddress?.emailAddress;

  if (!source.id) {
    throw new Error("Clerk user id is required for Risellar profile sync");
  }

  if (!email) {
    throw new Error("Clerk user email is required for Risellar profile sync");
  }

  const joinedName = [source.firstName, source.lastName]
    .map((part) => part?.trim())
    .filter(Boolean)
    .join(" ");
  const fullName = source.fullName?.trim() || joinedName || undefined;

  return {
    clerkUserId: source.id,
    email: normalizeEmail(email),
    ...(fullName ? { fullName } : {})
  };
}

export function buildProfileInsert(
  identity: ClerkProfileIdentity & { requestedRole?: string | null }
): ProfileInsert {
  const requestedRole = identity.requestedRole ?? "customer";

  if (!isSelfAssignableProfileRole(requestedRole)) {
    throw new Error("Cannot self-assign privileged role during profile sync");
  }

  return {
    clerk_user_id: identity.clerkUserId,
    email: normalizeEmail(identity.email),
    ...(identity.fullName?.trim() ? { full_name: identity.fullName.trim() } : {}),
    primary_role: requestedRole
  };
}

export async function findOrCreateProfileForClerkIdentity(
  identity: ClerkProfileIdentity & { requestedRole?: string | null },
  repository: ProfileRepository
) {
  const existingProfile = await repository.findByClerkUserId(identity.clerkUserId);

  if (existingProfile) {
    return existingProfile;
  }

  return repository.createProfile(buildProfileInsert(identity));
}
