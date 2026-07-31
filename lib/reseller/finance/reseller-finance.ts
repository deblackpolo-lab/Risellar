import "server-only";

import { buildFinanceFilterPayload, buildFinanceSummaryPayload, type FinanceFilters } from "@/lib/finance/filters";

export type FinanceRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): PromiseLike<{
    data: T | null;
    error: { code?: string; message?: string; details?: string } | null;
  }>;
};

export type ResellerFinanceSummary = {
  currencyCode: string;
  lockedCommissionAmount: number;
  availableBalanceAmount: number;
  pendingWithdrawalAmount: number;
  withdrawnAmount: number;
  periodCommissionEarnedAmount: number;
  periodAvailableCommissionAmount: number;
  periodWithdrawalRequestedAmount: number;
  periodWithdrawalPaidAmount: number;
  completedSalesCount: number;
  dateFrom: string | null;
  dateTo: string | null;
};

export type ResellerEarning = {
  commissionId: string;
  orderNumber: string;
  productName: string;
  quantity: number;
  resellerShopName: string;
  commissionAmount: number;
  currencyCode: string;
  commissionStatus: string;
  earnedAt: string | null;
  availableAt: string | null;
  withdrawalReference: string | null;
  withdrawalStatus: string | null;
};

export type ResellerWithdrawalHistory = {
  withdrawalId: string;
  requestReference: string | null;
  requestedAmount: number;
  currencyCode: string;
  withdrawalStatus: string;
  payoutMethod: string | null;
  payoutAccountName: string | null;
  payoutAccountMasked: string | null;
  requestedAt: string | null;
  paidAt: string | null;
  payoutReferencePresent: boolean;
};

export type FinanceLoadState = {
  code: "OK" | "AUTH_REQUIRED" | "INVALID_DATE_RANGE" | "INVALID_STATUS_FILTER" | "RESELLER_REQUIRED" | "SUPABASE_AUTH_TOKEN_MISSING" | "UNKNOWN";
  message: string;
};

export function mapFinanceRpcError(error: unknown): FinanceLoadState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as { code?: string; message?: string; details?: string }) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required") || combined.includes("28000")) return { code: "AUTH_REQUIRED", message: "Sign in to view finance history." };
  if (combined.includes("missing supabase user access token") || combined.includes("supabase_auth_token_missing")) return { code: "SUPABASE_AUTH_TOKEN_MISSING", message: "We could not prepare your secure session. Please sign in again." };
  if (combined.includes("invalid_date_range")) return { code: "INVALID_DATE_RANGE", message: "Choose a valid date range." };
  if (combined.includes("invalid_status_filter")) return { code: "INVALID_STATUS_FILTER", message: "Choose a valid status filter." };
  if (combined.includes("reseller_required") || combined.includes("42501")) return { code: "RESELLER_REQUIRED", message: "Use an active reseller account." };

  return { code: "UNKNOWN", message: "We could not load this finance information. Please refresh and try again." };
}

export async function getResellerFinanceSummarySafeWithClient(client: FinanceRpcClient, filters: Pick<FinanceFilters, "dateFrom" | "dateTo">) {
  const { data, error } = await client.rpc<unknown[]>("get_reseller_finance_summary_safe", buildFinanceSummaryPayload(filters));
  if (error) return { summaries: [], state: mapFinanceRpcError(error) };
  return { summaries: mapSummaryRows(data), state: { code: "OK" as const, message: "Finance summary loaded." } };
}

export async function listResellerEarningsHistorySafeWithClient(client: FinanceRpcClient, filters: FinanceFilters) {
  const { data, error } = await client.rpc<unknown[]>("list_reseller_earnings_history_safe", buildFinanceFilterPayload(filters));
  if (error) return { earnings: [], state: mapFinanceRpcError(error) };
  return { earnings: mapEarningRows(data), state: { code: "OK" as const, message: "Earnings loaded." } };
}

export async function listResellerWithdrawalHistorySafeWithClient(client: FinanceRpcClient, filters: FinanceFilters) {
  const { data, error } = await client.rpc<unknown[]>("list_reseller_withdrawal_history_safe", buildFinanceFilterPayload(filters));
  if (error) return { withdrawals: [], state: mapFinanceRpcError(error) };
  return { withdrawals: mapWithdrawalRows(data), state: { code: "OK" as const, message: "Withdrawals loaded." } };
}

function numberValue(value: unknown) {
  const number = Number(value ?? 0);
  return Number.isFinite(number) ? number : 0;
}

function stringValue(value: unknown, fallback = "") {
  return typeof value === "string" && value.trim() ? value : fallback;
}

function nullableString(value: unknown) {
  return typeof value === "string" && value.trim() ? value : null;
}

function mapSummaryRows(rows: unknown): ResellerFinanceSummary[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      currencyCode: stringValue(item.currency_code, "GHS"),
      lockedCommissionAmount: numberValue(item.locked_commission_amount),
      availableBalanceAmount: numberValue(item.available_balance_amount),
      pendingWithdrawalAmount: numberValue(item.pending_withdrawal_amount),
      withdrawnAmount: numberValue(item.withdrawn_amount),
      periodCommissionEarnedAmount: numberValue(item.period_commission_earned_amount),
      periodAvailableCommissionAmount: numberValue(item.period_available_commission_amount),
      periodWithdrawalRequestedAmount: numberValue(item.period_withdrawal_requested_amount),
      periodWithdrawalPaidAmount: numberValue(item.period_withdrawal_paid_amount),
      completedSalesCount: numberValue(item.completed_sales_count),
      dateFrom: nullableString(item.date_from),
      dateTo: nullableString(item.date_to)
    };
  }) : [];
}

function mapEarningRows(rows: unknown): ResellerEarning[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      commissionId: stringValue(item.commission_id),
      orderNumber: stringValue(item.order_number, "Order"),
      productName: stringValue(item.product_name, "Product"),
      quantity: numberValue(item.quantity),
      resellerShopName: stringValue(item.reseller_shop_name, "Shop"),
      commissionAmount: numberValue(item.commission_amount),
      currencyCode: stringValue(item.currency_code, "GHS"),
      commissionStatus: stringValue(item.commission_status, "unknown"),
      earnedAt: nullableString(item.earned_at),
      availableAt: nullableString(item.available_at),
      withdrawalReference: nullableString(item.withdrawal_reference),
      withdrawalStatus: nullableString(item.withdrawal_status)
    };
  }) : [];
}

function mapWithdrawalRows(rows: unknown): ResellerWithdrawalHistory[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      withdrawalId: stringValue(item.withdrawal_id),
      requestReference: nullableString(item.request_reference),
      requestedAmount: numberValue(item.requested_amount),
      currencyCode: stringValue(item.currency_code, "GHS"),
      withdrawalStatus: stringValue(item.withdrawal_status, "unknown"),
      payoutMethod: nullableString(item.payout_method),
      payoutAccountName: nullableString(item.payout_account_name),
      payoutAccountMasked: nullableString(item.payout_account_masked),
      requestedAt: nullableString(item.requested_at),
      paidAt: nullableString(item.paid_at),
      payoutReferencePresent: Boolean(item.payout_reference_present)
    };
  }) : [];
}
