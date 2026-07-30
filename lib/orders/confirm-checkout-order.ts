import "server-only";

export type CheckoutOrderConfirmationCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "ACKNOWLEDGEMENT_REQUIRED"
  | "VALIDATION_ERROR"
  | "CHECKOUT_DRAFT_NOT_FOUND"
  | "CHECKOUT_DRAFT_NOT_READY"
  | "INSUFFICIENT_STOCK"
  | "RPC_PERMISSION_DENIED"
  | "UNKNOWN";

export type CheckoutOrderConfirmationState = {
  code: CheckoutOrderConfirmationCode;
  message: string;
};

export type CheckoutOrderConfirmationInput = {
  checkoutDraftId?: string | null;
  idempotencyKey?: string | null;
};

export type CheckoutOrderConfirmationSafe = {
  orderId: string;
  orderNumber: string;
  checkoutDraftId: string;
  orderStatusLabel: string;
  paymentMethodLabel: string;
  paymentCollectionLabel: string;
  deliveryStatusLabel: string;
  customerConfirmationLabel: string;
  deliveryQuoteLabel: string;
  productName: string;
  productSlug: string | null;
  quantity: number;
  finalCustomerPriceAmount: number | null;
  lineTotalAmount: number | null;
  totalPayableAmount: number | null;
  currencyCode: string;
  reservationStatusLabel: string;
  reservationExpiresAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type CheckoutOrderConfirmationRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): PromiseLike<{
    data: T | null;
    error: { code?: string; message?: string; details?: string } | null;
  }>;
};

export const initialCheckoutOrderConfirmationState: CheckoutOrderConfirmationState = {
  code: "OK",
  message: ""
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

  if (text.length > 120) {
    throw new Error("Idempotency key is too long");
  }

  return text;
}

export function buildCheckoutOrderConfirmationPayload(input: CheckoutOrderConfirmationInput) {
  return {
    p_checkout_draft_id: requireUuid(input.checkoutDraftId, "Checkout draft id"),
    p_idempotency_key: normalizeIdempotencyKey(input.idempotencyKey)
  };
}

export function mapCheckoutOrderConfirmationRpcError(error: unknown): CheckoutOrderConfirmationState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as { code?: string; message?: string; details?: string }) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required") || combined.includes("28000")) {
    return { code: "AUTH_REQUIRED", message: "Sign in as a customer before placing this Pay on Delivery order." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return { code: "SUPABASE_AUTH_TOKEN_MISSING", message: "We could not verify your secure customer session. Please sign in again." };
  }

  if (combined.includes("acknowledgement_required")) {
    return { code: "ACKNOWLEDGEMENT_REQUIRED", message: "Accept the Pay on Delivery acknowledgement before placing this order." };
  }

  if (combined.includes("checkout_draft_not_found")) {
    return { code: "CHECKOUT_DRAFT_NOT_FOUND", message: "This checkout draft was not found for your customer account." };
  }

  if (
    combined.includes("checkout_draft_not_review_pending") ||
    combined.includes("checkout_draft_not_ready") ||
    combined.includes("checkout_draft_already_converted") ||
    combined.includes("checkout_draft_not_active")
  ) {
    return { code: "CHECKOUT_DRAFT_NOT_READY", message: "This draft is not ready for final Pay on Delivery confirmation." };
  }

  if (combined.includes("insufficient_stock")) {
    return { code: "INSUFFICIENT_STOCK", message: "This product just sold out or has less stock than requested. No order was placed." };
  }

  if (combined.includes("checkout draft id") || combined.includes("idempotency key") || combined.includes("23514")) {
    return { code: "VALIDATION_ERROR", message: "This checkout confirmation request is invalid." };
  }

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "Your profile is not allowed to place this order." };
  }

  return { code: "UNKNOWN", message: "Order confirmation failed. Try again or contact support." };
}

export async function confirmCheckoutDraftOrderWithClient(
  client: CheckoutOrderConfirmationRpcClient,
  input: CheckoutOrderConfirmationInput
) {
  try {
    const { data, error } = await client.rpc<unknown[]>("create_order_from_checkout_draft", buildCheckoutOrderConfirmationPayload(input));

    if (error) {
      return { order: null, state: mapCheckoutOrderConfirmationRpcError(error) };
    }

    const order = mapCheckoutOrderRows(data)[0] ?? null;
    return order
      ? { order, state: { code: "OK" as const, message: "Pay on Delivery order placed." } }
      : { order: null, state: { code: "UNKNOWN" as const, message: "Order confirmation did not return an order." } };
  } catch (error) {
    return { order: null, state: mapCheckoutOrderConfirmationRpcError(error) };
  }
}

function mapCheckoutOrderRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map(mapCheckoutOrderRow) : [];
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

function labelFromEnum(value: unknown, labels: Record<string, string>, fallback: string) {
  const key = typeof value === "string" ? value : "";
  return labels[key] ?? fallback;
}

function mapCheckoutOrderRow(row: unknown): CheckoutOrderConfirmationSafe {
  const item = row as Record<string, unknown>;

  return {
    orderId: requiredString(item.order_id, ""),
    orderNumber: requiredString(item.order_number, "Order number unavailable"),
    checkoutDraftId: requiredString(item.checkout_draft_id, ""),
    orderStatusLabel: labelFromEnum(item.order_status, {
      placed_pending_confirmation: "Placed - waiting for customer confirmation",
      confirmed: "Confirmed"
    }, "Order placed"),
    paymentMethodLabel: labelFromEnum(item.payment_method, {
      pay_on_delivery: "Pay on Delivery"
    }, "Pay on Delivery"),
    paymentCollectionLabel: labelFromEnum(item.payment_collection_status, {
      not_collected: "Payment not collected",
      pending: "Payment not collected"
    }, "Payment not collected"),
    deliveryStatusLabel: labelFromEnum(item.delivery_status, {
      not_arranged: "Delivery not arranged yet",
      pending_quote: "Delivery not arranged yet"
    }, "Delivery not arranged yet"),
    customerConfirmationLabel: labelFromEnum(item.customer_confirmation_status, {
      pending: "Customer confirmation pending",
      confirmed: "Customer confirmed"
    }, "Customer confirmation pending"),
    deliveryQuoteLabel: labelFromEnum(item.delivery_quote_status, {
      not_requested: "Delivery fee not confirmed",
      pending: "Delivery fee not confirmed"
    }, "Delivery fee not confirmed"),
    productName: requiredString(item.product_name, "Product unavailable"),
    productSlug: nullableString(item.product_slug),
    quantity: Number.isInteger(Number(item.quantity)) ? Number(item.quantity) : 0,
    finalCustomerPriceAmount: nullableNumber(item.final_customer_price_amount),
    lineTotalAmount: nullableNumber(item.line_total_amount),
    totalPayableAmount: nullableNumber(item.total_payable_amount),
    currencyCode: requiredString(item.currency_code, "GHS"),
    reservationStatusLabel: labelFromEnum(item.reservation_status, {
      active: "Stock reserved for this order",
      reserved: "Stock reserved for this order"
    }, "Stock reservation created"),
    reservationExpiresAt: nullableString(item.reservation_expires_at),
    createdAt: requiredString(item.created_at, ""),
    updatedAt: requiredString(item.updated_at, "")
  };
}
