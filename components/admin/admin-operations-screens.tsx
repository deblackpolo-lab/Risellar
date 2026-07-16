import Link from "next/link";
import { AdminShell } from "@/components/admin/AdminSidebar";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";
import {
  adminOperationQueues,
  auditLogs,
  getAdminOperationItem,
  getAdminOperationQueue,
  getAdminRiskEntities,
  getAdminRiskEntity,
  manualOverrideExamples,
  operationsMetrics,
  riskEvents,
  whatsappTemplates,
  type AdminOperationQueue,
  type Priority,
  type RiskEntityType
} from "@/lib/mock/admin-operations";

const priorityTone: Record<Priority, "neutral" | "info" | "warning" | "danger"> = {
  Low: "neutral",
  Medium: "info",
  High: "warning",
  Critical: "danger"
};

function PageHeader({ title, eyebrow, children }: { title: string; eyebrow: string; children?: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)] lg:flex-row lg:items-center lg:justify-between">
      <div>
        <p className="text-xs font-bold uppercase tracking-[0.08em] text-[var(--color-primary)]">{eyebrow}</p>
        <h1 className="mt-1 text-2xl font-bold">{title}</h1>
      </div>
      {children}
    </div>
  );
}

function PriorityBadge({ priority }: { priority: Priority }) {
  return <StatusBadge tone={priorityTone[priority]}>{priority}</StatusBadge>;
}

function AssignmentBadge({ admin }: { admin: string }) {
  return <span className="rounded-full border border-[var(--color-border)] bg-[var(--color-muted-soft)] px-3 py-1 text-xs font-bold text-[var(--color-muted)]">{admin}</span>;
}

