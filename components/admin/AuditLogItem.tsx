export function AuditLogItem({ action = "Settlement proof uploaded" }: { action?: string }) {
  return (
    <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-3 text-sm">
      <div className="font-semibold">{action}</div>
      <div className="mt-1 text-xs text-[var(--color-muted)]">Today, 10:22 AM · Admin queue placeholder</div>
    </div>
  );
}
