"use client";

import { useActionState, useEffect, useState } from "react";
import Link from "next/link";
import { AlertCircle, ArrowLeft, FileWarning, Home, MessageSquare, PackageCheck, Send, UserRound } from "lucide-react";
import { openCustomerDisputeAction, addCustomerDisputeResponseAction } from "@/app/customer/disputes/actions";
import { MobileShell } from "@/components/layout/MobileShell";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { ErrorState } from "@/components/ui/ErrorState";
import { Select } from "@/components/ui/Select";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { Textarea } from "@/components/ui/Textarea";
import {
  customerDisputeOutcomeOptions,
  customerDisputeItemSpecificReasonCodes,
  customerDisputeReasonOptions,
  initialCustomerDisputeActionState,
  type CustomerDispute,
  type CustomerDisputeActionState,
  type CustomerDisputeListItem,
  type CustomerDisputeOrderItemSafe
} from "@/lib/customer/dispute-shared";
import type { CustomerOrderSafe } from "@/lib/orders/customer-order-read";
import { cn } from "@/lib/utils/cn";

function CustomerBottomNav({ active }: { active: "orders" | "disputes" | "account" }) {
  const items = [
    { key: "orders", label: "Orders", href: "/customer/orders", icon: PackageCheck },
    { key: "disputes", label: "Disputes", href: "/customer/disputes", icon: FileWarning },
    { key: "account", label: "Account", href: "/customer/addresses", icon: UserRound }
  ] as const;

  return (
    <nav className="fixed inset-x-0 bottom-0 z-30 border-t border-[var(--color-border)] bg-white/95 px-4 pb-4 pt-2 shadow-[0_-10px_30px_rgba(17,24,39,0.08)] backdrop-blur">
      <div className="mx-auto grid max-w-md grid-cols-3 gap-2">
        {items.map(({ key, label, href, icon: Icon }) => (
          <Link
            aria-current={active === key ? "page" : undefined}
            className={cn(
              "grid min-h-12 place-items-center rounded-[var(--radius-md)] px-2 py-1 text-xs font-bold",
              active === key ? "bg-[var(--color-primary-subtle)] text-[var(--color-primary)]" : "text-[var(--color-muted)]"
            )}
            href={href}
            key={key}
          >
            <Icon className="h-4 w-4" aria-hidden="true" />
            <span>{label}</span>
          </Link>
        ))}
      </div>
    </nav>
  );
}

function CustomerPageHeader({ title, eyebrow, backHref }: { title: string; eyebrow?: string; backHref?: string }) {
  return (
    <header className="flex items-start gap-3">
      {backHref ? (
        <Link
          aria-label="Go back"
          className="grid h-10 w-10 shrink-0 place-items-center rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white text-[var(--color-charcoal)]"
          href={backHref}
        >
          <ArrowLeft className="h-4 w-4" />
        </Link>
      ) : null}
      <div className="min-w-0">
        {eyebrow ? <p className="text-xs font-bold uppercase text-[var(--color-primary)]">{eyebrow}</p> : null}
        <h1 className="text-[22px] font-bold leading-tight text-[var(--color-charcoal)]">{title}</h1>
      </div>
    </header>
  );
}

