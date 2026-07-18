import Link from "next/link";
import { ArrowLeft, CheckCircle2, Store } from "lucide-react";
import { submitResellerRoleOnboardingRequest } from "../actions";

const errorMessages: Record<string, string> = {
  DUPLICATE_PENDING_REQUEST: "You already have a pending reseller request.",
  INVALID_REQUESTED_ROLE: "That role cannot be requested from this page.",
  NOT_ALLOWED: "Only customer profiles can request reseller access.",
  PROFILE_SYNC_REQUIRED: "We could not prepare your customer profile. Please try again.",
  UNAUTHENTICATED: "Sign in before submitting a reseller request.",
  UNKNOWN: "We could not submit this request. Please try again."
};

export default async function ResellerRoleOnboardingPage({
  searchParams
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  const errorMessage = error ? errorMessages[error] ?? errorMessages.UNKNOWN : null;

  return (
    <main className="min-h-screen bg-[var(--color-page)] px-4 py-8 text-[var(--color-charcoal)]">
      <section className="mx-auto max-w-2xl space-y-6">
        <Link className="inline-flex items-center gap-2 text-sm font-semibold text-[var(--color-primary)]" href="/onboarding">
          <ArrowLeft className="h-4 w-4" aria-hidden />
          Role onboarding
        </Link>

        <header className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)]">
          <Store className="h-8 w-8 text-[var(--color-primary)]" aria-hidden />
          <p className="mt-4 text-xs font-bold uppercase tracking-normal text-[var(--color-primary)]">Customer request</p>
          <h1 className="mt-2 text-2xl font-extrabold tracking-normal">Request reseller access</h1>
          <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">
            This foundation keeps you as a customer while preparing a reseller request for a later audited approval workflow.
          </p>
        </header>

        <section className="space-y-3 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-5">
          <h2 className="text-base font-bold">Safe request rules</h2>
          {[
            "No reseller role is assigned from this page.",
            "Admin review and risk checks remain separate.",
            "Selling, wallet, commissions, and shop activation remain blocked until approval."
          ].map((item) => (
            <p className="flex gap-2 text-sm leading-6 text-[var(--color-muted)]" key={item}>
              <CheckCircle2 className="mt-1 h-4 w-4 shrink-0 text-[var(--color-success)]" aria-hidden />
              <span>{item}</span>
            </p>
          ))}
        </section>

        <form action={submitResellerRoleOnboardingRequest} className="space-y-4 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-5">
          <div>
            <label className="text-sm font-bold" htmlFor="business_name">
              Shop or business name
            </label>
            <input
              className="mt-2 min-h-12 w-full rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 text-sm"
              id="business_name"
              name="business_name"
              placeholder="Campus Beauty Picks"
              type="text"
            />
          </div>

          <div>
            <label className="text-sm font-bold" htmlFor="contact_phone">
              Contact phone
            </label>
            <input
              className="mt-2 min-h-12 w-full rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 text-sm"
              id="contact_phone"
              name="contact_phone"
              placeholder="0240000000"
              type="tel"
            />
          </div>

          <div>
            <label className="text-sm font-bold" htmlFor="notes">
              Notes
            </label>
            <textarea
              className="mt-2 min-h-24 w-full rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 py-3 text-sm"
              id="notes"
              name="notes"
              placeholder="Tell the review team how you plan to sell."
            />
          </div>

          {errorMessage ? (
            <p className="rounded-[var(--radius-md)] border border-[var(--color-danger)] bg-[var(--color-danger-soft)] p-3 text-sm font-semibold text-[var(--color-danger)]">
              {errorMessage}
            </p>
          ) : null}

          <button
            className="inline-flex min-h-12 w-full items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] px-4 text-sm font-bold text-white"
            type="submit"
          >
            Submit reseller request
          </button>
        </form>
      </section>
    </main>
  );
}
