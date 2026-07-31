import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it, vi } from "vitest";

import {
  buildDashboardPeriodPayload,
  getDashboardPeriodFromSearchParams,
  getAdminDashboardMetricsSafeWithClient,
  getCustomerDashboardMetricsSafeWithClient,
  getResellerDashboardMetricsSafeWithClient,
  getSupplierDashboardMetricsSafeWithClient,
  type DashboardRpcClient
} from "@/lib/dashboard/real-dashboard-metrics";

vi.mock("server-only", () => ({}));

const migrationPath = join(process.cwd(), "supabase/migrations/20260731234500_real_dashboard_metrics_safe_read_rpcs.sql");
const supplierCurrencyPatchPath = join(process.cwd(), "supabase/migrations/20260731235000_fix_dashboard_metrics_supplier_currency_ambiguity.sql");
const sqlTestPath = join(process.cwd(), "scripts/rpc/real-dashboard-metrics-safe-read-rpc-tests-dev-only.sql");
const dashboardHelperPath = join(process.cwd(), "lib/dashboard/real-dashboard-metrics.ts");
const customerDashboardPath = join(process.cwd(), "app/customer/dashboard/page.tsx");
const resellerDashboardPath = join(process.cwd(), "app/reseller/dashboard/page.tsx");
const supplierDashboardPath = join(process.cwd(), "app/supplier/dashboard/page.tsx");
const adminDashboardPath = join(process.cwd(), "app/admin/dashboard/page.tsx");
const dashboardScreensPath = join(process.cwd(), "components/dashboard/real-dashboard-metrics-screens.tsx");
const adminAccessPath = join(process.cwd(), "lib/auth/admin-access.ts");
const routeAccessBoundaryPath = join(process.cwd(), "lib/auth/route-access-boundary.tsx");

function read(path: string) {
  return readFileSync(path, "utf8");
}

function readSourceTree(relativePath: string): string {
  const fullPath = join(process.cwd(), relativePath);
  const stat = statSync(fullPath);

  if (stat.isFile()) {
    return readFileSync(fullPath, "utf8");
  }

  return readdirSync(fullPath)
    .map((entry): string => readSourceTree(join(relativePath, entry)))
    .join("\n");
}

function functionBody(source: string, functionName: string) {
  const pattern = new RegExp(`create or replace function public\\.${functionName}[\\s\\S]*?\\$fn\\$;`, "i");
  return source.match(pattern)?.[0] ?? "";
}

function createRpcSpyClient(responses: Record<string, { data?: unknown; error?: { code?: string; message?: string; details?: string } | null }>) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: DashboardRpcClient = {
    async rpc<T = unknown>(name: string, args?: Record<string, unknown>) {
      calls.push({ name, args });
      const response = responses[name] ?? {};
      return {
        data: (response.data ?? []) as T,
        error: response.error ?? null
      };
    }
  };

  return { calls, client };
}

