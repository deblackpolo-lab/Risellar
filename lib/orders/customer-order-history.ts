import "server-only";

export type CustomerOrderHistoryCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "VALIDATION_ERROR"
  | "RPC_PERMISSION_DENIED"
  | "UNKNOWN";

export type CustomerOrderHistoryState = {
  code: CustomerOrderHistoryCode;
  message: string;
};

export type CustomerOrderHistoryGroup = "all" | "active" | "completed" | "rejected";

export type CustomerOrderHistoryFilters = {
  group?: string | null;
  search?: string | null;
  dateFrom?: string | null;
  dateTo?: string | null;
  limit?: number | string | null;
  cursorCreatedAt?: string | null;
  cursorOrderId?: string | null;
};

export type CustomerOrderHistoryItem = {
  orderId: string;
  orderNumber: string;
  createdAt: string;
  updatedAt: string;
  orderStatusLabel: string;
  orderStatusGroup: CustomerOrderHistoryGroup;
  completedAt: string | null;
  rejectedAt: string | null;
  productName: string;
  productSlug: string | null;
  productImageSnapshot: Record<string, unknown>;
  quantity: number;
  finalCustomerPriceAmount: number | null;
  lineTotalAmount: number | null;
  totalPayableAmount: number | null;
  currencyCode: string;
  paymentMethodLabel: string;
  paymentCollectionLabel: string;
  deliveryStatusLabel: string;
  resellerShopName: string | null;
  resellerShopSlug: string | null;
  detailHref: string;
};

export type CustomerOrderSummary = {
  totalOrderCount: number;
  activeOrderCount: number;
  completedOrderCount: number;
  rejectedOrderCount: number;
  latestOrderCreatedAt: string | null;
  latestOrderNumber: string | null;
  latestOrderStatusLabel: string | null;
  latestTotalPayableAmount: number | null;
  currencyCode: string | null;
};

export type CustomerOrderHistoryRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): PromiseLike<{
    data: T | null;
    error: { code?: string; message?: string; details?: string } | null;
  }>;
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const allowedGroups = new Set<CustomerOrderHistoryGroup>(["all", "active", "completed", "rejected"]);
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

function cleanOptionalText(value: string | null | undefined) {
  const text = value?.trim();
  return text ? text : null;
}

function normalizeGroup(value: string | null | undefined): CustomerOrderHistoryGroup {
  const text = cleanOptionalText(value)?.toLowerCase();

  if (!text) {
    return "all";
  }

  if (!allowedGroups.has(text as CustomerOrderHistoryGroup)) {
    throw new Error("Order group is invalid");
  }

  return text as CustomerOrderHistoryGroup;
}

function normalizeSearch(value: string | null | undefined) {
  const text = cleanOptionalText(value);

  if (text && text.length > 120) {
    throw new Error("Search is too long");
  }

  return text;
}

function normalizeDate(value: string | null | undefined, label: string) {
  const text = cleanOptionalText(value);

  if (!text) {
    return null;
  }

  if (!datePattern.test(text)) {
    throw new Error(`${label} is invalid`);
  }

  return text;
}

function normalizeLimit(value: number | string | null | undefined) {
  const numericValue = Number(value ?? 20);

  if (!Number.isFinite(numericValue)) {
    return 20;
  }

  return Math.min(Math.max(Math.trunc(numericValue), 1), 50);
}

function normalizeCursorOrderId(value: string | null | undefined) {
  const text = cleanOptionalText(value);

  if (!text) {
    return null;
  }

  if (!uuidPattern.test(text)) {
    throw new Error("Cursor order id is invalid");
  }

  return text;
}

export function buildCustomerOrderHistoryPayload(filters: CustomerOrderHistoryFilters = {}) {
  const dateFrom = normalizeDate(filters.dateFrom, "Start date");
  const dateTo = normalizeDate(filters.dateTo, "End date");

  if (dateFrom && dateTo && dateFrom > dateTo) {
    throw new Error("Date range is invalid");
  }

  return {
    p_group: normalizeGroup(filters.group),
    p_search: normalizeSearch(filters.search),
    p_date_from: dateFrom,
    p_date_to: dateTo,
    p_limit: normalizeLimit(filters.limit),
    p_cursor_created_at: cleanOptionalText(filters.cursorCreatedAt),
    p_cursor_order_id: normalizeCursorOrderId(filters.cursorOrderId)
  };
}

export function mapCustomerOrderHistoryRpcError(error: unknown): CustomerOrderHistoryState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as { code?: string; message?: string; details?: string }) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required") || combined.includes("28000")) {
    return { code: "AUTH_REQUIRED", message: "Sign in as a customer to view your orders." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return { code: "SUPABASE_AUTH_TOKEN_MISSING", message: "We could not verify your customer session. Please sign in again." };
  }

  if (combined.includes("invalid") || combined.includes("too long") || combined.includes("23514")) {
    return { code: "VALIDATION_ERROR", message: "Check your order filters and try again." };
  }

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "You are not allowed to view customer orders with this account." };
  }

  return { code: "UNKNOWN", message: "We could not load your orders. Please try again." };
}

