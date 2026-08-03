import "server-only";

export type CustomerDisputeActionCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "VALIDATION_ERROR"
  | "DISPUTE_NOT_FOUND"
  | "ORDER_NOT_FOUND"
  | "DUPLICATE_ACTIVE_DISPUTE"
  | "IDEMPOTENCY_CONFLICT"
  | "ITEM_SELECTOR_REQUIRED"
  | "DISPUTE_RESPONSE_NOT_ALLOWED"
  | "RPC_PERMISSION_DENIED"
  | "UNKNOWN";

export type CustomerDisputeActionState = {
  code: CustomerDisputeActionCode;
  message: string;
  disputeHref?: string;
};

export type CustomerDisputeStatus =
  | "open"
  | "awaiting_customer"
  | "awaiting_supplier"
  | "under_review"
  | "return_review"
  | "refund_review"
  | "resolved_customer"
  | "resolved_supplier"
  | "partially_resolved"
  | "rejected"
  | "cancelled"
  | "closed";

export type CustomerDisputeListParams = {
  status?: string | null;
  limit?: string | number | null;
  cursorOpenedAt?: string | null;
  cursorDisputeId?: string | null;
};

export type CustomerDisputeOpenInput = {
  orderId?: string | null;
  orderItemId?: string | null;
  disputeCategory?: string | null;
  reasonCode?: string | null;
  requestedOutcome?: string | null;
  description?: string | null;
  idempotencyKey?: string | null;
};

export type CustomerDisputeResponseInput = {
  disputeId?: string | null;
  body?: string | null;
  idempotencyKey?: string | null;
};

export type CustomerDisputeListItem = {
  disputeId: string;
  safeOrderReference: string;
  scopeType: string;
  affectedItemSummary: string;
  category: string;
  categoryLabel: string;
  reasonCode: string;
  reasonLabel: string;
  requestedOutcome: string;
  requestedOutcomeLabel: string;
  status: CustomerDisputeStatus;
  statusLabel: string;
  customerActionRequired: boolean;
  supplierActionRequired: boolean;
  openedAt: string;
  updatedAt: string;
  safeLatestMessage: string | null;
  safeNextAction: string | null;
  detailHref: string;
};

export type CustomerDisputeMessage = {
  authorRole: string;
  messageType: string;
  body: string;
  createdAt: string;
};

export type CustomerDisputeStatusHistoryItem = {
  previousStatus: string | null;
  newStatus: string;
  changedByRole: string | null;
  publicNote: string | null;
  createdAt: string;
};

export type CustomerDispute = CustomerDisputeListItem & {
  priority: string;
  publicResolutionMessage: string | null;
  messages: CustomerDisputeMessage[];
  statusHistory: CustomerDisputeStatusHistoryItem[];
};

export type CustomerDisputeOrderItemSafe = {
  orderItemId: string;
  safeItemName: string;
  safeVariantSummary: string | null;
  quantity: number;
  finalCustomerPriceAmount: number | null;
  lineTotalAmount: number | null;
  currencyCode: string;
};

type CustomerDisputeRpcError = {
  code?: string;
  message?: string;
  details?: string;
};

type CustomerDisputeRpcResult<T> = PromiseLike<{
  data: T | null;
  error: CustomerDisputeRpcError | null;
}>;

export type CustomerDisputeRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): CustomerDisputeRpcResult<T>;
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const customerDisputeStatuses: CustomerDisputeStatus[] = [
  "open",
  "awaiting_customer",
  "awaiting_supplier",
  "under_review",
  "return_review",
  "refund_review",
  "resolved_customer",
  "resolved_supplier",
  "partially_resolved",
  "rejected",
  "cancelled",
  "closed"
];

const categoryLabels: Record<string, string> = {
  pre_delivery: "Before delivery",
  delivery: "Delivery",
  payment: "Payment",
  post_completion: "After delivery",
  other: "Other"
};

const reasonLabels: Record<string, string> = {
  supplier_not_responding: "Supplier not responding",
  supplier_rejected_status_incorrect: "Supplier rejection seems incorrect",
  order_stuck_in_preparation: "Order stuck in preparation",
  delivery_not_arranged: "Delivery not arranged",
  delivery_delay: "Delivery delay",
  customer_requests_cancellation: "I want to cancel",
  order_not_received: "Order not received",
  wrong_item_received: "Wrong item received",
  damaged_item_received: "Damaged item received",
  incomplete_order: "Incomplete order",
  unsafe_delivery_issue: "Unsafe delivery issue",
  delivery_fee_disagreement: "Delivery fee disagreement",
  customer_paid_not_reported: "Payment not reported",
  supplier_reported_customer_disagrees: "I disagree with payment report",
  duplicate_payment_claim: "Duplicate payment claim",
  wrong_amount_collected: "Wrong amount collected",
  unauthorised_extra_charge: "Unauthorised extra charge",
  item_not_as_described: "Item not as described",
  product_quality_issue: "Product quality issue",
  return_requested: "Return requested",
  refund_requested: "Refund requested",
  other: "Other"
};

