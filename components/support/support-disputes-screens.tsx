"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import { ArrowLeft, CheckCircle2, ClipboardList, FileText, Headphones, Home, Package, UserRound, Wallet } from "lucide-react";
import { AdminShell } from "@/components/admin/AdminSidebar";
import { MobileShell } from "@/components/layout";
import { ProductImageFrame } from "@/components/marketplace";
import { Button, Card, Input, StatusBadge, Textarea } from "@/components/ui";
import {
  disputeStatuses,
  disputeTypes,
  disputes,
  formatGhc,
  getDispute,
  getRefund,
  getReturnRequest,
  getTicket,
  refunds,
  returnRules,
  returns,
  returnStatuses,
  supportOrder,
  supportTickets,
  supportTimeline,
  type Dispute,
  type Refund,
  type ReturnRequest,
  type SupportTicket
} from "@/lib/mock/support-disputes";
import { getMockProductImages, getPrimaryProductImageAlt } from "@/lib/mock/product-images";
import { cn } from "@/lib/utils/cn";

const customerNav = [
  { label: "Orders", href: "/customer/orders", icon: ClipboardList },
  { label: "Support", href: "/customer/support", icon: Headphones },
  { label: "Account", href: "/checkout/account", icon: UserRound }
];

const resellerNav = [
  { label: "Home", href: "/reseller/dashboard", icon: Home },
  { label: "Orders", href: "/reseller/orders", icon: ClipboardList },
  { label: "Wallet", href: "/reseller/wallet", icon: Wallet },
  { label: "Support", href: "/reseller/support", icon: Headphones }
];

const supplierNav = [
  { label: "Home", href: "/supplier/dashboard", icon: Home },
  { label: "Products", href: "/supplier/products", icon: Package },
  { label: "Orders", href: "/supplier/orders", icon: ClipboardList },
  { label: "Support", href: "/supplier/support", icon: Headphones }
];

type SupportNavItem = { label: string; href: string; icon: LucideIcon };