function DataTable({ columns, rows }: { columns: string[]; rows: React.ReactNode[][] }) {
  return (
    <div className="overflow-x-auto rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white shadow-[var(--shadow-sm)]">
      <table className="min-w-[980px] w-full text-left text-sm">
        <thead className="bg-[var(--color-muted-soft)] text-xs uppercase text-[var(--color-muted)]">
          <tr>{columns.map((column) => <th className="px-4 py-3 font-bold" key={column}>{column}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr className="border-t border-[var(--color-border)] hover:bg-[var(--color-primary-subtle)]" key={rowIndex}>
              {row.map((cell, cellIndex) => <td className="px-4 py-3 align-top" key={cellIndex}>{cell}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function QueueCard({ queue }: { queue: AdminOperationQueue }) {
  return (
    <Link className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)] transition hover:border-[var(--color-primary)] hover:bg-[var(--color-primary-subtle)]" href={`/admin/operations/${queue.slug}`}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm text-[var(--color-muted)]">{queue.title}</p>
      <p className="mt-2 text-3xl font-bold">{queue.count} items</p>
        </div>
        <PriorityBadge priority={queue.priority} />
      </div>
      <p className="mt-3 text-xs font-semibold text-[var(--color-primary)]">{queue.summary}</p>
    </Link>
  );
}

function QueueHealthIndicators() {
  return (
    <Card title="Queue health indicators">
      <div className="grid gap-3 md:grid-cols-4">
        {["SLA healthy", "3 queues urgent", "6 items overdue", "12 assigned to me"].map((item) => (
          <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm font-bold" key={item}>{item}</div>
        ))}
      </div>
    </Card>
  );
}

function QueueTable({ queue }: { queue: AdminOperationQueue }) {
  return (
    <DataTable
      columns={["Queue ID", "Priority", "Status", "Related Entity", "Age", "Assigned Admin", "Due Time", "Recommended Action", "Actions"]}
      rows={queue.items.map((item) => [
        item.id,
        <PriorityBadge key={`${item.id}-priority`} priority={item.priority} />,
        <StatusBadge key={`${item.id}-status`} status={item.status} />,
        item.relatedEntity,
        item.age,
        <AssignmentBadge admin={item.assignedAdmin} key={`${item.id}-admin`} />,
        item.dueTime,
        item.recommendedAction,
        <div className="flex flex-wrap gap-2" key={`${item.id}-actions`}>
          {queue.actions.map((action) => (
            <Button disabled={action === "Release Commission"} key={action} size="table-action" type="button" variant={action.includes("Restrict") || action === "Reject" ? "danger" : "outline"}>
              {action}
            </Button>
          ))}
          <Link className="inline-flex h-8 items-center rounded-[var(--radius-md)] bg-[var(--color-primary)] px-3 text-xs font-bold text-white" href={item.href ?? `/admin/operations/${queue.slug}/${item.id.toLowerCase()}`}>
            View Detail {item.id.replace(/^DLQ-|^STL-|^DSP-|^COM-|^PRD-|^SUP-APP-|^WDL-|^FD-|^STK-|^PROMO-|^PREP-|^SUP-AVL-/, "")}
          </Link>
        </div>
      ])}
    />
  );
}

function MetadataCard({ title, rows }: { title: string; rows: Array<[string, string]> }) {
  return (
    <Card title={title}>
      <dl className="grid gap-3 md:grid-cols-2">
        {rows.map(([label, value]) => (
          <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={label}>
            <dt className="text-xs font-bold uppercase text-[var(--color-muted)]">{label}</dt>
            <dd className="mt-1 font-bold">{value}</dd>
          </div>
        ))}
      </dl>
    </Card>
  );
}

function WhatsAppTemplateCard({ type = "customer confirmation" }: { type?: string }) {
  const template = whatsappTemplates.find((item) => item.type === type) ?? whatsappTemplates[0];
  return (
    <Card title="WhatsApp template">
      <p className="font-bold">{template.title}</p>
      <p className="mt-3 rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] p-3 text-sm leading-6">{template.body}</p>
      <div className="mt-4 flex flex-wrap gap-2">
        <Button type="button" variant="outline">Copy Template</Button>
        <Button type="button" variant="ghost">Preview Variables</Button>
      </div>
    </Card>
  );
}

function AuditPreview() {
  return (
    <Card title="Audit log preview">
      <div className="space-y-3">
        {auditLogs.slice(0, 3).map((log) => (
          <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={`${log.timestamp}-${log.action}`}>
            <p className="text-sm font-bold">{log.action}</p>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{log.timestamp} • {log.actor} • {log.entity}</p>
          </div>
        ))}
      </div>
    </Card>
  );
}

export function AdminOperationsDashboard() {
  return (
    <AdminShell active="Operations">
      <PageHeader eyebrow="Real-time operations control center" title="Admin Operations Hub">
        <StatusBadge status="Mock Only" />
      </PageHeader>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-6">
        {operationsMetrics.map((metric) => (
          <Card key={metric.label}>
            <p className="text-sm text-[var(--color-muted)]">{metric.label}</p>
            <p className="mt-2 text-3xl font-bold">{metric.value}</p>
            <p className="mt-1 text-xs font-bold text-[var(--color-primary)]">{metric.priority} priority</p>
          </Card>
        ))}
      </div>
      <div className="grid gap-5 xl:grid-cols-[1fr_320px]">
        <Card title="Operations overview">
          <div className="mb-4 flex flex-wrap gap-2">
            {["Urgent", "Due Today", "Overdue", "High Risk", "Assigned to Me"].map((filter) => (
              <Button key={filter} size="table-action" type="button" variant={filter === "Urgent" ? "soft-warning" : "outline"}>{filter}</Button>
            ))}
          </div>
          <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {adminOperationQueues.map((queue) => <QueueCard key={queue.slug} queue={queue} />)}
          </div>
        </Card>
        <div className="space-y-5">
          <Card title="Urgent alerts">
            <div className="space-y-3 text-sm">
              <div className="rounded-[var(--radius-md)] bg-[var(--color-danger-soft)] p-3 text-[var(--color-danger)]">
                <p className="font-bold">Overdue settlement warning</p>
                <p className="mt-1 text-xs font-semibold">KNUST Gadgets has 2 days overdue.</p>
              </div>
              <p className="rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 font-bold text-[#8A5A00]">Customer confirmation deadline approaching for Nana Yaw.</p>
              <div className="rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] p-3 text-[var(--color-primary)]">
                <p className="font-bold">Mock admin user assignment status</p>
                <p className="mt-1 text-xs font-semibold">12 assigned to Kwame Admin.</p>
              </div>
            </div>
          </Card>
          <Card title="Today’s workload">
            <p className="text-sm text-[var(--color-muted)]">24 due today, 6 overdue, 10 high risk, 7 disputes.</p>
          </Card>
        </div>
      </div>
      <QueueHealthIndicators />
      <div className="grid gap-5 xl:grid-cols-3">
        <Card title="Delivery quote pending summary"><p className="text-3xl font-bold">9 quotes</p><p className="text-sm text-[var(--color-muted)]">Quotes need customer approval.</p></Card>
        <Card title="Commission release summary"><p className="text-3xl font-bold">14 commissions</p><p className="text-sm text-[var(--color-muted)]">All are placeholders until settlement verification exists.</p></Card>
        <Card title="Product/supplier approval summary"><p className="text-3xl font-bold">17</p><p className="text-sm text-[var(--color-muted)]">12 products and 5 suppliers await review.</p></Card>
      </div>
    </AdminShell>
  );
}

export function AdminOperationsQueueScreen({ queueSlug }: { queueSlug: string }) {
  const queue = getAdminOperationQueue(queueSlug);
  return (
    <AdminShell active="Operations">
      <PageHeader eyebrow="Queue management" title={queue.title}>
        <PriorityBadge priority={queue.priority} />
      </PageHeader>
      <Card title={queue.description}>
        <div className="mb-4 grid gap-3 md:grid-cols-4">
          <div><p className="text-sm text-[var(--color-muted)]">Open items</p><p className="text-2xl font-bold">{queue.count}</p></div>
          <div><p className="text-sm text-[var(--color-muted)]">Queue priority</p><p className="text-2xl font-bold">{queue.priority}</p></div>
          <div><p className="text-sm text-[var(--color-muted)]">Assigned admin</p><p className="text-2xl font-bold">Kwame</p></div>
          <div><p className="text-sm text-[var(--color-muted)]">Mock actions</p><p className="text-2xl font-bold">{queue.actions.length}</p></div>
        </div>
        {queue.slug === "commission-release" ? <p className="mb-4 rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-sm font-bold text-[#8A5A00]">No real commission release is connected.</p> : null}
        <div className="mb-4 flex flex-wrap gap-2">
          {["All", "Open", "In Review", "Waiting", "Resolved", "Assigned to Me"].map((filter) => (
            <Button key={filter} size="table-action" type="button" variant={filter === "All" ? "primary" : "outline"}>{filter}</Button>
          ))}
        </div>
        <div className="mb-4 grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          {queue.items[0]?.metadata.map(([label, value]) => (
            <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-muted-soft)] p-3" key={label}>
              <p className="text-xs font-bold uppercase text-[var(--color-muted)]">{label}</p>
              <p className="mt-1 text-sm font-bold">{value}</p>
            </div>
          ))}
        </div>
        <QueueTable queue={queue} />
      </Card>
    </AdminShell>
  );
}

