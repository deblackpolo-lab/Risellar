import "server-only";

export type DashboardPeriod = "last_7_days" | "last_30_days" | "this_month" | "this_year";

export type DashboardRpcClient = {
  rpc<T = unknown>(name: string, args?: Record<string, unknown>): PromiseLike<{
    data: T | null;
    error: { code?: string; message?: string; details?: string } | null;
  }>;
};

export type DashboardLoadState = {
  code: "OK" | "AUTH_REQUIRED" | "SUPABASE_AUTH_TOKEN_MISSING" | "INVALID_DATE_RANGE" | "ROLE_REQUIRED" | "UNKNOWN";
  message: string;
};

export type CustomerDashboardSummary = {
  current: {
    activeOrdersCount: number;
    completedOrdersCount: number;
    rejectedOrdersCount: number;
    totalOrdersCount: number;
  };
  latestActiveOrder: {
    orderId: string | null;
    orderNumber: string | null;
    productName: string | null;
    statusLabel: string | null;
    amount: number | null;
    currencyCode: string | null;
    createdAt: string | null;
    href: string | null;
  };
};

export type ResellerDashboardSummary = {
  current: {
    currencyCode: string;
    lockedCommissionAmount: number;
    availableBalanceAmount: number;
    pendingWithdrawalAmount: number;
    withdrawnAmount: number;
  };
  period: {
    dateFrom: string | null;
    dateTo: string | null;
    attributedOrdersCount: number;
    completedSalesCount: number;
    rejectedOrdersCount: number;
    commissionEarnedAmount: number;
  };
};

export type SupplierDashboardSummary = {
  current: {
    currencyCode: string;
    placedPendingConfirmationCount: number;
    supplierConfirmedCount: number;
    supplierPreparingCount: number;
    readyForDeliveryCount: number;
    deliveryArrangedCount: number;
    outForDeliveryCount: number;
    deliveredCount: number;
    paymentReportedCount: number;
    completedCount: number;
    supplierRejectedCount: number;
    pendingSettlementAmount: number;
    pendingSettlementCount: number;
  };
  period: {
    dateFrom: string | null;
    dateTo: string | null;
    customerPaymentsReportedAmount: number;
    verifiedSettlementAmount: number;
    completedOrdersCount: number;
  };
};

export type AdminDashboardSummary = {
  currencyCode: string;
  current: {
    pendingSupplierSettlementAmount: number;
    pendingSupplierSettlementCount: number;
    pendingResellerWithdrawalAmount: number;
    pendingResellerWithdrawalCount: number;
    activeSupplierCount: number;
    activeResellerCount: number;
    ordersWaitingSupplierConfirmationCount: number;
  };
  period: {
    dateFrom: string | null;
    dateTo: string | null;
    verifiedPlatformRevenueAmount: number;
    grossCompletedSalesAmount: number;
    resellerCommissionUnlockedAmount: number;
    withdrawalsPaidAmount: number;
    completedOrdersCount: number;
    newSupplierCount: number;
    newResellerCount: number;
  };
};

const allowedPeriods: DashboardPeriod[] = ["last_7_days", "last_30_days", "this_month", "this_year"];

export function getDashboardPeriodFromSearchParams(params?: { period?: string | string[] | null }): DashboardPeriod {
  const value = Array.isArray(params?.period) ? params?.period[0] : params?.period;
  return allowedPeriods.includes(value as DashboardPeriod) ? value as DashboardPeriod : "last_30_days";
}

export function buildDashboardPeriodPayload(period: string | null | undefined) {
  const selected = allowedPeriods.includes(period as DashboardPeriod) ? period as DashboardPeriod : null;

  if (!selected) {
    return { p_date_from: null, p_date_to: null };
  }

  const today = new Date();
  const utcDate = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()));
  const dateTo = formatDate(utcDate);
  const dateFrom = new Date(utcDate);

  if (selected === "last_7_days") {
    dateFrom.setUTCDate(dateFrom.getUTCDate() - 6);
  } else if (selected === "last_30_days") {
    dateFrom.setUTCDate(dateFrom.getUTCDate() - 29);
  } else if (selected === "this_month") {
    dateFrom.setUTCDate(1);
  } else {
    dateFrom.setUTCMonth(0, 1);
  }

  return { p_date_from: formatDate(dateFrom), p_date_to: dateTo };
}

function formatDate(value: Date) {
  return value.toISOString().slice(0, 10);
}

