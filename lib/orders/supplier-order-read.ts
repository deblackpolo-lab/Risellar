import "server-only";

export {
  initialSupplierOrderState,
  supplierOrderDeliveryMethodCodes,
  supplierOrderRejectReasonCodes,
  type SupplierOrderCode,
  type SupplierOrderSafe,
  type SupplierOrderState
} from "./supplier-order-shared";

import {
  initialSupplierOrderState,
  supplierOrderDeliveryMethodCodes,
  supplierOrderRejectReasonCodes,
  type SupplierOrderSafe,
  type SupplierOrderState
} from "./supplier-order-shared";

export type SupplierOrderListInput = {
  status?: string | null;
  limit?: number | null;
  cursorCreatedAt?: string | null;
  cursorOrderId?: string | null;
};

export type SupplierOrderDecisionInput = {
  orderId?: string | null;
  idempotencyKey?: string | null;
};

export type SupplierOrderRejectInput = SupplierOrderDecisionInput & {
  reasonCode?: string | null;
  reasonNote?: string | null;
};

export type SupplierOrderDeliveryArrangementInput = SupplierOrderDecisionInput & {
  deliveryMethod?: string | null;
  agreedDeliveryFeeAmount?: string | number | null;
  expectedDeliveryDate?: string | null;
  expectedTimeWindow?: string | null;
  courierDisplayName?: string | null;
  courierPhone?: string | null;
  customerInstruction?: string | null;
  supplierPrivateNote?: string | null;
};

export type SupplierOrderOutForDeliveryInput = SupplierOrderDecisionInput & {
  dispatchReference?: string | null;
  customerDispatchInstruction?: string | null;
};

export type SupplierOrderDeliveredInput = SupplierOrderDecisionInput & {
  deliveryConfirmationNote?: string | null;
};

export type SupplierOrderPaymentReportedInput = SupplierOrderDecisionInput & {
  paymentReference?: string | null;
  supplierPrivateNote?: string | null;
};

export type SupplierOrderRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): PromiseLike<{
    data: T | null;
    error: { code?: string; message?: string; details?: string } | null;
  }>;
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function cleanOptionalText(value: string | null | undefined) {
  const text = value?.trim();
  return text ? text : null;
}

function requireUuid(value: string | null | undefined, label: string) {
  const text = cleanOptionalText(value);

  if (!text || !uuidPattern.test(text)) {
    throw new Error(`${label} is required`);
  }

  return text;
}

function normalizeIdempotencyKey(value: string | null | undefined) {
  const text = cleanOptionalText(value);

  if (!text) {
    return null;
  }

  if (text.length > 140) {
    throw new Error("Idempotency key is too long");
  }

  return text;
}

function normalizeStatus(value: string | null | undefined) {
  const text = cleanOptionalText(value);
  const allowed = new Set(["placed_pending_confirmation", "supplier_confirmed", "supplier_rejected", "supplier_preparing", "ready_for_delivery", "delivery_arranged", "out_for_delivery", "delivered", "payment_reported"]);

  return text && allowed.has(text) ? text : null;
}

function assertDispatchTextIsSafe(text: string | null) {
  if (!text) {
    return;
  }

  if (/[<>]/.test(text) || /gps|latitude|longitude|live tracking|verified by risellar|rider verified/i.test(text)) {
    throw new Error("Dispatch details cannot include live tracking or verified delivery claims");
  }
}

function normalizeDeliveryMethod(value: string | null | undefined) {
  const text = cleanOptionalText(value);

  if (!text || !supplierOrderDeliveryMethodCodes.includes(text as (typeof supplierOrderDeliveryMethodCodes)[number])) {
    throw new Error("Choose a valid delivery method");
  }

  return text;
}

