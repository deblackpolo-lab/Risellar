import { auth } from "@clerk/nextjs/server";
import { Clock3, ShieldCheck, UserCheck } from "lucide-react";
import { AdminShell } from "@/components/admin/AdminSidebar";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";
import { canReviewRoleOnboardingRequests, type RoleOnboardingReviewErrorCode } from "@/lib/auth/role-onboarding";
import { createSupabaseUserServerClient } from "@/lib/supabase/server";
import { reviewRoleOnboardingRequestAction } from "./actions";

type SearchParams = Promise<{
  error?: RoleOnboardingReviewErrorCode;
  status?: "approved" | "rejected";
}>;

type RoleOnboardingRequestRow = {
  id: string;
  profile_id: string;
  requested_role: "reseller" | "supplier_owner";
  status: "pending" | "approved" | "rejected" | "cancelled";
  business_name: string | null;
  contact_phone: string | null;
  notes: string | null;
  submitted_at: string;
};

type RequesterProfileRow = {
  id: string;
  email: string | null;
  full_name: string | null;
};

type PendingRequestView = RoleOnboardingRequestRow & {
  requesterEmail: string | null;
  requesterName: string | null;
};

const errorMessages: Record<RoleOnboardingReviewErrorCode, string> = {
  AUTH_REQUIRED: "Sign in with an admin account before reviewing onboarding requests.",
  ADMIN_REQUIRED: "Only admin users can review role onboarding requests.",
  INVALID_REVIEW_DECISION: "Review decisions must be approved or rejected.",
  INVALID_REVIEW_REQUEST: "Choose a pending onboarding request before reviewing.",
  RPC_PERMISSION_DENIED: "Your signed-in session is not allowed to review onboarding requests.",
  SUPABASE_AUTH_TOKEN_MISSING: "We could not prepare your secure Supabase admin session. Please sign in again.",
  UNKNOWN: "We could not review this request. Please try again."
};

