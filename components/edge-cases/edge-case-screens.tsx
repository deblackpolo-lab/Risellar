import type { ReactNode } from "react";
import Link from "next/link";
import { AlertTriangle, ArrowLeft, ChevronRight, ExternalLink, Sparkles } from "lucide-react";
import { Button, Card, LoadingState, StatusBadge } from "@/components/ui";
import {
  edgeCaseDefinitions,
  formatEdgeCasePath,
  getEdgeCaseDefinition,
  getEdgeCasesByRole,
  requiredEdgeCasePaths,
  type EdgeCaseDefinition,
  type EdgeCaseKind,
  type EdgeCaseRole
} from "@/lib/mock/edge-cases";
import { cn } from "@/lib/utils/cn";

export { edgeCaseDefinitions, getEdgeCaseDefinition, requiredEdgeCasePaths };

const roleLabels: Record<EdgeCaseRole, string> = {
  shared: "Shared / General",
  customer: "Customer",
  reseller: "Reseller",
  supplier: "Supplier",
  admin: "Admin"
};

const kindLabels: Record<EdgeCaseKind, string> = {
  empty: "EmptyState",
  error: "ErrorState",
  loading: "LoadingState",
  "not-found": "NotFoundState",
  offline: "OfflineState",
  permission: "PermissionDeniedState",
  pending: "PendingReviewState",
  restricted: "RestrictedState",
  suspended: "SuspendedState",
  failure: "FailureState",
  success: "SuccessSubmittedState",
  action: "ActionRequiredState",
  financial: "FinancialBlockedState",
  stock: "StockUnavailableState",
  verification: "VerificationState",
  settlement: "SettlementOverdueState",
  commission: "CommissionPendingState",
  delivery: "DeliveryIssueState"
};

const tonePanelClasses = {
  success: "border-[var(--color-success)]/20 bg-[var(--color-success-soft)]",
  warning: "border-[var(--color-warning)]/30 bg-[var(--color-warning-soft)]",
  danger: "border-[var(--color-danger)]/25 bg-[var(--color-danger-soft)]",
  info: "border-[var(--color-info)]/20 bg-[var(--color-info-soft)]",
  neutral: "border-[var(--color-border)] bg-[var(--color-muted-soft)]"
};

const toneIconClasses = {
  success: "bg-[var(--color-success-soft)] text-[var(--color-success)]",
  warning: "bg-[var(--color-warning-soft)] text-[#8A5A00]",
  danger: "bg-[var(--color-danger-soft)] text-[var(--color-danger)]",
  info: "bg-[var(--color-info-soft)] text-[var(--color-info)]",
  neutral: "bg-[var(--color-muted-soft)] text-[var(--color-muted)]"
};

export function EdgeCaseIndexScreen() {
  return (
    <EdgeCasePageShell
      eyebrow="Risellar Phase 14"
      title="Empty States + Edge Cases"
      description="Reusable mock-only states for no data, pending review, restrictions, failed actions, stock problems, settlement blocks, and missing records across Risellar."
    >
      <div className="grid gap-4 lg:grid-cols-4">
        <EdgeCaseStat label="Required routes" value={String(requiredEdgeCasePaths.length)} />
        <EdgeCaseStat label="Reusable variants" value={String(edgeCaseDefinitions.length)} />
        <EdgeCaseStat label="Mock-only actions" value="12+" />
        <EdgeCaseStat label="Backend integrations" value="0" />
      </div>

      <Card className="bg-[var(--color-primary)] text-white">
        <div className="grid gap-4 lg:grid-cols-[1fr_auto] lg:items-center">
          <div>
            <p className="text-sm font-bold uppercase text-white/70">Pattern intent</p>
            <h2 className="mt-2 text-2xl font-bold">Calm, specific, and action-oriented</h2>
            <p className="mt-2 max-w-3xl text-sm leading-6 text-white/80">
              Every state includes a role-aware icon, clear heading, plain Ghana-friendly explanation, status badge, next action,
              and optional financial or operational details.
            </p>
          </div>
          <Sparkles className="h-14 w-14 text-[var(--color-accent)]" aria-hidden />
        </div>
      </Card>

      <EdgeCasePreviewStrip />

      {(["shared", "customer", "reseller", "supplier", "admin"] as const).map((role) => (
        <section key={role} className="space-y-4">
          <div className="flex flex-wrap items-end justify-between gap-3">
            <div>
              <p className="text-sm font-bold uppercase text-[var(--color-primary)]">{roleLabels[role]}</p>
              <h2 className="text-xl font-bold text-[var(--color-charcoal)]">{roleLabels[role]}</h2>
            </div>
            <StatusBadge tone="neutral">{`${getEdgeCasesByRole(role).length} states`}</StatusBadge>
          </div>
          <EdgeCaseGrid states={getEdgeCasesByRole(role)} />
        </section>
      ))}
    </EdgeCasePageShell>
  );
}

