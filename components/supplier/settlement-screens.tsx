"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { useMemo, useState } from "react";
import { Button, Card, FileUploadCard, Input, Select, StatusBadge, Textarea } from "@/components/ui";
import { MobileShell } from "@/components/layout";
import {
  formatGhc,
  getSettlementOutstanding,
  getSettlementsByStatus,
  getSupplierSettlement,
  supplierSettlementMock,
  type RestrictionLevel,
  type SupplierSettlement,
  type SupplierSettlementStatus
} from "@/lib/mock/supplier-settlements";
import { cn } from "@/lib/utils/cn";

type SettlementNavKey = "home" | "settlements" | "finance" | "orders" | "account";

const navItems: Array<{ key: SettlementNavKey; label: string; href: string; icon: string }> = [
  { key: "home", label: "Home", href: "/supplier/dashboard", icon: "H" },
  { key: "settlements", label: "Settle", href: "/supplier/settlements", icon: "S" },
  { key: "finance", label: "Finance", href: "/supplier/finance", icon: "F" },
  { key: "orders", label: "Orders", href: "/supplier/orders", icon: "O" },
  { key: "account", label: "Account", href: "/supplier/settings", icon: "A" }
];

function SettlementShell({ active = "settlements", children, title }: { active?: SettlementNavKey; children: ReactNode; title?: string }) {
  return (
    <MobileShell title={title} footer={<SettlementBottomNav active={active} />}>
      {children}
    </MobileShell>
  );
}

function SettlementBottomNav({ active }: { active: SettlementNavKey }) {
  return (
    <nav aria-label="Supplier finance navigation" className="fixed inset-x-0 bottom-0 z-20 border-t border-[var(--color-border)] bg-white/95 px-3 py-2 backdrop-blur">
      <div className="mx-auto grid max-w-md grid-cols-5 gap-1">
        {navItems.map((item) => (
          <Link
            key={item.key}
            href={item.href}
            className={cn(
              "flex min-h-12 flex-col items-center justify-center gap-1 rounded-[var(--radius-md)] text-[11px] font-semibold text-[var(--color-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-soft)]",
              active === item.key && "bg-[var(--color-primary-subtle)] text-[var(--color-primary)]"
            )}
          >
            <span
              aria-hidden="true"
              className={cn(
                "grid h-5 w-5 place-items-center rounded-full border border-[var(--color-border)] text-[10px]",
                active === item.key && "border-[var(--color-primary)] bg-[var(--color-primary)] text-white"
              )}
            >
              {item.icon}
            </span>
            {item.label}
          </Link>
        ))}
      </div>
    </nav>
  );
}

function SettlementHeader({ description, eyebrow = "Supplier settlements", title }: { description?: string; eyebrow?: string; title: string }) {
  return (
    <header className="mb-5 space-y-2">
      <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-primary)]">{eyebrow}</p>
      <h1 className="text-2xl font-extrabold tracking-normal text-[var(--color-charcoal)]">{title}</h1>
      {description ? <p className="text-sm leading-6 text-[var(--color-muted)]">{description}</p> : null}
    </header>
  );
}

function SettlementStatusBadge({ status }: { status: SupplierSettlementStatus | string }) {
  const tone = status === "Overdue" || status === "Restricted" || status === "Suspended" ? "danger" : status === "Paid" || status === "Good Standing" ? "success" : status === "Proof Submitted" || status === "Verifying" ? "info" : "warning";
  return <StatusBadge tone={tone}>{status}</StatusBadge>;
}

function TonePanel({ children, tone = "warning" }: { children: ReactNode; tone?: "warning" | "success" | "danger" | "info" }) {
  const classes = {
    warning: "border-[var(--color-warning)]/25 bg-[var(--color-warning-soft)] text-[#7A5300]",
    success: "border-[var(--color-success)]/25 bg-[var(--color-success-soft)] text-[var(--color-primary)]",
    danger: "border-[var(--color-danger)]/25 bg-[var(--color-danger-soft)] text-[var(--color-danger)]",
    info: "border-[var(--color-info)]/25 bg-[var(--color-info-soft)] text-[var(--color-info)]"
  };

  return <div className={cn("rounded-[var(--radius-md)] border p-3 text-sm font-semibold leading-6", classes[tone])}>{children}</div>;
}