function normalizeDeliveryFee(value: string | number | null | undefined) {
  if (value === null || value === undefined || value === "") {
    return null;
  }

  const amount = typeof value === "number" ? value : Number(value);

  if (!Number.isFinite(amount)) {
    throw new Error("Delivery fee must be a valid amount");
  }

  if (amount < 0) {
    throw new Error("Delivery fee must be zero or greater");
  }

  return Math.round(amount * 100) / 100;
}

function normalizeBoundedText(value: string | null | undefined, maxLength = 100) {
  const text = cleanOptionalText(value);

  if (text && text.length > maxLength) {
    throw new Error("Delivery arrangement text is too long");
  }

  return text;
}

function normalizeLimit(value: number | null | undefined) {
  if (!Number.isFinite(value ?? NaN)) {
    return 50;
  }

  return Math.min(Math.max(Math.trunc(Number(value)), 1), 100);
}

export function buildListSupplierOrdersSafePayload(input: SupplierOrderListInput = {}) {
  return {
    p_status: normalizeStatus(input.status),
    p_limit: normalizeLimit(input.limit),
    p_cursor_created_at: cleanOptionalText(input.cursorCreatedAt),
    p_cursor_order_id: input.cursorOrderId ? requireUuid(input.cursorOrderId, "Cursor order id") : null
  };
}

export function buildSupplierOrderDetailPayload(orderId: string | null | undefined) {
  return {
    p_order_id: requireUuid(orderId, "Order id")
  };
}

export function buildAcceptSupplierOrderPayload(input: SupplierOrderDecisionInput) {
  const orderId = requireUuid(input.orderId, "Order id");

  return {
    p_order_id: orderId,
    p_idempotency_key: normalizeIdempotencyKey(input.idempotencyKey) ?? `supplier-accept:${orderId}`
  };
}

export function buildStartPreparingSupplierOrderPayload(input: SupplierOrderDecisionInput) {
  const orderId = requireUuid(input.orderId, "Order id");

  return {
    p_order_id: orderId,
    p_idempotency_key: normalizeIdempotencyKey(input.idempotencyKey) ?? `supplier-start-preparing:${orderId}`
  };
}

export function buildMarkReadyForDeliverySupplierOrderPayload(input: SupplierOrderDecisionInput) {
  const orderId = requireUuid(input.orderId, "Order id");

  return {
    p_order_id: orderId,
    p_idempotency_key: normalizeIdempotencyKey(input.idempotencyKey) ?? `supplier-ready-for-delivery:${orderId}`
  };
}

export function buildArrangeSupplierOrderDeliveryPayload(input: SupplierOrderDeliveryArrangementInput) {
  const orderId = requireUuid(input.orderId, "Order id");

  return {
    p_order_id: orderId,
    p_delivery_method: normalizeDeliveryMethod(input.deliveryMethod),
    p_agreed_delivery_fee_amount: normalizeDeliveryFee(input.agreedDeliveryFeeAmount),
    p_expected_delivery_date: cleanOptionalText(input.expectedDeliveryDate),
    p_expected_time_window: normalizeBoundedText(input.expectedTimeWindow),
    p_courier_display_name: normalizeBoundedText(input.courierDisplayName, 120),
    p_courier_phone: normalizeBoundedText(input.courierPhone, 40),
    p_customer_instruction: normalizeBoundedText(input.customerInstruction, 500),
    p_supplier_private_note: normalizeBoundedText(input.supplierPrivateNote, 500),
    p_idempotency_key: normalizeIdempotencyKey(input.idempotencyKey) ?? `supplier-arrange-delivery:${orderId}`
  };
}

