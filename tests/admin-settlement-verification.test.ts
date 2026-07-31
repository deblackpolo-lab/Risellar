import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migrationPath = join(process.cwd(), "supabase/migrations/20260731200000_admin_supplier_settlement_verification_rpc.sql");
const helperPath = join(process.cwd(), "lib/admin/settlements/admin-supplier-settlement.ts");
const actionPath = join(process.cwd(), "app/admin/settlements/actions.ts");
const uiPath = join(process.cwd(), "components/admin/admin-supplier-settlement-rpc-screens.tsx");
const adminAccessPath = join(process.cwd(), "lib/auth/admin-access.ts");
const routeBoundaryPath = join(process.cwd(), "lib/auth/route-access-boundary.tsx");

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

describe("admin supplier settlement verification foundation", () => {
  it("creates a forward migration with finance-only settlement verification RPCs", () => {
    expect(existsSync(migrationPath)).toBe(true);

    const migration = read(migrationPath);

    expect(migration).toContain("admin_verify_supplier_settlement");
    expect(migration).toContain("list_admin_pending_supplier_settlements");
    expect(migration).toContain("get_admin_supplier_settlement_safe");
    expect(migration).toContain("current_finance_admin_profile_id");
    expect(migration).toMatch(/alter\s+type\s+public\.payment_collection_status\s+add\s+value\s+if\s+not\s+exists\s+'settlement_verified'/i);
    expect(migration).toMatch(/security\s+definer/i);
    expect(migration).toMatch(/set\s+search_path\s*=\s*public/i);
    expect(migration).toMatch(/admin_role\s+in\s+\('finance_staff',\s*'super_admin'\)/i);
    expect(migration).not.toMatch(/public\.has_admin_role\('finance_staff'\)/i);
    expect(migration).not.toMatch(/admin_role\s*=\s*'admin'/i);
  });

  it("keeps verification atomic, idempotent, and free of stock or withdrawal side effects", () => {
    const migration = read(migrationPath);

    expect(migration).toMatch(/for\s+update/i);
    expect(migration).toContain("FINANCE_ADMIN_REQUIRED");
    expect(migration).toContain("ORDER_NOT_PAYMENT_REPORTED");
    expect(migration).toContain("SETTLEMENT_NOT_FOUND");
    expect(migration).toContain("COMMISSION_NOT_FOUND");
    expect(migration).toContain("FINANCIAL_AMOUNT_MISMATCH");
    expect(migration).toContain("CURRENCY_MISMATCH");
    expect(migration).toContain("STOCK_STATE_INCONSISTENT");
    expect(migration).toContain("CONFLICTING_RETRY");
    expect(migration).toMatch(/settlement_status\s*=\s*'paid'/i);
    expect(migration).toMatch(/payment_collection_status\s*=\s*'settlement_verified'/i);
    expect(migration).toMatch(/commission_status\s*=\s*'available'/i);
    expect(migration).toMatch(/commission_available_amount\s*=\s*r\.commission_available_amount\s*\+/i);
    expect(migration).toMatch(/commission_pending_amount\s*=\s*greatest/i);
    expect(migration).toMatch(/order_status\s*=\s*'completed'/i);
    expect(migration).not.toMatch(/insert\s+into\s+public\.withdrawals/i);
    expect(migration).not.toMatch(/update\s+public\.stock_reservations/i);
    expect(migration).not.toMatch(/update\s+public\.product_variants/i);
    expect(migration).not.toMatch(/insert\s+into\s+public\.inventory_movements/i);
  });

  it("connects admin UI through server actions without browser-supplied money or status fields", () => {
    for (const path of [helperPath, actionPath, uiPath]) {
      expect(existsSync(path)).toBe(true);
    }

    const sources = [helperPath, actionPath, uiPath].map(read).join("\n");

    expect(sources).toContain("admin_verify_supplier_settlement");
    expect(sources).toContain("list_admin_pending_supplier_settlements");
    expect(sources).toContain("get_admin_supplier_settlement_safe");
    expect(sources).toContain("verifySupplierSettlementFormAction");
    expect(sources).toContain("settlement_acknowledgement");
    expect(sources).toContain("I confirm that Risellar received the full settlement amount for this order.");
    expect(sources).not.toContain('name="platform_amount');
    expect(sources).not.toContain('name="commission_amount');
    expect(sources).not.toContain('name="total_amount');
    expect(sources).not.toContain('name="currency');
    expect(sources).not.toContain('name="supplier_id');
    expect(sources).not.toContain('name="reseller_id');
    expect(sources).not.toContain('name="settlement_status');
    expect(sources).not.toContain('name="commission_status');
    expect(sources).not.toContain("createSupabaseAdminClient");
    expect(sources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
  });

  it("allows finance staff through the settlement route boundary without broadening every admin route", () => {
    const adminAccess = read(adminAccessPath);
    const routeBoundary = read(routeBoundaryPath);

    expect(adminAccess).toContain("getFinanceSettlementAdminAccess");
    expect(adminAccess).toContain("admin_can_verify_supplier_settlements");
    expect(routeBoundary).toContain('pathname === "/admin/settlements"');
    expect(routeBoundary).toContain('pathname.startsWith("/admin/settlements/")');
    expect(routeBoundary).toContain("getFinanceSettlementAdminAccess");
    expect(routeBoundary).toContain("getRoleOnboardingAdminAccess");
    expect(routeBoundary.indexOf("getFinanceSettlementAdminAccess")).toBeLessThan(routeBoundary.indexOf("getRoleOnboardingAdminAccess({"));
  });

  it("does not connect settlement verification to supplier, customer, reseller, checkout, stock, payment provider, or withdrawal flows", () => {
    const unrelatedPaths = ["app/supplier", "app/customer", "app/reseller", "app/checkout", "app/shop"];
    const forbidden = ["admin_verify_supplier_settlement", "verifySupplierSettlementFormAction"];

    for (const relativePath of unrelatedPaths) {
      const source = readSourceTree(relativePath);
      for (const token of forbidden) {
        expect(source).not.toContain(token);
      }
    }
  });
});
