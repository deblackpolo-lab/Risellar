import "server-only";

export type AdminWithdrawalCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "FINANCE_ADMIN_REQUIRED"
  | "WITHDRAWAL_NOT_FOUND"
  | "WITHDRAWAL_NOT_PENDING"
  | "WITHDRAWAL_ALREADY_PAID"
  | "PAYOUT_REFERENCE_REQUIRED"
  | "BALANCE_STATE_INCONSISTENT"
  | "CONFLICTING_PAYOUT_RETRY"
  | "VALIDATION_ERROR"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "UNKNOWN";

export type AdminWithdrawalState = {
  code: AdminWithdrawalCode;
  message: string;
};

export type AdminWithdrawalRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): PromiseLike<{
    data: T | null;
    error: { code?: string; message?: string; details?: string } | null;
  }>;
};

export type AdminResellerWithdrawal = {
  withdrawalId: string;
  requestReference: string | null;
  resellerDisplayName: string;
  resellerEmailMasked: string | null;
  requestedAmount: number | null;
  currencyCode: string;
  withdrawalStatus: string;
  payoutMethod: string | null;
  payoutAccountName: string | null;
  payoutAccountMasked: string | null;
  requestedAt: string | null;
  paidAt: string | null;
  payoutReferencePresent: boolean;
  canMarkPaid: boolean;
  resellerAvailableAmount?: number | null;
  resellerPendingWithdrawalAmount?: number | null;
  resellerWithdrawnAmount?: number | null;
};

export type MarkWithdrawalPaidInput = {
  withdrawalId?: string | null;
  payoutReference?: string | null;
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

export function buildMarkWithdrawalPaidPayload(input: MarkWithdrawalPaidInput) {
  const withdrawalId = requireUuid(input.withdrawalId, "Withdrawal id");
  const payoutReference = normalizeBoundedText(input.payoutReference, 100);

  if (input.acknowledgement !== "confirmed") {
    throw new Error("VALIDATION_ERROR");
  }

  if (!payoutReference) {
    throw new Error("PAYOUT_REFERENCE_REQUIRED");
  }

  return {
    p_withdrawal_id: withdrawalId,
    p_payout_reference: payoutReference,
    p_admin_note: normalizeBoundedText(input.adminNote, 500),
    p_idempotency_key: normalizeBoundedText(input.idempotencyKey, 140) ?? `admin-withdrawal-paid:${withdrawalId}`
  };
}

export function mapAdminWithdrawalRpcError(error: unknown): AdminWithdrawalState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as { code?: string; message?: string; details?: string }) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required") || combined.includes("28000")) {
    return { code: "AUTH_REQUIRED", message: "Sign in to manage withdrawals." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return { code: "SUPABASE_AUTH_TOKEN_MISSING", message: "We could not prepare your secure admin session. Please sign in again." };
  }

  if (combined.includes("finance_admin_required") || combined.includes("42501")) {
    return { code: "FINANCE_ADMIN_REQUIRED", message: "You do not have permission to manage withdrawals." };
  }

  if (combined.includes("withdrawal_not_found") || combined.includes("withdrawal id")) {
    return { code: "WITHDRAWAL_NOT_FOUND", message: "This withdrawal is unavailable." };
  }

  if (combined.includes("withdrawal_already_paid")) {
    return { code: "WITHDRAWAL_ALREADY_PAID", message: "This withdrawal has already been marked paid." };
  }

  if (combined.includes("withdrawal_not_pending")) {
    return { code: "WITHDRAWAL_NOT_PENDING", message: "This withdrawal can no longer be marked paid." };
  }

  if (combined.includes("payout_reference_required")) {
    return { code: "PAYOUT_REFERENCE_REQUIRED", message: "Enter the payout reference." };
  }

  if (combined.includes("balance_state_inconsistent")) {
    return { code: "BALANCE_STATE_INCONSISTENT", message: "The reseller balance is inconsistent. Contact support before continuing." };
  }

  if (combined.includes("conflicting_payout_retry")) {
    return { code: "CONFLICTING_PAYOUT_RETRY", message: "This withdrawal was already paid with different details. Refresh the page." };
  }

  if (combined.includes("validation_error") || combined.includes("field_too_long")) {
    return { code: "VALIDATION_ERROR", message: "Confirm the manual payout details before continuing." };
  }

  return { code: "UNKNOWN", message: "We could not confirm the result. Refresh before trying again." };
}