export function buildMarkSupplierOrderOutForDeliveryPayload(input: SupplierOrderOutForDeliveryInput) {
  const orderId = requireUuid(input.orderId, "Order id");
  const dispatchReference = cleanOptionalText(input.dispatchReference);
  const customerDispatchInstruction = cleanOptionalText(input.customerDispatchInstruction);

  if (dispatchReference && dispatchReference.length > 100) {
    throw new Error("Dispatch reference is too long");
  }

  if (customerDispatchInstruction && customerDispatchInstruction.length > 500) {
    throw new Error("Customer dispatch instruction is too long");
  }

  assertDispatchTextIsSafe(dispatchReference);
  assertDispatchTextIsSafe(customerDispatchInstruction);

  return {
    p_order_id: orderId,
    p_dispatch_reference: dispatchReference,
    p_customer_dispatch_instruction: customerDispatchInstruction,
    p_idempotency_key: normalizeIdempotencyKey(input.idempotencyKey) ?? `supplier-out-for-delivery:${orderId}`
  };
}

export function buildMarkSupplierOrderDeliveredPayload(input: SupplierOrderDeliveredInput) {
  const orderId = requireUuid(input.orderId, "Order id");
  const deliveryConfirmationNote = cleanOptionalText(input.deliveryConfirmationNote);

  if (deliveryConfirmationNote && deliveryConfirmationNote.length > 300) {
    throw new Error("Delivery confirmation note is too long");
  }

  if (deliveryConfirmationNote && (/[<>]/.test(deliveryConfirmationNote) || /payment collected|cash collected|paid in full|id card|national id|passport|gps|latitude|longitude|live tracking/i.test(deliveryConfirmationNote))) {
    throw new Error("Delivery confirmation note cannot include payment, identity, tracking, or sensitive details");
  }

  return {
    p_order_id: orderId,
    p_delivery_confirmation_note: deliveryConfirmationNote,
    p_idempotency_key: normalizeIdempotencyKey(input.idempotencyKey) ?? `supplier-delivered:${orderId}`
  };
}

export function buildReportSupplierOrderPaymentReceivedPayload(input: SupplierOrderPaymentReportedInput) {
  const orderId = requireUuid(input.orderId, "Order id");
  const paymentReference = cleanOptionalText(input.paymentReference);
  const supplierPrivateNote = cleanOptionalText(input.supplierPrivateNote);

  if (paymentReference && paymentReference.length > 100) {
    throw new Error("Payment reference is too long");
  }

  if (supplierPrivateNote && supplierPrivateNote.length > 300) {
    throw new Error("Payment note is too long");
  }

  const unsafePaymentText = /[<>]|pin|password|secret|card number|cvv|otp/i;

  if ((paymentReference && unsafePaymentText.test(paymentReference)) || (supplierPrivateNote && unsafePaymentText.test(supplierPrivateNote))) {
    throw new Error("Payment details cannot include secrets, card details, HTML, or OTPs");
  }

  return {
    p_order_id: orderId,
    p_payment_reference: paymentReference,
    p_supplier_private_note: supplierPrivateNote,
    p_idempotency_key: normalizeIdempotencyKey(input.idempotencyKey) ?? `supplier-payment-reported:${orderId}`
  };
}

export function buildRejectSupplierOrderPayload(input: SupplierOrderRejectInput) {
  const orderId = requireUuid(input.orderId, "Order id");
  const reasonCode = cleanOptionalText(input.reasonCode);

  if (!reasonCode) {
    throw new Error("Rejection reason is required");
  }

  if (!supplierOrderRejectReasonCodes.includes(reasonCode as (typeof supplierOrderRejectReasonCodes)[number])) {
    throw new Error("Choose a valid rejection reason");
  }

  const reasonNote = cleanOptionalText(input.reasonNote);

  if (reasonNote && reasonNote.length > 500) {
    throw new Error("Rejection note is too long");
  }

  return {
    p_order_id: orderId,
    p_reason_code: reasonCode,
    p_reason_note: reasonNote,
    p_idempotency_key: normalizeIdempotencyKey(input.idempotencyKey) ?? `supplier-reject:${orderId}`
  };
}