const outcomeLabels: Record<string, string> = {
  information_only: "Information only",
  cancellation: "Cancellation",
  redelivery: "Redelivery",
  replacement: "Replacement",
  return: "Return",
  full_refund: "Full refund",
  partial_refund: "Partial refund",
  delivery_fee_refund: "Delivery fee refund",
  accounting_correction: "Accounting correction",
  other: "Other"
};

const statusLabels: Record<CustomerDisputeStatus, string> = {
  open: "Open",
  awaiting_customer: "Waiting for you",
  awaiting_supplier: "Waiting for supplier",
  under_review: "Under review",
  return_review: "Return review",
  refund_review: "Refund review",
  resolved_customer: "Resolved for customer",
  resolved_supplier: "Resolved for supplier",
  partially_resolved: "Partially resolved",
  rejected: "Rejected",
  cancelled: "Cancelled",
  closed: "Closed"
};

const itemSpecificReasonCodes = new Set([
  "wrong_item_received",
  "damaged_item_received",
  "incomplete_order",
  "item_not_as_described",
  "product_quality_issue",
  "return_requested",
  "refund_requested"
]);

export const customerDisputeReasonOptions = [
  { category: "delivery", reasonCode: "delivery_delay", label: reasonLabels.delivery_delay, itemSelectorRequired: false },
  { category: "delivery", reasonCode: "delivery_not_arranged", label: reasonLabels.delivery_not_arranged, itemSelectorRequired: false },
  { category: "pre_delivery", reasonCode: "supplier_not_responding", label: reasonLabels.supplier_not_responding, itemSelectorRequired: false },
  { category: "pre_delivery", reasonCode: "customer_requests_cancellation", label: reasonLabels.customer_requests_cancellation, itemSelectorRequired: false },
  { category: "payment", reasonCode: "customer_paid_not_reported", label: reasonLabels.customer_paid_not_reported, itemSelectorRequired: false },
  { category: "other", reasonCode: "other", label: reasonLabels.other, itemSelectorRequired: false },
  { category: "post_completion", reasonCode: "wrong_item_received", label: reasonLabels.wrong_item_received, itemSelectorRequired: true },
  { category: "post_completion", reasonCode: "damaged_item_received", label: reasonLabels.damaged_item_received, itemSelectorRequired: true },
  { category: "post_completion", reasonCode: "return_requested", label: reasonLabels.return_requested, itemSelectorRequired: true },
  { category: "post_completion", reasonCode: "refund_requested", label: reasonLabels.refund_requested, itemSelectorRequired: true }
] as const;

export const customerDisputeOutcomeOptions = [
  { value: "information_only", label: outcomeLabels.information_only },
  { value: "cancellation", label: outcomeLabels.cancellation },
  { value: "redelivery", label: outcomeLabels.redelivery },
  { value: "replacement", label: outcomeLabels.replacement },
  { value: "return", label: outcomeLabels.return },
  { value: "full_refund", label: outcomeLabels.full_refund },
  { value: "partial_refund", label: outcomeLabels.partial_refund },
  { value: "delivery_fee_refund", label: outcomeLabels.delivery_fee_refund },
  { value: "accounting_correction", label: outcomeLabels.accounting_correction },
  { value: "other", label: outcomeLabels.other }
] as const;

export const initialCustomerDisputeActionState: CustomerDisputeActionState = {
  code: "OK",
  message: ""
};

function cleanOptionalText(value: string | null | undefined) {
  const text = value?.trim();
  return text ? text : null;
}

function requireText(value: string | null | undefined, label: string) {
  const text = cleanOptionalText(value);

  if (!text) {
    throw new Error(`${label} is required`);
  }

  return text;
}

function requireUuid(value: string | null | undefined, label: string) {
  const text = requireText(value, label);

  if (!uuidPattern.test(text)) {
    throw new Error(`${label} is invalid`);
  }

  return text;
}

function normalizeLimit(limit: string | number | null | undefined) {
  const value = typeof limit === "number" ? limit : Number(limit ?? 20);

  if (!Number.isFinite(value)) {
    return 20;
  }

  return Math.min(Math.max(Math.trunc(value), 1), 50);
}

