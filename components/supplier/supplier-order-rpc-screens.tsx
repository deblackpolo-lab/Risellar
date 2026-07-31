"use client";

import Link from "next/link";
import { useMemo, useState, type ReactNode } from "react";
import { ArrowLeft, CheckCircle2, PackageCheck, RotateCw, Truck, XCircle } from "lucide-react";
import { useFormStatus } from "react-dom";
import { Button, Card, Select, StatusBadge, Textarea } from "@/components/ui";
import {
  initialSupplierOrderState,
  supplierOrderDeliveryMethodCodes,
  supplierOrderRejectReasonCodes,
  type SupplierOrderSafe,
  type SupplierOrderState
} from "@/lib/orders/supplier-order-shared";
import { cn } from "@/lib/utils/cn";

type SupplierOrderAction = (formData: FormData) => void;

function formatMoney(amount: number | null, currencyCode: string) {
  if (amount === null) {
    return "Amount unavailable";
  }

  return `${currencyCode} ${amount.toLocaleString("en-GH", { maximumFractionDigits: 2, minimumFractionDigits: 2 })}`;
}

function formatDate(value: string | null) {
  if (!value) {
    return "Not available";
  }

  return new Intl.DateTimeFormat("en-GH", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

function formatDateOnly(value: string | null) {
  if (!value) {
    return "Not set";
  }

  return new Intl.DateTimeFormat("en-GH", {
    dateStyle: "medium"
  }).format(new Date(`${value}T00:00:00`));
}

function snapshotText(snapshot: Record<string, unknown>, key: string) {
  const value = snapshot[key];
  return typeof value === "string" && value.trim() ? value : "Not set";
}

function SupplierOrdersShell({ children, title, eyebrow }: { children: ReactNode; title: string; eyebrow?: string }) {
  return (
    <main className="min-h-screen bg-[var(--color-page)] pb-24 text-[var(--color-charcoal)]">
      <section className="border-b border-[var(--color-border)] bg-white px-4 py-5">
        <div className="mx-auto max-w-6xl">
          {eyebrow ? <p className="text-xs font-bold uppercase tracking-normal text-[var(--color-primary)]">{eyebrow}</p> : null}
          <h1 className="mt-1 text-2xl font-extrabold tracking-normal text-[var(--color-charcoal)]">{title}</h1>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--color-muted)]">
            Review Pay on Delivery orders assigned to your supplier account. Preparation and handoff steps are handled in later phases.
          </p>
        </div>
      </section>
      <section className="mx-auto grid max-w-6xl gap-4 px-4 py-5">{children}</section>
    </main>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4 border-b border-[var(--color-border)] pb-2 last:border-b-0 last:pb-0">
      <span className="text-[var(--color-muted)]">{label}</span>
      <span className="text-right font-bold text-[var(--color-charcoal)]">{value}</span>
    </div>
  );
}

function ActionMessage({ state }: { state: SupplierOrderState }) {
  if (!state.message) {
    return null;
  }

  const isSuccess = state.code === "OK";

  return (
    <p
      className={
        isSuccess
          ? "rounded-[var(--radius-md)] border border-[var(--color-success)]/25 bg-[var(--color-success-soft)] px-4 py-3 text-sm font-semibold text-[var(--color-success)]"
          : "rounded-[var(--radius-md)] border border-[var(--color-danger)]/25 bg-[var(--color-danger-soft)] px-4 py-3 text-sm font-semibold text-[var(--color-danger)]"
      }
      role={isSuccess ? "status" : "alert"}
    >
      {state.message} {state.code !== "OK" ? `(${state.code})` : null}
    </p>
  );
}

function statusGroup(status: string) {
  if (status === "out_for_delivery") {
    return "Out for delivery";
  }

  if (status === "delivery_arranged") {
    return "Arranged";
  }

  if (status === "ready_for_delivery") {
    return "Ready";
  }

  if (status === "supplier_preparing") {
    return "Preparing";
  }

  if (status === "supplier_confirmed") {
    return "Confirmed";
  }

  if (status === "supplier_rejected") {
    return "Rejected";
  }

  return "New orders";
}