function formatDateTime(value: string) {
  if (!value) {
    return "Not available";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "Not available";
  }

  return new Intl.DateTimeFormat("en-GH", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(date);
}

function ActionStateAlert({ state }: { state: CustomerDisputeActionState }) {
  if (!state.message) {
    return null;
  }

  const ok = state.code === "OK";

  return (
    <div
      className={cn(
        "rounded-[var(--radius-md)] border p-3 text-sm",
        ok
          ? "border-[var(--color-success)]/25 bg-[var(--color-success-soft)] text-[var(--color-success)]"
          : "border-[var(--color-danger)]/20 bg-[var(--color-danger-soft)] text-[var(--color-danger)]"
      )}
      role="status"
    >
      <p className="font-bold">{state.message}</p>
      {state.disputeHref ? (
        <Link className="mt-2 inline-flex font-bold text-[var(--color-primary)]" href={state.disputeHref}>
          View dispute
        </Link>
      ) : null}
    </div>
  );
}

function DisputeCard({ dispute }: { dispute: CustomerDisputeListItem }) {
  return (
    <Link
      className="block rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4 shadow-[var(--shadow-sm)] transition hover:border-[var(--color-primary)]"
      href={dispute.detailHref}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-xs font-bold uppercase text-[var(--color-muted)]">{dispute.safeOrderReference}</p>
          <h2 className="mt-1 text-base font-extrabold text-[var(--color-charcoal)]">{dispute.reasonLabel}</h2>
          <p className="mt-1 text-sm text-[var(--color-muted)]">{dispute.affectedItemSummary}</p>
        </div>
        <StatusBadge>{dispute.statusLabel}</StatusBadge>
      </div>
      <div className="mt-3 grid gap-2 text-sm text-[var(--color-muted)]">
        <p>
          <span className="font-bold text-[var(--color-charcoal)]">Outcome:</span> {dispute.requestedOutcomeLabel}
        </p>
        <p>
          <span className="font-bold text-[var(--color-charcoal)]">Next:</span> {dispute.safeNextAction ?? "Review in progress"}
        </p>
        {dispute.safeLatestMessage ? <p className="line-clamp-2">{dispute.safeLatestMessage}</p> : null}
      </div>
      <p className="mt-3 text-xs font-semibold text-[var(--color-muted)]">Opened {formatDateTime(dispute.openedAt)}</p>
    </Link>
  );
}

export function CustomerDisputeListScreen({
  disputes,
  state,
  status
}: {
  disputes: CustomerDisputeListItem[];
  state: CustomerDisputeActionState;
  status?: string | null;
}) {
  const filters = [
    { label: "All", href: "/customer/disputes", active: !status },
    { label: "Open", href: "/customer/disputes?status=open", active: status === "open" },
    { label: "Waiting for me", href: "/customer/disputes?status=awaiting_customer", active: status === "awaiting_customer" },
    { label: "Resolved", href: "/customer/disputes?status=resolved_customer", active: status === "resolved_customer" }
  ];

  return (
    <MobileShell footer={<CustomerBottomNav active="disputes" />}>
      <CustomerPageHeader title="Disputes" eyebrow="Customer support" />
      <Card className="bg-[var(--color-primary)] p-4 text-white">
        <div className="flex gap-3">
          <FileWarning className="mt-0.5 h-5 w-5 shrink-0 text-[var(--color-accent)]" aria-hidden="true" />
          <div>
            <h2 className="font-bold">Order issue tracking</h2>
            <p className="mt-1 text-sm leading-6 text-white/85">These cases are read from the customer-safe dispute boundary.</p>
          </div>
        </div>
      </Card>
      <div className="flex gap-2 overflow-x-auto pb-1">
        {filters.map((filter) => (
          <Link
            className={cn(
              "h-9 shrink-0 rounded-full border px-4 py-2 text-sm font-bold",
              filter.active
                ? "border-[var(--color-primary)] bg-[var(--color-primary)] text-white"
                : "border-[var(--color-border)] bg-white text-[var(--color-charcoal)]"
            )}
            href={filter.href}
            key={filter.label}
          >
            {filter.label}
          </Link>
        ))}
      </div>
      {state.code !== "OK" ? <ErrorState title="Disputes unavailable" description={state.message} /> : null}
      {state.code === "OK" && disputes.length === 0 ? (
        <EmptyState title="No disputes yet" description="Report a problem from an eligible order when you need help." action="Review orders" />
      ) : null}
      <section className="grid gap-3">
        {disputes.map((dispute) => (
          <DisputeCard dispute={dispute} key={dispute.disputeId} />
        ))}
      </section>
    </MobileShell>
  );
}

function MessageTimeline({ dispute }: { dispute: CustomerDispute }) {
  return (
    <Card title="Messages">
      <div className="grid gap-3">
        {dispute.messages.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No customer-visible messages yet.</p>
        ) : (
          dispute.messages.map((message, index) => (
            <article className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-page)] p-3" key={`${message.createdAt}-${index}`}>
              <div className="flex items-center justify-between gap-2">
                <p className="text-sm font-bold capitalize text-[var(--color-charcoal)]">{message.authorRole.replace(/_/g, " ")}</p>
                <p className="text-xs text-[var(--color-muted)]">{formatDateTime(message.createdAt)}</p>
              </div>
              <p className="mt-2 whitespace-pre-wrap text-sm leading-6 text-[var(--color-charcoal)]">{message.body}</p>
            </article>
          ))
        )}
      </div>
    </Card>
  );
}