export async function listCustomerOrdersSafeWithClient(
  client: CustomerOrderHistoryRpcClient,
  filters: CustomerOrderHistoryFilters = {}
) {
  try {
    const { data, error } = await client.rpc<unknown[]>("list_customer_orders_safe", buildCustomerOrderHistoryPayload(filters));

    if (error) {
      return { orders: [], state: mapCustomerOrderHistoryRpcError(error) };
    }

    return { orders: mapCustomerOrderHistoryRows(data), state: { code: "OK" as const, message: "" } };
  } catch (error) {
    return { orders: [], state: mapCustomerOrderHistoryRpcError(error) };
  }
}

export async function getCustomerOrderSummarySafeWithClient(client: CustomerOrderHistoryRpcClient) {
  try {
    const { data, error } = await client.rpc<unknown[]>("get_customer_order_summary_safe");

    if (error) {
      return { summary: emptySummary(), state: mapCustomerOrderHistoryRpcError(error) };
    }

    return { summary: mapCustomerOrderSummaryRows(data)[0] ?? emptySummary(), state: { code: "OK" as const, message: "" } };
  } catch (error) {
    return { summary: emptySummary(), state: mapCustomerOrderHistoryRpcError(error) };
  }
}

function mapCustomerOrderHistoryRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map(mapCustomerOrderHistoryRow) : [];
}

function mapCustomerOrderSummaryRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map(mapCustomerOrderSummaryRow) : [];
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

function requiredGroup(value: unknown): CustomerOrderHistoryGroup {
  const group = requiredString(value, "active");
  return allowedGroups.has(group as CustomerOrderHistoryGroup) ? group as CustomerOrderHistoryGroup : "active";
}

function mapCustomerOrderHistoryRow(row: unknown): CustomerOrderHistoryItem {
  const item = row as Record<string, unknown>;

  return {
    orderId: requiredString(item.order_id, ""),
    orderNumber: requiredString(item.order_number, "Order number unavailable"),
    createdAt: requiredString(item.created_at, ""),
    updatedAt: requiredString(item.updated_at, ""),
    orderStatusLabel: requiredString(item.order_status_label, "Order status unavailable"),
    orderStatusGroup: requiredGroup(item.order_status_group),
    completedAt: nullableString(item.completed_at),
    rejectedAt: nullableString(item.rejected_at),
    productName: requiredString(item.product_name, "Product unavailable"),
    productSlug: nullableString(item.product_slug),
    productImageSnapshot: mapJsonObject(item.product_image_snapshot),
    quantity: Number.isInteger(Number(item.quantity)) ? Number(item.quantity) : 0,
    finalCustomerPriceAmount: nullableNumber(item.final_customer_price_amount),
    lineTotalAmount: nullableNumber(item.line_total_amount),
    totalPayableAmount: nullableNumber(item.total_payable_amount),
    currencyCode: requiredString(item.currency_code, "GHS"),
    paymentMethodLabel: requiredString(item.payment_method_label, "Pay on Delivery"),
    paymentCollectionLabel: requiredString(item.payment_collection_label, "Payment status unavailable"),
    deliveryStatusLabel: requiredString(item.delivery_status_label, "Delivery status unavailable"),
    resellerShopName: nullableString(item.reseller_shop_name),
    resellerShopSlug: nullableString(item.reseller_shop_slug),
    detailHref: requiredString(item.detail_href, "/customer/orders")
  };
}

function emptySummary(): CustomerOrderSummary {
  return {
    totalOrderCount: 0,
    activeOrderCount: 0,
    completedOrderCount: 0,
    rejectedOrderCount: 0,
    latestOrderCreatedAt: null,
    latestOrderNumber: null,
    latestOrderStatusLabel: null,
    latestTotalPayableAmount: null,
    currencyCode: null
  };
}

function mapCustomerOrderSummaryRow(row: unknown): CustomerOrderSummary {
  const item = row as Record<string, unknown>;

  return {
    totalOrderCount: Number(item.total_order_count ?? 0),
    activeOrderCount: Number(item.active_order_count ?? 0),
    completedOrderCount: Number(item.completed_order_count ?? 0),
    rejectedOrderCount: Number(item.rejected_order_count ?? 0),
    latestOrderCreatedAt: nullableString(item.latest_order_created_at),
    latestOrderNumber: nullableString(item.latest_order_number),
    latestOrderStatusLabel: nullableString(item.latest_order_status_label),
    latestTotalPayableAmount: nullableNumber(item.latest_total_payable_amount),
    currencyCode: nullableString(item.currency_code)
  };
}