export function SupplierOrdersRpcScreen({ orders, error }: { orders: SupplierOrderSafe[]; error: SupplierOrderState | null }) {
  const groupedOrders = useMemo(() => {
    const groups = new Map<string, SupplierOrderSafe[]>([
      ["New orders", []],
      ["Confirmed", []],
      ["Preparing", []],
      ["Ready", []],
      ["Arranged", []],
      ["Out for delivery", []],
      ["Rejected", []]
    ]);

    for (const order of orders) {
      groups.get(statusGroup(order.orderStatus))?.push(order);
    }

    return groups;
  }, [orders]);

  return (
    <SupplierOrdersShell eyebrow="Supplier workspace" title="Supplier orders">
      {error && error.code !== "OK" ? <ActionMessage state={error} /> : null}
      {[...groupedOrders.entries()].map(([group, groupOrders]) => (
        <section className="grid gap-3" key={group}>
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-bold text-[var(--color-charcoal)]">{group}</h2>
            <StatusBadge status={`${groupOrders.length} order${groupOrders.length === 1 ? "" : "s"}`} />
          </div>
          {groupOrders.length === 0 ? (
            <Card className="p-4">
              <p className="text-sm text-[var(--color-muted)]">No orders in this section yet.</p>
            </Card>
          ) : (
            <div className="grid gap-3 md:grid-cols-2">
              {groupOrders.map((order) => (
                <SupplierOrderCard key={order.orderId} order={order} />
              ))}
            </div>
          )}
        </section>
      ))}
    </SupplierOrdersShell>
  );
}

function SupplierOrderCard({ order }: { order: SupplierOrderSafe }) {
  return (
    <Card className="grid gap-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-xs font-semibold uppercase text-[var(--color-primary)]">{order.orderNumber}</p>
          <h3 className="mt-1 text-base font-bold text-[var(--color-charcoal)]">{order.productName}</h3>
          <p className="mt-1 text-sm text-[var(--color-muted)]">Qty {order.quantity} for {order.recipientName ?? "recipient unavailable"}</p>
        </div>
        <StatusBadge status={order.orderStatusLabel} />
      </div>
      <div className="grid gap-2 text-sm sm:grid-cols-2">
        <InfoRow label="Expected" value={formatMoney(order.supplierAmountExpected, order.currencyCode)} />
        <InfoRow label="Payment" value={order.paymentStatusLabel} />
        <InfoRow label="Reservation" value={order.reservationStatusLabel} />
        <InfoRow label="Area" value={order.locationSummary ?? "Not set"} />
      </div>
      <Link
        className="inline-flex h-10 items-center justify-center rounded-[var(--radius-md)] border border-[var(--color-primary)] bg-white px-4 text-sm font-bold text-[var(--color-primary)]"
        href={`/supplier/orders/${order.orderId}`}
      >
        View order
      </Link>
    </Card>
  );
}

export function SupplierOrderNotFoundRpcScreen({ state = { code: "ORDER_NOT_FOUND", message: "This order is unavailable." } }: { state?: SupplierOrderState }) {
  return (
    <SupplierOrdersShell eyebrow="Supplier order" title="Order unavailable">
      <BackLink />
      <ActionMessage state={state} />
      <Card>
        <p className="text-sm leading-6 text-[var(--color-muted)]">This order is unavailable for the current supplier account.</p>
      </Card>
    </SupplierOrdersShell>
  );
}

