import "server-only";

export type WithdrawalStateCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "RESELLER_REQUIRED"
  | "PAYOUT_ACCOUNT_REQUIRED"
  | "PAYOUT_ACCOUNT_NOT_FOUND"
  | "INVALID_AMOUNT"
  | "BELOW_MINIMUM"
  | "INSUFFICIENT_AVAILABLE_BALANCE"
  | "WITHDRAWAL_ALREADY_PENDING"
  | "CONFLICTING_RETRY"
  | "VALIDATION_ERROR"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "UNKNOWN";

export type WithdrawalState = {
  code: WithdrawalStateCode;
  message: string;
};

export type WithdrawalRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): PromiseLike<{
    data: T | null;
    error: { code?: string; message?: string; details?: string } | null;
  }>;
};

export type ResellerWalletSafe = {
  currencyCode: string;
  lockedCommissionAmount: number;
  availableBalanceAmount: number;
  pendingWithdrawalAmount: number;
  withdrawnAmount: number;
  minimumWithdrawalAmount: number;
  hasPendingWithdrawal: boolean;
};

export type ResellerPayoutAccountSafe = {
  payoutAccountId: string;
  payoutMethod: string;
  accountName: string;
  mobileMoneyNetwork: string | null;
  phoneNumberMasked: string | null;
  isDefault: boolean;
  accountStatus: string;
};

export type ResellerWithdrawalSafe = {
  withdrawalId: string;
  requestReference: string | null;
  requestedAmount: number | null;
  currencyCode: string;
  withdrawalStatus: string;
  payoutMethod: string | null;
  payoutAccountName: string | null;
  payoutAccountMasked: string | null;
  requestedAt: string | null;
  paidAt: string | null;
  payoutReferencePresent: boolean;
};

export type RequestWithdrawalInput = {
  amount?: string | number | null;
  payoutAccountId?: string | null;
  acknowledgement?: string | null;
  idempotencyKey?: string | null;
};

export type SavePayoutAccountInput = {
  accountName?: string | null;
  mobileMoneyNetwork?: string | null;
  phoneNumber?: string | null;
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

function normalizeAmount(value: string | number | null | undefined) {
  const raw = typeof value === "number" ? String(value) : value?.trim();
  const amount = Number(raw);

  if (!raw || !Number.isFinite(amount) || amount <= 0) {
    throw new Error("INVALID_AMOUNT");
  }

  return Math.round(amount * 100) / 100;
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

export function buildRequestWithdrawalPayload(input: RequestWithdrawalInput) {
  if (input.acknowledgement !== "confirmed") {
    throw new Error("VALIDATION_ERROR");
  }

  return {
    p_amount: normalizeAmount(input.amount),
    p_payout_account_id: requireUuid(input.payoutAccountId, "Payout account"),
    p_idempotency_key: normalizeBoundedText(input.idempotencyKey, 140) ?? crypto.randomUUID()
  };
}

export function buildSavePayoutAccountPayload(input: SavePayoutAccountInput) {
  const accountName = normalizeBoundedText(input.accountName, 120);
  const mobileMoneyNetwork = normalizeBoundedText(input.mobileMoneyNetwork, 40);
  const phoneNumber = normalizeBoundedText(input.phoneNumber, 32);

  if (!accountName || !mobileMoneyNetwork || !phoneNumber) {
    throw new Error("PAYOUT_ACCOUNT_REQUIRED");
  }

  return {
    p_account_name: accountName,
    p_mobile_money_network: mobileMoneyNetwork,
    p_phone_number: phoneNumber,
    p_idempotency_key: normalizeBoundedText(input.idempotencyKey, 140) ?? crypto.randomUUID()
  };
}

export function mapWithdrawalRpcError(error: unknown): WithdrawalState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as { code?: string; message?: string; details?: string }) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required") || combined.includes("28000")) {
    return { code: "AUTH_REQUIRED", message: "Sign in to request a withdrawal." };
  }

  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) {
    return { code: "SUPABASE_AUTH_TOKEN_MISSING", message: "We could not prepare your secure session. Please sign in again." };
  }

  if (combined.includes("reseller_required") || combined.includes("reseller account is required") || combined.includes("42501")) {
    return { code: "RESELLER_REQUIRED", message: "Use an active reseller account." };
  }

  if (combined.includes("payout_account_not_found") || combined.includes("payout account")) {
    return { code: "PAYOUT_ACCOUNT_NOT_FOUND", message: "Choose a valid payout account." };
  }

  if (combined.includes("payout_account_required")) {
    return { code: "PAYOUT_ACCOUNT_REQUIRED", message: "Save a valid payout account first." };
  }

  if (combined.includes("invalid_amount")) {
    return { code: "INVALID_AMOUNT", message: "Enter a valid withdrawal amount." };
  }

  if (combined.includes("below_minimum")) {
    return { code: "BELOW_MINIMUM", message: "Enter at least the minimum withdrawal amount." };
  }

  if (combined.includes("insufficient_available_balance")) {
    return { code: "INSUFFICIENT_AVAILABLE_BALANCE", message: "Your available balance is not enough for this withdrawal." };
  }

  if (combined.includes("withdrawal_already_pending")) {
    return { code: "WITHDRAWAL_ALREADY_PENDING", message: "You already have a pending withdrawal request." };
  }

  if (combined.includes("conflicting_retry")) {
    return { code: "CONFLICTING_RETRY", message: "This withdrawal was already requested with different details. Refresh the page." };
  }

  if (combined.includes("validation_error") || combined.includes("field_too_long")) {
    return { code: "VALIDATION_ERROR", message: "Check the withdrawal details and try again." };
  }

  return { code: "UNKNOWN", message: "We could not confirm the result. Refresh before trying again." };
}

