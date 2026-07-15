export function LoadingState({ label = "Loading Risellar data..." }: { label?: string }) {
  return (
    <div className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)]">
      <div className="h-4 w-32 animate-pulse rounded bg-[var(--color-muted-soft)]" />
      <div className="mt-4 h-20 animate-pulse rounded-[var(--radius-md)] bg-[var(--color-muted-soft)]" />
      <p className="mt-3 text-sm text-[var(--color-muted)]">{label}</p>
    </div>
  );
}