export function SupplierOrderDetailRpcScreen({
  acceptAction,
  actionState = initialSupplierOrderState,
  markReadyForDeliveryAction,
  order,
  rejectAction,
  startPreparingAction,
  arrangeDeliveryAction,
  markOutForDeliveryAction
}: {
  acceptAction?: SupplierOrderAction;
  arrangeDeliveryAction?: SupplierOrderAction;
  actionState?: SupplierOrderState;
  markReadyForDeliveryAction?: SupplierOrderAction;
  order: SupplierOrderSafe;
  rejectAction?: SupplierOrderAction;
  startPreparingAction?: SupplierOrderAction;
  markOutForDeliveryAction?: SupplierOrderAction;
}) {
  return (
    <SupplierOrdersShell eyebrow="Supplier order" title={order.orderNumber}>
      <BackLink />
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_340px]">
        <div className="grid gap-4">
          <Card>
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-sm font-semibold text-[var(--color-primary)]">{order.orderStatusLabel}</p>
                <h2 className="mt-1 text-xl font-bold text-[var(--color-charcoal)]">{order.productName}</h2>
                <p className="mt-2 text-sm leading-6 text-[var(--color-muted)]">
                  Qty {order.quantity} {order.variantName ? `- ${order.variantName}` : null}
                </p>
              </div>
              <StatusBadge status={order.orderStatusLabel} />
            </div>
            <div className="mt-5 grid gap-3 text-sm sm:grid-cols-2">
              <InfoRow label="Supplier expected" value={formatMoney(order.supplierAmountExpected, order.currencyCode)} />
              <InfoRow label="Customer total" value={formatMoney(order.customerTotalAmount, order.currencyCode)} />
              <InfoRow label="Payment method" value={order.paymentMethodLabel} />
              <InfoRow label="Payment" value={order.paymentStatusLabel} />
              <InfoRow label="Reservation" value={order.reservationStatusLabel} />
              <InfoRow label="Reserved qty" value={String(order.reservationQuantity ?? order.quantity)} />
              <InfoRow label="Created" value={formatDate(order.createdAt)} />
              <InfoRow label="Expires" value={formatDate(order.reservationExpiresAt)} />
            </div>
          </Card>

          <Card title="Fulfilment contact">
            <div className="grid gap-3 text-sm">
              <InfoRow label="Recipient" value={order.recipientName ?? "Not set"} />
              <InfoRow label="Phone" value={order.recipientPhone ?? "Not set"} />
              <InfoRow label="WhatsApp" value={order.recipientWhatsapp ?? "Not set"} />
              <InfoRow label="Region" value={snapshotText(order.deliveryAddressSnapshot, "region")} />
              <InfoRow label="City" value={snapshotText(order.deliveryAddressSnapshot, "city")} />
              <InfoRow label="Area" value={snapshotText(order.deliveryAddressSnapshot, "area")} />
              <InfoRow label="Landmark" value={snapshotText(order.deliveryAddressSnapshot, "landmark")} />
              <InfoRow label="GhanaPost GPS" value={snapshotText(order.deliveryAddressSnapshot, "ghana_post_gps")} />
            </div>
          </Card>

          <Card title="Reseller shop context">
            <div className="grid gap-3 text-sm">
              <InfoRow label="Shop" value={order.resellerShopName ?? "Not set"} />
              <InfoRow label="Slug" value={order.resellerShopSlug ?? "Not set"} />
            </div>
          </Card>

          <SupplierOrderTimeline order={order} />
        </div>

        <aside className="grid content-start gap-4">
          <ActionMessage state={actionState} />
          <SupplierOrderDecisionActions
            acceptAction={acceptAction}
            arrangeDeliveryAction={arrangeDeliveryAction}
            markOutForDeliveryAction={markOutForDeliveryAction}
            markReadyForDeliveryAction={markReadyForDeliveryAction}
            order={order}
            rejectAction={rejectAction}
            startPreparingAction={startPreparingAction}
          />
        </aside>
      </div>
    </SupplierOrdersShell>
  );
}