function SimpleBottomNav({ items, active }: { items: SupportNavItem[]; active: string }) {
  return (
    <nav className="fixed inset-x-0 bottom-0 z-[var(--z-header)] border-t border-[var(--color-border)] bg-white/95 px-4 pb-[calc(0.75rem+env(safe-area-inset-bottom))] pt-3 shadow-[var(--shadow-md)] backdrop-blur">
      <div className={cn("mx-auto grid max-w-md gap-2", items.length === 3 ? "grid-cols-3" : "grid-cols-4")}>
        {items.map((item) => {
          const Icon = item.icon;
          const selected = item.label === active;

          return (
            <Link
              aria-current={selected ? "page" : undefined}
              aria-label={item.label}
              className={cn(
                "flex min-h-12 min-w-0 flex-col items-center justify-center rounded-[var(--radius-md)] text-[11px] font-semibold text-[var(--color-muted)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--color-focus-ring)]",
                selected && "bg-[var(--color-primary-soft)] text-[var(--color-primary)]"
              )}
              href={item.href}
              key={item.label}
            >
              <Icon className="mb-1 h-4 w-4" aria-hidden />
              <span className="truncate">{item.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}

function MobileSupportShell({
  active,
  backHref,
  children,
  eyebrow,
  nav,
  title
}: {
  active: string;
  backHref?: string;
  children: ReactNode;
  eyebrow?: string;
  nav: SupportNavItem[];
  title: string;
}) {
  return (
    <MobileShell footer={<SimpleBottomNav active={active} items={nav} />} title={title}>
      <header className="mb-5 flex items-start gap-3">
        {backHref ? (
          <Link
            aria-label="Go back"
            className="grid h-10 w-10 shrink-0 place-items-center rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-soft)]"
            href={backHref}
          >
            <ArrowLeft className="h-4 w-4" aria-hidden="true" />
          </Link>
        ) : null}
        <div>
          {eyebrow ? <p className="text-xs font-bold uppercase text-[var(--color-primary)]">{eyebrow}</p> : null}
          <h1 className="text-2xl font-extrabold text-[var(--color-charcoal)]">{title}</h1>
        </div>
      </header>
      <div className="space-y-4">{children}</div>
    </MobileShell>
  );
}

function AdminHeader({ title, eyebrow, children }: { title: string; eyebrow: string; children?: ReactNode }) {
  return (
    <div className="flex flex-col gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-5 shadow-[var(--shadow-sm)] lg:flex-row lg:items-center lg:justify-between">
      <div>
        <p className="text-xs font-bold uppercase text-[var(--color-primary)]">{eyebrow}</p>
        <h1 className="mt-1 text-2xl font-bold">{title}</h1>
      </div>
      {children}
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-4 border-b border-[var(--color-border)] py-2 text-sm last:border-0">
      <span className="text-[var(--color-muted)]">{label}</span>
      <span className="max-w-[58%] text-right font-bold text-[var(--color-charcoal)]">{value}</span>
    </div>
  );
}

function SummaryStat({ label, value, tone = "neutral" }: { label: string; value: string; tone?: "success" | "warning" | "danger" | "info" | "neutral" }) {
  return (
    <Card className="p-4">
      <p className="text-xs font-bold uppercase text-[var(--color-muted)]">{label}</p>
      <p className="mt-2 text-2xl font-extrabold">{value}</p>
      <div className="mt-3"><StatusBadge tone={tone}>{tone === "neutral" ? "Mock" : tone}</StatusBadge></div>
    </Card>
  );
}

function productKeyFromName(name: string) {
  if (/anua/i.test(name)) return "anua-niacinamide-serum-30ml";
  if (/hostel/i.test(name)) return "hostel-essentials-pack";
  return "nike-air-force-1-07-green-white";
}

function SupportProductContext({ product, size = "sm" }: { product: string; size?: "sm" | "md" }) {
  return (
    <div className="flex items-center gap-3">
      <ProductImageFrame
        className={size === "md" ? "h-20 w-20 shrink-0 rounded-[12px]" : "h-14 w-14 shrink-0 rounded-[12px]"}
        imageAlt={getPrimaryProductImageAlt(product)}
        images={getMockProductImages(productKeyFromName(product))}
        productName={product}
      />
      <div className="min-w-0">
        <p className="line-clamp-2 text-sm font-semibold leading-5 text-[var(--color-charcoal)]">{product}</p>
        <p className="mt-0.5 text-xs text-[var(--color-muted)]">Product context</p>
      </div>
    </div>
  );
}

export function IssueCategoryCard({ title, description, selected = false }: { title: string; description: string; selected?: boolean }) {
  return (
    <button
      className={cn(
        "min-h-16 rounded-[var(--radius-md)] border p-3 text-left text-sm focus:outline-none focus:ring-2 focus:ring-[var(--color-primary-soft)]",
        selected ? "border-[var(--color-primary)] bg-[var(--color-primary-subtle)]" : "border-[var(--color-border)] bg-white"
      )}
      type="button"
    >
      <span className="block font-bold text-[var(--color-charcoal)]">{title}</span>
      <span className="mt-1 block text-xs leading-5 text-[var(--color-muted)]">{description}</span>
    </button>
  );
}

export function EvidenceUploadPlaceholder({ label = "Evidence upload placeholder" }: { label?: string }) {
  return (
    <div className="rounded-[var(--radius-md)] border border-dashed border-[var(--color-border)] bg-[var(--color-page)] p-4 text-center">
      <FileText className="mx-auto h-8 w-8 text-[var(--color-primary)]" aria-hidden="true" />
      <p className="mt-2 font-bold text-[var(--color-charcoal)]">{label}</p>
      <p className="mt-1 text-xs leading-5 text-[var(--color-muted)]">Photos, receipts, and proof files will connect to private storage in a later backend phase.</p>
    </div>
  );
}

function OrderContextCard({ customerSafe = false }: { customerSafe?: boolean }) {
  return (
    <Card title="Order context">
      <div className="mb-4 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-[var(--color-page)] p-3">
        <SupportProductContext product={supportOrder.product} size="md" />
      </div>
      <InfoRow label="Order" value={supportOrder.id} />
      <InfoRow label="Product" value={supportOrder.product} />
      <InfoRow label="Delivery area" value={supportOrder.deliveryArea} />
      <InfoRow label="Payment" value={supportOrder.paymentMethod} />
      <InfoRow label="Total paid on delivery" value={formatGhc(supportOrder.total)} />
      {customerSafe ? (
        <p className="mt-3 rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] p-3 text-sm font-semibold text-[var(--color-primary)]">
          Customer view hides supplier base price and reseller commission.
        </p>
      ) : null}
    </Card>
  );
}

export function SupportTicketCard({ ticket }: { ticket: SupportTicket }) {
  return (
    <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-xs font-bold text-[var(--color-muted)]">{ticket.id}</p>
          <h2 className="mt-1 font-bold text-[var(--color-charcoal)]">{ticket.title}</h2>
          <p className="mt-1 text-sm text-[var(--color-muted)]">{ticket.summary}</p>
        </div>
        <StatusBadge status={ticket.status} />
      </div>
      <div className="mt-3 flex flex-wrap gap-2">
        <StatusBadge status={ticket.priority} />
        <StatusBadge tone="neutral">{ticket.party}</StatusBadge>
        {ticket.relatedDisputeId ? <StatusBadge tone="danger">{ticket.relatedDisputeId}</StatusBadge> : null}
      </div>
    </div>
  );
}

function TicketList({ party }: { party?: SupportTicket["party"] }) {
  const rows = party ? supportTickets.filter((ticket) => ticket.party === party) : supportTickets;
  return (
    <div className="space-y-3">
      {rows.map((ticket) => (
        <SupportTicketCard key={ticket.id} ticket={ticket} />
      ))}
    </div>
  );
}

export function SupportTicketDetail({ ticket }: { ticket: SupportTicket }) {
  return (
    <>
      <Card>
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className="text-xs font-bold text-[var(--color-muted)]">{ticket.id}</p>
            <h2 className="mt-1 text-xl font-extrabold">{ticket.title}</h2>
            <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">{ticket.summary}</p>
          </div>
          <StatusBadge status={ticket.status} />
        </div>
      </Card>
      <Card title="Ticket timeline">
        <Timeline rows={supportTimeline} />
      </Card>
      <Card title="Support reply composer">
        <Textarea aria-label="Support reply" placeholder="Add a mock support reply." />
        <p className="mt-2 text-xs text-[var(--color-muted)]">No message is sent in this frontend phase.</p>
      </Card>
    </>
  );
}

function Timeline({ rows }: { rows: ReadonlyArray<readonly [string, string]> }) {
  return (
    <ol className="space-y-3">
      {rows.map(([label, value], index) => (
        <li className="flex gap-3" key={`${label}-${value}`}>
          <span className="mt-1 grid h-6 w-6 shrink-0 place-items-center rounded-full bg-[var(--color-primary)] text-xs font-bold text-white">{index + 1}</span>
          <div>
            <p className="font-bold text-[var(--color-charcoal)]">{label}</p>
            <p className="text-sm text-[var(--color-muted)]">{value}</p>
          </div>
        </li>
      ))}
    </ol>
  );
}

export function DisputeSummaryCard({ dispute }: { dispute: Dispute }) {
  return (
    <Card title="Dispute summary">
      <InfoRow label="Dispute ID" value={dispute.id} />
      <InfoRow label="Dispute type" value={dispute.type} />
      <InfoRow label="Status" value={<StatusBadge status={dispute.status} />} />
      <InfoRow label="Priority" value={<StatusBadge status={dispute.priority} />} />
      <InfoRow label="Next action" value={dispute.nextAction} />
    </Card>
  );
}

export function DisputeTimeline() {
  return (
    <Card title="Dispute timeline">
      <Timeline rows={supportTimeline} />
    </Card>
  );
}

export function CommissionImpactCard({ amount = supportOrder.commission }: { amount?: number }) {
  return (
    <Card title="Commission impact">
      <p className="text-3xl font-extrabold text-[var(--color-primary)]">{formatGhc(amount)}</p>
      <p className="mt-2 text-sm font-semibold text-[var(--color-primary)]">Commission remains pending</p>
      <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">Commission remains pending while the dispute is open. Supplier settlement must be verified before release.</p>
      <p className="mt-2 text-sm font-semibold text-[var(--color-primary)]">Supplier settlement must be verified before release.</p>
      <p className="mt-2 text-sm font-semibold text-[var(--color-primary)]">Awaiting supplier settlement verification</p>
    </Card>
  );
}

export function SettlementImpactCard({ amount = supportOrder.settlementDue }: { amount?: number }) {
  return (
    <Card title="Settlement impact">
      <p className="text-3xl font-extrabold text-[var(--color-warning)]">{formatGhc(amount)}</p>
      <p className="mt-2 text-sm font-semibold text-[var(--color-warning)]">Settlement remains disputed</p>
      <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">Settlement remains disputed until admin finance verification clears the proof.</p>
    </Card>
  );
}

export function RefundStatusCard({ refund }: { refund: Refund }) {
  return (
    <Card title="Refund status">
      <StatusBadge status={refund.status} />
      <InfoRow label="Refund ID" value={refund.id} />
      <InfoRow label="Expected refund" value={formatGhc(refund.amount)} />
      <InfoRow label="Method" value={refund.method} />
      <p className="mt-3 rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-sm font-semibold text-[#8A5A00]">{refund.note}</p>
      <p className="mt-2 text-sm font-semibold text-[#8A5A00]">Pay on Delivery refunds may be manual/off-platform.</p>
    </Card>
  );
}

export function ReturnRequestForm() {
  return (
    <Card title="Return details">
      <div className="space-y-3">
        <Input aria-label="Order ID" defaultValue={supportOrder.id} />
        <Input aria-label="Reason" defaultValue="Wrong product received" />
        <Textarea aria-label="Return explanation" defaultValue="The product delivered does not match the ordered item." />
        <EvidenceUploadPlaceholder />
        <Button className="w-full" type="button">Submit Return Request Mock</Button>
      </div>
    </Card>
  );
}

export function ResolutionPanel() {
  return (
    <Card title="Resolution panel">
      <div className="grid gap-2 sm:grid-cols-2">
        {["Request Evidence", "Mark Under Review", "Resolve Dispute Mock", "Reject Request Mock"].map((action, index) => (
          <Button key={action} type="button" variant={index === 2 ? "primary" : index === 3 ? "danger" : "outline"}>{action}</Button>
        ))}
      </div>
      <p className="mt-3 text-xs font-semibold text-[var(--color-danger)]">No real refund or commission release is connected.</p>
    </Card>
  );
}

export function InternalNotesCard() {
  return (
    <Card title="Internal notes">
      <Textarea aria-label="Internal notes" placeholder="Mock internal note. Nothing is saved." />
      <p className="mt-2 text-xs text-[var(--color-muted)]">Future notes must be permissioned and audited.</p>
    </Card>
  );
}

export function CustomerSupportCenterScreen() {
  return (
    <MobileSupportShell active="Support" eyebrow="We are here to help" nav={customerNav} title="Support Center">
      <Card>
        <p className="text-sm leading-6 text-[var(--color-muted)]">Ghana-friendly support for orders, delivery, Pay on Delivery, returns, and refunds.</p>
      </Card>
      <div className="grid gap-3">
        {[
          ["Report an order issue", "Wrong product, damaged product, delivery issue"],
          ["Track support tickets", "Follow updates without calling multiple people"],
          ["Return or refund help", "Understand return review and refund status"],
          ["Pay on Delivery questions", "We never ask for your PIN or password"]
        ].map(([title, description], index) => (
          <IssueCategoryCard key={title} title={title} description={description} selected={index === 0} />
        ))}
      </div>
      <Card className="bg-[var(--color-warning-soft)]">
        <p className="font-bold text-[#8A5A00]">Do not share your MoMo PIN, card PIN, or password with anyone.</p>
      </Card>
    </MobileSupportShell>
  );
}

export function CustomerSupportTicketsScreen() {
  return (
    <MobileSupportShell active="Support" backHref="/customer/support" nav={customerNav} title="My Support Tickets">
      <TicketList party="Customer" />
    </MobileSupportShell>
  );
}

export function CustomerSupportTicketDetailScreen({ ticketId }: { ticketId: string }) {
  return (
    <MobileSupportShell active="Support" backHref="/customer/support/tickets" nav={customerNav} title="Ticket Detail">
      <SupportTicketDetail ticket={getTicket(ticketId)} />
    </MobileSupportShell>
  );
}

export function CustomerReportIssueScreen({ id }: { id: string }) {
  return (
    <MobileSupportShell active="Support" backHref={`/customer/orders/${id}`} nav={customerNav} title="Report Issue">
      <OrderContextCard customerSafe />
      <Card title="What happened?">
        <div className="grid grid-cols-2 gap-2">
          {disputeTypes.slice(0, 8).map((type, index) => (
            <IssueCategoryCard key={type} title={type} description="Select if this matches your issue." selected={index === 0} />
          ))}
        </div>
      </Card>
      <Card title="Evidence">
        <EvidenceUploadPlaceholder />
      </Card>
      <Card title="Contact preference">
        <Input aria-label="Preferred phone" defaultValue="+233 24 123 4567" />
      </Card>
      <Button className="w-full" type="button">Submit Issue Mock</Button>
      <Card className="bg-[var(--color-success-soft)]">
        <div className="flex gap-3">
          <CheckCircle2 className="h-5 w-5 text-[var(--color-success)]" aria-hidden="true" />
          <div>
            <p className="font-bold">Issue Submitted</p>
            <p className="text-sm text-[var(--color-muted)]">Your mock ticket reference is TKT-RSR-20260713-00021.</p>
          </div>
        </div>
      </Card>
    </MobileSupportShell>
  );
}

export function CustomerReturnRequestScreen({ id }: { id: string }) {
  return (
    <MobileSupportShell active="Support" backHref={`/customer/orders/${id}`} nav={customerNav} title="Return Request">
      <StatusBadge status="Return Requested" />
      <Card title="Return rules">
        {returnRules.map(([category, rule]) => (
          <InfoRow key={category} label={category} value={rule} />
        ))}
      </Card>
      <StatusBadge status="Return Under Review" />
      <ReturnRequestForm />
    </MobileSupportShell>
  );
}

export function CustomerRefundStatusScreen({ id }: { id: string }) {
  const refund = getRefund(`rfd-${id}`);
  return (
    <MobileSupportShell active="Support" backHref={`/customer/orders/${id}`} nav={customerNav} title="Refund Status">
      <RefundStatusCard refund={refund} />
      <Card title="What happens next?">
        <p className="text-sm leading-6 text-[var(--color-muted)]">Support will confirm if a manual/off-platform refund is needed for this Pay on Delivery order.</p>
      </Card>
    </MobileSupportShell>
  );
}

export function CustomerDisputeDetailScreen({ disputeId }: { disputeId: string }) {
  const dispute = getDispute(disputeId);
  return (
    <MobileSupportShell active="Support" backHref="/customer/support/tickets" nav={customerNav} title="Dispute Detail">
      <DisputeSummaryCard dispute={dispute} />
      <OrderContextCard customerSafe />
      <DisputeTimeline />
      <Card title="Evidence placeholders">
        <EvidenceUploadPlaceholder label="Customer evidence placeholder" />
      </Card>
      <Card title="Resolution updates">
        <p className="text-sm leading-6 text-[var(--color-muted)]">Support will update this dispute when customer, supplier, or admin evidence changes.</p>
      </Card>
    </MobileSupportShell>
  );
}

export function ResellerSupportCenterScreen() {
  return (
    <MobileSupportShell active="Support" eyebrow="Commission and order help" nav={resellerNav} title="Reseller Support">
      <Card>
        <p className="text-sm leading-6 text-[var(--color-muted)]">Pending commission is not withdrawable until supplier settlement is verified.</p>
      </Card>
      <IssueCategoryCard title="Missing commission" description="Check why an expected commission has not become available." selected />
      <IssueCategoryCard title="Commission disputes" description="Track disputed order commissions and support follow-up." />
      <IssueCategoryCard title="Order and customer issue" description="Get support when an order blocks commission." />
    </MobileSupportShell>
  );
}

export function ResellerSupportTicketsScreen() {
  return (
    <MobileSupportShell active="Support" backHref="/reseller/support" nav={resellerNav} title="Reseller Support Tickets">
      <TicketList party="Reseller" />
    </MobileSupportShell>
  );
}

export function ResellerSupportTicketDetailScreen({ ticketId }: { ticketId: string }) {
  const ticket = getTicket(ticketId);
  return (
    <MobileSupportShell active="Support" backHref="/reseller/support/tickets" nav={resellerNav} title="Ticket Detail">
      <SupportTicketDetail ticket={ticket} />
      <CommissionImpactCard />
    </MobileSupportShell>
  );
}

export function ResellerMissingCommissionScreen() {
  return (
    <MobileSupportShell active="Support" backHref="/reseller/support" nav={resellerNav} title="Missing Commission">
      <CommissionImpactCard />
      <Card title="Common reasons">
        {["Order settlement not verified", "Dispute is open", "Order cancelled or returned", "Settlement overdue"].map((reason) => (
          <InfoRow key={reason} label={reason} value="May keep commission pending" />
        ))}
      </Card>
      <Button className="w-full" type="button">Submit Commission Check Mock</Button>
    </MobileSupportShell>
  );
}

export function ResellerCommissionDisputeDetailScreen({ disputeId }: { disputeId: string }) {
  const dispute = getDispute(disputeId);
  return (
    <MobileSupportShell active="Support" backHref="/reseller/support/tickets" nav={resellerNav} title="Commission Dispute">
      <DisputeSummaryCard dispute={dispute} />
      <CommissionImpactCard amount={dispute.commissionImpact} />
      <DisputeTimeline />
    </MobileSupportShell>
  );
}

export function SupplierSupportCenterScreen() {
  return (
    <MobileSupportShell active="Support" eyebrow="Settlement and return help" nav={supplierNav} title="Supplier Support">
      <Card>
        <p className="text-sm leading-6 text-[var(--color-muted)]">No real payout, settlement, or upload integration is connected.</p>
      </Card>
      <IssueCategoryCard title="Settlement dispute" description="Ask admin finance to review payment proof or due amount." selected />
      <IssueCategoryCard title="Returns from customers" description="Track return requests and supplier-side inspection." />
      <IssueCategoryCard title="Order preparation issue" description="Report preparation, stock, or delivery blockers." />
    </MobileSupportShell>
  );
}

export function SupplierSupportTicketsScreen() {
  return (
    <MobileSupportShell active="Support" backHref="/supplier/support" nav={supplierNav} title="Supplier Support Tickets">
      <TicketList party="Supplier" />
    </MobileSupportShell>
  );
}

export function SupplierSupportTicketDetailScreen({ ticketId }: { ticketId: string }) {
  const ticket = getTicket(ticketId);
  return (
    <MobileSupportShell active="Support" backHref="/supplier/support/tickets" nav={supplierNav} title="Ticket Detail">
      <SupportTicketDetail ticket={ticket} />
      <SettlementImpactCard />
      <p className="rounded-[var(--radius-md)] bg-[var(--color-warning-soft)] p-3 text-sm font-semibold text-[#8A5A00]">Proof verification is mock-only.</p>
    </MobileSupportShell>
  );
}

export function SupplierSettlementDisputeScreen() {
  return (
    <MobileSupportShell active="Support" backHref="/supplier/support" nav={supplierNav} title="Settlement Dispute">
      <SettlementImpactCard />
      <Card title="Settlement proof dispute">
        <label className="block text-sm font-bold text-[var(--color-charcoal)]">
          Reference number
          <Input aria-label="Reference number" className="mt-2" defaultValue="MOMO-REF-8391" />
        </label>
        <div className="mt-3">
          <EvidenceUploadPlaceholder />
        </div>
      </Card>
      <Button className="w-full" type="button">Submit Settlement Dispute Mock</Button>
    </MobileSupportShell>
  );
}

export function SupplierSettlementDisputeDetailScreen({ disputeId }: { disputeId: string }) {
  const dispute = getDispute(disputeId);
  return (
    <MobileSupportShell active="Support" backHref="/supplier/support/tickets" nav={supplierNav} title="Supplier Settlement Dispute">
      <DisputeSummaryCard dispute={dispute} />
      <SettlementImpactCard amount={dispute.settlementImpact} />
      <Card title="Admin finance verification required.">
        <p className="text-sm leading-6 text-[var(--color-muted)]">Settlement remains disputed until admin finance verifies proof and clears the account.</p>
      </Card>
    </MobileSupportShell>
  );
}

export function SupplierReturnsScreen() {
  return (
    <MobileSupportShell active="Support" backHref="/supplier/support" nav={supplierNav} title="Supplier Returns">
      <Card title="Returns requiring supplier review">
        <div className="space-y-3">
          {returns.map((item) => (
            <ReturnRow key={item.id} item={item} />
          ))}
        </div>
      </Card>
      <Card title="Supplier action guide">
        <div className="mb-3 flex flex-wrap gap-2">
          <StatusBadge status="Return Approved" />
          <StatusBadge status="Returned to Supplier" />
        </div>
        <InfoRow label="Inspect returned item" value="Check condition before restock." />
        <InfoRow label="Restock only after review" value="Returned stock should not auto-return to inventory." />
      </Card>
    </MobileSupportShell>
  );
}

function ReturnRow({ item }: { item: ReturnRequest }) {
  return (
    <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-bold">{item.id}</p>
          <p className="mt-1 text-sm text-[var(--color-muted)]">{item.product}</p>
        </div>
        <StatusBadge status={item.status} />
      </div>
      <p className="mt-2 text-sm font-semibold text-[var(--color-primary)]">{item.nextAction}</p>
    </div>
  );
}

function DataTable({ columns, rows }: { columns: string[]; rows: ReactNode[][] }) {
  return (
    <div className="overflow-x-auto rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white shadow-[var(--shadow-sm)]">
      <table className="min-w-[980px] w-full text-left text-sm">
        <thead className="bg-[var(--color-muted-soft)] text-xs uppercase text-[var(--color-muted)]">
          <tr>{columns.map((column) => <th className="px-4 py-3 font-bold" key={column}>{column}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr className="border-t border-[var(--color-border)]" key={index}>
              {row.map((cell, cellIndex) => <td className="px-4 py-3 align-top" key={cellIndex}>{cell}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function SupportTicketTable({ tickets = supportTickets }: { tickets?: SupportTicket[] }) {
  return (
    <DataTable
      columns={["Ticket", "Issue", "Party", "Priority", "Status", "Owner"]}
      rows={tickets.map((ticket) => [
        ticket.id,
        ticket.title,
        ticket.party,
        <StatusBadge key={`${ticket.id}-priority`} status={ticket.priority} />,
        <StatusBadge key={`${ticket.id}-status`} status={ticket.status} />,
        ticket.owner
      ])}
    />
  );
}

export function AdminSupportInboxScreen() {
  return (
    <AdminShell active="Support">
      <AdminHeader eyebrow="Support operations" title="Admin Support Inbox">
        <StatusBadge status="Mock Only" />
      </AdminHeader>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <SummaryStat label="Open tickets" value="18" tone="warning" />
        <SummaryStat label="High priority" value="6" tone="danger" />
        <SummaryStat label="Assigned to me" value="9" tone="info" />
        <SummaryStat label="SLA watch" value="4" tone="warning" />
      </div>
      <Card title="Recent support tickets">
        <SupportTicketTable />
      </Card>
    </AdminShell>
  );
}

export function AdminSupportTicketsScreen() {
  return (
    <AdminShell active="Support">
      <AdminHeader eyebrow="Ticket management" title="Support Tickets" />
      <SupportTicketTable />
    </AdminShell>
  );
}

export function AdminSupportTicketDetailScreen({ ticketId }: { ticketId: string }) {
  const ticket = getTicket(ticketId);
  return (
    <AdminShell active="Support">
      <AdminHeader eyebrow="Ticket detail" title="Support Ticket Detail">
        <StatusBadge status={ticket.status} />
      </AdminHeader>
      <div className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
        <div className="space-y-5">
          <SupportTicketDetail ticket={ticket} />
          <ResolutionPanel />
        </div>
        <div className="space-y-5">
          <InternalNotesCard />
          <AuditPreview />
        </div>
      </div>
    </AdminShell>
  );
}

export function AdminDisputesScreen() {
  return (
    <AdminShell active="Disputes">
      <AdminHeader eyebrow="Dispute operations" title="Disputes" />
      <Card title="Dispute status filters">
        <div className="flex flex-wrap gap-2">
          {disputeStatuses.map((status) => <StatusBadge key={status} status={status} />)}
        </div>
      </Card>
      <DataTable
        columns={["Dispute", "Type", "Order", "Priority", "Status", "Next Action"]}
        rows={disputes.map((dispute) => [
          dispute.id,
          dispute.type,
          dispute.orderId,
          <StatusBadge key={`${dispute.id}-priority`} status={dispute.priority} />,
          <StatusBadge key={`${dispute.id}-status`} status={dispute.status} />,
          dispute.nextAction
        ])}
      />
    </AdminShell>
  );
}

export function AdminDisputeDetail({ dispute }: { dispute: Dispute }) {
  return (
    <div className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
      <div className="space-y-5">
        <DisputeSummaryCard dispute={dispute} />
        <OrderContextCard />
        <Card title="Evidence review">
          <EvidenceUploadPlaceholder label="Evidence review" />
        </Card>
        <ResolutionPanel />
      </div>
      <div className="space-y-5">
        <CommissionImpactCard amount={dispute.commissionImpact} />
        <SettlementImpactCard amount={dispute.settlementImpact} />
        <InternalNotesCard />
        <AuditPreview />
      </div>
    </div>
  );
}

export function AdminDisputeDetailScreen({ disputeId }: { disputeId: string }) {
  const dispute = getDispute(disputeId);
  return (
    <AdminShell active="Disputes">
      <AdminHeader eyebrow="Dispute detail" title="Admin Dispute Detail">
        <StatusBadge status={dispute.status} />
      </AdminHeader>
      <AdminDisputeDetail dispute={dispute} />
    </AdminShell>
  );
}

export function AdminReturnsScreen() {
  return (
    <AdminShell active="Returns">
      <AdminHeader eyebrow="Return review" title="Returns" />
      <Card title="Return statuses">
        <div className="flex flex-wrap gap-2">
          {returnStatuses.map((status) => <StatusBadge key={status} status={status} />)}
        </div>
      </Card>
      <DataTable
        columns={["Return", "Order", "Product", "Reason", "Status", "Next Action"]}
        rows={returns.map((item) => [item.id, item.orderId, <SupportProductContext key={`${item.id}-product`} product={item.product} />, item.reason, <StatusBadge key={`${item.id}-status`} status={item.status} />, item.nextAction])}
      />
    </AdminShell>
  );
}

export function AdminReturnDetailScreen({ returnId }: { returnId: string }) {
  const item = getReturnRequest(returnId);
  return (
    <AdminShell active="Returns">
      <AdminHeader eyebrow="Return detail" title="Return Detail">
        <StatusBadge status={item.status} />
      </AdminHeader>
      <div className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
        <Card title="Returned item inspection">
          <div className="mb-4 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-[var(--color-page)] p-3">
            <SupportProductContext product={item.product} size="md" />
          </div>
          <InfoRow label="Return ID" value={item.id} />
          <InfoRow label="Order" value={item.orderId} />
          <InfoRow label="Product" value={item.product} />
          <InfoRow label="Reason" value={item.reason} />
          <InfoRow label="Refund link" value="RFD-RSR-20260713-00021" />
        </Card>
        <Card title="Return actions">
          <div className="grid gap-2">
            <Button type="button">Approve Return Mock</Button>
            <Button type="button" variant="danger">Reject Return Mock</Button>
            <Button type="button" variant="outline">Request More Evidence</Button>
          </div>
        </Card>
      </div>
    </AdminShell>
  );
}

export function AdminRefundsScreen() {
  return (
    <AdminShell active="Refunds">
      <AdminHeader eyebrow="Refund tracking" title="Refunds" />
      <Card title="Refund states">
        <div className="flex flex-wrap gap-2">
          {refunds.map((refund) => <StatusBadge key={refund.id} status={refund.status} />)}
        </div>
      </Card>
      <DataTable
        columns={["Refund", "Order", "Method", "Amount", "Status", "Note"]}
        rows={refunds.map((refund) => [refund.id, refund.orderId, refund.method, formatGhc(refund.amount), <StatusBadge key={`${refund.id}-status`} status={refund.status} />, refund.note])}
      />
    </AdminShell>
  );
}

export function AdminRefundDetailScreen({ refundId }: { refundId: string }) {
  const refund = getRefund(refundId);
  return (
    <AdminShell active="Refunds">
      <AdminHeader eyebrow="Refund detail" title="Refund Detail">
        <StatusBadge status={refund.status} />
      </AdminHeader>
      <div className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
        <RefundStatusCard refund={refund} />
        <div className="space-y-5">
          <Card title="Refund actions">
            <div className="grid gap-2">
              <Button type="button">Mark Refund Completed Mock</Button>
              <Button type="button" variant="danger">Reject Refund Mock</Button>
            </div>
          </Card>
          <AuditPreview />
        </div>
      </div>
    </AdminShell>
  );
}

function AuditPreview() {
  return (
    <Card title="Audit preview">
      <div className="space-y-3">
        {["Ticket opened by customer", "Support requested evidence", "Admin viewed mock dispute"].map((item, index) => (
          <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-3" key={item}>
            <p className="text-sm font-bold">{item}</p>
            <p className="mt-1 text-xs text-[var(--color-muted)]">13 July 2026, 12:{20 + index * 5} PM • mock audit entry</p>
          </div>
        ))}
      </div>
    </Card>
  );
}
