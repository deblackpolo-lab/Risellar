import {
  protectedRoutePolicies,
  publicRoutePolicies,
  type AuthRoutePolicy,
  type OnboardingStatus,
  type PublicRoutePolicy,
  type RisellarRole
} from "./role-policy";

export type VerifiedProfileAccess = {
  role: RisellarRole;
  onboardingStatus: OnboardingStatus;
};

export type RouteAccessProfileInput = {
  primaryRole?: string | null;
  onboardingStatus?: OnboardingStatus | null;
  hasActiveAdminStaff?: boolean;
};

function normalizePath(pathname: string) {
  if (pathname.length > 1 && pathname.endsWith("/")) {
    return pathname.slice(0, -1);
  }

  return pathname || "/";
}

function routePatternMatches(pattern: string, pathname: string) {
  const normalizedPath = normalizePath(pathname);

  if (pattern === normalizedPath) {
    return true;
  }

  if (pattern.endsWith("/:slug*")) {
    const basePath = pattern.slice(0, -"/:slug*".length);

    return normalizedPath === basePath || normalizedPath.startsWith(`${basePath}/`);
  }

  const patternParts = pattern.split("/").filter(Boolean);
  const pathParts = normalizedPath.split("/").filter(Boolean);

  if (patternParts.length !== pathParts.length) {
    return false;
  }

  return patternParts.every((part, index) => part.startsWith(":") || part === pathParts[index]);
}

function mostSpecificFirst<T extends AuthRoutePolicy | PublicRoutePolicy>(routes: T[]) {
  return [...routes].sort((left, right) => right.pattern.length - left.pattern.length);
}

export function getPublicRoutePolicyForPath(pathname: string) {
  return mostSpecificFirst(publicRoutePolicies).find((policy) => routePatternMatches(policy.pattern, pathname));
}

export function isPublicPath(pathname: string) {
  return Boolean(getPublicRoutePolicyForPath(pathname));
}

export function getRoutePolicyForPath(pathname: string) {
  return mostSpecificFirst(protectedRoutePolicies).find((policy) => routePatternMatches(policy.pattern, pathname));
}

export function canAccessRoute(pathname: string, profile: VerifiedProfileAccess | null) {
  if (isPublicPath(pathname)) {
    return true;
  }

  const policy = getRoutePolicyForPath(pathname);

  if (!policy) {
    return true;
  }

  if (!profile) {
    return false;
  }

  const roleAllowed = policy.roles.includes(profile.role);
  const onboardingAllowed = !policy.onboarding || policy.onboarding.includes(profile.onboardingStatus);

  return roleAllowed && onboardingAllowed;
}

function isRisellarRole(value: string | null | undefined): value is RisellarRole {
  return (
    value === "customer"
    || value === "reseller"
    || value === "supplier_owner"
    || value === "supplier_inventory_manager"
    || value === "admin"
  );
}

export function getVerifiedRouteAccessProfile(input: RouteAccessProfileInput): VerifiedProfileAccess | null {
  const onboardingStatus = input.onboardingStatus ?? "complete";

  if (input.hasActiveAdminStaff) {
    return {
      role: "admin",
      onboardingStatus
    };
  }

  if (!isRisellarRole(input.primaryRole) || input.primaryRole === "admin") {
    return null;
  }

  return {
    role: input.primaryRole,
    onboardingStatus
  };
}
