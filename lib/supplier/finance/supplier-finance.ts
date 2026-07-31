import "server-only";

import { buildFinanceFilterPayload, buildFinanceSummaryPayload, type FinanceFilters } from "@/lib/finance/filters";
import { mapFinanceRpcError, type FinanceRpcClient, type FinanceLoadState } from "@/lib/reseller/finance/reseller-finance";

export type SupplierFinanceSummary = {
  currencyCode: string;
  pendingSettlementAmount: number;
  pendingSettlementCount: number;
  customerPaymentsReportedAmount: number;
  verifiedSettlementAmount: number;
  completedOrderCount: number;
  platformAmountSettled: number;
  resellerCommissionSettled: number;
  dateFrom: string | null;
  dateTo: string | null;
};

export type SupplierSettlementHistory = {
  settlementId: string;
  orderId: string;
  orderNumber: string;
  customerTotalAmount: number;
  supplierAmount: number;
  platformAmountDue: number;
  resellerCommissionDue: number;
  totalSettlementDue: number;
  currencyCode: string;
  settlementStatus: string;
  paymentReportedAt: string | null;
  settlementCreatedAt: string | null;
  settlementVerifiedAt: string | null;
  orderStatus: string;
  settlementReferencePresent: boolean;
};

export async function getSupplierFinanceSummarySafeWithClient(client: FinanceRpcClient, filters: Pick<FinanceFilters, "dateFrom" | "dateTo">) {
  const { data, error } = await client.rpc<unknown[]>("get_supplier_finance_summary_safe", buildFinanceSummaryPayload(filters));
  if (error) return { summaries: [], state: mapFinanceRpcError(error) as FinanceLoadState };
  return { summaries: mapSummaryRows(data), state: { code: "OK" as const, message: "Supplier finance loaded." } };
}

export async function listSupplierSettlementHistorySafeWithClient(client: FinanceRpcClient, filters: FinanceFilters) {
  const { data, error } = await client.rpc<unknown[]>("list_supplier_settlement_history_safe", buildFinanceFilterPayload(filters));
  if (error) return { settlements: [], state: mapFinanceRpcError(error) as FinanceLoadState };
  return { settlements: mapSettlementRows(data), state: { code: "OK" as const, message: "Supplier settlements loaded." } };
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

function mapSummaryRows(rows: unknown): SupplierFinanceSummary[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      currencyCode: stringValue(item.currency_code, "GHS"),
      pendingSettlementAmount: numberValue(item.pending_settlement_amount),
      pendingSettlementCount: numberValue(item.pending_settlement_count),
      customerPaymentsReportedAmount: numberValue(item.customer_payments_reported_amount),
      verifiedSettlementAmount: numberValue(item.verified_settlement_amount),
      completedOrderCount: numberValue(item.completed_order_count),
      platformAmountSettled: numberValue(item.platform_amount_settled),
      resellerCommissionSettled: numberValue(item.reseller_commission_settled),
      dateFrom: nullableString(item.date_from),
      dateTo: nullableString(item.date_to)
    };
  }) : [];
}

function mapSettlementRows(rows: unknown): SupplierSettlementHistory[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      settlementId: stringValue(item.settlement_id),
      orderId: stringValue(item.order_id),
      orderNumber: stringValue(item.order_number, "Order"),
      customerTotalAmount: numberValue(item.customer_total_amount),
      supplierAmount: numberValue(item.supplier_amount),
      platformAmountDue: numberValue(item.platform_amount_due),
      resellerCommissionDue: numberValue(item.reseller_commission_due),
      totalSettlementDue: numberValue(item.total_settlement_due),
      currencyCode: stringValue(item.currency_code, "GHS"),
      settlementStatus: stringValue(item.settlement_status, "unknown"),
      paymentReportedAt: nullableString(item.payment_reported_at),
      settlementCreatedAt: nullableString(item.settlement_created_at),
      settlementVerifiedAt: nullableString(item.settlement_verified_at),
      orderStatus: stringValue(item.order_status, "unknown"),
      settlementReferencePresent: Boolean(item.settlement_reference_present)
    };
  }) : [];
}