export function mapSupplierOrderRpcError(error: unknown): SupplierOrderState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as { code?: string; message?: string; details?: string }) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required") || combined.includes("28000")) {
    return { code: "AUTH_REQUIRED", message: "Sign in to manage this order." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return { code: "SUPABASE_AUTH_TOKEN_MISSING", message: "We could not verify your supplier session. Please sign in again." };
  }

  if (combined.includes("supplier_required")) {
    return { code: "SUPPLIER_REQUIRED", message: "Use an approved supplier account." };
  }

  if (combined.includes("order_not_found") || combined.includes("order_not_owned")) {
    return { code: "ORDER_NOT_FOUND", message: "This order is unavailable." };
  }

  if (combined.includes("order_not_actionable")) {
    return { code: "ORDER_NOT_ACTIONABLE", message: "This order cannot be updated right now." };
  }

  if (combined.includes("order_not_confirmed")) {
    return { code: "ORDER_NOT_CONFIRMED", message: "Accept this order before starting preparation." };
  }

  if (combined.includes("order_not_preparing")) {
    return { code: "ORDER_NOT_PREPARING", message: "Start preparing this order before marking it ready." };
  }

  if (combined.includes("order_not_arranged")) {
    return { code: "ORDER_NOT_ARRANGED", message: "Arrange delivery before marking this order out for delivery." };
  }

  if (combined.includes("reservation_not_found")) {
    return { code: "RESERVATION_NOT_FOUND", message: "The stock reservation is unavailable." };
  }

  if (combined.includes("reservation_expired")) {
    return { code: "RESERVATION_EXPIRED", message: "The stock reservation has expired." };
  }

  if (combined.includes("reservation_not_active")) {
    return { code: "RESERVATION_NOT_ACTIVE", message: "This order no longer has an active stock reservation." };
  }

  if (combined.includes("already_confirmed")) {
    return { code: "ALREADY_CONFIRMED", message: "This order has already been accepted." };
  }

  if (combined.includes("already_rejected")) {
    return { code: "ALREADY_REJECTED", message: "This order has already been rejected." };
  }

  if (combined.includes("already_preparing")) {
    return { code: "ALREADY_PREPARING", message: "Preparation has already started." };
  }

  if (combined.includes("already_ready")) {
    return { code: "ALREADY_READY", message: "This order is already ready for delivery." };
  }

  if (combined.includes("already_arranged")) {
    return { code: "ALREADY_ARRANGED", message: "Delivery arrangement has already been recorded." };
  }

  if (combined.includes("already_out_for_delivery")) {
    return { code: "ALREADY_OUT_FOR_DELIVERY", message: "This order is already out for delivery." };
  }

  if (combined.includes("already_delivered")) {
    return { code: "ALREADY_DELIVERED", message: "This order has already been marked delivered." };
  }

  if (combined.includes("already_reported")) {
    return { code: "ALREADY_REPORTED", message: "Payment has already been reported for this order." };
  }

  if (combined.includes("order_not_out_for_delivery")) {
    return { code: "ORDER_NOT_OUT_FOR_DELIVERY", message: "Mark this order out for delivery before marking it delivered." };
  }

  if (combined.includes("order_not_delivered")) {
    return { code: "ORDER_NOT_DELIVERED", message: "Mark this order delivered before reporting payment." };
  }

  if (combined.includes("payment_method_not_supported")) {
    return { code: "PAYMENT_METHOD_NOT_SUPPORTED", message: "Only Pay on Delivery payment can be reported here." };
  }

  if (combined.includes("payment_already_collected")) {
    return { code: "PAYMENT_ALREADY_COLLECTED", message: "Payment has already been recorded." };
  }

  if (combined.includes("stock_state_inconsistent")) {
    return { code: "STOCK_STATE_INCONSISTENT", message: "The stock record is inconsistent. Contact support before continuing." };
  }

  if (combined.includes("financial_snapshot_invalid")) {
    return { code: "FINANCIAL_SNAPSHOT_INVALID", message: "The order amounts could not be verified safely." };
  }

  if (combined.includes("delivery_arrangement_not_found")) {
    return { code: "DELIVERY_ARRANGEMENT_NOT_FOUND", message: "The delivery arrangement is unavailable." };
  }

  if (combined.includes("dispatch_not_recorded")) {
    return { code: "DISPATCH_NOT_RECORDED", message: "Dispatch has not been recorded for this order." };
  }

  if (combined.includes("invalid_dispatch_field")) {
    return { code: "INVALID_DISPATCH_FIELD", message: "Dispatch details cannot include live tracking or verified delivery claims." };
  }

  if (combined.includes("invalid_delivery_note") || combined.includes("delivery confirmation note cannot")) {
    return { code: "INVALID_DELIVERY_NOTE", message: "Delivery note cannot include payment, identity, tracking, or sensitive details." };
  }

  if (combined.includes("invalid_payment_field") || combined.includes("payment details cannot")) {
    return { code: "INVALID_PAYMENT_FIELD", message: "Payment details cannot include secrets, card details, HTML, or OTPs." };
  }

  if (combined.includes("invalid_delivery_method") || combined.includes("choose a valid delivery method")) {
    return { code: "INVALID_DELIVERY_METHOD", message: "Choose a valid delivery method." };
  }

  if (combined.includes("invalid_delivery_fee") || combined.includes("delivery fee must")) {
    return { code: "INVALID_DELIVERY_FEE", message: "Enter a valid delivery fee." };
  }

  if (combined.includes("delivery_fee_too_high")) {
    return { code: "DELIVERY_FEE_TOO_HIGH", message: "The delivery fee is above the allowed limit." };
  }

  if (combined.includes("expected_date_in_past")) {
    return { code: "EXPECTED_DATE_IN_PAST", message: "Choose today or a future expected delivery date." };
  }

  if (combined.includes("invalid_courier_phone")) {
    return { code: "INVALID_COURIER_PHONE", message: "Enter a valid courier or rider phone number." };
  }

  if (combined.includes("field_too_long") || combined.includes("delivery arrangement text is too long") || combined.includes("dispatch reference is too long") || combined.includes("customer dispatch instruction is too long") || combined.includes("delivery confirmation note is too long") || combined.includes("payment reference is too long") || combined.includes("payment note is too long")) {
    return { code: "FIELD_TOO_LONG", message: "Shorten the information and try again." };
  }

  if (combined.includes("conflicting_retry")) {
    return { code: "CONFLICTING_RETRY", message: "This retry does not match the saved order update. Refresh the order." };
  }

  if (combined.includes("preparation_not_started")) {
    return { code: "PREPARATION_NOT_STARTED", message: "Preparation has not started for this order." };
  }

  if (combined.includes("invalid_rejection_reason") || combined.includes("choose a valid rejection reason")) {
    return { code: "INVALID_REJECTION_REASON", message: "Choose a valid rejection reason." };
  }

  if (combined.includes("rejection_note_too_long") || combined.includes("rejection note is too long")) {
    return { code: "REJECTION_NOTE_TOO_LONG", message: "Keep the note within the allowed length." };
  }

  if (combined.includes("stock_release_failed")) {
    return { code: "STOCK_RELEASE_FAILED", message: "The reserved stock could not be released safely." };
  }

  if (combined.includes("order id") || combined.includes("idempotency") || combined.includes("23514") || combined.includes("rejection reason is required")) {
    return { code: "VALIDATION_ERROR", message: "Check the order request and try again." };
  }

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "This order is unavailable." };
  }

  return { code: "UNKNOWN", message: "We could not confirm the result. Refresh the order before trying again." };
}