const terminalDisputeStatuses = new Set([
  "cancelled",
  "closed",
  "partially_resolved",
  "rejected",
  "resolved_customer",
  "resolved_supplier"
]);

function CustomerResponseForm({ disputeId }: { disputeId: string }) {
  const [idempotencyKey] = useState(() => `customer-dispute-response-${crypto.randomUUID()}`);
  const [state, formAction, pending] = useActionState(addCustomerDisputeResponseAction.bind(null, disputeId), initialCustomerDisputeActionState);

  return (
    <Card title="Add a response">
      <form action={formAction} className="grid gap-3">
        <input name="idempotency_key" type="hidden" value={idempotencyKey} />
        <Textarea aria-label="Your response" maxLength={2000} name="body" placeholder="Add only customer-safe details. Do not include passwords, OTPs, card numbers, or private account data." required />
        <ActionStateAlert state={state} />
        <Button loading={pending} type="submit">
          <Send className="h-4 w-4" aria-hidden="true" />
          Send response
        </Button>
      </form>
    </Card>
  );
}

export function CustomerDisputeDetailScreen({ dispute }: { dispute: CustomerDispute }) {
  const canRespond = !terminalDisputeStatuses.has(dispute.status);

  return (
    <MobileShell footer={<CustomerBottomNav active="disputes" />}>
      <CustomerPageHeader title="Dispute details" eyebrow={dispute.safeOrderReference} backHref="/customer/disputes" />
      <Card>
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className="text-sm font-bold text-[var(--color-muted)]">{dispute.affectedItemSummary}</p>
            <h2 className="mt-1 text-xl font-extrabold text-[var(--color-charcoal)]">{dispute.reasonLabel}</h2>
          </div>
          <StatusBadge>{dispute.statusLabel}</StatusBadge>
        </div>
        <div className="mt-4 grid gap-2 text-sm text-[var(--color-muted)]">
          <p><span className="font-bold text-[var(--color-charcoal)]">Category:</span> {dispute.categoryLabel}</p>
          <p><span className="font-bold text-[var(--color-charcoal)]">Requested outcome:</span> {dispute.requestedOutcomeLabel}</p>
          <p><span className="font-bold text-[var(--color-charcoal)]">Next step:</span> {dispute.safeNextAction ?? "Review in progress"}</p>
          <p><span className="font-bold text-[var(--color-charcoal)]">Updated:</span> {formatDateTime(dispute.updatedAt)}</p>
        </div>
      </Card>
      {dispute.publicResolutionMessage ? (
        <Card className="border-[var(--color-success)]/25 bg-[var(--color-success-soft)]">
          <h2 className="font-bold text-[var(--color-charcoal)]">Resolution</h2>
          <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">{dispute.publicResolutionMessage}</p>
        </Card>
      ) : null}
      <MessageTimeline dispute={dispute} />
      <Card title="Status history">
        <ol className="grid gap-3">
          {dispute.statusHistory.map((entry, index) => (
            <li className="flex gap-3" key={`${entry.createdAt}-${index}`}>
              <span className="mt-1 grid h-7 w-7 shrink-0 place-items-center rounded-full bg-[var(--color-primary-subtle)] text-xs font-bold text-[var(--color-primary)]">
                {index + 1}
              </span>
              <div>
                <p className="font-bold text-[var(--color-charcoal)]">{entry.newStatus.replace(/_/g, " ")}</p>
                {entry.publicNote ? <p className="mt-1 text-sm text-[var(--color-muted)]">{entry.publicNote}</p> : null}
                <p className="mt-1 text-xs text-[var(--color-muted)]">{formatDateTime(entry.createdAt)}</p>
              </div>
            </li>
          ))}
        </ol>
      </Card>
      {canRespond ? (
        <CustomerResponseForm disputeId={dispute.disputeId} />
      ) : (
        <Card title="Responses closed">
          <p className="text-sm leading-6 text-[var(--color-muted)]">This dispute is in a terminal state, so the customer response form is no longer available.</p>
        </Card>
      )}
    </MobileShell>
  );
}