function normalizeStatus(status: string | null | undefined) {
  const value = cleanOptionalText(status);

  if (!value) {
    return null;
  }

  if (!customerDisputeStatuses.includes(value as CustomerDisputeStatus)) {
    throw new Error("Dispute status filter is invalid");
  }

  return value;
}

function labelFor(map: Record<string, string>, value: string, fallback = "Unavailable") {
  return map[value] ?? fallback;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asArray(value: unknown) {
  return Array.isArray(value) ? value : [];
}

function normalizeRpcRows(data: unknown) {
  return Array.isArray(data) ? data : [];
}

function buildDetailHref(disputeId: string) {
  return `/customer/disputes/${disputeId}`;
}

export function buildCustomerDisputeListPayload(params: CustomerDisputeListParams) {
  return {
    p_status: normalizeStatus(params.status),
    p_limit: normalizeLimit(params.limit),
    p_cursor_opened_at: cleanOptionalText(params.cursorOpenedAt),
    p_cursor_dispute_id: cleanOptionalText(params.cursorDisputeId)
  };
}

export function buildCustomerDisputeOpenPayload(input: CustomerDisputeOpenInput) {
  const orderItemId = cleanOptionalText(input.orderItemId);
  const reasonCode = requireText(input.reasonCode, "Reason");

  if (itemSpecificReasonCodes.has(reasonCode) && !orderItemId) {
    throw new Error("This reason needs a safe item selector before it can be submitted.");
  }

  return {
    p_order_id: requireUuid(input.orderId, "Order id"),
    p_order_item_id: orderItemId,
    p_dispute_category: requireText(input.disputeCategory, "Dispute category"),
    p_reason_code: reasonCode,
    p_requested_outcome: requireText(input.requestedOutcome, "Requested outcome"),
    p_description: requireText(input.description, "Description"),
    p_idempotency_key: requireText(input.idempotencyKey, "Idempotency key")
  };
}

export function buildCustomerDisputeResponsePayload(input: CustomerDisputeResponseInput) {
  return {
    p_dispute_id: requireUuid(input.disputeId, "Dispute id"),
    p_body: requireText(input.body, "Response"),
    p_idempotency_key: requireText(input.idempotencyKey, "Idempotency key")
  };
}

export function buildCustomerDisputeOpenInputFromFormData(orderId: string, formData: FormData): CustomerDisputeOpenInput {
  const reasonCode = formData.get("reason_code")?.toString();
  const option = customerDisputeReasonOptions.find((item) => item.reasonCode === reasonCode);

  return {
    orderId,
    orderItemId: formData.get("order_item_id")?.toString(),
    disputeCategory: formData.get("dispute_category")?.toString() || option?.category,
    reasonCode,
    requestedOutcome: formData.get("requested_outcome")?.toString(),
    description: formData.get("description")?.toString(),
    idempotencyKey: formData.get("idempotency_key")?.toString()
  };
}

export function buildCustomerDisputeResponseInputFromFormData(disputeId: string, formData: FormData): CustomerDisputeResponseInput {
  return {
    disputeId,
    body: formData.get("body")?.toString(),
    idempotencyKey: formData.get("idempotency_key")?.toString()
  };
}

export function mapCustomerDisputeRpcError(error: unknown): CustomerDisputeActionState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = isRecord(error) ? (error as CustomerDisputeRpcError) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required") || combined.includes("customer_required") || combined.includes("profile_sync_failed")) {
    return { code: "AUTH_REQUIRED", message: "Sign in with your customer account before managing disputes." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return { code: "SUPABASE_AUTH_TOKEN_MISSING", message: "We could not prepare your secure customer session. Please sign in again." };
  }

  if (combined.includes("order_item_required")) {
    return { code: "ITEM_SELECTOR_REQUIRED", message: "This issue needs a safe item selector before it can be reported." };
  }

  if (combined.includes("order_item_not_allowed")) {
    return { code: "VALIDATION_ERROR", message: "This issue should be reported without selecting an item." };
  }

  if (combined.includes("order_item_not_found")) {
    return { code: "RPC_PERMISSION_DENIED", message: "That order item was not found for your customer account." };
  }

  if (combined.includes("invalid_reason_category")) {
    return { code: "VALIDATION_ERROR", message: "Choose a supported reason for this issue." };
  }

  if (combined.includes("dispute_not_allowed_for_order_state")) {
    return { code: "VALIDATION_ERROR", message: "This issue is not available for the current order status." };
  }

  if (combined.includes("duplicate_active_dispute")) {
    return { code: "DUPLICATE_ACTIVE_DISPUTE", message: "A matching active dispute already exists for this order." };
  }

  if (combined.includes("idempotency_conflict")) {
    return { code: "IDEMPOTENCY_CONFLICT", message: "This submission key was already used for different dispute details. Refresh and try again." };
  }

  if (combined.includes("dispute_response_not_allowed")) {
    return { code: "DISPUTE_RESPONSE_NOT_ALLOWED", message: "This dispute is not accepting customer responses right now." };
  }

  if (combined.includes("dispute_not_found")) {
    return { code: "DISPUTE_NOT_FOUND", message: "That dispute was not found for your customer account." };
  }

  if (combined.includes("order_not_found")) {
    return { code: "ORDER_NOT_FOUND", message: "That order was not found for your customer account." };
  }

  if (combined.includes("permission denied") || combined.includes("42501") || combined.includes("rls")) {
    return { code: "RPC_PERMISSION_DENIED", message: "Your customer account is not allowed to perform this dispute action." };
  }

  if (
    combined.includes("is required")
    || combined.includes("invalid")
    || combined.includes("23514")
    || combined.includes("validation")
    || combined.includes("not_allowed")
  ) {
    return { code: "VALIDATION_ERROR", message: "Check the dispute details and try again." };
  }

  return { code: "UNKNOWN", message: "Customer dispute action failed. Try again or contact support." };
}