export function EdgeCaseRouteScreen({ slug }: { slug?: string[] }) {
  const path = formatEdgeCasePath(slug);

  if (path === "/edge-cases") {
    return <EdgeCaseIndexScreen />;
  }

  const state = getEdgeCaseDefinition(path);

  if (!state) {
    return (
      <EdgeCasePageShell
        eyebrow="Edge case preview"
        title="Preview route not found"
        description="This internal edge-case URL is not mapped yet."
      >
        <NotFoundState
          state={{
            path,
            role: "shared",
            kind: "not-found",
            title: "Record not found",
            description: "This edge-case preview does not exist in the mock catalog.",
            status: "Not Found",
            tone: "neutral",
            icon: AlertTriangle,
            primaryAction: { label: "Return to dashboard" },
            secondaryAction: { label: "Contact support", variant: "outline" }
          }}
        />
      </EdgeCasePageShell>
    );
  }

  return (
    <EdgeCasePageShell
      eyebrow={`${roleLabels[state.role]} edge state`}
      title={state.title}
      description={`${kindLabels[state.kind]} pattern for ${roleLabels[state.role].toLowerCase()} previews.`}
    >
      <div className={cn("grid gap-6", state.role === "admin" ? "xl:grid-cols-[1fr_380px]" : "lg:grid-cols-[minmax(0,520px)_1fr]")}>
        <StateRenderer state={state} />
        <StateActionPanel state={state} />
      </div>
      <RelatedStates currentPath={state.path} role={state.role} />
    </EdgeCasePageShell>
  );
}

export function StateRenderer({ state }: { state: EdgeCaseDefinition }) {
  switch (state.kind) {
    case "loading":
      return <LoadingStateCard state={state} />;
    case "empty":
      return <EmptyState state={state} />;
    case "error":
      return <ErrorState state={state} />;
    case "not-found":
      return <NotFoundState state={state} />;
    case "offline":
      return <OfflineState state={state} />;
    case "permission":
      return <PermissionDeniedState state={state} />;
    case "pending":
      return <PendingReviewState state={state} />;
    case "restricted":
      return <RestrictedState state={state} />;
    case "suspended":
      return <SuspendedState state={state} />;
    case "failure":
      return <FailureState state={state} />;
    case "success":
      return <SuccessSubmittedState state={state} />;
    case "action":
      return <ActionRequiredState state={state} />;
    case "financial":
      return <FinancialBlockedState state={state} />;
    case "stock":
      return <StockUnavailableState state={state} />;
    case "verification":
      return <VerificationState state={state} />;
    case "settlement":
      return <SettlementOverdueState state={state} />;
    case "commission":
      return <CommissionPendingState state={state} />;
    case "delivery":
      return <DeliveryIssueState state={state} />;
    default:
      return <BaseStateCard state={state} />;
  }
}

export function EmptyState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} />;
}

export function ErrorState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis="danger" />;
}

export function LoadingStateCard({ state }: { state: EdgeCaseDefinition }) {
  return (
    <div className="space-y-4">
      <LoadingState label="Loading mock edge-case data..." />
      <BaseStateCard state={state} />
    </div>
  );
}

export function NotFoundState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} />;
}

export function OfflineState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} />;
}

export function RestrictedState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis="danger" />;
}

export function SuspendedState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis="danger" />;
}

export function PendingReviewState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis="warning" />;
}

export function PermissionDeniedState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis="danger" />;
}

export function FailureState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis="danger" />;
}

export function SuccessSubmittedState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis="success" />;
}

export function ActionRequiredState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis={state.tone === "danger" ? "danger" : "warning"} />;
}

export function FinancialBlockedState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis="danger" />;
}

export function StockUnavailableState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis={state.tone === "danger" ? "danger" : "warning"} />;
}

export function VerificationState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis={state.tone === "danger" ? "danger" : "warning"} />;
}

export function SettlementOverdueState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis={state.tone === "danger" ? "danger" : "warning"} />;
}

export function CommissionPendingState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis="warning" />;
}

export function DeliveryIssueState({ state }: { state: EdgeCaseDefinition }) {
  return <BaseStateCard state={state} emphasis={state.tone === "danger" ? "danger" : "warning"} />;
}

export function AccountStatusBanner({ state }: { state: EdgeCaseDefinition }) {
  const Icon = state.icon;

  return (
    <div className={cn("flex items-start gap-3 rounded-[var(--radius-lg)] border p-4", tonePanelClasses[state.tone])}>
      <span className={cn("flex h-10 w-10 shrink-0 items-center justify-center rounded-full", toneIconClasses[state.tone])}>
        <Icon className="h-5 w-5" aria-hidden />
      </span>
      <div>
        <div className="flex flex-wrap items-center gap-2">
          <p className="font-bold text-[var(--color-charcoal)]">{state.status}</p>
          <StatusBadge status={state.status} tone={state.tone} />
        </div>
        <p className="mt-1 text-sm leading-6 text-[var(--color-muted)]">
          Status is visible by label, tone, and icon so the state is not communicated by color alone.
        </p>
      </div>
    </div>
  );
}