export function AdminOperationsQueueDetailScreen({ queueSlug, itemId }: { queueSlug: string; itemId: string }) {
  const item = getAdminOperationItem(queueSlug, itemId);
  const title = item.orderId ?? item.id;
  const templateType = queueSlug === "delivery-quotes" ? "delivery quote" : queueSlug === "overdue-settlements" ? "overdue settlement warning" : queueSlug === "disputes" ? "dispute follow-up" : "customer confirmation";
  return (
    <AdminShell active="Operations">
      <PageHeader eyebrow="Queue detail" title={title}>
        <div className="flex gap-2"><PriorityBadge priority={item.priority} /><StatusBadge status={item.status} /></div>
      </PageHeader>
      <div className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
        <div className="space-y-5">
          <MetadataCard title={queueSlug === "disputes" ? "Dispute summary" : queueSlug === "overdue-settlements" ? "Settlement breakdown" : "Order summary"} rows={item.metadata} />
          {queueSlug === "customer-confirmations" ? <MetadataCard title="Confirmation history" rows={[["Order placed", "13 Jul 2026, 10:24 AM"], ["Reminder sent", "Not yet"], ["Confirmation source", "Pending customer account or WhatsApp follow-up"]]} /> : null}
          {queueSlug === "overdue-settlements" ? (
            <>
              <MetadataCard title="Supplier risk impact" rows={[["Due amount", "GH₵40"], ["Overdue days", "2 days"], ["Prior settlement history", "2 late settlements in 30 days"], ["Restriction recommendation", "Limit promotions and prepare visibility review"]]} />
              <Card title="Manual restriction warning"><p className="text-sm font-bold text-[var(--color-danger)]">Restriction is placeholder-only. No real supplier restriction is connected.</p></Card>
            </>
          ) : null}
          {queueSlug === "disputes" ? (
            <>
              <MetadataCard title="Order context" rows={[["Order", "RSR-20260713-00021"], ["Customer", "Nana Yaw"], ["Reseller", "Ama's Beauty Plug"], ["Supplier", "KNUST Gadgets"]]} />
              <MetadataCard title="Evidence placeholders" rows={[["Customer evidence", "Photo upload placeholder"], ["Supplier evidence", "Delivery note placeholder"], ["Admin note", "No private files shown"]]} />
              <MetadataCard title="Messages timeline" rows={[["10:24 AM", "Order placed"], ["11:10 AM", "Customer opened dispute"], ["11:30 AM", "Support requested evidence"]]} />
              <Card title="Resolution panel mock"><p className="text-sm text-[var(--color-muted)]">Resolution controls are mock-only and do not update disputes.</p></Card>
            </>
          ) : null}
        </div>
        <div className="space-y-5">
          {queueSlug === "customer-confirmations" ? <Card title="Reservation timer"><p className="text-3xl font-bold text-[var(--color-danger)]">00:14:00</p><p className="mt-1 text-sm text-[var(--color-muted)]">Stock reservation expires soon.</p></Card> : null}
          <WhatsAppTemplateCard type={templateType} />
          <Card title="Admin notes">
            <textarea aria-label="Admin notes" className="min-h-28 w-full rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm focus:border-[var(--color-primary)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-soft)]" placeholder="Mock note only. Nothing is saved." />
          </Card>
          <AuditPreview />
        </div>
      </div>
    </AdminShell>
  );
}