export function SupplierOrderDecisionActions({
  acceptAction,
  markReadyForDeliveryAction,
  order,
  rejectAction,
  startPreparingAction,
  arrangeDeliveryAction,
  markOutForDeliveryAction
}: {
  acceptAction?: SupplierOrderAction;
  arrangeDeliveryAction?: SupplierOrderAction;
  markReadyForDeliveryAction?: SupplierOrderAction;
  markOutForDeliveryAction?: SupplierOrderAction;
  order: SupplierOrderSafe;
  rejectAction?: SupplierOrderAction;
  startPreparingAction?: SupplierOrderAction;
}) {
  const [fulfilmentAcknowledged, setFulfilmentAcknowledged] = useState(false);
  const [preparationAcknowledged, setPreparationAcknowledged] = useState(false);
  const [readyAcknowledged, setReadyAcknowledged] = useState(false);
  const [deliveryAcknowledged, setDeliveryAcknowledged] = useState(false);
  const [outForDeliveryAcknowledged, setOutForDeliveryAcknowledged] = useState(false);
  const [deliveryMethod, setDeliveryMethod] = useState("manually_arranged");
  const [customerInstruction, setCustomerInstruction] = useState("");
  const [supplierPrivateNote, setSupplierPrivateNote] = useState("");
  const [dispatchCustomerInstruction, setDispatchCustomerInstruction] = useState("");
  const [reasonCode, setReasonCode] = useState("");
  const [reasonNote, setReasonNote] = useState("");
  const canAct = order.isSupplierActionable && order.orderStatus === "placed_pending_confirmation";
  const canStartPreparing =
    order.orderStatus === "supplier_confirmed" &&
    order.reservationStatusLabel.toLowerCase().includes("reserved") &&
    !order.reservationStatusLabel.toLowerCase().includes("expired");
  const canMarkReady =
    order.orderStatus === "supplier_preparing" &&
    order.reservationStatusLabel.toLowerCase().includes("reserved") &&
    !order.reservationStatusLabel.toLowerCase().includes("expired");
  const canArrangeDelivery =
    order.orderStatus === "ready_for_delivery" &&
    order.reservationStatusLabel.toLowerCase().includes("reserved") &&
    !order.reservationStatusLabel.toLowerCase().includes("expired");
  const canMarkOutForDelivery =
    order.orderStatus === "delivery_arranged" &&
    order.reservationStatusLabel.toLowerCase().includes("reserved") &&
    !order.reservationStatusLabel.toLowerCase().includes("expired");

  if (canStartPreparing && startPreparingAction) {
    return (
      <Card title="Start preparation">
        <form action={startPreparingAction} className="grid gap-4">
          <input name="order_id" type="hidden" value={order.orderId} />
          <input name="idempotency_key" type="hidden" value={`supplier-start-preparing:${order.orderId}`} />
          <p className="text-sm leading-6 text-[var(--color-muted)]">
            Start preparing this order only when you are ready to begin fulfilment. Delivery and payment are handled later.
          </p>
          <label className="flex items-start gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm font-semibold leading-6 text-[var(--color-charcoal)]">
            <input
              checked={preparationAcknowledged}
              className="mt-1 h-4 w-4 rounded border-[var(--color-border)] accent-[var(--color-primary)]"
              name="preparation_acknowledgement"
              onChange={(event) => setPreparationAcknowledged(event.currentTarget.checked)}
              type="checkbox"
              value="confirmed"
            />
            Confirm that you are starting preparation for this order.
          </label>
          <SupplierSubmitButton
            disabled={!preparationAcknowledged}
            icon={<PackageCheck className="h-4 w-4" aria-hidden="true" />}
            label="Start preparing"
            pendingLabel="Starting preparation..."
          />
        </form>
      </Card>
    );
  }

  if (canMarkReady && markReadyForDeliveryAction) {
    return (
      <Card title="Ready for delivery">
        <form action={markReadyForDeliveryAction} className="grid gap-4">
          <input name="order_id" type="hidden" value={order.orderId} />
          <input name="idempotency_key" type="hidden" value={`supplier-ready-for-delivery:${order.orderId}`} />
          <p className="text-sm leading-6 text-[var(--color-muted)]">
            Mark this order ready only when preparation is complete. Delivery arrangements will be handled separately.
          </p>
          <label className="flex items-start gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm font-semibold leading-6 text-[var(--color-charcoal)]">
            <input
              checked={readyAcknowledged}
              className="mt-1 h-4 w-4 rounded border-[var(--color-border)] accent-[var(--color-primary)]"
              name="ready_for_delivery_acknowledgement"
              onChange={(event) => setReadyAcknowledged(event.currentTarget.checked)}
              type="checkbox"
              value="confirmed"
            />
            Confirm that this order is fully prepared and ready for delivery arrangement.
          </label>
          <SupplierSubmitButton
            disabled={!readyAcknowledged}
            icon={<PackageCheck className="h-4 w-4" aria-hidden="true" />}
            label="Mark ready for delivery"
            pendingLabel="Marking order ready..."
          />
        </form>
      </Card>
    );
  }

  if (canArrangeDelivery && arrangeDeliveryAction) {
    return (
      <Card title="Arrange delivery">
        <form action={arrangeDeliveryAction} className="grid gap-4">
          <input name="order_id" type="hidden" value={order.orderId} />
          <input name="idempotency_key" type="hidden" value={`supplier-arrange-delivery:${order.orderId}`} />
          <p className="text-sm leading-6 text-[var(--color-muted)]">
            Record the manual delivery arrangement once you and the customer have agreed the handoff outside Risellar. This does not book a courier, assign a rider, collect payment, or mark the order delivered.
          </p>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Delivery method
            <Select name="delivery_method" required value={deliveryMethod} onChange={(event) => setDeliveryMethod(event.target.value)}>
              {supplierOrderDeliveryMethodCodes.map((method) => (
                <option key={method} value={method}>
                  {method.replaceAll("_", " ")}
                </option>
              ))}
            </Select>
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Agreed delivery fee
            <input
              className="min-h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-3 text-sm text-[var(--color-charcoal)] outline-none focus:border-[var(--color-primary)]"
              min="0"
              name="agreed_delivery_fee_amount"
              placeholder="Optional"
              step="0.01"
              type="number"
            />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Expected date
            <input
              className="min-h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-3 text-sm text-[var(--color-charcoal)] outline-none focus:border-[var(--color-primary)]"
              name="expected_delivery_date"
              type="date"
            />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Expected time window
            <input
              className="min-h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-3 text-sm text-[var(--color-charcoal)] outline-none focus:border-[var(--color-primary)]"
              maxLength={100}
              name="expected_time_window"
              placeholder="Optional"
              type="text"
            />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Courier or rider display name
            <input
              className="min-h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-3 text-sm text-[var(--color-charcoal)] outline-none focus:border-[var(--color-primary)]"
              maxLength={120}
              name="courier_display_name"
              placeholder="Optional"
              type="text"
            />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Courier or rider phone
            <input
              className="min-h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-3 text-sm text-[var(--color-charcoal)] outline-none focus:border-[var(--color-primary)]"
              maxLength={40}
              name="courier_phone"
              placeholder="Optional"
              type="tel"
            />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Customer instruction
            <Textarea
              aria-label="Customer instruction"
              maxLength={500}
              name="customer_instruction"
              placeholder="Optional instruction visible to the customer"
              value={customerInstruction}
              onChange={(event) => setCustomerInstruction(event.target.value)}
            />
            <span className="text-xs font-semibold text-[var(--color-muted)]">{customerInstruction.length}/500</span>
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Private supplier note
            <Textarea
              aria-label="Private supplier note"
              maxLength={500}
              name="supplier_private_note"
              placeholder="Optional internal supplier note"
              value={supplierPrivateNote}
              onChange={(event) => setSupplierPrivateNote(event.target.value)}
            />
            <span className="text-xs font-semibold text-[var(--color-muted)]">{supplierPrivateNote.length}/500</span>
          </label>
          <label className="flex items-start gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm font-semibold leading-6 text-[var(--color-charcoal)]">
            <input
              checked={deliveryAcknowledged}
              className="mt-1 h-4 w-4 rounded border-[var(--color-border)] accent-[var(--color-primary)]"
              name="delivery_arrangement_acknowledgement"
              onChange={(event) => setDeliveryAcknowledged(event.currentTarget.checked)}
              type="checkbox"
              value="confirmed"
            />
            Confirm this is a manual arrangement outside Risellar and no payment, delivery booking, rider assignment, tracking, or completion is being triggered.
          </label>
          <SupplierSubmitButton
            disabled={!deliveryAcknowledged}
            icon={<Truck className="h-4 w-4" aria-hidden="true" />}
            label="Save delivery arrangement"
            pendingLabel="Saving arrangement..."
          />
        </form>
      </Card>
    );
  }

  if (canMarkOutForDelivery && markOutForDeliveryAction) {
    return (
      <Card title="Out for delivery">
        <form action={markOutForDeliveryAction} className="grid gap-4">
          <input name="order_id" type="hidden" value={order.orderId} />
          <input name="idempotency_key" type="hidden" value={`supplier-out-for-delivery:${order.orderId}`} />
          <p className="text-sm leading-6 text-[var(--color-muted)]">
            Use this only after the order has been handed to the rider, courier, or customer pickup contact. Risellar does not provide live tracking or collect payment.
          </p>
          <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-muted-soft)] p-3 text-sm">
            <div className="grid gap-3">
              <InfoRow label="Method" value={order.deliveryArrangementMethodLabel ?? "Not set"} />
              <InfoRow label="Agreed fee" value={formatMoney(order.deliveryArrangementFeeAmount, order.deliveryArrangementCurrencyCode ?? order.currencyCode)} />
              <InfoRow label="Customer instruction" value={order.deliveryArrangementCustomerInstruction ?? "Not set"} />
              <InfoRow label="Private note" value={order.deliveryArrangementSupplierPrivateNote ?? "Not set"} />
            </div>
          </div>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Dispatch reference
            <input
              className="min-h-11 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white px-3 text-sm text-[var(--color-charcoal)] outline-none focus:border-[var(--color-primary)]"
              maxLength={100}
              name="dispatch_reference"
              placeholder="Optional manual dispatch reference"
              type="text"
            />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Customer dispatch instruction
            <Textarea
              aria-label="Customer dispatch instruction"
              maxLength={500}
              name="customer_dispatch_instruction"
              placeholder="Optional dispatch note visible to the customer"
              value={dispatchCustomerInstruction}
              onChange={(event) => setDispatchCustomerInstruction(event.target.value)}
            />
            <span className="text-xs font-semibold text-[var(--color-muted)]">{dispatchCustomerInstruction.length}/500</span>
          </label>
          <label className="flex items-start gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm font-semibold leading-6 text-[var(--color-charcoal)]">
            <input
              checked={outForDeliveryAcknowledged}
              className="mt-1 h-4 w-4 rounded border-[var(--color-border)] accent-[var(--color-primary)]"
              name="out_for_delivery_acknowledgement"
              onChange={(event) => setOutForDeliveryAcknowledged(event.currentTarget.checked)}
              type="checkbox"
              value="confirmed"
            />
            Confirm the order has been handed off outside Risellar. This does not collect payment, mark delivery complete, or create live tracking.
          </label>
          <SupplierSubmitButton
            disabled={!outForDeliveryAcknowledged}
            icon={<Truck className="h-4 w-4" aria-hidden="true" />}
            label="Mark as out for delivery"
            pendingLabel="Updating delivery status..."
          />
        </form>
      </Card>
    );
  }

  if (!canAct) {
    return <TerminalOrderState order={order} />;
  }

  return (
    <Card title="Supplier decision">
      <div className="grid gap-4">
        <div className="rounded-[var(--radius-md)] border border-[var(--color-warning)]/25 bg-[var(--color-warning-soft)] p-3 text-sm font-semibold leading-6 text-[#8A5A00]">
          Stock is already reserved. Accept only if you can fulfil this order. Rejecting releases the reserved stock. The customer will not be charged.
        </div>
        <form action={acceptAction} className="grid gap-3">
          <input name="order_id" type="hidden" value={order.orderId} />
          <input name="idempotency_key" type="hidden" value={`supplier-accept:${order.orderId}`} />
          <label className="flex items-start gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm font-semibold leading-6 text-[var(--color-charcoal)]">
            <input
              checked={fulfilmentAcknowledged}
              className="mt-1 h-4 w-4 rounded border-[var(--color-border)] accent-[var(--color-primary)]"
              name="fulfilment_acknowledgement"
              onChange={(event) => setFulfilmentAcknowledged(event.currentTarget.checked)}
              type="checkbox"
              value="confirmed"
            />
            Confirm that you can fulfil this order. Stock is already reserved.
          </label>
          <SupplierSubmitButton
            disabled={!fulfilmentAcknowledged}
            icon={<CheckCircle2 className="h-4 w-4" aria-hidden="true" />}
            label="Accept order"
            pendingLabel="Accepting..."
          />
        </form>
        <form action={rejectAction} className="grid gap-3">
          <input name="order_id" type="hidden" value={order.orderId} />
          <input name="idempotency_key" type="hidden" value={`supplier-reject:${order.orderId}`} />
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Rejection reason
            <Select name="reason_code" required value={reasonCode} onChange={(event) => setReasonCode(event.target.value)}>
              <option value="">Choose a reason</option>
              {supplierOrderRejectReasonCodes.map((reason) => (
                <option key={reason} value={reason}>
                  {reason.replaceAll("_", " ")}
                </option>
              ))}
            </Select>
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--color-charcoal)]">
            Private note
            <Textarea
              maxLength={500}
              name="reason_note"
              placeholder="Optional note for internal supplier review"
              value={reasonNote}
              onChange={(event) => setReasonNote(event.target.value)}
            />
            <span className="text-xs font-semibold text-[var(--color-muted)]">{reasonNote.length}/500</span>
          </label>
          <SupplierSubmitButton
            disabled={!reasonCode}
            icon={<XCircle className="h-4 w-4" aria-hidden="true" />}
            label="Reject order"
            pendingLabel="Rejecting..."
            variant="danger"
          />
        </form>
      </div>
    </Card>
  );
}