export async function listSupplierOrdersSafeWithClient(client: SupplierOrderRpcClient, input: SupplierOrderListInput = {}) {
  try {
    const { data, error } = await client.rpc<unknown[]>("list_supplier_orders_safe", buildListSupplierOrdersSafePayload(input));

    if (error) {
      return { orders: [], state: mapSupplierOrderRpcError(error) };
    }

    return { orders: mapSupplierOrderRows(data), state: initialSupplierOrderState };
  } catch (error) {
    return { orders: [], state: mapSupplierOrderRpcError(error) };
  }
}

export async function getSupplierOrderSafeWithClient(client: SupplierOrderRpcClient, orderId: string | null | undefined) {
  try {
    const { data, error } = await client.rpc<unknown[]>("get_supplier_order_safe", buildSupplierOrderDetailPayload(orderId));

    if (error) {
      return { order: null, state: mapSupplierOrderRpcError(error) };
    }

    const order = mapSupplierOrderRows(data)[0] ?? null;

    return order
      ? { order, state: initialSupplierOrderState }
      : { order: null, state: { code: "ORDER_NOT_FOUND" as const, message: "This order is unavailable." } };
  } catch (error) {
    return { order: null, state: mapSupplierOrderRpcError(error) };
  }
}

export async function acceptSupplierOrderWithClient(client: SupplierOrderRpcClient, input: SupplierOrderDecisionInput) {
  try {
    const { data, error } = await client.rpc<unknown[]>("supplier_accept_order", buildAcceptSupplierOrderPayload(input));

    if (error) {
      return { order: null, state: mapSupplierOrderRpcError(error) };
    }

    return { order: mapSupplierOrderRows(data)[0] ?? null, state: { code: "OK" as const, message: "Order accepted" } };
  } catch (error) {
    return { order: null, state: mapSupplierOrderRpcError(error) };
  }
}