export function EdgeCasePreviewCard({ state }: { state: EdgeCaseDefinition }) {
  const Icon = state.icon;

  return (
    <Link
      className="group block rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4 shadow-[var(--shadow-sm)] transition-[var(--transition-fast)] hover:-translate-y-0.5 hover:border-[var(--color-primary)]/30"
      href={state.path}
    >
      <div className="flex items-start justify-between gap-3">
        <span className={cn("flex h-10 w-10 items-center justify-center rounded-full", toneIconClasses[state.tone])}>
          <Icon className="h-5 w-5" aria-hidden />
        </span>
        <ChevronRight className="h-4 w-4 text-[var(--color-muted)] transition group-hover:translate-x-0.5" aria-hidden />
      </div>
      <div className="mt-4 flex flex-wrap gap-2">
        <StatusBadge status={state.status} tone={state.tone} />
        <StatusBadge tone="neutral">{kindLabels[state.kind]}</StatusBadge>
      </div>
      <h3 className="mt-3 text-base font-bold text-[var(--color-charcoal)]">{state.title}</h3>
      <p className="mt-2 line-clamp-3 text-sm leading-6 text-[var(--color-muted)]">{state.description}</p>
    </Link>
  );
}

export function EdgeCaseGrid({ states }: { states: EdgeCaseDefinition[] }) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
      {states.map((state) => (
        <EdgeCasePreviewCard key={state.path} state={state} />
      ))}
    </div>
  );
}

export function StateActionPanel({ state }: { state: EdgeCaseDefinition }) {
  return (
    <div className="space-y-4">
      <AccountStatusBanner state={state} />
      <Card title="Mock action panel">
        <div className="space-y-3">
          <p className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-3 text-sm font-semibold text-[var(--color-charcoal)]">
            Primary mock action: {state.primaryAction.label}
          </p>
          {state.secondaryAction ? (
            <p className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-3 text-sm font-semibold text-[var(--color-charcoal)]">
              Secondary mock action: {state.secondaryAction.label}
            </p>
          ) : null}
          <p className="text-xs leading-5 text-[var(--color-muted)]">
            Actions are preview-only. No backend, auth, payments, storage, or account restriction logic is connected.
          </p>
        </div>
      </Card>
      <Card title="State contract">
        <div className="space-y-3 text-sm">
          <PanelRow label="Role" value={roleLabels[state.role]} />
          <PanelRow label="Component pattern" value={kindLabels[state.kind]} />
          <PanelRow label="Route" value={state.path} />
        </div>
      </Card>
    </div>
  );
}

