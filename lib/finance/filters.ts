import "server-only";

export type FinanceFilters = {
  status: string | null;
  dateFrom: string | null;
  dateTo: string | null;
};

const isoDatePattern = /^\d{4}-\d{2}-\d{2}$/;

export function normalizeFinanceStatus(value: unknown, allowed: readonly string[]) {
  const text = typeof value === "string" ? value.trim() : "";
  if (!text || text === "all") return null;
  return allowed.includes(text) ? text : null;
}

export function normalizeFinanceDate(value: unknown) {
  const text = typeof value === "string" ? value.trim() : "";
  return isoDatePattern.test(text) ? text : null;
}

export function buildFinanceFilterPayload(filters: FinanceFilters) {
  return {
    p_status: filters.status,
    p_date_from: filters.dateFrom,
    p_date_to: filters.dateTo,
    p_limit: 50,
    p_cursor_created_at: null,
    p_cursor_id: null
  };
}

export function buildFinanceSummaryPayload(filters: Pick<FinanceFilters, "dateFrom" | "dateTo">) {
  return {
    p_date_from: filters.dateFrom,
    p_date_to: filters.dateTo
  };
}
