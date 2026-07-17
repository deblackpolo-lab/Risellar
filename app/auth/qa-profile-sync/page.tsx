import { auth } from "@clerk/nextjs/server";
import { notFound } from "next/navigation";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";

export default async function AuthQaProfileSyncPage() {
  const isQaRouteEnabled =
    process.env.NODE_ENV === "development" || process.env.RISELLAR_ENABLE_AUTH_QA === "true";

  if (!isQaRouteEnabled) {
    notFound();
  }

  const { userId } = await auth();
  const profile = await getCurrentSyncedProfile();

  return (
    <main style={{ margin: "0 auto", maxWidth: 760, padding: 32, fontFamily: "system-ui, sans-serif" }}>
      <h1>Risellar Auth QA Profile Sync</h1>
      <p>This development-only QA route verifies Clerk sign-in and server-side Supabase profile sync.</p>

      {!userId ? (
        <p>Sign in with a test Clerk account to run profile sync.</p>
      ) : profile ? (
        <dl>
          <dt>Profile row</dt>
          <dd>created or found</dd>

          <dt>Clerk user id stored</dt>
          <dd>{profile.clerk_user_id ? "yes" : "no"}</dd>

          <dt>Email stored</dt>
          <dd>{profile.email ? "yes" : "no"}</dd>

          <dt>Display name stored</dt>
          <dd>{profile.full_name ? "yes" : "no"}</dd>

          <dt>Default role</dt>
          <dd>{profile.primary_role}</dd>

          <dt>Account status</dt>
          <dd>{profile.account_status}</dd>
        </dl>
      ) : (
        <p>No signed-in Clerk user was available for profile sync.</p>
      )}
    </main>
  );
}