export async function listCustomerDisputesSafeWithClient(client: CustomerDisputeRpcClient, params: CustomerDisputeListParams = {}) {
  const { data, error } = await client.rpc<unknown[]>("list_customer_disputes_safe", buildCustomerDisputeListPayload(params));

  if (error) {
    return {
      disputes: [] as CustomerDisputeListItem[],
      state: mapCustomerDisputeRpcError(error)
    };
  }

  return {
    disputes: normalizeRpcRows(data).map(mapCustomerDisputeListItem),
    state: initialCustomerDisputeActionState
  };
}

export async function getCustomerDisputeSafeWithClient(client: CustomerDisputeRpcClient, disputeId: string) {
  try {
    const { data, error } = await client.rpc<unknown[]>("get_customer_dispute_safe", {
      p_dispute_id: requireUuid(disputeId, "Dispute id")
    });

    if (error) {
      return {
        dispute: null,
        state: mapCustomerDisputeRpcError(error)
      };
    }

    const row = normalizeRpcRows(data)[0];

    return {
      dispute: row ? mapCustomerDispute(row) : null,
      state: row ? initialCustomerDisputeActionState : ({ code: "DISPUTE_NOT_FOUND", message: "That dispute was not found for your customer account." } as const)
    };
  } catch (error) {
    return {
      dispute: null,
      state: mapCustomerDisputeRpcError(error)
    };
  }
}

export async function listCustomerOrderItemsForDisputeSafeWithClient(client: CustomerDisputeRpcClient, orderId: string | null | undefined) {
  try {
    const { data, error } = await client.rpc<unknown[]>("list_customer_order_items_for_dispute_safe", {
      p_order_id: requireUuid(orderId, "Order id")
    });

    if (error) {
      return {
        orderItems: [] as CustomerDisputeOrderItemSafe[],
        state: mapCustomerDisputeRpcError(error)
      };
    }

    return {
      orderItems: normalizeRpcRows(data).map(mapCustomerDisputeOrderItem).filter((item) => Boolean(item.orderItemId)),
      state: initialCustomerDisputeActionState
    };
  } catch (error) {
    return {
      orderItems: [] as CustomerDisputeOrderItemSafe[],
      state: mapCustomerDisputeRpcError(error)
    };
  }
}

export async function openCustomerDisputeWithClient(client: CustomerDisputeRpcClient, input: CustomerDisputeOpenInput) {
  try {
    const { data, error } = await client.rpc<unknown[]>("customer_open_order_dispute", buildCustomerDisputeOpenPayload(input));

    if (error) {
      return mapCustomerDisputeRpcError(error);
    }

    const row = normalizeRpcRows(data)[0] as Record<string, unknown> | undefined;
    const disputeId = String(row?.dispute_id ?? "");

    return {
      code: "OK" as const,
      message: row?.created === false ? "A matching dispute is already open." : "Dispute opened.",
      disputeHref: disputeId ? buildDetailHref(disputeId) : undefined
    };
  } catch (error) {
    return mapCustomerDisputeRpcError(error);
  }
}