function MetricCard({ detail, label, tone = "neutral", value }: { detail: string; label: string; tone?: "success" | "warning" | "danger" | "info" | "neutral"; value: string }) {
  const classes = {
    success: "border-[var(--color-success)]/20 bg-[var(--color-success-soft)]",
    warning: "border-[var(--color-warning)]/25 bg-[var(--color-warning-soft)]",
    danger: "border-[var(--color-danger)]/20 bg-[var(--color-danger-soft)]",
    info: "border-[var(--color-info)]/20 bg-[var(--color-info-soft)]",
    neutral: "border-[var(--color-border)] bg-white"
  };

  return (
    <Card className={cn("p-4", classes[tone])}>
      <p className="text-xs font-bold uppercase text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 text-2xl font-extrabold text-[var(--color-charcoal)]">{value}</p>
      <p className="mt-1 text-xs leading-5 text-[var(--color-muted)]">{detail}</p>
    </Card>
  );
}

function TrustScoreCard({ compact = false }: { compact?: boolean }) {
  const summary = supplierSettlementMock.summary;

  return (
    <Card className={cn("bg-[var(--color-primary)] text-white", compact ? "p-4" : "p-5")}>
      <p className="text-sm font-semibold text-white/80">Trust score</p>
      <div className="mt-2 flex items-end justify-between gap-3">
        <p className="text-3xl font-extrabold">{summary.trustScore}/100</p>
        <StatusBadge tone="success">{summary.trustLabel}</StatusBadge>
      </div>
      <div className="mt-4 h-2 rounded-full bg-white/20">
        <div className="h-2 rounded-full bg-[var(--color-accent)]" style={{ width: `${summary.trustScore}%` }} />
      </div>
      <p className="mt-3 text-sm leading-6 text-white/80">Settle on time, upload valid proof, and complete orders to keep access healthy.</p>
    </Card>
  );
}

function SettlementObligationCard({ settlement }: { settlement: SupplierSettlement }) {
  const outstanding = getSettlementOutstanding(settlement);

  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-bold text-[var(--color-charcoal)]">{settlement.orderId}</p>
          <p className="mt-1 text-sm text-[var(--color-muted)]">{settlement.customer} · {settlement.orderDate}</p>
        </div>
        <SettlementStatusBadge status={settlement.status} />
      </div>
      <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
        <div><dt className="text-xs text-[var(--color-muted)]">Customer paid</dt><dd className="font-bold">{formatGhc(settlement.customerPaidAmount)}</dd></div>
        <div><dt className="text-xs text-[var(--color-muted)]">Supplier base</dt><dd className="font-bold">{formatGhc(settlement.supplierBaseAmount)}</dd></div>
        <div><dt className="text-xs text-[var(--color-muted)]">Due to Risellar</dt><dd className="font-bold text-[var(--color-danger)]">{formatGhc(outstanding || settlement.amountDue)}</dd></div>
        <div><dt className="text-xs text-[var(--color-muted)]">Due date</dt><dd className="font-bold">{settlement.dueDate}</dd></div>
      </dl>
      <div className="mt-4 grid grid-cols-2 gap-2">
        <Link href={`/supplier/settlements/${settlement.id}`} className="inline-flex h-10 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">
          View Details
        </Link>
        <Link href={`/supplier/settlements/${settlement.id}/settle`} className="inline-flex h-10 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] text-sm font-bold text-white">
          Settle
        </Link>
      </div>
    </Card>
  );
}

function SettlementBreakdownCard({ settlement }: { settlement: SupplierSettlement }) {
  const outstanding = getSettlementOutstanding(settlement);

  return (
    <Card title="Settlement breakdown">
      <div className="space-y-3 text-sm">
        <Row label="Customer paid amount" value={formatGhc(settlement.customerPaidAmount)} />
        <Row label="Supplier base amount" value={formatGhc(settlement.supplierBaseAmount)} />
        <Row label="Risellar margin" value={formatGhc(settlement.risellarMargin)} />
        <Row label="Reseller commission" value={formatGhc(settlement.resellerCommission)} />
        <div className="border-t border-[var(--color-border)] pt-3">
          <Row label="Total amount to settle" value={formatGhc(settlement.amountDue)} strong />
          <Row label="Amount paid" value={formatGhc(settlement.amountPaid)} />
          <Row label="Outstanding amount" value={formatGhc(outstanding)} strong danger={outstanding > 0} />
        </div>
      </div>
      <TonePanel>Supplier keeps {formatGhc(settlement.supplierBaseAmount)} and settles Risellar margin plus reseller commission.</TonePanel>
    </Card>
  );
}

