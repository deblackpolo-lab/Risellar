import "server-only";

import { auth } from "@clerk/nextjs/server";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { getRoleOnboardingAdminAccess } from "./admin-access";
import { getCurrentSyncedProfile } from "./profile-sync";
import { getUnauthorizedRoleRedirect } from "./role-redirect";
import {
  canAccessRoute,
  getRoutePolicyForPath,
  getVerifiedRouteAccessProfile,
  isPublicPath
} from "./route-guards";

export async function RouteAccessBoundary({ children }: Readonly<{ children: React.ReactNode }>) {
  const requestHeaders = await headers();
  const pathname = requestHeaders.get("x-risellar-pathname") ?? "/";
  const routePolicy = getRoutePolicyForPath(pathname);

  if (isPublicPath(pathname) || !routePolicy) {
    return children;
  }

  const { getToken, userId } = await auth();

  if (!userId) {
    redirect("/sign-in");
  }

  const profile = await getCurrentSyncedProfile();
  let hasActiveAdminStaff = false;

  if (routePolicy.roles.includes("admin")) {
    const accessToken = await getToken();

    if (accessToken) {
      const adminAccess = await getRoleOnboardingAdminAccess({
        accessToken,
        profile
      });
      hasActiveAdminStaff = adminAccess.hasActiveAdminStaff;
    }
  }

  const routeAccessProfile = getVerifiedRouteAccessProfile({
    primaryRole: profile?.primary_role,
    hasActiveAdminStaff
  });

  if (!canAccessRoute(pathname, routeAccessProfile)) {
    redirect(getUnauthorizedRoleRedirect(routeAccessProfile));
  }

  return children;
}