export async function addCustomerDisputeResponseWithClient(client: CustomerDisputeRpcClient, input: CustomerDisputeResponseInput) {
  try {
    const { error } = await client.rpc<unknown[]>("customer_add_dispute_response", buildCustomerDisputeResponsePayload(input));

    if (error) {
      return mapCustomerDisputeRpcError(error);
    }

    return { code: "OK" as const, message: "Response added." };
  } catch (error) {
    return mapCustomerDisputeRpcError(error);
  }
}

function mapCustomerDisputeListItem(row: unknown): CustomerDisputeListItem {
  const item = isRecord(row) ? row : {};
  const disputeId = String(item.dispute_id ?? "");
  const status = customerDisputeStatuses.includes(String(item.status) as CustomerDisputeStatus)
    ? (String(item.status) as CustomerDisputeStatus)
    : "open";
  const category = String(item.category ?? "");
  const reasonCode = String(item.reason_code ?? "");
  const requestedOutcome = String(item.requested_outcome ?? "");

  return {
    disputeId,
    safeOrderReference: String(item.safe_order_reference ?? "Order"),
    scopeType: String(item.scope_type ?? "order"),
    affectedItemSummary: String(item.affected_item_summary ?? "Order-wide review"),
    category,
    categoryLabel: labelFor(categoryLabels, category),
    reasonCode,
    reasonLabel: labelFor(reasonLabels, reasonCode),
    requestedOutcome,
    requestedOutcomeLabel: labelFor(outcomeLabels, requestedOutcome),
    status,
    statusLabel: statusLabels[status],
    customerActionRequired: item.customer_action_required === true,
    supplierActionRequired: item.supplier_action_required === true,
    openedAt: String(item.opened_at ?? ""),
    updatedAt: String(item.updated_at ?? ""),
    safeLatestMessage: cleanOptionalText(typeof item.safe_latest_message === "string" ? item.safe_latest_message : null),
    safeNextAction: cleanOptionalText(typeof item.safe_next_action === "string" ? item.safe_next_action : null),
    detailHref: buildDetailHref(disputeId)
  };
}

function mapCustomerDispute(row: unknown): CustomerDispute {
  const item = isRecord(row) ? row : {};

  return {
    ...mapCustomerDisputeListItem(row),
    priority: String(item.priority ?? "normal"),
    publicResolutionMessage: cleanOptionalText(typeof item.public_resolution_message === "string" ? item.public_resolution_message : null),
    messages: asArray(item.messages).map(mapCustomerDisputeMessage).filter((message) => Boolean(message.body)),
    statusHistory: asArray(item.status_history).map(mapCustomerDisputeStatusHistoryItem).filter((entry) => Boolean(entry.newStatus))
  };
}

function nullableNumber(value: unknown) {
  if (value === null || value === undefined) {
    return null;
  }

  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : null;
}

function mapCustomerDisputeOrderItem(row: unknown): CustomerDisputeOrderItemSafe {
  const item = isRecord(row) ? row : {};

  return {
    orderItemId: String(item.order_item_id ?? ""),
    safeItemName: String(item.safe_item_name ?? "Order item"),
    safeVariantSummary: cleanOptionalText(typeof item.safe_variant_summary === "string" ? item.safe_variant_summary : null),
    quantity: Number.isInteger(Number(item.quantity)) ? Number(item.quantity) : 0,
    finalCustomerPriceAmount: nullableNumber(item.final_customer_price_amount),
    lineTotalAmount: nullableNumber(item.line_total_amount),
    currencyCode: String(item.currency_code ?? "GHS")
  };
}

function mapCustomerDisputeMessage(row: unknown): CustomerDisputeMessage {
  const item = isRecord(row) ? row : {};

  return {
    authorRole: String(item.authorRole ?? ""),
    messageType: String(item.messageType ?? ""),
    body: String(item.body ?? ""),
    createdAt: String(item.createdAt ?? "")
  };
}

function mapCustomerDisputeStatusHistoryItem(row: unknown): CustomerDisputeStatusHistoryItem {
  const item = isRecord(row) ? row : {};

  return {
    previousStatus: cleanOptionalText(typeof item.previousStatus === "string" ? item.previousStatus : null),
    newStatus: String(item.newStatus ?? ""),
    changedByRole: cleanOptionalText(typeof item.changedByRole === "string" ? item.changedByRole : null),
    publicNote: cleanOptionalText(typeof item.publicNote === "string" ? item.publicNote : null),
    createdAt: String(item.createdAt ?? "")
  };
}
