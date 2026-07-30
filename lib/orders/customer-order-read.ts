import "server-only";

export type CustomerOrderReadCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "ORDER_NOT_FOUND"
  | "VALIDATION_ERROR"
  | "RPC_PERMISSION_DENIED"
  | "UNKNOWN";

export type CustomerOrderReadState = {
  code: CustomerOrderReadCode;
  message: string;
};

export type CustomerOrderSafe = {
  orderId: string;
  orderNumber: string;
  createdAt: string;
  updatedAt: string;
  orderStatusLabel: string;
  customerConfirmationLabel: string;
  paymentMethodLabel: string;
  paymentCollectionLabel: string;
  deliveryStatusLabel: string;
  deliveryQuoteLabel: string;
  productName: string;
  productSlug: string | null;
  productImageSnapshot: Record<string, unknown>;
  quantity: number;
  finalCustomerPriceAmount: number | null;
  lineTotalAmount: number | null;
  totalPayableAmount: number | null;
  currencyCode: string;
  customerContactSnapshot: Record<string, unknown>;
  deliveryAddressSnapshot: Record<string, unknown>;
  resellerShopName: string | null;
  resellerShopSlug: string | null;
  reservationStatusLabel: string;
  reservationExpiresAt: string | null;
};

export type CustomerOrderReadRpcClient = {
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

export function buildCustomerOrderSafeReadPayload(orderId: string | null | undefined) {
  return {
    p_order_id: requireUuid(orderId, "Order id")
  };
}

export function mapCustomerOrderReadRpcError(error: unknown): CustomerOrderReadState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as { code?: string; message?: string; details?: string }) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required") || combined.includes("28000")) {
    return { code: "AUTH_REQUIRED", message: "Sign in as a customer to view this order." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return { code: "SUPABASE_AUTH_TOKEN_MISSING", message: "We could not verify your customer session. Please sign in again." };
  }

  if (combined.includes("order id") || combined.includes("23514")) {
    return { code: "VALIDATION_ERROR", message: "This order link is invalid." };
  }

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "You are not allowed to view this order." };
  }

  return { code: "UNKNOWN", message: "We could not load this order. Please try again." };
}

export async function getCustomerOrderSafeWithClient(client: CustomerOrderReadRpcClient, orderId: string | null | undefined) {
  try {
    const { data, error } = await client.rpc<unknown[]>("get_customer_order_safe", buildCustomerOrderSafeReadPayload(orderId));

    if (error) {
      return { order: null, state: mapCustomerOrderReadRpcError(error) };
    }

    const order = mapCustomerOrderRows(data)[0] ?? null;

    return order
      ? { order, state: { code: "OK" as const, message: "" } }
      : { order: null, state: { code: "ORDER_NOT_FOUND" as const, message: "This order was not found for your customer account." } };
  } catch (error) {
    return { order: null, state: mapCustomerOrderReadRpcError(error) };
  }
}

function mapCustomerOrderRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map(mapCustomerOrderRow) : [];
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

function mapCustomerOrderRow(row: unknown): CustomerOrderSafe {
  const item = row as Record<string, unknown>;

  return {
    orderId: requiredString(item.order_id, ""),
    orderNumber: requiredString(item.order_number, "Order number unavailable"),
    createdAt: requiredString(item.created_at, ""),
    updatedAt: requiredString(item.updated_at, ""),
    orderStatusLabel: requiredString(item.order_status_label, "Order status unavailable"),
    customerConfirmationLabel: requiredString(item.customer_confirmation_label, "Customer confirmation unavailable"),
    paymentMethodLabel: requiredString(item.payment_method_label, "Pay on Delivery"),
    paymentCollectionLabel: requiredString(item.payment_collection_label, "Payment not collected"),
    deliveryStatusLabel: requiredString(item.delivery_status_label, "Delivery not arranged yet"),
    deliveryQuoteLabel: requiredString(item.delivery_quote_label, "Delivery fee not confirmed"),
    productName: requiredString(item.product_name, "Product unavailable"),
    productSlug: nullableString(item.product_slug),
    productImageSnapshot: mapJsonObject(item.product_image_snapshot),
    quantity: Number.isInteger(Number(item.quantity)) ? Number(item.quantity) : 0,
    finalCustomerPriceAmount: nullableNumber(item.final_customer_price_amount),
    lineTotalAmount: nullableNumber(item.line_total_amount),
    totalPayableAmount: nullableNumber(item.total_payable_amount),
    currencyCode: requiredString(item.currency_code, "GHS"),
    customerContactSnapshot: mapJsonObject(item.customer_contact_snapshot),
    deliveryAddressSnapshot: mapJsonObject(item.delivery_address_snapshot),
    resellerShopName: nullableString(item.reseller_shop_name),
    resellerShopSlug: nullableString(item.reseller_shop_slug),
    reservationStatusLabel: requiredString(item.reservation_status_label, "Stock reservation unavailable"),
    reservationExpiresAt: nullableString(item.reservation_expires_at)
  };
}