function SettlementHistoryList({ settlementId }: { settlementId?: string }) {
  const events = settlementId ? supplierSettlementMock.history.filter((event) => event.settlementId === settlementId) : supplierSettlementMock.history;

  return (
    <Card title="Payment history">
      <div className="space-y-3">
        {events.map((event) => (
          <div key={event.id} className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-bold text-[var(--color-charcoal)]">{event.label}</p>
                <p className="mt-1 text-xs text-[var(--color-muted)]">{event.timestamp}</p>
              </div>
              <SettlementStatusBadge status={event.status} />
            </div>
            <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">{event.detail}</p>
          </div>
        ))}
      </div>
    </Card>
  );
}

function RestrictionLevelCard({ level }: { level: RestrictionLevel }) {
  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-3">
        <h3 className="font-bold text-[var(--color-charcoal)]">{level.level}</h3>
        <SettlementStatusBadge status={level.level} />
      </div>
      <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">{level.description}</p>
      <p className="mt-2 text-sm font-semibold text-[var(--color-charcoal)]">{level.impact}</p>
    </Card>
  );
}

function SettlementProofForm({ settlement }: { settlement: SupplierSettlement }) {
  const [submitted, setSubmitted] = useState(false);
  const [copied, setCopied] = useState(false);
  const instructions = supplierSettlementMock.paymentInstructions;

  return (
    <Card title="Submit settlement proof">
      <div className="space-y-4">
        <TonePanel>Upload proof after sending the settlement amount.</TonePanel>
        <TonePanel tone="info">Admin will verify your payment before reseller commission is released.</TonePanel>
        <TonePanel>Submitting proof does not mean settlement is verified yet.</TonePanel>
        <div className="rounded-[var(--radius-md)] bg-[var(--color-page)] p-3 text-sm">
          <p className="text-xs text-[var(--color-muted)]">Amount to settle</p>
          <p className="text-2xl font-extrabold text-[var(--color-primary)]">{formatGhc(getSettlementOutstanding(settlement) || settlement.amountDue)}</p>
          <p className="mt-2 font-semibold">{instructions.accountName}</p>
          <p>{instructions.momoNumber}</p>
          <p className="text-[var(--color-muted)]">{instructions.businessReference}</p>
        </div>
        <Button variant="outline" className="w-full" onClick={() => setCopied(true)}>Copy Payment Instructions</Button>
        {copied ? <div role="status" className="rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] p-3 text-sm font-semibold text-[var(--color-primary)]">Payment instructions copied for this mock session.</div> : null}
        <label className="space-y-2 text-sm font-semibold">
          <span>Payment method</span>
          <Select aria-label="Payment method" defaultValue="MTN Mobile Money">
            {supplierSettlementMock.paymentMethods.map((method) => (
              <option key={method} value={method}>{method}</option>
            ))}
          </Select>
        </label>
        <div className="grid grid-cols-2 gap-2">
          {supplierSettlementMock.paymentMethods.map((method, index) => (
            <label key={method} className="flex min-h-11 items-center gap-2 rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 text-sm font-semibold">
              <input aria-label={method} type="radio" name="settlement-method" defaultChecked={index === 0} />
              {method}
            </label>
          ))}
        </div>
        <label className="space-y-2 text-sm font-semibold">
          <span>Amount sent</span>
          <Input aria-label="Amount sent" defaultValue={formatGhc(getSettlementOutstanding(settlement) || settlement.amountDue)} />
        </label>
        <label className="space-y-2 text-sm font-semibold">
          <span>Transaction or reference number</span>
          <Input aria-label="Transaction or reference number" defaultValue="MOMO-RSL-00021" />
        </label>
        <div>
          <p className="mb-2 text-sm font-semibold">Upload proof placeholder</p>
          <FileUploadCard hint="PNG, JPG or PDF. Max 5MB. Mock only." label="Upload proof placeholder" />
        </div>
        <label className="space-y-2 text-sm font-semibold">
          <span>Settlement notes</span>
          <Textarea aria-label="Settlement notes" defaultValue="Settlement sent after customer payment was received." />
        </label>
        {submitted ? <div role="status" className="rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] p-3 text-sm font-semibold text-[var(--color-primary)]">Settlement proof submitted for admin verification.</div> : null}
        <Button className="w-full" onClick={() => setSubmitted(true)}>Submit Proof</Button>
      </div>
    </Card>
  );
}