function formatDate(value: string) {
  return new Intl.DateTimeFormat("en", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

async function loadPendingRequests(accessToken: string) {
  const supabase = createSupabaseUserServerClient(accessToken);
  const { data, error } = await supabase
    .from("role_onboarding_requests")
    .select("id, profile_id, requested_role, status, business_name, contact_phone, notes, submitted_at")
    .eq("status", "pending")
    .order("submitted_at", { ascending: true });

  if (error) {
    return {
      error: error.message,
      requests: [] as PendingRequestView[]
    };
  }

  const requests = (data ?? []) as RoleOnboardingRequestRow[];
  const profileIds = [...new Set(requests.map((request) => request.profile_id))];
  const requesterProfiles = new Map<string, RequesterProfileRow>();
  let profileWarning: string | null = null;

  if (profileIds.length > 0) {
    const { data: profiles, error: profileError } = await supabase
      .from("profiles")
      .select("id, email, full_name")
      .in("id", profileIds);

    if (profileError) {
      profileWarning = profileError.message;
    } else {
      for (const profile of (profiles ?? []) as RequesterProfileRow[]) {
        requesterProfiles.set(profile.id, profile);
      }
    }
  }

  return {
    error: profileWarning,
    requests: requests.map((request) => {
      const requester = requesterProfiles.get(request.profile_id);

      return {
        ...request,
        requesterEmail: requester?.email ?? null,
        requesterName: requester?.full_name ?? null
      };
    })
  };
}

function AdminAccessDenied() {
  return (
    <AdminShell searchPlaceholder="Search admin review queues...">
      <Card title="Admin access required">
        <div className="flex gap-3 text-sm leading-6 text-[var(--color-muted)]">
          <ShieldCheck className="mt-1 h-5 w-5 shrink-0 text-[var(--color-warning)]" aria-hidden />
          <p>
            This queue is available only to admin profiles. Customers, resellers, suppliers, and supplier inventory
            managers cannot review or approve role onboarding requests.
          </p>
        </div>
      </Card>
    </AdminShell>
  );
}

export default async function AdminOnboardingRequestsPage({ searchParams }: { searchParams: SearchParams }) {
  const { error, status } = await searchParams;
  const { getToken, userId } = await auth();

  if (!userId) {
    return <AdminAccessDenied />;
  }

  const profile = await getCurrentSyncedProfile();

  if (!canReviewRoleOnboardingRequests(profile)) {
    return <AdminAccessDenied />;
  }

  const accessToken = await getToken();

  if (!accessToken) {
    return (
      <AdminShell searchPlaceholder="Search admin review queues...">
        <Card title="Secure admin session required">
          <p className="text-sm leading-6 text-[var(--color-muted)]">{errorMessages.SUPABASE_AUTH_TOKEN_MISSING}</p>
        </Card>
      </AdminShell>
    );
  }

  const { requests, error: loadError } = await loadPendingRequests(accessToken);
  const actionMessage = status
    ? `Role onboarding request ${status}. The audited RPC completed without direct profile-role mutation from the UI.`
    : error
      ? errorMessages[error] ?? errorMessages.UNKNOWN
      : null;

  return (
    <AdminShell searchPlaceholder="Search onboarding requests...">
      <section className="rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-6 shadow-[0_14px_36px_rgba(18,28,28,0.05)]">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-primary)]">Admin review</p>
            <h1 className="mt-2 text-2xl font-extrabold tracking-normal text-[var(--color-charcoal)]">
              Role onboarding requests
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--color-muted)]">
              Review pending reseller and supplier owner requests through the audited review RPC. Profile roles are not
              mutated directly from this page.
            </p>
          </div>
          <StatusBadge status={`${requests.length} Pending`} tone={requests.length > 0 ? "warning" : "success"} />
        </div>
      </section>

      {actionMessage ? (
        <div className="rounded-[var(--radius-md)] border border-[var(--color-primary-soft)] bg-[var(--color-primary-subtle)] p-4 text-sm font-semibold text-[var(--color-primary)]">
          {actionMessage}
        </div>
      ) : null}

      {loadError ? (
        <div className="rounded-[var(--radius-md)] border border-[var(--color-warning)]/40 bg-[var(--color-warning-soft)] p-4 text-sm font-semibold text-[#7A5300]">
          Request rows loaded, but requester profile details were limited by the current admin session.
        </div>
      ) : null}

      {requests.length === 0 ? (
        <Card title="No pending requests">
          <div className="flex gap-3 text-sm leading-6 text-[var(--color-muted)]">
            <Clock3 className="mt-1 h-5 w-5 shrink-0 text-[var(--color-primary)]" aria-hidden />
            <p>New reseller or supplier owner requests will appear here after customers submit them.</p>
          </div>
        </Card>
      ) : (
        <div className="space-y-4">
          {requests.map((request) => (
            <Card className="space-y-4" key={request.id}>
              <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <StatusBadge status={request.status} />
                    <StatusBadge status={request.requested_role === "supplier_owner" ? "Supplier owner" : "Reseller"} tone="info" />
                  </div>
                  <h2 className="mt-3 text-lg font-extrabold tracking-normal text-[var(--color-charcoal)]">
                    {request.business_name ?? "Unnamed onboarding request"}
                  </h2>
                  <p className="mt-1 text-sm text-[var(--color-muted)]">
                    Submitted {formatDate(request.submitted_at)}
                  </p>
                </div>
                <div className="flex items-center gap-2 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-page)] px-3 py-2 text-sm">
                  <UserCheck className="h-4 w-4 text-[var(--color-primary)]" aria-hidden />
                  <span className="font-semibold text-[var(--color-charcoal)]">
                    {request.requesterName ?? request.requesterEmail ?? "Requester details unavailable"}
                  </span>
                </div>
              </div>

              <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
                {[
                  ["Requester email", request.requesterEmail ?? "Unavailable"],
                  ["Contact phone", request.contact_phone ?? "Not provided"],
                  ["Requested role", request.requested_role],
                  ["Request id", request.id]
                ].map(([label, value]) => (
                  <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={label}>
                    <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-muted)]">{label}</p>
                    <p className="mt-1 break-words text-sm font-semibold text-[var(--color-charcoal)]">{value}</p>
                  </div>
                ))}
              </div>

              {request.notes ? (
                <p className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-page)] p-3 text-sm leading-6 text-[var(--color-muted)]">
                  {request.notes}
                </p>
              ) : null}

              <form action={reviewRoleOnboardingRequestAction} className="grid gap-3 lg:grid-cols-[1fr_auto] lg:items-end">
                <input name="request_id" type="hidden" value={request.id} />
                <div>
                  <label className="text-sm font-bold" htmlFor={`review-notes-${request.id}`}>
                    Review notes
                  </label>
                  <input
                    className="mt-2 min-h-11 w-full rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 text-sm"
                    id={`review-notes-${request.id}`}
                    name="review_notes"
                    placeholder="Optional audit note"
                    type="text"
                  />
                </div>
                <div className="flex flex-wrap gap-2">
                  <Button name="decision" size="compact" type="submit" value="approved">
                    Approve
                  </Button>
                  <Button name="decision" size="compact" type="submit" value="rejected" variant="outline">
                    Reject
                  </Button>
                </div>
              </form>
            </Card>
          ))}
        </div>
      )}
    </AdminShell>
  );
}