export async function listAdminResellerWithdrawalsSafeWithClient(client: AdminWithdrawalRpcClient, status = "requested") {
  const { data, error } = await client.rpc<unknown[]>("list_admin_reseller_withdrawals_safe", {
    p_status: status,
    p_limit: 50
  });

  if (error) {
    return { withdrawals: [], state: mapAdminWithdrawalRpcError(error) };
  }

  return { withdrawals: mapAdminWithdrawalRows(data), state: { code: "OK" as const, message: "Withdrawals loaded." } };
}

export async function getAdminResellerWithdrawalSafeWithClient(client: AdminWithdrawalRpcClient, withdrawalId: string) {
  const { data, error } = await client.rpc<unknown[]>("get_admin_reseller_withdrawal_safe", {
    p_withdrawal_id: requireUuid(withdrawalId, "Withdrawal id")
  });

  if (error) {
    return { withdrawal: null, state: mapAdminWithdrawalRpcError(error) };
  }

  return { withdrawal: mapAdminWithdrawalRows(data)[0] ?? null, state: { code: "OK" as const, message: "Withdrawal loaded." } };
}

export async function markResellerWithdrawalPaidWithClient(client: AdminWithdrawalRpcClient, input: MarkWithdrawalPaidInput) {
  try {
    const payload = buildMarkWithdrawalPaidPayload(input);
    const { data, error } = await client.rpc<unknown[]>("admin_mark_reseller_withdrawal_paid", payload);

    if (error) {
      return { withdrawal: null, state: mapAdminWithdrawalRpcError(error) };
    }

    return { withdrawal: mapPaidRows(data)[0] ?? null, state: { code: "OK" as const, message: "Withdrawal marked as paid." } };
  } catch (error) {
    return { withdrawal: null, state: mapAdminWithdrawalRpcError(error) };
  }
}

function mapAdminWithdrawalRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map(mapAdminWithdrawalRow) : [];
}

function mapAdminWithdrawalRow(row: unknown): AdminResellerWithdrawal {
  const item = row as Record<string, unknown>;

  return {
    withdrawalId: requiredString(item.withdrawal_id, ""),
    requestReference: nullableString(item.request_reference),
    resellerDisplayName: requiredString(item.reseller_display_name, "Reseller"),
    resellerEmailMasked: nullableString(item.reseller_email_masked),
    requestedAmount: nullableNumber(item.requested_amount),
    currencyCode: requiredString(item.currency_code, "GHS"),
    withdrawalStatus: requiredString(item.withdrawal_status, "unknown"),
    payoutMethod: nullableString(item.payout_method),
    payoutAccountName: nullableString(item.payout_account_name),
    payoutAccountMasked: nullableString(item.payout_account_masked),
    requestedAt: nullableString(item.requested_at),
    paidAt: nullableString(item.paid_at),
    payoutReferencePresent: Boolean(item.payout_reference_present),
    canMarkPaid: Boolean(item.can_mark_paid),
    resellerAvailableAmount: nullableNumber(item.reseller_available_amount),
    resellerPendingWithdrawalAmount: nullableNumber(item.reseller_pending_withdrawal_amount),
    resellerWithdrawnAmount: nullableNumber(item.reseller_withdrawn_amount)
  };
}

function mapPaidRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      withdrawalId: requiredString(item.withdrawal_id, ""),
      requestReference: nullableString(item.request_reference),
      requestedAmount: nullableNumber(item.requested_amount),
      currencyCode: requiredString(item.currency_code, "GHS"),
      withdrawalStatus: requiredString(item.withdrawal_status, "unknown"),
      paidAt: nullableString(item.paid_at),
      pendingWithdrawalAmount: nullableNumber(item.pending_withdrawal_amount),
      withdrawnAmount: nullableNumber(item.withdrawn_amount)
    };
  }) : [];
}