function RiskEntityCard({ type }: { type: RiskEntityType }) {
  const items = getAdminRiskEntities(type);
  const title = `${type[0].toUpperCase()}${type.slice(1, -1)} risk cards`;
  return (
    <Card title={title}>
      <div className="space-y-3">
        {items.map((item) => (
          <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={item.id}>
            <div className="flex items-center justify-between gap-3"><p className="font-bold">{item.name}</p><StatusBadge status={item.level} /></div>
            <p className="mt-1 text-sm text-[var(--color-muted)]">Risk score {item.score}/100 • {item.triggerCount} triggers</p>
          </div>
        ))}
      </div>
    </Card>
  );
}

export function AdminRiskDashboardScreen() {
  return (
    <AdminShell active="Risk">
      <PageHeader eyebrow="Risk and fraud control" title="Risk Dashboard" />
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {(["suppliers", "resellers", "customers", "products"] as RiskEntityType[]).map((type) => <RiskEntityCard key={type} type={type} />)}
      </div>
      <div className="grid gap-5 xl:grid-cols-3">
        <Card title="Risk events">{riskEvents.map((event) => <p className="border-b border-[var(--color-border)] py-2 text-sm last:border-0" key={event}>{event}</p>)}</Card>
        <Card title="Restriction summary"><p className="text-3xl font-bold">4 active</p><p className="mt-1 text-sm text-[var(--color-muted)]">Restrictions are displayed only; no enforcement is connected.</p></Card>
        <Card title="Recent risk triggers">{riskEvents.slice(0, 3).map((event) => <p className="py-2 text-sm" key={event}>{event}</p>)}</Card>
      </div>
    </AdminShell>
  );
}

