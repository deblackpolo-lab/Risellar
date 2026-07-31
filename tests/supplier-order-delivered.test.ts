import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migrationPath = join(process.cwd(), "supabase/migrations/20260730203000_supplier_order_delivered_rpc.sql");
const supplierReadPath = join(process.cwd(), "lib/orders/supplier-order-read.ts");
const supplierSharedPath = join(process.cwd(), "lib/orders/supplier-order-shared.ts");
const supplierScreenPath = join(process.cwd(), "components/supplier/supplier-order-rpc-screens.tsx");

function read(path: string) {
  return readFileSync(path, "utf8").toLowerCase();
}

function readMigration() {
  return existsSync(migrationPath) ? read(migrationPath) : "";
}

function functionBody(sql: string, functionName: string) {
  const escapedName = functionName.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = sql.match(new RegExp(`create or replace function public\\.${escapedName}[\\s\\S]*?\\$fn\\$;`, "i"));

  return match?.[0] ?? "";
}

describe("Supplier delivered order flow", () => {
  it("creates a narrow delivered RPC that accepts only order, note, and idempotency inputs", () => {
    const migration = readMigration();
    const body = functionBody(migration, "supplier_mark_order_delivered");

    expect(migration).toContain("create or replace function public.supplier_mark_order_delivered(");
    expect(migration).toContain("p_order_id uuid");
    expect(migration).toContain("p_delivery_confirmation_note text default null");
    expect(migration).toContain("p_idempotency_key text default null");
    expect(body).not.toContain("p_supplier_id");
    expect(body).not.toContain("p_order_status");
    expect(body).not.toContain("p_payment");
    expect(body).not.toContain("p_stock");
    expect(body).not.toContain("p_commission");
  });

  it("requires out_for_delivery source state and records delivered without payment completion", () => {
    const body = functionBody(readMigration(), "supplier_mark_order_delivered");

    expect(body).toContain("order_status::text <> 'out_for_delivery'");
    expect(body).toContain("out_for_delivery_at is null");
    expect(body).toContain("delivery_arrangements");
    expect(body).toContain("set order_status = 'delivered'::text::public.order_status");
    expect(body).toContain("delivered_at = coalesce");
    expect(body).not.toContain("delivered_payment_pending");
    expect(body).not.toContain("payment_collected");
  });

  it("uses row locks, idempotency, conflict protection, and a single audit event", () => {
    const body = functionBody(readMigration(), "supplier_mark_order_delivered");

    expect(body).toContain("for update");
    expect(body).toContain("delivered_idempotency_key");
    expect(body).toContain("conflicting_retry");
    expect(body).toContain("supplier_order_delivered");
    expect(body).toContain("insert into public.audit_logs");
    expect(body).toMatch(/select count\(\*\)[\s\S]+supplier_order_delivered/);
  });

  it("preserves reservation, stock, payment, and commercial snapshots", () => {
    const body = functionBody(readMigration(), "supplier_mark_order_delivered");

    expect(body).toContain("reservation_status");
    expect(body).toContain("not_collected");
    expect(body).not.toMatch(/update\s+public\.stock_reservations/i);
    expect(body).not.toMatch(/update\s+public\.product_variants/i);
    expect(body).not.toMatch(/insert\s+into\s+public\.(payments|payment_intents|delivery_quotes|commissions|reseller_commissions|supplier_settlements|withdrawals|refunds|order_cancellations)/i);
  });

  it("keeps supplier-only delivery notes out of customer-safe reads", () => {
    const migration = readMigration();
    const supplierRead = functionBody(migration, "get_supplier_order_safe");
    const customerRead = functionBody(migration, "get_customer_order_safe");

    expect(supplierRead).toContain("delivery_confirmation_note");
    expect(customerRead).toContain("your order has been delivered");
    expect(customerRead).toContain("payment has not yet been confirmed in risellar");
    expect(customerRead).toContain("delivered_at");
    expect(customerRead).not.toContain("delivery_confirmation_note");
    expect(customerRead).not.toContain("delivered_idempotency_key");
  });

  it("keeps execute permissions authenticated-only and avoids proof, tracking, payment, or finance helpers", () => {
    const migration = readMigration();

    expect(migration).toContain("security definer");
    expect(migration).toContain("set search_path = public");
    expect(migration).toContain("revoke all on function public.supplier_mark_order_delivered");
    expect(migration).toContain("grant execute on function public.supplier_mark_order_delivered");
    expect(migration).not.toMatch(/grant\s+(insert|update|delete|all)\s+on\s+public\.(orders|stock_reservations|product_variants|delivery_arrangements)\s+to\s+authenticated/i);
    expect(migration).not.toMatch(/create\s+table[\s\S]+(proof_of_delivery|live_tracking|tracking_url|gps|rider_account|provider_booking|delivery_tracking)/i);
  });

  it("adds a server helper/action contract without caller-controlled supplier, stock, payment, or finance fields", () => {
    const readHelper = read(supplierReadPath);
    const shared = read(supplierSharedPath);

    expect(readHelper).toContain("buildmarksupplierorderdeliveredpayload");
    expect(readHelper).toContain("\"supplier_mark_order_delivered\"");
    expect(readHelper).toContain("p_delivery_confirmation_note");
    expect(shared).toContain("deliveredat");
    expect(shared).toContain("deliveryconfirmationnote");
    expect(readHelper).not.toContain("p_supplier_id");
    expect(readHelper).not.toContain("p_payment_status");
    expect(readHelper).not.toContain("p_stock");
    expect(readHelper).not.toContain("p_commission");
  });

  it("shows delivered controls only for out_for_delivery and excludes payment/proof controls", () => {
    const screen = read(supplierScreenPath);

    expect(screen).toContain("mark as delivered");
    expect(screen).toContain("order.orderstatus === \"out_for_delivery\"");
    expect(screen).toContain("order.orderstatus === \"delivered\"");
    expect(screen).toContain("payment has not yet been confirmed in risellar");
    expect(screen).not.toContain("confirm payment");
    expect(screen).not.toContain("payment received");
    expect(screen).not.toContain("upload proof");
    expect(screen).not.toContain("tracking_url");
    expect(screen).not.toContain("proof_of_delivery");
  });
});
