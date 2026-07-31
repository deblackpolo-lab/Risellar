import "server-only";

import { buildFinanceFilterPayload, buildFinanceSummaryPayload, type FinanceFilters } from "@/lib/finance/filters";
import { mapFinanceRpcError, type FinanceRpcClient } from "@/lib/reseller/finance/reseller-finance";

export type AdminFinanceSummary = {
  currencyCode: string;
  pendingSupplierSettlementAmount: number;
  pendingSupplierSettlementCount: number;
  pendingResellerWithdrawalAmount: number;
  pendingResellerWithdrawalCount: number;
  verifiedPlatformRevenueAmount: number;
  verifiedSupplierSettlementTotal: number;
  resellerCommissionUnlockedAmount: number;
  resellerWithdrawalPaidAmount: number;
  grossCompletedSalesAmount: number;
  completedOrderCount: number;
  dateFrom: string | null;
  dateTo: string | null;
};

export type AdminFinanceSettlement = {
  settlementId: string;
  orderId: string;
  orderNumber: string;
  supplierBusinessName: string;
  resellerDisplayName: string;
  customerTotalAmount: number;
  platformAmount: number;
  resellerCommissionAmount: number;
  totalSettlementAmount: number;
  currencyCode: string;
  settlementStatus: string;
  supplierReportedAt: string | null;
  settlementVerifiedAt: string | null;
  orderStatus: string;
  financeActorPresent: boolean;
};

export type AdminFinanceWithdrawal = {
  withdrawalId: string;
  requestReference: string | null;
  resellerDisplayName: string;
  resellerEmailMasked: string | null;
  requestedAmount: number;
  currencyCode: string;
  withdrawalStatus: string;
  payoutMethod: string | null;
  payoutAccountName: string | null;
  payoutAccountMasked: string | null;
  requestedAt: string | null;
  paidAt: string | null;
  payoutReferencePresent: boolean;
  financeActorPresent: boolean;
};

export async function getAdminFinanceSummarySafeWithClient(client: FinanceRpcClient, filters: Pick<FinanceFilters, "dateFrom" | "dateTo">) {
  const { data, error } = await client.rpc<unknown[]>("get_admin_finance_summary_safe", buildFinanceSummaryPayload(filters));
  if (error) return { summaries: [], state: mapFinanceRpcError(error) };
  return { summaries: mapSummaryRows(data), state: { code: "OK" as const, message: "Admin finance loaded." } };
}

export async function listAdminSettlementHistorySafeWithClient(client: FinanceRpcClient, filters: FinanceFilters) {
  const { data, error } = await client.rpc<unknown[]>("list_admin_settlement_history_safe", buildFinanceFilterPayload(filters));
  if (error) return { settlements: [], state: mapFinanceRpcError(error) };
  return { settlements: mapSettlementRows(data), state: { code: "OK" as const, message: "Admin settlements loaded." } };
}

export async function listAdminWithdrawalHistorySafeWithClient(client: FinanceRpcClient, filters: FinanceFilters) {
  const { data, error } = await client.rpc<unknown[]>("list_admin_withdrawal_history_safe", buildFinanceFilterPayload(filters));
  if (error) return { withdrawals: [], state: mapFinanceRpcError(error) };
  return { withdrawals: mapWithdrawalRows(data), state: { code: "OK" as const, message: "Admin withdrawals loaded." } };
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

function mapSummaryRows(rows: unknown): AdminFinanceSummary[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      currencyCode: stringValue(item.currency_code, "GHS"),
      pendingSupplierSettlementAmount: numberValue(item.pending_supplier_settlement_amount),
      pendingSupplierSettlementCount: numberValue(item.pending_supplier_settlement_count),
      pendingResellerWithdrawalAmount: numberValue(item.pending_reseller_withdrawal_amount),
      pendingResellerWithdrawalCount: numberValue(item.pending_reseller_withdrawal_count),
      verifiedPlatformRevenueAmount: numberValue(item.verified_platform_revenue_amount),
      verifiedSupplierSettlementTotal: numberValue(item.verified_supplier_settlement_total),
      resellerCommissionUnlockedAmount: numberValue(item.reseller_commission_unlocked_amount),
      resellerWithdrawalPaidAmount: numberValue(item.reseller_withdrawal_paid_amount),
      grossCompletedSalesAmount: numberValue(item.gross_completed_sales_amount),
      completedOrderCount: numberValue(item.completed_order_count),
      dateFrom: nullableString(item.date_from),
      dateTo: nullableString(item.date_to)
    };
  }) : [];
}

function mapSettlementRows(rows: unknown): AdminFinanceSettlement[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      settlementId: stringValue(item.settlement_id),
      orderId: stringValue(item.order_id),
      orderNumber: stringValue(item.order_number, "Order"),
      supplierBusinessName: stringValue(item.supplier_business_name, "Supplier"),
      resellerDisplayName: stringValue(item.reseller_display_name, "Reseller"),
      customerTotalAmount: numberValue(item.customer_total_amount),
      platformAmount: numberValue(item.platform_amount),
      resellerCommissionAmount: numberValue(item.reseller_commission_amount),
      totalSettlementAmount: numberValue(item.total_settlement_amount),
      currencyCode: stringValue(item.currency_code, "GHS"),
      settlementStatus: stringValue(item.settlement_status, "unknown"),
      supplierReportedAt: nullableString(item.supplier_reported_at),
      settlementVerifiedAt: nullableString(item.settlement_verified_at),
      orderStatus: stringValue(item.order_status, "unknown"),
      financeActorPresent: Boolean(item.finance_actor_present)
    };
  }) : [];
}

function mapWithdrawalRows(rows: unknown): AdminFinanceWithdrawal[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      withdrawalId: stringValue(item.withdrawal_id),
      requestReference: nullableString(item.request_reference),
      resellerDisplayName: stringValue(item.reseller_display_name, "Reseller"),
      resellerEmailMasked: nullableString(item.reseller_email_masked),
      requestedAmount: numberValue(item.requested_amount),
      currencyCode: stringValue(item.currency_code, "GHS"),
      withdrawalStatus: stringValue(item.withdrawal_status, "unknown"),
      payoutMethod: nullableString(item.payout_method),
      payoutAccountName: nullableString(item.payout_account_name),
      payoutAccountMasked: nullableString(item.payout_account_masked),
      requestedAt: nullableString(item.requested_at),
      paidAt: nullableString(item.paid_at),
      payoutReferencePresent: Boolean(item.payout_reference_present),
      financeActorPresent: Boolean(item.finance_actor_present)
    };
  }) : [];
}
