import Link from "next/link";
import { ShieldCheck, Store, Truck } from "lucide-react";

const options = [
  {
    href: "/onboarding/reseller",
    icon: Store,
    title: "Request reseller access",
    body: "Start a reseller request without changing your customer role. Approval and shop activation stay separate."
  },
  {
    href: "/onboarding/supplier",
    icon: Truck,
    title: "Request supplier access",
    body: "Prepare a supplier owner request for review. Supplier approval and product activation stay separate."
  }
];

export default function RoleOnboardingPage() {
  return (
    <main className="min-h-screen bg-[var(--color-page)] px-4 py-8 text-[var(--color-charcoal)]">
      <section className="mx-auto max-w-3xl space-y-6">
        <header className="space-y-3">
          <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-primary)]">Role onboarding</p>
          <h1 className="text-3xl font-extrabold tracking-normal">Choose what you want to request</h1>
          <p className="max-w-2xl text-sm leading-6 text-[var(--color-muted)]">
            Every account starts as a customer. Reseller and supplier access require a request path and later approval before any workspace is activated.
          </p>
        </header>

        <div className="grid gap-4 md:grid-cols-2">
          {options.map((option) => {
            const Icon = option.icon;

            return (
              <Link
                className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)] transition hover:border-[var(--color-primary-soft)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-soft)]"
                href={option.href}
                key={option.href}
              >
                <Icon className="h-7 w-7 text-[var(--color-primary)]" aria-hidden />
                <h2 className="mt-4 text-lg font-bold">{option.title}</h2>
                <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">{option.body}</p>
              </Link>
            );
          })}
        </div>

        <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-4 text-sm leading-6 text-[var(--color-muted)]">
          <ShieldCheck className="mr-2 inline h-4 w-4 text-[var(--color-success)]" aria-hidden />
          Request pages do not change your role. A trusted backend approval step is still required before reseller or supplier access becomes active.
        </div>
      </section>
    </main>
  );
}

