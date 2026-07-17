import Link from "next/link";
import { ArrowLeft, CheckCircle2, Truck } from "lucide-react";

export default function SupplierRoleOnboardingPage() {
  return (
    <main className="min-h-screen bg-[var(--color-page)] px-4 py-8 text-[var(--color-charcoal)]">
      <section className="mx-auto max-w-2xl space-y-6">
        <Link className="inline-flex items-center gap-2 text-sm font-semibold text-[var(--color-primary)]" href="/onboarding">
          <ArrowLeft className="h-4 w-4" aria-hidden />
          Role onboarding
        </Link>

        <header className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)]">
          <Truck className="h-8 w-8 text-[var(--color-primary)]" aria-hidden />
          <p className="mt-4 text-xs font-bold uppercase tracking-normal text-[var(--color-primary)]">Customer request</p>
          <h1 className="mt-2 text-2xl font-extrabold tracking-normal">Request supplier access</h1>
          <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">
            This foundation prepares a supplier owner request without granting supplier workspace access or product activation.
          </p>
        </header>

        <section className="space-y-3 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-5">
          <h2 className="text-base font-bold">Safe request rules</h2>
          {[
            "No supplier owner role is assigned from this page.",
            "Business verification and admin approval remain separate.",
            "Products, stock, settlements, and supplier orders remain disconnected from live data."
          ].map((item) => (
            <p className="flex gap-2 text-sm leading-6 text-[var(--color-muted)]" key={item}>
              <CheckCircle2 className="mt-1 h-4 w-4 shrink-0 text-[var(--color-success)]" aria-hidden />
              <span>{item}</span>
            </p>
          ))}
        </section>

        <Link
          className="inline-flex min-h-12 w-full items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] px-4 text-sm font-bold text-white"
          href="/onboarding/pending?request=supplier"
        >
          Preview supplier request pending state
        </Link>
      </section>
    </main>
  );
}