function SupplierFinanceSummary() {
  const summary = supplierSettlementMock.summary;

  return (
    <Card title="Financial summary">
      <div className="grid grid-cols-2 gap-3">
        <MetricCard label="Settlement due" value={formatGhc(summary.totalSettlementsDue)} detail="Must be settled" tone="warning" />
        <MetricCard label="Overdue" value={formatGhc(summary.overdueAmount)} detail="Restriction risk" tone="danger" />
        <MetricCard label="Paid this month" value={formatGhc(summary.paidThisMonth)} detail="Verified or submitted" tone="success" />
        <MetricCard label="All-time settled" value={formatGhc(summary.totalSettledAllTime)} detail="Supplier history" tone="info" />
      </div>
    </Card>
  );
}

function PayoutDetailsCard({ editable = false }: { editable?: boolean }) {
  const [saved, setSaved] = useState(false);
  const supplier = supplierSettlementMock.supplier;

  return (
    <Card title="Payout and MoMo details">
      <div className="space-y-3 text-sm">
        <Row label="Provider" value={supplier.payoutProvider} />
        <Row label="MoMo number" value={supplier.payoutNumber} />
        <Row label="Account name" value={supplier.payoutAccountName} />
        <Row label="Bank option" value={supplier.bankPlaceholder} />
      </div>
      <TonePanel tone="info">For your security, payout changes are reviewed before they affect real payments.</TonePanel>
      {editable ? (
        <>
          {saved ? <div role="status" className="rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] p-3 text-sm font-semibold text-[var(--color-primary)]">Payout details update saved for this mock session.</div> : null}
          <Button className="mt-4 w-full" onClick={() => setSaved(true)}>Edit Payout Details</Button>
        </>
      ) : null}
    </Card>
  );
}

function SettlementRulesCard({ title, children }: { title: string; children: ReactNode }) {
  return (
    <Card title={title}>
      <p className="text-sm leading-6 text-[var(--color-muted)]">{children}</p>
    </Card>
  );
}

function Row({ danger = false, label, strong = false, value }: { danger?: boolean; label: string; strong?: boolean; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4 py-1">
      <span className="text-[var(--color-muted)]">{label}</span>
      <span className={cn("text-right font-bold", strong && "text-base", danger ? "text-[var(--color-danger)]" : "text-[var(--color-charcoal)]")}>{value}</span>
    </div>
  );
}

export function SettlementOverviewScreen() {
  const [filter, setFilter] = useState("All");
  const [message, setMessage] = useState("");
  const filters = ["All", "Due", "Overdue", "Paid", "Partially Paid"];
  const settlements = useMemo(
    () => filter === "All" ? supplierSettlementMock.settlements : supplierSettlementMock.settlements.filter((settlement) => settlement.status === filter),
    [filter]
  );

  return (
    <SettlementShell title="Supplier settlements">
      <SettlementHeader title="Settlements" description="Track what you owe Risellar after customer payment and protect reseller commissions." />
      <Card className="mb-4 bg-[var(--color-primary)] text-white">
        <p className="text-sm font-semibold text-white/80">{supplierSettlementMock.supplier.businessName}</p>
        <p className="mt-1 text-2xl font-extrabold">Financial control center</p>
        <p className="mt-2 text-sm leading-6 text-white/80">Settlement is not optional after customer payment.</p>
      </Card>
      <TrustScoreCard compact />
      <div className="mt-4 grid grid-cols-2 gap-3">
        <MetricCard label="Total settlements due" value={formatGhc(supplierSettlementMock.summary.totalSettlementsDue)} detail="Open obligations" tone="warning" />
        <MetricCard label="Overdue amount" value={formatGhc(supplierSettlementMock.summary.overdueAmount)} detail="Needs action" tone="danger" />
        <MetricCard label="Paid this month" value={formatGhc(supplierSettlementMock.summary.paidThisMonth)} detail="Settled recently" tone="success" />
        <MetricCard label="Total settled all time" value={formatGhc(supplierSettlementMock.summary.totalSettledAllTime)} detail="Verified history" tone="info" />
      </div>
      <TonePanel tone="danger">You have {formatGhc(supplierSettlementMock.summary.overdueAmount)} in overdue settlements.</TonePanel>
      <Card title="Quick actions">
        <div className="grid grid-cols-2 gap-2">
          <Link href="/supplier/settlements/overdue" className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-danger)] text-sm font-bold text-white">View Overdue</Link>
          <Button variant="outline" onClick={() => setMessage("Statement download prepared for this mock session.")}>Download Statement</Button>
          <Link href="/supplier/settlements/rules" className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">Settlement Rules</Link>
          <Button variant="outline" onClick={() => setMessage("Support request opened for this mock session.")}>Contact Support</Button>
        </div>
        {message ? <div role="status" className="mt-3 rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] p-3 text-sm font-semibold text-[var(--color-primary)]">{message}</div> : null}
      </Card>
      <Card title="Settlement status guide">
        <div className="grid grid-cols-2 gap-2">
          {["Due", "Overdue", "Partially Paid", "Paid", "Cancelled"].map((status) => (
            <div key={status} className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3">
              <SettlementStatusBadge status={status} />
              <p className="mt-2 text-xs leading-5 text-[var(--color-muted)]">{status === "Paid" ? "Verified and closed." : status === "Overdue" ? "Settle immediately." : status === "Cancelled" ? "No settlement required." : "Action may still be needed."}</p>
            </div>
          ))}
        </div>
      </Card>
      <Card title="Settlement obligations">
        <div className="flex gap-2 overflow-x-auto pb-1">
          {filters.map((item) => (
            <Button key={item} variant={filter === item ? "primary" : "outline"} size="compact" onClick={() => setFilter(item)}>{item}</Button>
          ))}
        </div>
        <div className="mt-4 space-y-3">
          {settlements.map((settlement) => (
            <SettlementObligationCard key={settlement.id} settlement={settlement} />
          ))}
        </div>
      </Card>
    </SettlementShell>
  );
}