describe("real dashboard metrics safe-read phase", () => {
  it("creates narrow read-only dashboard summary RPCs with role-scoped ownership", () => {
    expect(existsSync(migrationPath)).toBe(true);
    const migration = read(migrationPath);

    for (const rpc of [
      "get_customer_dashboard_summary_safe",
      "get_reseller_dashboard_summary_safe",
      "get_supplier_dashboard_summary_safe",
      "get_admin_dashboard_summary_safe"
    ]) {
      expect(migration).toContain(`public.${rpc}`);
      expect(migration).toMatch(new RegExp(`revoke all on function public\\.${rpc}`, "i"));
      expect(migration).toMatch(new RegExp(`grant execute on function public\\.${rpc}.*to authenticated`, "i"));
      expect(functionBody(migration, rpc)).toMatch(/stable/i);
      expect(functionBody(migration, rpc)).toMatch(/security\s+definer/i);
      expect(functionBody(migration, rpc)).toMatch(/set\s+search_path\s*=\s*public/i);
    }

    expect(migration).toContain("current_profile_id()");
    expect(migration).toContain("current_verified_reseller_id()");
    expect(migration).toContain("current_verified_supplier_owner_id()");
    expect(migration).toContain("has_admin_role('finance_staff')");
    expect(migration).not.toMatch(/p_(customer|reseller|supplier|profile|admin)_id/i);
  });

  it("keeps dashboard RPCs read-only and avoids broad direct grants", () => {
    const migration = read(migrationPath);
    const bodies = [
      "get_customer_dashboard_summary_safe",
      "get_reseller_dashboard_summary_safe",
      "get_supplier_dashboard_summary_safe",
      "get_admin_dashboard_summary_safe"
    ].map((rpc) => functionBody(migration, rpc)).join("\n");

    expect(bodies).not.toMatch(/\binsert\s+into\b/i);
    expect(bodies).not.toMatch(/\bupdate\s+public\./i);
    expect(bodies).not.toMatch(/\bdelete\s+from\b/i);
    expect(bodies).not.toMatch(/for\s+update/i);
    expect(migration).not.toMatch(/grant\s+(select|insert|update|delete|all)\s+on\s+public\./i);
  });

  it("separates current-state from selected-period metrics and groups finance by currency", () => {
    const migration = read(migrationPath);
    const supplierCurrencyPatch = read(supplierCurrencyPatchPath);
    const helper = read(dashboardHelperPath);

    expect(buildDashboardPeriodPayload("last_7_days")).toMatchObject({ p_date_from: expect.any(String), p_date_to: expect.any(String) });
    expect(buildDashboardPeriodPayload("bad-range")).toEqual({ p_date_from: null, p_date_to: null });
    expect(getDashboardPeriodFromSearchParams({ period: "this_year" })).toBe("this_year");
    expect(getDashboardPeriodFromSearchParams({ period: "bad" })).toBe("last_30_days");
    expect(migration).toContain("currency_code");
    expect(migration).toContain("verified_platform_revenue_amount");
    expect(migration).toContain("gross_completed_sales_amount");
    expect(migration).toContain("settlement_status = 'paid'");
    expect(migration).toContain("verified_at is not null");
    expect(existsSync(supplierCurrencyPatchPath)).toBe(true);
    expect(supplierCurrencyPatch).toContain("order_currency_code");
    expect(supplierCurrencyPatch).not.toContain("min(s.id)");
    expect(helper).toContain("current");
    expect(helper).toContain("period");
  });

  it("maps all role dashboard helpers through safe RPCs without tenant ids", async () => {
    const { calls, client } = createRpcSpyClient({
      get_customer_dashboard_summary_safe: { data: [{ active_orders_count: 2, completed_orders_count: 1, rejected_orders_count: 1, total_orders_count: 4 }] },
      get_reseller_dashboard_summary_safe: { data: [{ currency_code: "GHS", available_balance_amount: 80, locked_commission_amount: 20, pending_withdrawal_amount: 10, withdrawn_amount: 5, attributed_orders_count: 3, completed_sales_count: 2, rejected_orders_count: 1, commission_earned_amount: 25 }] },
      get_supplier_dashboard_summary_safe: { data: [{ currency_code: "GHS", placed_pending_confirmation_count: 1, supplier_confirmed_count: 2, supplier_preparing_count: 3, ready_for_delivery_count: 4, delivery_arranged_count: 5, out_for_delivery_count: 6, delivered_count: 7, payment_reported_count: 8, completed_count: 9, supplier_rejected_count: 10, pending_settlement_amount: 11, pending_settlement_count: 12, customer_payments_reported_amount: 13, verified_settlement_amount: 14, completed_orders_count: 15 }] },
      get_admin_dashboard_summary_safe: { data: [{ currency_code: "GHS", pending_supplier_settlement_amount: 1, pending_supplier_settlement_count: 2, pending_reseller_withdrawal_amount: 3, pending_reseller_withdrawal_count: 4, verified_platform_revenue_amount: 5, gross_completed_sales_amount: 6, reseller_commission_unlocked_amount: 7, withdrawals_paid_amount: 8, completed_orders_count: 9, active_supplier_count: 10, active_reseller_count: 11, orders_waiting_supplier_confirmation_count: 12, new_supplier_count: 13, new_reseller_count: 14 }] }
    });

    await getCustomerDashboardMetricsSafeWithClient(client);
    await getResellerDashboardMetricsSafeWithClient(client, "last_30_days");
    await getSupplierDashboardMetricsSafeWithClient(client, "this_month");
    await getAdminDashboardMetricsSafeWithClient(client, "this_year");

    expect(calls.map((call) => call.name)).toEqual([
      "get_customer_dashboard_summary_safe",
      "get_reseller_dashboard_summary_safe",
      "get_supplier_dashboard_summary_safe",
      "get_admin_dashboard_summary_safe"
    ]);
    expect(JSON.stringify(calls)).not.toMatch(/customer_id|reseller_id|supplier_id|profile_id|service_role/i);
  });

  it("connects dashboard routes to live helpers and removes mock dashboard imports", () => {
    for (const path of [customerDashboardPath, resellerDashboardPath, supplierDashboardPath, adminDashboardPath, dashboardScreensPath]) {
      expect(existsSync(path)).toBe(true);
    }

    const routeSources = [customerDashboardPath, resellerDashboardPath, supplierDashboardPath, adminDashboardPath].map(read).join("\n");
    expect(routeSources).toContain("createSupabaseUserServerClient");
    expect(routeSources).toContain("getToken()");
    expect(routeSources).toContain("Dashboard");
    expect(routeSources).not.toContain("@/lib/mock");
    expect(routeSources).not.toContain("createSupabaseAdminClient");
    expect(routeSources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");

    const screenSource = read(dashboardScreensPath);
    expect(screenSource).toContain("We could not load this dashboard. Please refresh and try again.");
    expect(screenSource).toContain("No recent activity yet.");
    expect(screenSource).toContain("Selected period");
    expect(screenSource).toContain("Gross completed sales");
    expect(screenSource).toContain("Verified platform revenue");
    expect(screenSource).toContain('key={`${withdrawal.withdrawalId}-${index}`}');
  });

  it("allows finance staff through the admin dashboard gate without broadening all admin routes", () => {
    const adminAccess = read(adminAccessPath);
    const routeBoundary = read(routeAccessBoundaryPath);

    expect(adminAccess).toContain("getFinanceDashboardAdminAccess");
    expect(adminAccess).toContain('required_role: "finance_staff"');
    expect(routeBoundary).toContain('pathname === "/admin/dashboard"');
    expect(routeBoundary).toContain("getFinanceDashboardAdminAccess");
    expect(routeBoundary).toContain("getRoleOnboardingAdminAccess");
  });

  it("adds active SQL boundary assertions with rollback and no-side-effect checks", () => {
    expect(existsSync(sqlTestPath)).toBe(true);
    const sql = read(sqlTestPath);

    expect(sql).toContain("begin;");
    expect(sql).toContain("rollback;");
    for (const assertion of [
      "customer reads own dashboard counts",
      "reseller reads own dashboard balances",
      "supplier reads own order status counts",
      "finance admin reads dashboard finance metrics",
      "support staff cannot read finance dashboard",
      "anonymous blocked from customer dashboard",
      "no order rows changed by dashboard reads",
      "no payment rows changed by dashboard reads",
      "no settlement rows changed by dashboard reads",
      "no commission rows changed by dashboard reads",
      "no withdrawal rows changed by dashboard reads",
      "no stock rows changed by dashboard reads",
      "no audit rows changed by dashboard reads"
    ]) {
      expect(sql).toContain(assertion);
    }
  });

  it("does not add dashboard metric mutation integrations to purchase or provider flows", () => {
    const sources = [
      customerDashboardPath,
      resellerDashboardPath,
      supplierDashboardPath,
      adminDashboardPath,
      dashboardHelperPath,
      dashboardScreensPath
    ].map(read).join("\n");

    expect(sources).not.toMatch(/createSupabaseAdminClient.*dashboard|dashboard.*createSupabaseAdminClient/i);
    expect(sources).not.toMatch(/SUPABASE_SERVICE_ROLE_KEY/);
    expect(sources).not.toMatch(/dashboard[\s\S]{0,120}(create_order_from_checkout_draft|stock_reservation|create_payment|delivery_quote|commission_release|settlement_verify|withdrawal_paid)/i);
    expect(readSourceTree("app/checkout")).not.toContain("get_admin_dashboard_summary_safe");
    expect(readSourceTree("app/shop")).not.toContain("get_reseller_dashboard_summary_safe");
  });
});