function BaseStateCard({ emphasis, state }: { emphasis?: "success" | "warning" | "danger"; state: EdgeCaseDefinition }) {
  const Icon = state.icon;
  const panelTone = emphasis ?? state.tone;

  return (
    <section className={cn("rounded-[var(--radius-xl)] border bg-white p-5 shadow-[var(--shadow-sm)] sm:p-6", tonePanelClasses[panelTone])}>
      <div className="mx-auto max-w-md text-center">
        <span className={cn("mx-auto flex h-16 w-16 items-center justify-center rounded-full", toneIconClasses[state.tone])}>
          <Icon className="h-8 w-8" aria-hidden />
        </span>
        <div className="mt-4 flex justify-center">
          <StatusBadge status={state.status} tone={state.tone} />
        </div>
        <p className="mt-4 text-2xl font-bold leading-tight text-[var(--color-charcoal)]">{state.title}</p>
        <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">{state.description}</p>
        {state.helperText ? <p className="mt-3 text-xs font-semibold leading-5 text-[var(--color-primary)]">{state.helperText}</p> : null}
      </div>

      {state.metrics?.length ? (
        <div className="mt-6 grid gap-3 sm:grid-cols-2">
          {state.metrics.map((metric) => (
            <div key={`${metric.label}-${metric.value}`} className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-4">
              <p className="text-xs font-semibold uppercase text-[var(--color-muted)]">{metric.label}</p>
              <div className="mt-2 flex flex-wrap items-center gap-2">
                <p className="text-lg font-bold text-[var(--color-charcoal)]">{metric.value}</p>
                {metric.status ? <StatusBadge status={metric.status} /> : null}
              </div>
            </div>
          ))}
        </div>
      ) : null}

      {state.panelItems?.length ? (
        <div className={cn("mt-6 rounded-[var(--radius-md)] border p-4", tonePanelClasses[state.tone])}>
          <p className="font-bold text-[var(--color-charcoal)]">{state.panelTitle ?? "What this means"}</p>
          <ul className="mt-3 space-y-2 text-sm leading-6 text-[var(--color-muted)]">
            {state.panelItems.map((item) => (
              <li key={item} className="flex gap-2">
                <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-[var(--color-primary)]" aria-hidden />
                <span>{item}</span>
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        <Button type="button" variant={state.primaryAction.variant ?? "primary"}>
          {state.primaryAction.label}
        </Button>
        {state.secondaryAction ? (
          <Button type="button" variant={state.secondaryAction.variant ?? "outline"}>
            {state.secondaryAction.label}
          </Button>
        ) : (
          <Button type="button" variant="ghost">
            Go back
          </Button>
        )}
      </div>
    </section>
  );
}

function EdgeCasePageShell({
  children,
  description,
  eyebrow,
  title
}: {
  children: ReactNode;
  description: string;
  eyebrow: string;
  title: string;
}) {
  return (
    <main className="min-h-screen bg-[var(--color-page)] px-4 py-6 text-[var(--color-charcoal)] sm:px-6 lg:px-10">
      <div className="mx-auto max-w-7xl space-y-6">
        <Link className="inline-flex items-center gap-2 text-sm font-bold text-[var(--color-primary)]" href="/design-system">
          <ArrowLeft className="h-4 w-4" aria-hidden />
          Back to design system
        </Link>
        <header className="rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)] sm:p-6">
          <p className="text-sm font-bold uppercase text-[var(--color-primary)]">{eyebrow}</p>
          <h1 className="mt-2 text-3xl font-bold leading-tight">{title}</h1>
          <p className="mt-3 max-w-3xl text-sm leading-6 text-[var(--color-muted)]">{description}</p>
        </header>
        {children}
      </div>
    </main>
  );
}

function EdgeCaseStat({ label, value }: { label: string; value: string }) {
  return (
    <Card>
      <p className="text-sm font-semibold text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 text-2xl font-bold text-[var(--color-primary)]">{value}</p>
    </Card>
  );
}

function EdgeCasePreviewStrip() {
  const previewPaths = [
    "/edge-cases/customer/empty-cart",
    "/edge-cases/reseller/commission-pending",
    "/edge-cases/supplier/settlement-overdue",
    "/edge-cases/admin/manual-override-warning",
    "/edge-cases/permission-denied",
    "/edge-cases/customer/product-out-of-stock",
    "/edge-cases/customer/support-submitted"
  ];

  return (
    <section className="space-y-4">
      <div>
        <p className="text-sm font-bold uppercase text-[var(--color-primary)]">Design-system additions</p>
        <h2 className="text-xl font-bold">Key state patterns</h2>
      </div>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {previewPaths.map((path) => {
          const state = getEdgeCaseDefinition(path);
          return state ? (
            <div key={path} className="space-y-2">
              <p className="text-xs font-bold uppercase text-[var(--color-primary)]">{previewLabelFor(state)}</p>
              <EdgeCasePreviewCard state={state} />
            </div>
          ) : null;
        })}
      </div>
    </section>
  );
}

function RelatedStates({ currentPath, role }: { currentPath: string; role: EdgeCaseRole }) {
  const related = getEdgeCasesByRole(role)
    .filter((state) => state.path !== currentPath)
    .slice(0, 3);

  return (
    <Card title="Related edge states">
      <div className="grid gap-3 md:grid-cols-3">
        {related.map((state) => (
          <Link
            className="flex items-center justify-between gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm font-semibold hover:border-[var(--color-primary)]/40"
            href={state.path}
            key={state.path}
          >
            <span>{state.title}</span>
            <ExternalLink className="h-4 w-4 text-[var(--color-muted)]" aria-hidden />
          </Link>
        ))}
      </div>
    </Card>
  );
}

function PanelRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-[var(--color-muted)]">{label}</span>
      <span className="text-right font-bold text-[var(--color-charcoal)]">{value}</span>
    </div>
  );
}

function previewLabelFor(state: EdgeCaseDefinition) {
  if (state.path === "/edge-cases/customer/empty-cart") return "Customer empty state";
  if (state.path === "/edge-cases/reseller/commission-pending") return "Reseller commission pending";
  if (state.path === "/edge-cases/supplier/settlement-overdue") return "Supplier settlement overdue";
  if (state.path === "/edge-cases/admin/manual-override-warning") return "Admin manual override warning";
  if (state.path === "/edge-cases/permission-denied") return "Permission denied state";
  if (state.path === "/edge-cases/customer/product-out-of-stock") return "Product out-of-stock state";
  if (state.path === "/edge-cases/customer/support-submitted") return "Support issue submitted";
  return state.title;
}