export function SettlementDetailScreen({ settlementId }: { settlementId: string }) {
  const settlement = getSupplierSettlement(settlementId);

  return (
    <SettlementShell title="Settlement detail">
      <SettlementHeader title={settlement.settlementNumber} description={`${settlement.orderId} · Due ${settlement.dueDate}`} />
      <div className="mb-4 flex items-center justify-between">
        <SettlementStatusBadge status={settlement.status} />
        <p className="text-sm font-bold text-[var(--color-muted)]">{settlement.customer}</p>
      </div>
      {settlement.status === "Overdue" ? <TonePanel tone="danger">Restriction warning: settle overdue amounts to avoid limits and product visibility loss.</TonePanel> : null}
      <SettlementBreakdownCard settlement={settlement} />
      <SettlementHistoryList settlementId={settlement.id} />
      <Card title="Linked order summary">
        <p className="text-sm leading-6 text-[var(--color-muted)]">{settlement.linkedOrderSummary}</p>
      </Card>
      <div className="mt-4 grid grid-cols-2 gap-2">
        <Link href={`/supplier/settlements/${settlement.id}/settle`} className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] text-sm font-bold text-white">Settle Now</Link>
        <Link href={`/supplier/settlements/${settlement.id}/settle`} className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">Upload Proof</Link>
        <Button variant="outline">View Order</Button>
        <Button variant="outline">Contact Support</Button>
      </div>
    </SettlementShell>
  );
}

export function SettlementSettleScreen({ settlementId }: { settlementId: string }) {
  const settlement = getSupplierSettlement(settlementId);

  return (
    <SettlementShell title="Settle now">
      <SettlementHeader title="Settle now" description={settlement.settlementNumber} />
      <SettlementProofForm settlement={settlement} />
    </SettlementShell>
  );
}

export function PartialSettlementsScreen() {
  const settlements = getSettlementsByStatus(["Partially Paid"]);

  return (
    <SettlementShell title="Partial settlements">
      <SettlementHeader title="Partial settlements" description="Finish outstanding balances so commissions can move forward." />
      <TonePanel>Reseller commission may remain pending until settlement is complete.</TonePanel>
      <div className="mt-4 space-y-3">
        {settlements.map((settlement) => (
          <Card key={settlement.id} className="p-4">
            <SettlementStatusBadge status="Partially Paid" />
            <h3 className="mt-3 font-bold text-[var(--color-charcoal)]">{settlement.orderId}</h3>
            <dl className="mt-3 space-y-2 text-sm">
              <Row label="Amount due" value={formatGhc(settlement.amountDue)} />
              <Row label="Amount paid" value={formatGhc(settlement.amountPaid)} />
              <Row label="Outstanding balance" value={formatGhc(getSettlementOutstanding(settlement))} danger strong />
            </dl>
            <Link href={`/supplier/settlements/${settlement.id}/settle`} className="mt-4 inline-flex h-10 w-full items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-primary)] text-sm font-bold text-white">Settle Balance</Link>
          </Card>
        ))}
      </div>
    </SettlementShell>
  );
}

