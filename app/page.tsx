import Link from "next/link";

export default function HomePage() {
  return (
    <main className="min-h-screen bg-[var(--color-page)] px-6 py-10 text-[var(--color-charcoal)]">
      <div className="mx-auto max-w-3xl rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-[var(--color-surface)] p-8 shadow-[var(--shadow-sm)]">
        <p className="text-sm font-semibold text-[var(--color-primary)]">Risellar Phase 1</p>
        <h1 className="mt-3 text-3xl font-bold">Design foundation shell</h1>
        <p className="mt-4 text-[var(--color-muted)]">
          This project is currently limited to the design-system foundation. No reseller, supplier, customer, admin,
          backend, auth, payment, or storage routes have been built.
        </p>
        <Link
          className="mt-6 inline-flex h-11 items-center rounded-[var(--radius-md)] bg-[var(--color-primary)] px-5 text-sm font-semibold text-white"
          href="/design-system"
        >
          Open design system
        </Link>
      </div>
    </main>
  );
}
