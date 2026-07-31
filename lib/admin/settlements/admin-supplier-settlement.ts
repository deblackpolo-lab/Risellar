import "server-only";

export type AdminSettlementCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "FINANCE_ADMIN_REQUIRED"
  | "ORDER_NOT_FOUND"
  | "ORDER_NOT_PAYMENT_REPORTED"
  | "SETTLEMENT_NOT_FOUND"
  | "COMMISSION_NOT_FOUND"
  | "SETTLEMENT_ALREADY_VERIFIED"
  | "COMMISSION_ALREADY_AVAILABLE"
  | "FINANCIAL_AMOUNT_MISMATCH"
  | "CURRENCY_MISMATCH"
  | "STOCK_STATE_INCONSISTENT"
  | "FIELD_TOO_LONG"
  | "CONFLICTING_RETRY"
  | "VALIDATION_ERROR"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "UNKNOWN";

export type AdminSettlementState = {
  code: AdminSettlementCode;
  message: string;
};

export type AdminSettlementRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): PromiseLike<{
    data: T | null;
    error: { code?: string; message?: string; details?: string } | null;
  }>;
};

export type AdminSupplierSettlement = {
  orderId: string;
  orderNumber: string;
  supplierBusinessName: string;
  resellerDisplayName: string;
  customerTotalAmount: number | null;
  supplierAmountExpected?: number | null;
  platformAmountDue: number | null;
  resellerCommissionDue: number | null;
  totalSettlementDue: number | null;
  currencyCode: string;
  orderStatus: string;
  paymentCollectionStatus: string;
  settlementStatus: string;
  commissionStatus: string;
  supplierReportedAt: string | null;
  settlementCreatedAt?: string | null;
  settlementVerifiedAt?: string | null;
  completedAt?: string | null;
  reservationStatus?: string | null;
  settlementReferencePresent?: boolean;
  adminNotePresent?: boolean;
  canVerify?: boolean;
};

export type VerifySupplierSettlementInput = {
  orderId?: string | null;
  settlementReference?: string | null;
  adminNote?: string | null;
  acknowledgement?: string | null;
  idempotencyKey?: string | null;
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

function normalizeBoundedText(value: string | null | undefined, maxLength: number) {
  const text = cleanOptionalText(value);

  if (text && text.length > maxLength) {
    throw new Error("FIELD_TOO_LONG");
  }

  if (text && /[<>]|pin|password|secret|token|card|cvv|otp/i.test(text)) {
    throw new Error("FIELD_TOO_LONG");
  }

  return text;
}

function nullableNumber(value: unknown) {
  if (value === null || value === undefined) return null;
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : null;
}

function nullableString(value: unknown) {
  return typeof value === "string" && value.trim() ? value : null;
}

function requiredString(value: unknown, fallback: string) {
  return nullableString(value) ?? fallback;
}

export function buildVerifySupplierSettlementPayload(input: VerifySupplierSettlementInput) {
  const orderId = requireUuid(input.orderId, "Order id");

  if (input.acknowledgement !== "confirmed") {
    throw new Error("ACKNOWLEDGEMENT_REQUIRED");
  }

  return {
    p_order_id: orderId,
    p_settlement_reference: normalizeBoundedText(input.settlementReference, 100),
    p_admin_note: normalizeBoundedText(input.adminNote, 500),
    p_idempotency_key: normalizeBoundedText(input.idempotencyKey, 140) ?? `admin-settlement-verify:${orderId}`
  };
}

export function mapAdminSettlementRpcError(error: unknown): AdminSettlementState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as { code?: string; message?: string; details?: string }) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required") || combined.includes("28000")) {
    return { code: "AUTH_REQUIRED", message: "Sign in to verify settlements." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return { code: "SUPABASE_AUTH_TOKEN_MISSING", message: "We could not prepare your secure admin session. Please sign in again." };
  }

  if (combined.includes("finance_admin_required") || combined.includes("42501")) {
    return { code: "FINANCE_ADMIN_REQUIRED", message: "You do not have permission to verify settlements." };
  }

  if (combined.includes("order_not_found")) {
    return { code: "ORDER_NOT_FOUND", message: "This settlement is unavailable." };
  }

  if (combined.includes("order_not_payment_reported")) {
    return { code: "ORDER_NOT_PAYMENT_REPORTED", message: "The supplier has not reported payment for this order." };
  }

  if (combined.includes("settlement_not_found")) {
    return { code: "SETTLEMENT_NOT_FOUND", message: "The settlement obligation is unavailable." };
  }

  if (combined.includes("commission_not_found")) {
    return { code: "COMMISSION_NOT_FOUND", message: "The reseller commission record is unavailable." };
  }

  if (combined.includes("settlement_already_verified")) {
    return { code: "SETTLEMENT_ALREADY_VERIFIED", message: "This settlement has already been verified." };
  }

  if (combined.includes("commission_already_available")) {
    return { code: "COMMISSION_ALREADY_AVAILABLE", message: "This commission is already available." };
  }

  if (combined.includes("financial_amount_mismatch")) {
    return { code: "FINANCIAL_AMOUNT_MISMATCH", message: "The settlement amounts do not match the order records." };
  }

  if (combined.includes("currency_mismatch")) {
    return { code: "CURRENCY_MISMATCH", message: "The settlement currency does not match the order." };
  }

  if (combined.includes("stock_state_inconsistent")) {
    return { code: "STOCK_STATE_INCONSISTENT", message: "Stock finalization is incomplete or inconsistent." };
  }

  if (combined.includes("field_too_long")) {
    return { code: "FIELD_TOO_LONG", message: "Shorten the information and try again." };
  }

  if (combined.includes("conflicting_retry")) {
    return { code: "CONFLICTING_RETRY", message: "This settlement was already verified with different details. Refresh the page." };
  }

  if (combined.includes("acknowledgement_required") || combined.includes("validation_error") || combined.includes("order id")) {
    return { code: "VALIDATION_ERROR", message: "Confirm the settlement details before verifying." };
  }

  return { code: "UNKNOWN", message: "We could not confirm the result. Refresh before trying again." };
}

