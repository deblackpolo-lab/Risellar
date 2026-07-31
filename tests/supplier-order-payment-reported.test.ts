import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migrationPath = join(process.cwd(), "supabase/migrations/20260730220000_supplier_order_payment_reported_rpc.sql");
const supplierHelperPath = join(process.cwd(), "lib/orders/supplier-order-read.ts");
const supplierActionPath = join(process.cwd(), "app/supplier/orders/actions.ts");
const supplierUiPath = join(process.cwd(), "components/supplier/supplier-order-rpc-screens.tsx");

function read(path: string) {
  return readFileSync(path, "utf8");
}

describe("Pay on Delivery supplier payment reporting foundation", () => {
  it("creates a forward migration for supplier-reported Pay on Delivery payment", () => {
    expect(existsSync(migrationPath)).toBe(true);

    const migration = read(migrationPath);

    expect(migration).toContain("supplier_report_order_payment_received");
    expect(migration).toContain("supplier_payment_reports");
    expect(migration).toMatch(/alter\s+type\s+public\.order_status\s+add\s+value\s+if\s+not\s+exists\s+'payment_reported'/i);
    expect(migration).toMatch(/alter\s+type\s+public\.payment_collection_status\s+add\s+value\s+if\s+not\s+exists\s+'supplier_reported'/i);
    expect(migration).toMatch(/add\s+column\s+if\s+not\s+exists\s+payment_reported_at/i);
    expect(migration).toMatch(/enable\s+row\s+level\s+security/i);
    expect(migration).toMatch(/force\s+row\s+level\s+security/i);
  });

  it("keeps supplier payment reporting inside audited server-side RPC boundaries", () => {
    const migration = read(migrationPath);

    expect(migration).toMatch(/create\s+or\s+replace\s+function\s+public\.supplier_report_order_payment_received\s*\(\s*p_order_id\s+uuid,\s*p_payment_reference\s+text\s+default\s+null,\s*p_supplier_private_note\s+text\s+default\s+null,\s*p_idempotency_key\s+text\s+default\s+null\s*\)/i);
    expect(migration).toMatch(/security\s+definer/i);
    expect(migration).toMatch(/set\s+search_path\s*=\s*public/i);
    expect(migration).toMatch(/for\s+update/i);
    expect(migration).toContain("ORDER_NOT_DELIVERED");
    expect(migration).toContain("PAYMENT_METHOD_NOT_SUPPORTED");
    expect(migration).toContain("FINANCIAL_SNAPSHOT_INVALID");
    expect(migration).toContain("STOCK_STATE_INCONSISTENT");
    expect(migration).toContain("CONFLICTING_RETRY");
    expect(migration).toMatch(/revoke\s+all\s+on\s+function\s+public\.supplier_report_order_payment_received/i);
    expect(migration).toMatch(/grant\s+execute\s+on\s+function\s+public\.supplier_report_order_payment_received/i);
    expect(migration).not.toMatch(/grant\s+(insert|update|delete|all)\s+on\s+public\.(orders|order_items|stock_reservations|product_variants|settlements|commissions)\s+to\s+authenticated/i);
  });

  it("finalizes stock exactly once and keeps finance pending or locked", () => {
    const migration = read(migrationPath);

    expect(migration).toMatch(/reservation_status\s*=\s*'committed'/i);
    expect(migration).toMatch(/committed_at\s*=\s*coalesce/i);
    expect(migration).toMatch(/reserved_stock_quantity\s*=\s*pv\.reserved_stock_quantity\s*-\s*v_reservation\.quantity/i);
    expect(migration).toMatch(/sold_stock_quantity\s*=\s*pv\.sold_stock_quantity\s*\+\s*v_reservation\.quantity/i);
    expect(migration).toMatch(/movement_type[\s\S]*?'sale_committed'/i);
    expect(migration).toMatch(/insert\s+into\s+public\.settlements/i);
    expect(migration).toMatch(/settlement_status[\s\S]*?'due'/i);
    expect(migration).toMatch(/verified_at[\s\S]+?null/i);
    expect(migration).toMatch(/insert\s+into\s+public\.commissions/i);
    expect(migration).toMatch(/commission_status[\s\S]*?'awaiting_supplier_settlement'/i);
    expect(migration).toMatch(/available_at[\s\S]+?null/i);
    expect(migration).not.toMatch(/commission_available_amount\s*=\s*commission_available_amount\s*\+/i);
    expect(migration).not.toMatch(/commission_status\s*=\s*'available'/i);
    expect(migration).not.toMatch(/settlement_status\s*=\s*'paid'/i);
    expect(migration).not.toMatch(/order_status\s*=\s*'completed'/i);
    expect(migration).not.toMatch(/insert\s+into\s+public\.withdrawals/i);
  });

  it("connects supplier UI through server action without browser money, stock, or finance inputs", () => {
    const sources = [supplierHelperPath, supplierActionPath, supplierUiPath].map(read).join("\n");

    expect(sources).toContain("supplier_report_order_payment_received");
    expect(sources).toContain("reportSupplierOrderPaymentReceivedFormAction");
    expect(sources).toContain("payment_received_acknowledgement");
    expect(sources).toContain("supplier-payment-reported:");
    expect(sources).toContain("Payment reported - settlement pending");
    expect(sources).not.toContain("p_reported_amount");
    expect(sources).not.toContain("p_currency");
    expect(sources).not.toContain("p_stock");
    expect(sources).not.toContain("p_commission");
    expect(sources).not.toContain("p_settlement_status");
    expect(sources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(sources).not.toContain("createSupabaseAdminClient");
  });
});