function SupplierSubmitButton({
  disabled,
  icon,
  label,
  pendingLabel,
  variant = "primary"
}: {
  disabled?: boolean;
  icon: ReactNode;
  label: string;
  pendingLabel: string;
  variant?: "primary" | "danger";
}) {
  const { pending } = useFormStatus();

  return (
    <Button className="w-full" disabled={disabled || pending} loading={pending} type="submit" variant={variant}>
      {pending ? <RotateCw className="h-4 w-4 animate-spin" aria-hidden="true" /> : icon}
      {pending ? pendingLabel : label}
    </Button>
  );
}

function TerminalOrderState({ order }: { order: SupplierOrderSafe }) {
  if (order.orderStatus === "out_for_delivery") {
    return (
      <Card title="Out for delivery">
        <div className="grid gap-4">
          <p className="text-sm leading-6 text-[var(--color-muted)]">
            The order has been dispatched. Payment has not been collected and the order has not been marked delivered.
          </p>
          <div className="grid gap-3 text-sm">
            <InfoRow label="Dispatch reference" value={order.dispatchReference ?? "Not set"} />
            <InfoRow label="Customer dispatch instruction" value={order.customerDispatchInstruction ?? "Not set"} />
            <InfoRow label="Dispatched" value={formatDate(order.outForDeliveryAt)} />
            <InfoRow label="Payment" value={order.paymentStatusLabel} />
            <InfoRow label="Method" value={order.deliveryArrangementMethodLabel ?? "Not set"} />
            <InfoRow label="Agreed fee" value={formatMoney(order.deliveryArrangementFeeAmount, order.deliveryArrangementCurrencyCode ?? order.currencyCode)} />
            <InfoRow label="Customer instruction" value={order.deliveryArrangementCustomerInstruction ?? "Not set"} />
            <InfoRow label="Private note" value={order.deliveryArrangementSupplierPrivateNote ?? "Not set"} />
          </div>
        </div>
      </Card>
    );
  }

  if (order.orderStatus === "delivery_arranged") {
    return (
      <Card title="Delivery arranged">
        <div className="grid gap-4">
          <p className="text-sm leading-6 text-[var(--color-muted)]">
            The delivery arrangement has been recorded. Payment has not been collected and the order has not been marked delivered.
          </p>
          <div className="grid gap-3 text-sm">
            <InfoRow label="Method" value={order.deliveryArrangementMethodLabel ?? "Not set"} />
            <InfoRow label="Agreed fee" value={formatMoney(order.deliveryArrangementFeeAmount, order.deliveryArrangementCurrencyCode ?? order.currencyCode)} />
            <InfoRow label="Expected date" value={formatDateOnly(order.deliveryArrangementExpectedDate)} />
            <InfoRow label="Time window" value={order.deliveryArrangementTimeWindow ?? "Not set"} />
            <InfoRow label="Courier/rider" value={order.deliveryArrangementCourierName ?? "Not set"} />
            <InfoRow label="Courier phone" value={order.deliveryArrangementCourierPhone ?? "Not set"} />
            <InfoRow label="Customer instruction" value={order.deliveryArrangementCustomerInstruction ?? "Not set"} />
            <InfoRow label="Private note" value={order.deliveryArrangementSupplierPrivateNote ?? "Not set"} />
            <InfoRow label="Recorded" value={formatDate(order.deliveryArrangedAt)} />
          </div>
        </div>
      </Card>
    );
  }

  const content =
    order.orderStatus === "ready_for_delivery"
      ? "This order is prepared and waiting for delivery arrangement. No rider or delivery fee has been confirmed yet."
      : order.orderStatus === "supplier_preparing"
      ? "You have started preparing this order. Delivery arrangement will be added in a later phase."
      : order.orderStatus === "supplier_confirmed"
        ? "Order accepted. Preparation is available while active reserved stock remains."
        : order.orderStatus === "supplier_rejected"
          ? "Order rejected. The reserved stock has been released."
          : order.reservationStatusLabel.toLowerCase().includes("expired")
            ? "This order can no longer be accepted because the stock reservation expired."
            : "This order can no longer be accepted or rejected.";
  const title =
    order.orderStatus === "ready_for_delivery"
      ? "Ready for delivery"
      : order.orderStatus === "supplier_preparing"
        ? "Preparing order"
        : "Decision";

  return (
    <Card title={title}>
      <p className="text-sm leading-6 text-[var(--color-muted)]">{content}</p>
    </Card>
  );
}