export function OverdueSettlementsScreen() {
  const settlements = getSettlementsByStatus(["Overdue"]);

  return (
    <SettlementShell title="Overdue settlements">
      <SettlementHeader title="Overdue settlements" description="Overdue settlements can reduce supplier access and reseller confidence." />
      <MetricCard label="Overdue amount" value={formatGhc(supplierSettlementMock.summary.overdueAmount)} detail="Settle now to protect your account" tone="danger" />
      <TonePanel tone="danger">Settle overdue amounts to avoid restrictions.</TonePanel>
      <TonePanel>Suppliers with overdue settlements cannot boost products.</TonePanel>
      <TonePanel>Repeated overdue settlements may hide your products from resellers.</TonePanel>
      <Card title="Trust score impact">
        <p className="text-sm leading-6 text-[var(--color-muted)]">Late settlements reduce trust score and may move the account from warning to limited, restricted, or suspended.</p>
      </Card>
      <div className="space-y-3">
        {settlements.map((settlement) => (
          <Card key={settlement.id} className="p-4">
            <div className="flex items-start justify-between gap-3">
              <h3 className="font-bold text-[var(--color-charcoal)]">{settlement.orderId}</h3>
              <SettlementStatusBadge status={settlement.status} />
            </div>
            <p className="mt-2 text-sm text-[var(--color-muted)]">{settlement.daysOverdue} days overdue</p>
            <p className="mt-2 text-xl font-extrabold text-[var(--color-danger)]">{formatGhc(getSettlementOutstanding(settlement) || settlement.amountDue)}</p>
            <div className="mt-4 grid grid-cols-2 gap-2">
              <Link href={`/supplier/settlements/${settlement.id}/settle`} className="inline-flex h-10 items-center justify-center rounded-[var(--radius-md)] bg-[var(--color-danger)] text-sm font-bold text-white">Settle Now</Link>
              <Button variant="outline">Contact Support</Button>
            </div>
          </Card>
        ))}
      </div>
      <Card title="Restriction levels">
        <div className="space-y-3">
          {supplierSettlementMock.restrictionLevels.map((level) => (
            <RestrictionLevelCard key={level.level} level={level} />
          ))}
        </div>
      </Card>
    </SettlementShell>
  );
}

export function SettlementHistoryScreen() {
  const [message, setMessage] = useState("");
  const paid = supplierSettlementMock.settlements.filter((settlement) => ["Paid", "Proof Submitted", "Verifying"].includes(settlement.status));

  return (
    <SettlementShell title="Settlement history">
      <SettlementHeader title="Settlement history" description="Review paid, submitted, and verifying settlement records." />
      <Button className="mb-4 w-full" variant="outline" onClick={() => setMessage("Export statement prepared for this mock session.")}>Export Statement</Button>
      {message ? <div role="status" className="mb-4 rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] p-3 text-sm font-semibold text-[var(--color-primary)]">{message}</div> : null}
      <div className="space-y-3">
        {paid.map((settlement) => (
          <Card key={settlement.id} className="p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-bold text-[var(--color-charcoal)]">{settlement.orderId}</p>
                <p className="mt-1 text-xs text-[var(--color-muted)]">Date paid: {settlement.dueDate}</p>
              </div>
              <SettlementStatusBadge status={settlement.status === "Paid" ? "Proof verified" : settlement.status} />
            </div>
            <dl className="mt-3 space-y-2 text-sm">
              <Row label="Amount" value={formatGhc(settlement.amountPaid)} />
              <Row label="Receipt/reference" value={settlement.reference ?? "Mock receipt pending"} />
            </dl>
          </Card>
        ))}
      </div>
    </SettlementShell>
  );
}

