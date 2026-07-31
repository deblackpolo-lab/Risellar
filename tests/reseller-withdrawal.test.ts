import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migrationPath = join(process.cwd(), "supabase/migrations/20260731213000_reseller_withdrawal_request_payout_rpc.sql");
const commissionPatchPath = join(
  process.cwd(),
  "supabase/migrations/20260731220000_remove_reseller_withdrawal_commission_row_mutation.sql",
);
const payoutAccountPatchPath = join(
  process.cwd(),
  "supabase/migrations/20260731221500_fix_reseller_payout_account_default_ambiguity.sql",
);
const resellerHelperPath = join(process.cwd(), "lib/reseller/withdrawals/reseller-withdrawal.ts");
const resellerActionPath = join(process.cwd(), "app/reseller/withdrawals/actions.ts");
const resellerScreenPath = join(process.cwd(), "components/reseller/reseller-withdrawal-rpc-screens.tsx");
const adminHelperPath = join(process.cwd(), "lib/admin/withdrawals/admin-reseller-withdrawal.ts");
const adminActionPath = join(process.cwd(), "app/admin/withdrawals/actions.ts");
const adminScreenPath = join(process.cwd(), "components/admin/admin-reseller-withdrawal-rpc-screens.tsx");

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

describe("reseller withdrawal and admin manual payout foundation", () => {
  it("creates a forward migration with safe withdrawal request and manual payout RPCs", () => {
    expect(existsSync(migrationPath)).toBe(true);

    const migration = read(migrationPath);

    expect(migration).toContain("reseller_request_withdrawal");
    expect(migration).toContain("admin_mark_reseller_withdrawal_paid");
    expect(migration).toContain("list_reseller_withdrawals_safe");
    expect(migration).toContain("list_admin_reseller_withdrawals_safe");
    expect(migration).toContain("reseller_payout_accounts");
    expect(migration).toContain("commission_pending_withdrawal_amount");
    expect(migration).toContain("commission_withdrawn_amount");
    expect(migration).toMatch(/security\s+definer/i);
    expect(migration).toMatch(/set\s+search_path\s*=\s*public/i);
    expect(migration).toMatch(/for\s+update/i);
    expect(migration).toContain("current_finance_admin_profile_id");
    expect(migration).not.toMatch(/public\.has_admin_role\('finance_staff'\)/i);
  });

  it("keeps withdrawal accounting atomic, idempotent, and provider-free", () => {
    const migration = read(migrationPath);
    const commissionPatch = read(commissionPatchPath);
    const payoutAccountPatch = read(payoutAccountPatchPath);

    expect(migration).toContain("request_idempotency_key");
    expect(migration).toContain("payout_idempotency_key");
    expect(migration).toContain("CONFLICTING_RETRY");
    expect(migration).toContain("CONFLICTING_PAYOUT_RETRY");
    expect(migration).toContain("INSUFFICIENT_AVAILABLE_BALANCE");
    expect(migration).toContain("WITHDRAWAL_ALREADY_PENDING");
    expect(migration).toMatch(/commission_available_amount\s*=\s*r\.commission_available_amount\s*-/i);
    expect(migration).toMatch(/commission_pending_withdrawal_amount\s*=\s*r\.commission_pending_withdrawal_amount\s*\+/i);
    expect(migration).toMatch(/commission_pending_withdrawal_amount\s*=\s*r\.commission_pending_withdrawal_amount\s*-/i);
    expect(migration).toMatch(/commission_withdrawn_amount\s*=\s*r\.commission_withdrawn_amount\s*\+/i);
    expect(migration).toMatch(/withdrawal_status\s*=\s*'requested'/i);
    expect(migration).toMatch(/withdrawal_status\s*=\s*'paid'/i);
    expect(migration).not.toMatch(/paystack|flutterwave|hubtel|stripe|zeepay/i);
    expect(migration).not.toMatch(/insert\s+into\s+public\.supplier_payout/i);
    expect(migration).not.toMatch(/update\s+public\.orders/i);
    expect(migration).not.toMatch(/update\s+public\.stock_reservations/i);
    expect(commissionPatch).toContain("commission_row_allocation_deferred");
    expect(commissionPatch).not.toMatch(/\bupdate\s+public\.commissions\b/i);
    expect(payoutAccountPatch).toContain("reseller_upsert_payout_account");
    expect(payoutAccountPatch).toMatch(/update\s+public\.reseller_payout_accounts\s+as\s+rpa/i);
    expect(payoutAccountPatch).toMatch(/rpa\.is_default\s+is\s+true/i);
  });

  it("connects reseller and admin UI through server actions without trusted browser money/status fields", () => {
    for (const path of [resellerHelperPath, resellerActionPath, resellerScreenPath, adminHelperPath, adminActionPath, adminScreenPath]) {
      expect(existsSync(path)).toBe(true);
    }

    const sources = [resellerHelperPath, resellerActionPath, resellerScreenPath, adminHelperPath, adminActionPath, adminScreenPath]
      .map(read)
      .join("\n");

    expect(sources).toContain("reseller_request_withdrawal");
    expect(sources).toContain("admin_mark_reseller_withdrawal_paid");
    expect(sources).toContain("requestResellerWithdrawalFormAction");
    expect(sources).toContain("markResellerWithdrawalPaidFormAction");
    expect(sources).toContain("Money has not been sent yet.");
    expect(sources).toContain("I confirm that the withdrawal amount was sent manually to the reseller's payout account.");
    expect(sources).not.toContain('name="reseller_id');
    expect(sources).not.toContain('name="available_balance');
    expect(sources).not.toContain('name="pending_balance');
    expect(sources).not.toContain('name="withdrawn_balance');
    expect(sources).not.toContain('name="currency');
    expect(sources).not.toContain('name="withdrawal_status');
    expect(sources).not.toContain('name="admin_note" value=');
    const adminSources = [adminActionPath, adminHelperPath, adminScreenPath].map(read).join("\n");
    expect(adminSources).not.toContain('name="amount"');
    expect(adminSources).not.toContain("p_amount");
    expect(sources).not.toContain("createSupabaseAdminClient");
    expect(sources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
  });

  it("does not connect withdrawal payout logic to checkout, orders, supplier payouts, delivery, stock, or payment providers", () => {
    const unrelatedPaths = ["app/checkout", "app/customer", "app/shop", "app/supplier", "lib/supplier"];
    const forbidden = ["reseller_request_withdrawal", "admin_mark_reseller_withdrawal_paid", "withdrawal payout", "payout provider"];

    for (const relativePath of unrelatedPaths) {
      const source = readSourceTree(relativePath);
      for (const token of forbidden) {
        expect(source).not.toContain(token);
      }
    }
  });
});
