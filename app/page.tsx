import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { getRootAdminDashboardAccess } from "@/lib/auth/admin-access";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import { getRootAuthRedirectPath } from "@/lib/auth/root-redirect";

export default async function HomePage() {
  const { getToken, userId } = await auth();

  if (!userId) {
    redirect(getRootAuthRedirectPath({ isAuthenticated: false }));
  }

  const profile = await getCurrentSyncedProfile();
  const accessToken = await getToken();
  const adminAccess = accessToken
    ? await getRootAdminDashboardAccess({
        accessToken,
        profile
      })
    : null;

  redirect(
    getRootAuthRedirectPath({
      isAuthenticated: true,
      profile: profile
        ? {
            primaryRole: profile.primary_role,
            accountStatus: profile.account_status
          }
        : null,
      adminAccess
    })
  );
}