export function SettlementRulesScreen() {
  return (
    <SettlementShell title="Settlement rules">
      <SettlementHeader title="Settlement rules" description="Simple Ghana-friendly rules for supplier settlement and account trust." />
      <div className="space-y-3">
        <SettlementRulesCard title="How Risellar settlement works">Customer pays the supplier on delivery. The supplier keeps the base amount and sends Risellar margin plus reseller commission to Risellar.</SettlementRulesCard>
        <SettlementRulesCard title="Supplier receives customer payment at MVP">This MVP supports Pay on Delivery trust. Because suppliers may receive the cash first, settlement must happen immediately after payment.</SettlementRulesCard>
        <SettlementRulesCard title="What the amount includes">The settlement amount includes Risellar platform margin and the reseller commission linked to the order.</SettlementRulesCard>
        <SettlementRulesCard title="Reseller commission depends on verified settlement">Reseller commission stays pending until settlement proof is verified. Partial settlement may keep commission pending.</SettlementRulesCard>
        <SettlementRulesCard title="If settlement delays">Overdue settlements can trigger warning, limited, restricted, or suspended states. Suppliers with overdue settlements cannot boost products.</SettlementRulesCard>
        <SettlementRulesCard title="Improve trust score">Settle on time, keep disputes low, upload valid proof, complete orders successfully, and respond to support when needed.</SettlementRulesCard>
        <SettlementRulesCard title="Future trusted supplier benefits">Future trusted suppliers may qualify for better settlement terms, daily or weekly schedules, and stronger marketplace visibility.</SettlementRulesCard>
      </div>
    </SettlementShell>
  );
}

export function FinanceOverviewScreen() {
  const [message, setMessage] = useState("");

  return (
    <SettlementShell active="finance" title="Supplier finance">
      <SettlementHeader eyebrow="Supplier finance" title="Finance" description="Financial summary, payout details, settlement status, and trust controls." />
      <SupplierFinanceSummary />
      <Card title="Finance actions">
        <div className="grid grid-cols-2 gap-2">
          <Link href="/supplier/settlements/history" className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">Settlement History</Link>
          <Link href="/supplier/finance/payout-details" className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">Payout Details</Link>
          <Link href="/supplier/finance/trust-score" className="inline-flex h-11 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] text-sm font-bold text-[var(--color-primary)]">Trust Score</Link>
          <Button variant="outline" onClick={() => setMessage("Finance statement download prepared for this mock session.")}>Download Statement</Button>
        </div>
        {message ? <div role="status" className="mt-3 rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] p-3 text-sm font-semibold text-[var(--color-primary)]">{message}</div> : null}
      </Card>
      <PayoutDetailsCard />
      <TrustScoreCard />
      <Card title="Restriction status">
        <div className="flex items-center justify-between">
          <p className="font-bold text-[var(--color-charcoal)]">Current status</p>
          <SettlementStatusBadge status={supplierSettlementMock.summary.restrictionStatus} />
        </div>
        <p className="mt-3 text-sm leading-6 text-[var(--color-muted)]">Settlement behavior affects promotions, product visibility, and future trusted supplier benefits.</p>
      </Card>
    </SettlementShell>
  );
}

export function PayoutDetailsScreen() {
  return (
    <SettlementShell active="finance" title="Payout details">
      <SettlementHeader eyebrow="Supplier finance" title="Payout details" description="Mock MoMo and bank payout summary. Real edits require later backend review." />
      <PayoutDetailsCard editable />
    </SettlementShell>
  );
}

export function TrustScoreScreen() {
  return (
    <SettlementShell active="finance" title="Trust score">
      <SettlementHeader eyebrow="Supplier finance" title="Trust score" description="Trust score explains settlement behavior, disputes, proof quality, and completion reliability." />
      <TrustScoreCard />
      <Card title="What affects score">
        <div className="space-y-3">
          {supplierSettlementMock.trustFactors.map((factor) => (
            <div key={factor} className="flex items-center justify-between rounded-[var(--radius-md)] border border-[var(--color-border)] p-3">
              <p className="font-bold text-[var(--color-charcoal)]">{factor}</p>
              <StatusBadge tone="success">Tracked</StatusBadge>
            </div>
          ))}
        </div>
      </Card>
      <Card title="Current restriction status">
        <div className="flex items-center justify-between">
          <p className="font-bold text-[var(--color-charcoal)]">Good Standing</p>
          <SettlementStatusBadge status="Good Standing" />
        </div>
      </Card>
      <TonePanel>Settle overdue balances before they affect product visibility, boosts, or new order access.</TonePanel>
    </SettlementShell>
  );
}
