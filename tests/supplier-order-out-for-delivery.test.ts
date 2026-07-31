import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migrationPath = join(process.cwd(), "supabase/migrations/20260730190000_supplier_order_out_for_delivery_rpc.sql");

function readMigration() {
  return readFileSync(migrationPath, "utf8").toLowerCase();
}

function functionBody(sql: string, functionName: string) {
  const escapedName = functionName.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = sql.match(new RegExp(`create or replace function public\\.${escapedName}[\\s\\S]*?\\$fn\\$;`, "i"));

  return match?.[0] ?? "";
}

describe("Supplier out-for-delivery RPC foundation", () => {
  it("creates a narrow supplier dispatch RPC without caller-controlled ownership, status, stock, payment, or economics", () => {
    const migration = readMigration();
    const body = functionBody(migration, "supplier_mark_order_out_for_delivery");

    expect(migration).toContain("create or replace function public.supplier_mark_order_out_for_delivery(");
    expect(migration).toContain("p_order_id uuid");
    expect(migration).toContain("p_dispatch_reference text default null");
    expect(migration).toContain("p_customer_dispatch_instruction text default null");
    expect(migration).toContain("p_idempotency_key text default null");
    expect(body).not.toContain("p_supplier_id");
    expect(body).not.toContain("p_order_status");
    expect(body).not.toContain("p_payment");
    expect(body).not.toContain("p_stock");
    expect(body).not.toContain("p_agreed_delivery_fee");
  });

  it("requires delivery_arranged source state, preserves arrangement, and transitions to out_for_delivery", () => {
    const body = functionBody(readMigration(), "supplier_mark_order_out_for_delivery");

    expect(body).toContain("delivery_arranged");
    expect(body).toContain("delivery_arranged_at is null");
    expect(body).toContain("delivery_arrangements");
    expect(body).toContain("out_for_delivery");
    expect(body).toContain("out_for_delivery_at");
    expect(body).not.toContain("delivered_payment_pending");
    expect(body).not.toContain("payment_collected");
  });

  it("uses row locks, idempotency, conflict protection, and one audit event", () => {
    const body = functionBody(readMigration(), "supplier_mark_order_out_for_delivery");

    expect(body).toContain("for update");
    expect(body).toContain("out_for_delivery_idempotency_key");
    expect(body).toContain("conflicting_retry");
    expect(body).toContain("supplier_order_out_for_delivery");
    expect(body).toContain("insert into public.audit_logs");
    expect(body).toMatch(/select count\(\*\)[\s\S]+supplier_order_out_for_delivery/);
  });

  it("preserves reservation, stock, payment, and commercial side effects", () => {
    const body = functionBody(readMigration(), "supplier_mark_order_out_for_delivery");

    expect(body).toContain("reservation_status");
    expect(body).toContain("not_collected");
    expect(body).not.toMatch(/update\s+public\.stock_reservations/i);
    expect(body).not.toMatch(/update\s+public\.product_variants/i);
    expect(body).not.toMatch(/insert\s+into\s+public\.(payments|payment_intents|delivery_quotes|commissions|reseller_commissions|supplier_settlements|withdrawals|refunds|order_cancellations)/i);
  });

  it("updates supplier-safe and customer-safe reads without exposing private or tracking fields", () => {
    const migration = readMigration();
    const supplierRead = functionBody(migration, "get_supplier_order_safe");
    const customerRead = functionBody(migration, "get_customer_order_safe");

    expect(supplierRead).toContain("dispatch_reference");
    expect(supplierRead).toContain("customer_dispatch_instruction");
    expect(supplierRead).toContain("when o.order_status::text = 'out_for_delivery' then 'out for delivery'");
    expect(customerRead).toContain("your order is out for delivery");
    expect(customerRead).toContain("risellar has not collected the order or delivery fee");
    expect(customerRead).not.toContain("supplier_private_note as");
    expect(migration).not.toMatch(/create\s+table[\s\S]+(live_tracking|tracking_url|rider_account|provider_booking|delivery_tracking)/i);
    expect(migration).not.toMatch(/insert\s+into\s+public\.(rider_accounts|delivery_tracking|provider_bookings)/i);
  });

  it("keeps execute permissions authenticated-only and avoids direct supplier table grants", () => {
    const migration = readMigration();

    expect(migration).toContain("security definer");
    expect(migration).toContain("set search_path = public");
    expect(migration).toContain("revoke all on function public.supplier_mark_order_out_for_delivery");
    expect(migration).toContain("grant execute on function public.supplier_mark_order_out_for_delivery");
    expect(migration).not.toMatch(/grant\s+(insert|update|delete|all)\s+on\s+public\.(orders|stock_reservations|product_variants|delivery_arrangements)\s+to\s+authenticated/i);
  });
});