export async function startPreparingSupplierOrderWithClient(client: SupplierOrderRpcClient, input: SupplierOrderDecisionInput) {
  try {
    const { data, error } = await client.rpc<unknown[]>("supplier_start_preparing", buildStartPreparingSupplierOrderPayload(input));

    if (error) {
      return { order: null, state: mapSupplierOrderRpcError(error) };
    }

    return { order: mapSupplierOrderRows(data)[0] ?? null, state: { code: "OK" as const, message: "Order preparation started" } };
  } catch (error) {
    return { order: null, state: mapSupplierOrderRpcError(error) };
  }
}

export async function markReadyForDeliverySupplierOrderWithClient(client: SupplierOrderRpcClient, input: SupplierOrderDecisionInput) {
  try {
    const { data, error } = await client.rpc<unknown[]>("supplier_mark_ready_for_delivery", buildMarkReadyForDeliverySupplierOrderPayload(input));

    if (error) {
      return { order: null, state: mapSupplierOrderRpcError(error) };
    }

    return { order: mapSupplierOrderRows(data)[0] ?? null, state: { code: "OK" as const, message: "Order is ready for delivery" } };
  } catch (error) {
    return { order: null, state: mapSupplierOrderRpcError(error) };
  }
}

export async function arrangeSupplierOrderDeliveryWithClient(client: SupplierOrderRpcClient, input: SupplierOrderDeliveryArrangementInput) {
  try {
    const { data, error } = await client.rpc<unknown[]>("supplier_arrange_order_delivery", buildArrangeSupplierOrderDeliveryPayload(input));

    if (error) {
      return { order: null, state: mapSupplierOrderRpcError(error) };
    }

    return { order: mapSupplierOrderRows(data)[0] ?? null, state: { code: "OK" as const, message: "Delivery arrangement saved" } };
  } catch (error) {
    return { order: null, state: mapSupplierOrderRpcError(error) };
  }
}

export async function markSupplierOrderOutForDeliveryWithClient(client: SupplierOrderRpcClient, input: SupplierOrderOutForDeliveryInput) {
  try {
    const { data, error } = await client.rpc<unknown[]>("supplier_mark_order_out_for_delivery", buildMarkSupplierOrderOutForDeliveryPayload(input));

    if (error) {
      return { order: null, state: mapSupplierOrderRpcError(error) };
    }

    return { order: mapSupplierOrderRows(data)[0] ?? null, state: { code: "OK" as const, message: "Order marked as out for delivery" } };
  } catch (error) {
    return { order: null, state: mapSupplierOrderRpcError(error) };
  }
}