export async function listPendingSupplierSettlementsWithClient(client: AdminSettlementRpcClient) {
  const { data, error } = await client.rpc<unknown[]>("list_admin_pending_supplier_settlements", {
    p_limit: 50
  });

  if (error) {
    return { settlements: [], state: mapAdminSettlementRpcError(error) };
  }

  return { settlements: mapSettlementRows(data), state: { code: "OK" as const, message: "Settlements loaded." } };
}

export async function getAdminSupplierSettlementSafeWithClient(client: AdminSettlementRpcClient, orderId: string) {
  const { data, error } = await client.rpc<unknown[]>("get_admin_supplier_settlement_safe", {
    p_order_id: requireUuid(orderId, "Order id")
  });

  if (error) {
    return { settlement: null, state: mapAdminSettlementRpcError(error) };
  }

  return {
    settlement: mapSettlementRows(data)[0] ?? null,
    state: { code: "OK" as const, message: "Settlement loaded." }
  };
}

export async function verifySupplierSettlementWithClient(client: AdminSettlementRpcClient, input: VerifySupplierSettlementInput) {
  try {
    const payload = buildVerifySupplierSettlementPayload(input);
    const { data, error } = await client.rpc<unknown[]>("admin_verify_supplier_settlement", payload);

    if (error) {
      return { settlement: null, state: mapAdminSettlementRpcError(error) };
    }

    return {
      settlement: mapSettlementRows(data)[0] ?? null,
      state: { code: "OK" as const, message: "Settlement verified - commission available." }
    };
  } catch (error) {
    return { settlement: null, state: mapAdminSettlementRpcError(error) };
  }
}

function mapSettlementRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map(mapSettlementRow) : [];
}

function mapSettlementRow(row: unknown): AdminSupplierSettlement {
  const item = row as Record<string, unknown>;

  return {
    orderId: requiredString(item.order_id, ""),
    orderNumber: requiredString(item.order_number, "Order unavailable"),
    supplierBusinessName: requiredString(item.supplier_business_name, "Supplier unavailable"),
    resellerDisplayName: requiredString(item.reseller_display_name, "Reseller shop unavailable"),
    customerTotalAmount: nullableNumber(item.customer_total_amount),
    supplierAmountExpected: nullableNumber(item.supplier_amount_expected),
    platformAmountDue: nullableNumber(item.platform_amount_due),
    resellerCommissionDue: nullableNumber(item.reseller_commission_due),
    totalSettlementDue: nullableNumber(item.total_settlement_due),
    currencyCode: requiredString(item.currency_code, "GHS"),
    orderStatus: requiredString(item.order_status, "unknown"),
    paymentCollectionStatus: requiredString(item.payment_collection_status, "unknown"),
    settlementStatus: requiredString(item.settlement_status, "unknown"),
    commissionStatus: requiredString(item.commission_status, "unknown"),
    supplierReportedAt: nullableString(item.supplier_reported_at),
    settlementCreatedAt: nullableString(item.settlement_created_at),
    settlementVerifiedAt: nullableString(item.settlement_verified_at),
    completedAt: nullableString(item.completed_at),
    reservationStatus: nullableString(item.reservation_status),
    settlementReferencePresent: Boolean(item.settlement_reference_present),
    adminNotePresent: Boolean(item.admin_note_present),
    canVerify: Boolean(item.can_verify)
  };
}