function numberValue(value: unknown) {
  const numericValue = Number(value ?? 0);
  return Number.isFinite(numericValue) ? numericValue : 0;
}

function nullableNumber(value: unknown) {
  if (value === null || value === undefined) return null;
  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : null;
}

function nullableString(value: unknown) {
  return typeof value === "string" && value.trim() ? value : null;
}

function stringValue(value: unknown, fallback = "") {
  return nullableString(value) ?? fallback;
}

function mapDashboardRpcError(error: unknown): DashboardLoadState {
  const message = typeof error === "string" ? error : error instanceof Error ? error.message : "";
  const rpcError = typeof error === "object" && error !== null ? (error as { code?: string; message?: string; details?: string }) : {};
  const combined = `${rpcError.code ?? ""} ${rpcError.message ?? ""} ${rpcError.details ?? ""} ${message}`.toLowerCase();

  if (combined.includes("auth_required") || combined.includes("28000")) return { code: "AUTH_REQUIRED", message: "Sign in to view this dashboard." };
  if (combined.includes("supabase_auth_token_missing") || combined.includes("missing supabase user access token")) return { code: "SUPABASE_AUTH_TOKEN_MISSING", message: "We could not prepare your secure session. Please sign in again." };
  if (combined.includes("invalid_date_range")) return { code: "INVALID_DATE_RANGE", message: "Choose a valid dashboard period." };
  if (combined.includes("required") || combined.includes("42501") || combined.includes("permission denied")) return { code: "ROLE_REQUIRED", message: "This dashboard is unavailable for this account." };

  return { code: "UNKNOWN", message: "We could not load this dashboard. Please refresh and try again." };
}

export async function getCustomerDashboardMetricsSafeWithClient(client: DashboardRpcClient) {
  try {
    const { data, error } = await client.rpc<unknown[]>("get_customer_dashboard_summary_safe");
    if (error) return { summary: emptyCustomerDashboardSummary(), state: mapDashboardRpcError(error) };
    return { summary: mapCustomerRows(data)[0] ?? emptyCustomerDashboardSummary(), state: okState() };
  } catch (error) {
    return { summary: emptyCustomerDashboardSummary(), state: mapDashboardRpcError(error) };
  }
}

export async function getResellerDashboardMetricsSafeWithClient(client: DashboardRpcClient, period: DashboardPeriod) {
  try {
    const { data, error } = await client.rpc<unknown[]>("get_reseller_dashboard_summary_safe", buildDashboardPeriodPayload(period));
    if (error) return { summaries: [], state: mapDashboardRpcError(error) };
    return { summaries: mapResellerRows(data), state: okState() };
  } catch (error) {
    return { summaries: [], state: mapDashboardRpcError(error) };
  }
}

export async function getSupplierDashboardMetricsSafeWithClient(client: DashboardRpcClient, period: DashboardPeriod) {
  try {
    const { data, error } = await client.rpc<unknown[]>("get_supplier_dashboard_summary_safe", buildDashboardPeriodPayload(period));
    if (error) return { summaries: [], state: mapDashboardRpcError(error) };
    return { summaries: mapSupplierRows(data), state: okState() };
  } catch (error) {
    return { summaries: [], state: mapDashboardRpcError(error) };
  }
}

export async function getAdminDashboardMetricsSafeWithClient(client: DashboardRpcClient, period: DashboardPeriod) {
  try {
    const { data, error } = await client.rpc<unknown[]>("get_admin_dashboard_summary_safe", buildDashboardPeriodPayload(period));
    if (error) return { summaries: [], state: mapDashboardRpcError(error) };
    return { summaries: mapAdminRows(data), state: okState() };
  } catch (error) {
    return { summaries: [], state: mapDashboardRpcError(error) };
  }
}

function okState(): DashboardLoadState {
  return { code: "OK", message: "" };
}

function emptyCustomerDashboardSummary(): CustomerDashboardSummary {
  return {
    current: { activeOrdersCount: 0, completedOrdersCount: 0, rejectedOrdersCount: 0, totalOrdersCount: 0 },
    latestActiveOrder: { orderId: null, orderNumber: null, productName: null, statusLabel: null, amount: null, currencyCode: null, createdAt: null, href: null }
  };
}