function SupplierOrderTimeline({ order }: { order: SupplierOrderSafe }) {
  const isOutForDelivery = order.orderStatus === "out_for_delivery";
  const isArranged = order.orderStatus === "delivery_arranged" || isOutForDelivery;
  const isReady = order.orderStatus === "ready_for_delivery" || isArranged;
  const isConfirmed = order.orderStatus === "supplier_confirmed" || order.orderStatus === "supplier_preparing" || isReady;
  const isPreparing = order.orderStatus === "supplier_preparing" || isReady;
  const steps =
    order.orderStatus === "supplier_rejected"
      ? [
          { label: "Customer placed order", state: "Complete", active: true },
          { label: "Supplier could not fulfil", state: "Terminal", active: true },
          { label: "Reserved stock released", state: "Complete", active: true }
        ]
      : [
          { label: "Customer placed order", state: "Complete", active: true },
          {
            label: isConfirmed ? "Supplier confirmed" : "Waiting for your decision",
            state: isConfirmed ? "Complete" : "Current",
            active: true
          },
          { label: "Preparing order", state: isReady ? "Complete" : isPreparing ? "Current" : "Inactive", active: isPreparing },
          { label: "Ready for delivery", state: isArranged ? "Complete" : isReady ? "Current" : "Inactive", active: isReady },
          { label: "Delivery arrangement", state: isOutForDelivery ? "Complete" : isArranged ? "Current" : "Inactive", active: isArranged },
          { label: "Out for delivery", state: isOutForDelivery ? "Current" : "Inactive", active: isOutForDelivery },
          { label: "Payment confirmation", state: "Inactive", active: false },
          { label: "Completed", state: "Inactive", active: false }
        ];

  return (
    <Card title="Timeline">
      <ol className="grid gap-4">
        {steps.map((step, index) => (
          <li className="flex gap-3" key={`${step.label}-${index}`}>
            <span
              className={cn(
                "grid h-7 w-7 shrink-0 place-items-center rounded-full border text-xs font-bold",
                step.active
                  ? "border-[var(--color-primary)] bg-[var(--color-primary)] text-white"
                  : "border-[var(--color-border)] text-[var(--color-muted)]"
              )}
            >
              {step.active ? <CheckCircle2 className="h-4 w-4" aria-hidden="true" /> : index + 1}
            </span>
            <div>
              <p className="font-bold text-[var(--color-charcoal)]">{step.label}</p>
              <p className="text-sm text-[var(--color-muted)]">{step.state}</p>
            </div>
          </li>
        ))}
      </ol>
    </Card>
  );
}

function BackLink() {
  return (
    <Link className="inline-flex items-center gap-2 text-sm font-semibold text-[var(--color-primary)]" href="/supplier/orders">
      <ArrowLeft className="h-4 w-4" aria-hidden="true" />
      Back to supplier orders
    </Link>
  );
}
