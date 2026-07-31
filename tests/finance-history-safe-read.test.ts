import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migrationPath = join(process.cwd(), "supabase/migrations/20260731230000_finance_history_and_dashboard_safe_read_rpcs.sql");
const sqlTestPath = join(process.cwd(), "scripts/rpc/finance-history-safe-read-rpc-tests-dev-only.sql");
const resellerHelperPath = join(process.cwd(), "lib/reseller/finance/reseller-finance.ts");
const supplierHelperPath = join(process.cwd(), "lib/supplier/finance/supplier-finance.ts");
const adminHelperPath = join(process.cwd(), "lib/admin/finance/admin-finance.ts");
const filterHelperPath = join(process.cwd(), "lib/finance/filters.ts");
const financeUiPath = join(process.cwd(), "components/finance/finance-ui.tsx");

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

describe("finance history safe-read foundation", () => {
  it("creates read-only finance summary and history RPCs with role-scoped ownership", () => {
    expect(existsSync(migrationPath)).toBe(true);
    const migration = read(migrationPath);

    for (const rpc of [
      "get_reseller_finance_summary_safe",
      "list_reseller_earnings_history_safe",
      "list_reseller_withdrawal_history_safe",
      "get_supplier_finance_summary_safe",
      "list_supplier_settlement_history_safe",
      "get_admin_finance_summary_safe",
      "list_admin_settlement_history_safe",
      "list_admin_withdrawal_history_safe"
    ]) {
      expect(migration).toContain(`public.${rpc}`);
      expect(migration).toMatch(new RegExp(`revoke all on function public\\.${rpc}`, "i"));
      expect(migration).toMatch(new RegExp(`grant execute on function public\\.${rpc}.*to authenticated`, "i"));
      expect(functionBody(migration, rpc)).toMatch(/stable/i);
      expect(functionBody(migration, rpc)).toMatch(/security\s+definer/i);
      expect(functionBody(migration, rpc)).toMatch(/set\s+search_path\s*=\s*public/i);
    }

    expect(migration).toContain("current_verified_reseller_id()");
    expect(migration).toContain("current_verified_supplier_owner_id()");
    expect(migration).toContain("current_finance_admin_profile_id()");
    expect(migration).not.toContain("p_reseller_id");
    expect(migration).not.toContain("p_supplier_id");
    expect(migration).not.toContain("p_admin_profile_id");
  });

  it("keeps read RPC function bodies free of finance mutations and broad grants", () => {
    const migration = read(migrationPath);
    const readBodies = [
      "get_reseller_finance_summary_safe",
      "list_reseller_earnings_history_safe",
      "list_reseller_withdrawal_history_safe",
      "get_supplier_finance_summary_safe",
      "list_supplier_settlement_history_safe",
      "get_admin_finance_summary_safe",
      "list_admin_settlement_history_safe",
      "list_admin_withdrawal_history_safe"
    ].map((rpc) => functionBody(migration, rpc)).join("\n");

    expect(readBodies).not.toMatch(/\binsert\s+into\b/i);
    expect(readBodies).not.toMatch(/\bupdate\s+public\./i);
    expect(readBodies).not.toMatch(/\bdelete\s+from\b/i);
    expect(readBodies).not.toMatch(/for\s+update/i);
    expect(migration).not.toMatch(/grant\s+(select|insert|update|delete|all)\s+on\s+public\.(orders|settlements|commissions|withdrawals|resellers|supplier_payment_reports)/i);
  });

  it("validates filters, distinguishes dates, and does not silently combine currencies", () => {
    const migration = read(migrationPath);
    const filters = read(filterHelperPath);

    expect(migration).toContain("finance_history_assert_date_range");
    expect(migration).toContain("INVALID_DATE_RANGE");
    expect(migration).toContain("INVALID_STATUS_FILTER");
    expect(migration).toContain("p_cursor_created_at");
    expect(migration).toContain("p_cursor_id");
    expect(migration).toContain("order by cur.currency_code");
    expect(migration).toContain("st.verified_at");
    expect(migration).toContain("spr.reported_at");
    expect(migration).toContain("w.paid_at");
    expect(filters).toContain("normalizeFinanceStatus");
    expect(filters).toContain("normalizeFinanceDate");
  });

  it("calculates verified platform revenue only from paid settlements and keeps gross sales separate", () => {
    const migration = read(migrationPath);
    const adminBody = functionBody(migration, "get_admin_finance_summary_safe");
    const ui = read(financeUiPath);

    expect(adminBody).toContain("st.settlement_status = 'paid'");
    expect(adminBody).toContain("st.verified_at is not null");
    expect(adminBody).toContain("settlement_due_amount - commission_amount");
    expect(adminBody).toContain("gross_completed_sales_amount");
    expect(adminBody).toContain("verified_platform_revenue_amount");
    expect(ui).toContain("Gross completed sales");
    expect(ui).toContain("Verified platform revenue");
    expect(ui).toContain("Separate from platform revenue.");
  });

  it("connects helpers and UI through safe RPCs without service role or direct table writes", () => {
    for (const path of [resellerHelperPath, supplierHelperPath, adminHelperPath, financeUiPath]) {
      expect(existsSync(path)).toBe(true);
    }

    const sources = [resellerHelperPath, supplierHelperPath, adminHelperPath, financeUiPath].map(read).join("\n");
    expect(sources).toContain("get_reseller_finance_summary_safe");
    expect(sources).toContain("list_reseller_earnings_history_safe");
    expect(sources).toContain("list_reseller_withdrawal_history_safe");
    expect(sources).toContain("get_supplier_finance_summary_safe");
    expect(sources).toContain("list_supplier_settlement_history_safe");
    expect(sources).toContain("get_admin_finance_summary_safe");
    expect(sources).toContain("list_admin_settlement_history_safe");
    expect(sources).toContain("list_admin_withdrawal_history_safe");
    expect(sources).not.toContain("createSupabaseAdminClient");
    expect(sources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(sources).not.toMatch(/\.from\("(orders|settlements|commissions|withdrawals|resellers|supplier_payment_reports)"\)/i);
  });

  it("keeps private finance fields and false per-commission withdrawn allocation out of UI", () => {
    const ui = read(financeUiPath);

    expect(ui).toContain("Withdrawal allocation by commission row is deferred");
    expect(ui).not.toContain("supplier_private_note");
    expect(ui).not.toContain("customer_contact_snapshot");
    expect(ui).not.toContain("admin_private_note");
    expect(ui).not.toContain("payout_reference");
    expect(ui).not.toContain("account_number");
  });

  it("adds active development SQL boundary assertions with rollback and no-side-effect checks", () => {
    expect(existsSync(sqlTestPath)).toBe(true);
    const sql = read(sqlTestPath);

    expect(sql).toContain("begin;");
    expect(sql).toContain("rollback;");
    expect(sql).toContain("reseller reads own summary");
    expect(sql).toContain("supplier reads own finance summary");
    expect(sql).toContain("finance admin reads summary");
    expect(sql).toContain("anonymous blocked from admin finance");
    expect(sql).toContain("no order rows changed by read RPCs");
    expect(sql).toContain("no settlement rows changed by read RPCs");
    expect(sql).toContain("no commission rows changed by read RPCs");
    expect(sql).toContain("no withdrawal rows changed by read RPCs");
    expect(sql).toContain("no stock rows changed by read RPCs");
    expect(sql).toContain("no audit rows changed by read RPCs");
  });

  it("does not add finance history RPCs to checkout, public shop, or provider flows", () => {
    const unrelated = ["app/checkout", "app/shop", "app/customer"];
    const forbidden = [
      "get_admin_finance_summary_safe",
      "list_admin_withdrawal_history_safe",
      "list_reseller_earnings_history_safe",
      "admin_mark_reseller_withdrawal_paid",
      "admin_verify_supplier_settlement"
    ];

    for (const relativePath of unrelated) {
      const source = readSourceTree(relativePath);
      for (const token of forbidden) {
        expect(source).not.toContain(token);
      }
    }
  });
});