function mapCustomerRows(rows: unknown): CustomerDashboardSummary[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    const orderId = nullableString(item.latest_active_order_id);

    return {
      current: {
        activeOrdersCount: numberValue(item.active_orders_count),
        completedOrdersCount: numberValue(item.completed_orders_count),
        rejectedOrdersCount: numberValue(item.rejected_orders_count),
        totalOrdersCount: numberValue(item.total_orders_count)
      },
      latestActiveOrder: {
        orderId,
        orderNumber: nullableString(item.latest_active_order_number),
        productName: nullableString(item.latest_active_product_name),
        statusLabel: nullableString(item.latest_active_status_label),
        amount: nullableNumber(item.latest_active_total_payable_amount),
        currencyCode: nullableString(item.latest_active_currency_code),
        createdAt: nullableString(item.latest_active_created_at),
        href: orderId ? `/customer/orders/${orderId}` : null
      }
    };
  }) : [];
}

function mapResellerRows(rows: unknown): ResellerDashboardSummary[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      current: {
        currencyCode: stringValue(item.currency_code, "GHS"),
        lockedCommissionAmount: numberValue(item.locked_commission_amount),
        availableBalanceAmount: numberValue(item.available_balance_amount),
        pendingWithdrawalAmount: numberValue(item.pending_withdrawal_amount),
        withdrawnAmount: numberValue(item.withdrawn_amount)
      },
      period: {
        dateFrom: nullableString(item.date_from),
        dateTo: nullableString(item.date_to),
        attributedOrdersCount: numberValue(item.attributed_orders_count),
        completedSalesCount: numberValue(item.completed_sales_count),
        rejectedOrdersCount: numberValue(item.rejected_orders_count),
        commissionEarnedAmount: numberValue(item.commission_earned_amount)
      }
    };
  }) : [];
}

function mapSupplierRows(rows: unknown): SupplierDashboardSummary[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      current: {
        currencyCode: stringValue(item.currency_code, "GHS"),
        placedPendingConfirmationCount: numberValue(item.placed_pending_confirmation_count),
        supplierConfirmedCount: numberValue(item.supplier_confirmed_count),
        supplierPreparingCount: numberValue(item.supplier_preparing_count),
        readyForDeliveryCount: numberValue(item.ready_for_delivery_count),
        deliveryArrangedCount: numberValue(item.delivery_arranged_count),
        outForDeliveryCount: numberValue(item.out_for_delivery_count),
        deliveredCount: numberValue(item.delivered_count),
        paymentReportedCount: numberValue(item.payment_reported_count),
        completedCount: numberValue(item.completed_count),
        supplierRejectedCount: numberValue(item.supplier_rejected_count),
        pendingSettlementAmount: numberValue(item.pending_settlement_amount),
        pendingSettlementCount: numberValue(item.pending_settlement_count)
      },
      period: {
        dateFrom: nullableString(item.date_from),
        dateTo: nullableString(item.date_to),
        customerPaymentsReportedAmount: numberValue(item.customer_payments_reported_amount),
        verifiedSettlementAmount: numberValue(item.verified_settlement_amount),
        completedOrdersCount: numberValue(item.completed_orders_count)
      }
    };
  }) : [];
}

function mapAdminRows(rows: unknown): AdminDashboardSummary[] {
  return Array.isArray(rows) ? rows.map((row) => {
    const item = row as Record<string, unknown>;
    return {
      currencyCode: stringValue(item.currency_code, "GHS"),
      current: {
        pendingSupplierSettlementAmount: numberValue(item.pending_supplier_settlement_amount),
        pendingSupplierSettlementCount: numberValue(item.pending_supplier_settlement_count),
        pendingResellerWithdrawalAmount: numberValue(item.pending_reseller_withdrawal_amount),
        pendingResellerWithdrawalCount: numberValue(item.pending_reseller_withdrawal_count),
        activeSupplierCount: numberValue(item.active_supplier_count),
        activeResellerCount: numberValue(item.active_reseller_count),
        ordersWaitingSupplierConfirmationCount: numberValue(item.orders_waiting_supplier_confirmation_count)
      },
      period: {
        dateFrom: nullableString(item.date_from),
        dateTo: nullableString(item.date_to),
        verifiedPlatformRevenueAmount: numberValue(item.verified_platform_revenue_amount),
        grossCompletedSalesAmount: numberValue(item.gross_completed_sales_amount),
        resellerCommissionUnlockedAmount: numberValue(item.reseller_commission_unlocked_amount),
        withdrawalsPaidAmount: numberValue(item.withdrawals_paid_amount),
        completedOrdersCount: numberValue(item.completed_orders_count),
        newSupplierCount: numberValue(item.new_supplier_count),
        newResellerCount: numberValue(item.new_reseller_count)
      }
    };
  }) : [];
}