export function AdminRiskEntityScreen({ entityType }: { entityType: RiskEntityType }) {
  const title = `${entityType[0].toUpperCase()}${entityType.slice(1, -1)} Risk`;
  const items = getAdminRiskEntities(entityType);
  return (
    <AdminShell active="Risk">
      <PageHeader eyebrow="Risk review" title={title} />
      <DataTable
        columns={["Entity", "Risk Score", "Risk Level", "Trigger Count", "Restriction Status", "Recommended Action", "Actions"]}
        rows={items.map((item) => [
          <Link aria-label={item.name} className="font-bold text-[var(--color-primary)]" href={`/admin/risk/${entityType}/${item.id}`} key={item.id}>{item.name}</Link>,
          `${item.score}/100`,
          <StatusBadge key={`${item.id}-level`} status={item.level} />,
          item.triggerCount,
          item.restrictionStatus,
          item.recommendedAction,
          <div className="flex gap-2" key={`${item.id}-actions`}><Button size="table-action" type="button" variant="outline">Review</Button><Button size="table-action" type="button" variant="soft-warning">Flag</Button></div>
        ])}
      />
    </AdminShell>
  );
}

export function AdminRiskDetailScreen({ entityType, entityId }: { entityType: RiskEntityType; entityId: string }) {
  const entity = getAdminRiskEntity(entityType, entityId);
  return (
    <AdminShell active="Risk">
      <PageHeader eyebrow="Risk detail" title={entity.name}><StatusBadge status={entity.level} /></PageHeader>
      <div className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
        <MetadataCard title="Supplier profile" rows={[["Entity type", entity.type], ["Risk score", `${entity.score}/100`], ...entity.details.filter(([label]) => label !== "Risk score")]} />
        <div className="space-y-5">
          <Card title="Manual override placeholder"><p className="text-sm font-bold text-[var(--color-danger)]">Overrides require super admin permission, reason, confirmation, and audit logging in a future backend phase.</p></Card>
          <AuditPreview />
        </div>
      </div>
    </AdminShell>
  );
}

export function AdminAuditLogsScreen() {
  return (
    <AdminShell active="Audit Logs">
      <PageHeader eyebrow="Audit and compliance" title="Audit Logs" />
      <Card title="Audit log filters">
        <div className="grid gap-3 md:grid-cols-5">
          {["Action type", "Actor", "Entity", "Date", "Risk/sensitive actions"].map((filter) => <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm font-bold" key={filter}>{filter}</div>)}
        </div>
      </Card>
      <DataTable
        columns={["Timestamp", "Admin Actor", "Role", "Action", "Target Entity", "Old Value", "New Value", "Reason/Note", "Sensitive Flag"]}
        rows={auditLogs.map((log) => [log.timestamp, log.actor, log.role, log.action, log.entity, log.oldValue, log.newValue, log.reason, log.sensitive ? <StatusBadge key={`${log.timestamp}-sensitive`} status="Sensitive" /> : "No"])}
      />
    </AdminShell>
  );
}

export function AdminManualOverridesScreen() {
  return (
    <AdminShell active="Manual Overrides">
      <PageHeader eyebrow="Restricted admin tools" title="Manual Overrides">
        <StatusBadge tone="danger">Sensitive</StatusBadge>
      </PageHeader>
      <div className="grid gap-5 xl:grid-cols-[1fr_0.8fr]">
        <Card title="Manual override should only be used in exceptional cases.">
          <p className="rounded-[var(--radius-md)] bg-[var(--color-danger-soft)] p-4 text-sm font-bold text-[var(--color-danger)]">All override changes are logged and reviewed. This Phase 10 panel is disabled and mock-only.</p>
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {manualOverrideExamples.map((example) => <label className="flex items-center gap-2 rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm font-bold" key={example}><input type="radio" name="override" />{example}</label>)}
          </div>
          <label className="mt-4 block text-sm font-bold" htmlFor="override-reason">Required reason</label>
          <textarea className="mt-2 min-h-28 w-full rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm" id="override-reason" placeholder="A reason is required before any future real override." />
          <p className="mt-4 rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-sm font-bold text-[#8A5A00]">Second confirmation mock: a real workflow must require confirmation before any sensitive action.</p>
          <Button className="mt-4 w-full" disabled type="button" variant="danger">Apply Override</Button>
        </Card>
        <AuditPreview />
      </div>
    </AdminShell>
  );
}
