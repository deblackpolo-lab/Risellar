import Link from "next/link";
import { Clock3 } from "lucide-react";

export default async function RoleOnboardingPendingPage({
  searchParams
}: {
  searchParams: Promise<{ request?: string; status?: string }>;
}) {
  const { request, status } = await searchParams;
  const requestLabel = request === "supplier" ? "supplier" : "reseller";
  const submitted = status === "submitted";

  return (
    <main className="min-h-screen bg-[var(--color-page)] px-4 py-8 text-[var(--color-charcoal)]">
      <section className="mx-auto max-w-2xl rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-6 text-center shadow-[var(--shadow-sm)]">
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-full bg-[var(--color-warning-soft)]">
          <Clock3 className="h-7 w-7 text-[#7A5300]" aria-hidden />
        </div>
        <p className="mt-5 text-xs font-bold uppercase tracking-normal text-[var(--color-primary)]">
          {submitted ? "Request submitted" : "Pending review"}
        </p>
        <h1 className="mt-2 text-2xl font-extrabold tracking-normal">Your {requestLabel} request is not active yet</h1>
        <p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-[var(--color-muted)]">
          {submitted
            ? "Your request was sent to the review queue without changing your customer role. A separate approval step is required before any reseller or supplier access becomes active."
            : "This pending state confirms the request path without changing your customer role. A separate approval step is required before any reseller or supplier access becomes active."}
        </p>
        <Link
          className="mt-6 inline-flex min-h-12 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] px-5 text-sm font-bold text-white"
          href="/onboarding"
        >
          Back to role onboarding
        </Link>
      </section>
    </main>
  );
}