export async function getResellerWalletSafeWithClient(client: WithdrawalRpcClient) {
  const { data, error } = await client.rpc<unknown[]>("get_reseller_wallet_safe");

  if (error) {
    return { wallet: null, state: mapWithdrawalRpcError(error) };
  }

  return { wallet: mapWalletRows(data)[0] ?? null, state: { code: "OK" as const, message: "Wallet loaded." } };
}

export async function listResellerPayoutAccountsSafeWithClient(client: WithdrawalRpcClient) {
  const { data, error } = await client.rpc<unknown[]>("list_reseller_payout_accounts_safe");

  if (error) {
    return { payoutAccounts: [], state: mapWithdrawalRpcError(error) };
  }

  return { payoutAccounts: mapPayoutAccountRows(data), state: { code: "OK" as const, message: "Payout accounts loaded." } };
}

export async function listResellerWithdrawalsSafeWithClient(client: WithdrawalRpcClient) {
  const { data, error } = await client.rpc<unknown[]>("list_reseller_withdrawals_safe", {
    p_limit: 25
  });

  if (error) {
    return { withdrawals: [], state: mapWithdrawalRpcError(error) };
  }

  return { withdrawals: mapWithdrawalRows(data), state: { code: "OK" as const, message: "Withdrawals loaded." } };
}

export async function getResellerWithdrawalSafeWithClient(client: WithdrawalRpcClient, withdrawalId: string) {
  const { data, error } = await client.rpc<unknown[]>("get_reseller_withdrawal_safe", {
    p_withdrawal_id: requireUuid(withdrawalId, "Withdrawal id")
  });

  if (error) {
    return { withdrawal: null, state: mapWithdrawalRpcError(error) };
  }

  return { withdrawal: mapWithdrawalRows(data)[0] ?? null, state: { code: "OK" as const, message: "Withdrawal loaded." } };
}

export async function requestResellerWithdrawalWithClient(client: WithdrawalRpcClient, input: RequestWithdrawalInput) {
  try {
    const payload = buildRequestWithdrawalPayload(input);
    const { data, error } = await client.rpc<unknown[]>("reseller_request_withdrawal", payload);

    if (error) {
      return { withdrawal: null, state: mapWithdrawalRpcError(error) };
    }

    return { withdrawal: mapRequestRows(data)[0] ?? null, state: { code: "OK" as const, message: "Withdrawal requested. Money has not been sent yet." } };
  } catch (error) {
    return { withdrawal: null, state: mapWithdrawalRpcError(error) };
  }
}