export async function markSupplierOrderDeliveredWithClient(client: SupplierOrderRpcClient, input: SupplierOrderDeliveredInput) {
  try {
    const { data, error } = await client.rpc<unknown[]>("supplier_mark_order_delivered", buildMarkSupplierOrderDeliveredPayload(input));

    if (error) {
      return { order: null, state: mapSupplierOrderRpcError(error) };
    }

    return { order: mapSupplierOrderRows(data)[0] ?? null, state: { code: "OK" as const, message: "Order marked as delivered" } };
  } catch (error) {
    return { order: null, state: mapSupplierOrderRpcError(error) };
  }
}

export async function reportSupplierOrderPaymentReceivedWithClient(client: SupplierOrderRpcClient, input: SupplierOrderPaymentReportedInput) {
  try {
    const { data, error } = await client.rpc<unknown[]>("supplier_report_order_payment_received", buildReportSupplierOrderPaymentReceivedPayload(input));

    if (error) {
      return { order: null, state: mapSupplierOrderRpcError(error) };
    }

    return { order: mapSupplierOrderRows(data)[0] ?? null, state: { code: "OK" as const, message: "Payment reported - settlement pending" } };
  } catch (error) {
    return { order: null, state: mapSupplierOrderRpcError(error) };
  }
}

export async function rejectSupplierOrderWithClient(client: SupplierOrderRpcClient, input: SupplierOrderRejectInput) {
  try {
    const { data, error } = await client.rpc<unknown[]>("supplier_reject_order", buildRejectSupplierOrderPayload(input));

    if (error) {
      return { order: null, state: mapSupplierOrderRpcError(error) };
    }

    return { order: mapSupplierOrderRows(data)[0] ?? null, state: { code: "OK" as const, message: "Order rejected and reserved stock released" } };
  } catch (error) {
    return { order: null, state: mapSupplierOrderRpcError(error) };
  }
}

function mapSupplierOrderRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map(mapSupplierOrderRow) : [];
}