export function CustomerDisputeUnavailableScreen({ message }: { message: string }) {
  return (
    <MobileShell footer={<CustomerBottomNav active="disputes" />}>
      <CustomerPageHeader title="Dispute unavailable" backHref="/customer/disputes" />
      <ErrorState title="We could not load this dispute" description={message} />
    </MobileShell>
  );
}

export function CustomerReportProblemScreen({
  order,
  orderItems = [],
  orderItemsState = initialCustomerDisputeActionState
}: {
  order: CustomerOrderSafe;
  orderItems?: CustomerDisputeOrderItemSafe[];
  orderItemsState?: CustomerDisputeActionState;
}) {
  const [selectedReason, setSelectedReason] = useState("delivery_delay");
  const [selectedOrderItemId, setSelectedOrderItemId] = useState("");
  const [idempotencyKey] = useState(() => `customer-dispute-open-${crypto.randomUUID()}`);
  const selectedReasonRequiresItem = customerDisputeItemSpecificReasonCodes.has(selectedReason);
  const selectedItemBelongsToOptions = orderItems.some((item) => item.orderItemId === selectedOrderItemId);
  const itemSelectionMissing = selectedReasonRequiresItem && !selectedItemBelongsToOptions;
  const [state, formAction, pending] = useActionState(openCustomerDisputeAction.bind(null, order.orderId), initialCustomerDisputeActionState);
  const handleReasonSelection = (nextReason: string) => {
    setSelectedReason(nextReason);

    if (!customerDisputeItemSpecificReasonCodes.has(nextReason)) {
      setSelectedOrderItemId("");
    }
  };

  useEffect(() => {
    if (state.code === "OK" && state.disputeHref) {
      window.location.assign(state.disputeHref);
    }
  }, [state.code, state.disputeHref]);

  return (
    <MobileShell footer={<CustomerBottomNav active="orders" />}>
      <CustomerPageHeader title="Report a problem" eyebrow={order.orderNumber} backHref={`/customer/orders/${order.orderId}`} />
      <Card>
        <div className="flex gap-3">
          <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-[var(--color-warning)]" aria-hidden="true" />
          <div>
            <h2 className="font-bold text-[var(--color-charcoal)]">Open a customer dispute</h2>
            <p className="mt-1 text-sm leading-6 text-[var(--color-muted)]">
              This sends your issue through the audited customer dispute RPC. It does not create a refund, return, payment, stock, or delivery action.
            </p>
          </div>
        </div>
      </Card>
      <Card title="Order summary">
        <div className="grid gap-2 text-sm">
          <p className="font-bold text-[var(--color-charcoal)]">{order.productName}</p>
          <p className="text-[var(--color-muted)]">{order.orderStatusLabel}</p>
          <p className="text-[var(--color-muted)]">{order.paymentMethodLabel} - {order.paymentCollectionLabel}</p>
        </div>
      </Card>
      <Card title="Problem details">
        <form action={formAction} className="grid gap-3">
          <input name="idempotency_key" type="hidden" value={idempotencyKey} />
          <label className="grid gap-2 text-sm font-bold text-[var(--color-charcoal)]">
            What happened?
            <Select
              name="reason_code"
              onChange={(event) => handleReasonSelection(event.currentTarget.value)}
              onInput={(event) => handleReasonSelection(event.currentTarget.value)}
              required
              value={selectedReason}
            >
              {customerDisputeReasonOptions.map((option) => (
                <option key={option.reasonCode} value={option.reasonCode}>
                  {option.label}
                </option>
              ))}
            </Select>
          </label>
          {orderItemsState.code !== "OK" || orderItems.length > 0 ? (
            <fieldset aria-describedby="customer-dispute-item-selector-help" className="grid gap-3">
              <legend className="text-sm font-bold text-[var(--color-charcoal)]">Select the affected item</legend>
              {orderItemsState.code !== "OK" ? <ErrorState title="Items unavailable" description={orderItemsState.message} /> : null}
              {orderItemsState.code === "OK" && orderItems.length === 0 ? (
                <EmptyState title="No selectable items" description="This order does not have a customer-safe item selector yet." />
              ) : null}
              <div className="grid gap-2">
                {orderItems.map((item) => {
                  const selected = selectedOrderItemId === item.orderItemId;

                  return (
                    <label
                      className={cn(
                        "grid cursor-pointer gap-2 rounded-[var(--radius-md)] border bg-white p-3 text-sm transition",
                        selected
                          ? "border-[var(--color-primary)] bg-[var(--color-primary-subtle)] text-[var(--color-charcoal)]"
                          : "border-[var(--color-border)] text-[var(--color-muted)]"
                      )}
                      key={item.orderItemId}
                    >
                      <span className="flex items-start gap-3">
                        <input
                          className="mt-1 h-4 w-4 accent-[var(--color-primary)]"
                          name="order_item_id"
                          onChange={() => setSelectedOrderItemId(item.orderItemId)}
                          type="radio"
                          value={item.orderItemId}
                        />
                        <span className="min-w-0">
                          <span className="block font-bold text-[var(--color-charcoal)]">{item.safeItemName}</span>
                          {item.safeVariantSummary ? <span className="block break-words">{item.safeVariantSummary}</span> : null}
                          <span className="block">Quantity {item.quantity}</span>
                          {item.lineTotalAmount !== null ? (
                            <span className="block">
                              {item.currencyCode} {item.lineTotalAmount.toFixed(2)}
                            </span>
                          ) : null}
                        </span>
                      </span>
                      {selected ? <span className="text-xs font-bold text-[var(--color-primary)]">Selected item</span> : null}
                    </label>
                  );
                })}
              </div>
              <p className="text-xs leading-5 text-[var(--color-muted)]" id="customer-dispute-item-selector-help">
                Item-specific issues use only this safe order item ID. Supplier assignment is derived by the audited RPC.
              </p>
              {itemSelectionMissing ? (
                <p className="rounded-[var(--radius-md)] border border-[var(--color-danger)]/20 bg-[var(--color-danger-soft)] p-3 text-sm font-bold text-[var(--color-danger)]" role="alert">
                  Select the affected item before submitting this issue.
                </p>
              ) : null}
            </fieldset>
          ) : null}
          <label className="grid gap-2 text-sm font-bold text-[var(--color-charcoal)]">
            Requested outcome
            <Select name="requested_outcome" required>
              {customerDisputeOutcomeOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </Select>
          </label>
          <label className="grid gap-2 text-sm font-bold text-[var(--color-charcoal)]">
            Description
            <Textarea maxLength={1200} name="description" placeholder="Describe the problem. Do not include passwords, OTPs, card numbers, or private account data." required />
          </label>
          <p className="text-xs leading-5 text-[var(--color-muted)]">
            Supplier assignment remains backend-derived. No supplier IDs, margins, commissions, stock internals, or finance fields are sent from this form.
          </p>
          <ActionStateAlert state={state} />
          <Button disabled={itemSelectionMissing} loading={pending} size="large" type="submit">
            <MessageSquare className="h-4 w-4" aria-hidden="true" />
            Submit dispute
          </Button>
        </form>
      </Card>
      <Link className="inline-flex items-center justify-center gap-2 text-sm font-bold text-[var(--color-primary)]" href="/customer/disputes">
        <Home className="h-4 w-4" aria-hidden="true" />
        View all disputes
      </Link>
    </MobileShell>
  );
}