export async function saveResellerPayoutAccountWithClient(client: WithdrawalRpcClient, input: SavePayoutAccountInput) {
  try {
    const payload = buildSavePayoutAccountPayload(input);
    const { data, error } = await client.rpc<unknown[]>("reseller_upsert_payout_account", payload);

    if (error) {
      return { payoutAccount: null, state: mapWithdrawalRpcError(error) };
    }

    return { payoutAccount: mapPayoutAccountRows(data)[0] ?? null, state: { code: "OK" as const, message: "Payout account saved." } };
  } catch (error) {
    return { payoutAccount: null, state: mapWithdrawalRpcError(error) };
  }
}

function mapWalletRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map(mapWalletRow) : [];
}

function mapWalletRow(row: unknown): ResellerWalletSafe {
  const item = row as Record<string, unknown>;

  return {
    currencyCode: requiredString(item.currency_code, "GHS"),
    lockedCommissionAmount: nullableNumber(item.locked_commission_amount) ?? 0,
    availableBalanceAmount: nullableNumber(item.available_balance_amount) ?? 0,
    pendingWithdrawalAmount: nullableNumber(item.pending_withdrawal_amount) ?? 0,
    withdrawnAmount: nullableNumber(item.withdrawn_amount) ?? 0,
    minimumWithdrawalAmount: nullableNumber(item.minimum_withdrawal_amount) ?? 10,
    hasPendingWithdrawal: Boolean(item.has_pending_withdrawal)
  };
}

function mapPayoutAccountRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map(mapPayoutAccountRow) : [];
}

function mapPayoutAccountRow(row: unknown): ResellerPayoutAccountSafe {
  const item = row as Record<string, unknown>;

  return {
    payoutAccountId: requiredString(item.payout_account_id, ""),
    payoutMethod: requiredString(item.payout_method, "mobile_money"),
    accountName: requiredString(item.account_name, "Payout account"),
    mobileMoneyNetwork: nullableString(item.mobile_money_network),
    phoneNumberMasked: nullableString(item.phone_number_masked),
    isDefault: Boolean(item.is_default),
    accountStatus: requiredString(item.account_status, "active")
  };
}

function mapWithdrawalRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map(mapWithdrawalRow) : [];
}

function mapWithdrawalRow(row: unknown): ResellerWithdrawalSafe {
  const item = row as Record<string, unknown>;

  return {
    withdrawalId: requiredString(item.withdrawal_id, ""),
    requestReference: nullableString(item.request_reference),
    requestedAmount: nullableNumber(item.requested_amount),
    currencyCode: requiredString(item.currency_code, "GHS"),
    withdrawalStatus: requiredString(item.withdrawal_status, "unknown"),
    payoutMethod: nullableString(item.payout_method),
    payoutAccountName: nullableString(item.payout_account_name),
    payoutAccountMasked: nullableString(item.payout_account_masked),
    requestedAt: nullableString(item.requested_at),
    paidAt: nullableString(item.paid_at),
    payoutReferencePresent: Boolean(item.payout_reference_present)
  };
}

function mapRequestRows(rows: unknown) {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      withdrawalId: requiredString(item.withdrawal_id, ""),
      requestReference: nullableString(item.request_reference),
      requestedAmount: nullableNumber(item.requested_amount),
      currencyCode: requiredString(item.currency_code, "GHS"),
      withdrawalStatus: requiredString(item.withdrawal_status, "unknown"),
      availableBalanceAmount: nullableNumber(item.available_balance_amount) ?? 0,
      pendingWithdrawalAmount: nullableNumber(item.pending_withdrawal_amount) ?? 0,
      withdrawnAmount: nullableNumber(item.withdrawn_amount) ?? 0
    };
  }) : [];
}