function mapJsonObject(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function nullableNumber(value: unknown) {
  if (value === null || value === undefined) {
    return null;
  }

  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : null;
}

function nullableString(value: unknown) {
  return typeof value === "string" && value.trim() ? value : null;
}

function requiredString(value: unknown, fallback: string) {
  return nullableString(value) ?? fallback;
}

function supplierOrderStatusLabel(status: string) {
  const labels: Record<string, string> = {
    placed_pending_confirmation: "New order - confirm or reject",
    supplier_confirmed: "Supplier confirmed",
    supplier_preparing: "Preparing order",
    ready_for_delivery: "Ready for delivery",
    delivery_arranged: "Delivery arranged",
    out_for_delivery: "Out for delivery",
    delivered: "Delivered",
    payment_reported: "Payment reported",
    completed: "Completed",
    supplier_rejected: "Rejected - stock released"
  };

  return labels[status] ?? "Order status unavailable";
}

function supplierOrderStatusLabelFromRow(label: unknown, status: string) {
  const text = nullableString(label);

  if (!text || text === "Order status unavailable") {
    return supplierOrderStatusLabel(status);
  }

  return text;
}

function optionalInteger(value: unknown) {
  if (value === null || value === undefined) {
    return null;
  }

  const numericValue = Number(value);
  return Number.isInteger(numericValue) ? numericValue : null;
}

function mapSupplierOrderRow(row: unknown): SupplierOrderSafe {
  const item = row as Record<string, unknown>;
  const orderStatus = requiredString(item.order_status, "unknown");

  return {
    orderId: requiredString(item.order_id, ""),
    orderNumber: requiredString(item.order_number, "Order number unavailable"),
    createdAt: requiredString(item.created_at, ""),
    updatedAt: requiredString(item.updated_at, ""),
    orderStatus,
    orderStatusLabel: supplierOrderStatusLabelFromRow(item.order_status_label, orderStatus),
    isSupplierActionable: Boolean(item.is_supplier_actionable),
    productName: requiredString(item.product_name, "Product unavailable"),
    productSlug: nullableString(item.product_slug),
    productImageSnapshot: mapJsonObject(item.product_image_snapshot),
    variantSku: nullableString(item.variant_sku),
    variantName: nullableString(item.variant_name),
    quantity: Number.isInteger(Number(item.quantity)) ? Number(item.quantity) : 0,
    supplierAmountExpected: nullableNumber(item.supplier_amount_expected),
    customerTotalAmount: nullableNumber(item.customer_total_amount),
    currencyCode: requiredString(item.currency_code, "GHS"),
    paymentMethodLabel: requiredString(item.payment_method_label, "Pay on Delivery"),
    paymentStatusLabel: requiredString(item.payment_status_label, "Payment not collected"),
    deliveryStatusLabel: requiredString(item.delivery_status_label, "Delivery not arranged yet"),
    reservationStatusLabel: requiredString(item.reservation_status_label, "Reservation unavailable"),
    reservationExpiresAt: nullableString(item.reservation_expires_at),
    reservationQuantity: optionalInteger(item.reservation_quantity),
    recipientName: nullableString(item.recipient_name),
    recipientPhone: nullableString(item.recipient_phone),
    recipientWhatsapp: nullableString(item.recipient_whatsapp),
    deliveryAddressSnapshot: mapJsonObject(item.delivery_address_snapshot),
    locationSummary: nullableString(item.location_summary),
    resellerShopName: nullableString(item.reseller_shop_name),
    resellerShopSlug: nullableString(item.reseller_shop_slug),
    deliveryArrangementMethod: nullableString(item.delivery_arrangement_method),
    deliveryArrangementMethodLabel: nullableString(item.delivery_arrangement_method_label),
    deliveryArrangementFeeAmount: nullableNumber(item.delivery_arrangement_fee_amount),
    deliveryArrangementCurrencyCode: nullableString(item.delivery_arrangement_currency_code),
    deliveryArrangementExpectedDate: nullableString(item.delivery_arrangement_expected_date),
    deliveryArrangementTimeWindow: nullableString(item.delivery_arrangement_time_window),
    deliveryArrangementCourierName: nullableString(item.delivery_arrangement_courier_name),
    deliveryArrangementCourierPhone: nullableString(item.delivery_arrangement_courier_phone),
    deliveryArrangementCustomerInstruction: nullableString(item.delivery_arrangement_customer_instruction),
    deliveryArrangementSupplierPrivateNote: nullableString(item.delivery_arrangement_supplier_private_note),
    deliveryArrangedAt: nullableString(item.delivery_arranged_at),
    outForDeliveryAt: nullableString(item.out_for_delivery_at),
    dispatchReference: nullableString(item.dispatch_reference),
    customerDispatchInstruction: nullableString(item.customer_dispatch_instruction),
    deliveredAt: nullableString(item.delivered_at),
    deliveryConfirmationNote: nullableString(item.delivery_confirmation_note),
    paymentReportedAt: nullableString(item.payment_reported_at),
    paymentReference: nullableString(item.payment_reference),
    supplierPaymentPrivateNote: nullableString(item.supplier_payment_private_note),
    platformAmountDue: nullableNumber(item.platform_amount_due),
    resellerCommissionDue: nullableNumber(item.reseller_commission_due),
    settlementStatusLabel: nullableString(item.settlement_status_label),
    commissionStatusLabel: nullableString(item.commission_status_label)
  };
}
