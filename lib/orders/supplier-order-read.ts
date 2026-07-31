import "server-only";

export {
  initialSupplierOrderState,
  supplierOrderRejectReasonCodes,
  type SupplierOrderCode,
  type SupplierOrderSafe,
  type SupplierOrderState
} from "./supplier-order-shared";

import {
  initialSupplierOrderState,
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
  const allowed = new Set(["placed_pending_confirmation", "supplier_confirmed", "supplier_rejected", "supplier_preparing"]);

  return text && allowed.has(text) ? text : null;
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
    return { code: "ORDER_NOT_ACTIONABLE", message: "This order can no longer be accepted or rejected." };
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

function optionalInteger(value: unknown) {
  if (value === null || value === undefined) {
    return null;
  }

  const numericValue = Number(value);
  return Number.isInteger(numericValue) ? numericValue : null;
}

function mapSupplierOrderRow(row: unknown): SupplierOrderSafe {
  const item = row as Record<string, unknown>;

  return {
    orderId: requiredString(item.order_id, ""),
    orderNumber: requiredString(item.order_number, "Order number unavailable"),
    createdAt: requiredString(item.created_at, ""),
    updatedAt: requiredString(item.updated_at, ""),
    orderStatus: requiredString(item.order_status, "unknown"),
    orderStatusLabel: requiredString(item.order_status_label, "Order status unavailable"),
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
    resellerShopSlug: nullableString(item.reseller_shop_slug)
  };
}
