import { getDefaultRedirect, type OnboardingStatus, type RisellarRole } from "./role-policy";

export type RoleRedirectProfile = {
  role: RisellarRole;
  onboardingStatus: OnboardingStatus;
};

export function getRoleHomePath(profile: RoleRedirectProfile) {
  return getDefaultRedirect(profile.role, profile.onboardingStatus);
}

export function getUnauthorizedRoleRedirect(profile: RoleRedirectProfile | null) {
  if (!profile) {
    return "/sign-in";
  }

  return getRoleHomePath(profile);
}
