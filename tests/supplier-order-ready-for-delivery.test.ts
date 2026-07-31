import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migrationPath = join(process.cwd(), "supabase/migrations/20260730163000_supplier_order_ready_for_delivery_rpc.sql");
const boundaryTestPath = join(process.cwd(), "scripts/rpc/supplier-order-ready-for-delivery-rpc-tests-dev-only.sql");
const concurrencyTestPath = join(process.cwd(), "scripts/rpc/supplier-order-ready-for-delivery-concurrency-tests-dev-only.sql");

const readIfExists = (path: string) => (existsSync(path) ? readFileSync(path, "utf8") : "");

const migration = readIfExists(migrationPath);
const boundaryTest = readIfExists(boundaryTestPath);
const concurrencyTest = readIfExists(concurrencyTestPath);

function functionSignature(name: string) {
  const match = migration.match(new RegExp(`create or replace function public\\.${name}\\(([\\s\\S]*?)\\)\\s*returns`, "i"));

  if (!match) {
    throw new Error(`Missing ${name} signature`);
  }

  return match[1];
}

function functionBody(name: string) {
  const match = migration.match(new RegExp(`create or replace function public\\.${name}\\([\\s\\S]*?\\$\\$([\\s\\S]*?)\\$\\$;`, "i"));

  if (!match) {
    throw new Error(`Missing ${name} body`);
  }

  return match[1];
}

function readSourceTree(relativePath: string): string {
  const fullPath = join(process.cwd(), relativePath);

  if (!existsSync(fullPath)) {
    return "";
  }

  const stat = statSync(fullPath);

  if (stat.isFile()) {
    return readFileSync(fullPath, "utf8");
  }

  return readdirSync(fullPath)
    .map((entry): string => readSourceTree(join(relativePath, entry)))
    .join("\n");
}

describe("Supplier fulfilment Phase 3 ready-for-delivery contract", () => {
  it("adds a ready_for_delivery status, ready metadata, and a narrow supplier RPC signature", () => {
    expect(migration).toContain("add value if not exists 'ready_for_delivery'");
    expect(migration).toContain("add column if not exists ready_for_delivery_at timestamptz");
    expect(migration).toContain("add column if not exists ready_for_delivery_by_profile_id uuid");
    expect(migration).toContain("add column if not exists ready_for_delivery_idempotency_key text");
    expect(migration).toContain("create or replace function public.supplier_mark_ready_for_delivery(");

    const signature = functionSignature("supplier_mark_ready_for_delivery");

    expect(signature).toContain("p_order_id uuid");
    expect(signature).toContain("p_idempotency_key text default null");

    for (const forbiddenInput of [
      "p_supplier_id",
      "p_customer_id",
      "p_reseller_id",
      "p_product_id",
      "p_variant_id",
      "p_reservation_id",
      "p_quantity",
      "p_stock",
      "p_price",
      "p_status",
      "p_payment",
      "p_delivery"
    ]) {
      expect(signature).not.toMatch(new RegExp(forbiddenInput, "i"));
    }
  });

  it("requires preparing supplier-owned reserved POD orders and preserves reservation, stock, and payment", () => {
    const body = functionBody("supplier_mark_ready_for_delivery");

    expect(migration).toContain("v_profile_id := public.current_profile_id()");
    expect(migration).toContain("p.primary_role = 'supplier_owner'");
    expect(migration).toContain("s.supplier_status = 'active'");
    expect(migration).toContain("s.verification_status = 'approved'");
    expect(body).toMatch(/for update/i);
    expect(body).toContain("supplier_preparing");
    expect(body).toContain("ready_for_delivery");
    expect(body).toContain("supplier_preparing_at is null");
    expect(body).toMatch(/payment_collection_status\s*<>\s*'not_collected'/i);
    expect(body).toMatch(/reservation_status\s*<>\s*'reserved'/i);
    expect(body).toContain("expires_at <= now()");
    expect(body).not.toMatch(/update\s+public\.stock_reservations/i);
    expect(body).not.toMatch(/update\s+public\.product_variants/i);
    expect(body).not.toMatch(/reservation_status\s*=/i);
    expect(body).not.toMatch(/reserved_stock_quantity\s*=/i);
    expect(body).not.toMatch(/sold_stock_quantity\s*=/i);
    expect(body).not.toMatch(/total_stock_quantity\s*=/i);
    expect(body).not.toContain("payment_collection_status = 'collected'");
  });

  it("is idempotent, audited once, and grants execute only to authenticated", () => {
    const body = functionBody("supplier_mark_ready_for_delivery");

    expect(body).toContain("ready_for_delivery_idempotency_key");
    expect(body).toContain("supplier_order_ready_for_delivery");
    expect(body).toContain("ready_for_delivery_at = coalesce(o.ready_for_delivery_at, now())");
    expect(migration).toContain("revoke all on function public.supplier_mark_ready_for_delivery(uuid, text) from public");
    expect(migration).toContain("revoke all on function public.supplier_mark_ready_for_delivery(uuid, text) from anon");
    expect(migration).toContain("grant execute on function public.supplier_mark_ready_for_delivery(uuid, text) to authenticated");

    const transitionAuditMatches = migration.match(/supplier_order_ready_for_delivery/g) ?? [];
    expect(transitionAuditMatches.length).toBeGreaterThanOrEqual(2);
  });

  it("updates supplier and customer safe-read mappings truthfully", () => {
    expect(migration).toContain("when o.order_status::text = 'ready_for_delivery' then 'Ready for delivery'");
    expect(migration).toContain("when o.order_status::text = 'ready_for_delivery' then 'Your order is ready for delivery arrangement'");
    expect(migration).toContain("Delivery has not been arranged yet");
    expect(migration).toContain("o.order_status::text = 'supplier_preparing'");
    expect(migration).toContain("and sr.reservation_status = 'reserved'");
    expect(migration).toContain("and sr.expires_at > now()");
  });

  it("does not add delivery, payment, finance, refund, cancellation, or broad access changes", () => {
    const body = functionBody("supplier_mark_ready_for_delivery");

    expect(body).not.toMatch(/\binsert\s+into\s+public\.(delivery_quotes|payments|commissions|settlements|withdrawals|refunds|order_cancellations|supplier_order_preparations)\b/i);
    expect(body).not.toMatch(/\bupdate\s+public\.(delivery_quotes|payments|commissions|settlements|withdrawals|refunds|order_cancellations|product_variants|stock_reservations)\b/i);
    expect(migration).not.toMatch(/grant\s+(select|insert|update|delete|all)\s+on\s+public\.(orders|order_items|stock_reservations|product_variants)\s+to\s+authenticated/i);
    expect(migration).not.toMatch(/using\s*\(\s*true\s*\)|with check\s*\(\s*true\s*\)/i);
    expect(migration).not.toMatch(/cascade/i);
  });

  it("adds development-only boundary and concurrency harnesses with rollback and active assertions", () => {
    expect(boundaryTest).toContain("DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION");
    expect(boundaryTest).toContain("begin;");
    expect(boundaryTest).toContain("rollback;");
    expect(boundaryTest).toContain("supplier marks own preparing order ready");
    expect(boundaryTest).toContain("confirmed-but-not-preparing order blocked");
    expect(boundaryTest).toContain("missing preparation timestamp blocked");
    expect(boundaryTest).toContain("cross-supplier blocked");
    expect(boundaryTest).toContain("customer blocked");
    expect(boundaryTest).toContain("no delivery payment finance side effects");
    expect(boundaryTest).toContain("fixture data rolled back");

    expect(concurrencyTest).toContain("DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION");
    expect(concurrencyTest).toContain("two mark ready calls");
    expect(concurrencyTest).toContain("one ready audit event");
    expect(concurrencyTest).toContain("reservation unchanged");
    expect(concurrencyTest).toContain("stock unchanged");
  });

  it("connects server helper, server action, and UI without service role or direct table writes", () => {
    const sources = [
      "app/supplier/orders",
      "components/supplier/supplier-order-rpc-screens.tsx",
      "lib/orders"
    ].map(readSourceTree).join("\n");

    expect(sources).toContain("supplier_mark_ready_for_delivery");
    expect(sources).toContain("markSupplierOrderReadyForDeliveryFormAction");
    expect(sources).toContain("supplier-ready-for-delivery:");
    expect(sources).toContain("Mark ready for delivery");
    expect(sources).toContain("Order is ready for delivery");
    expect(sources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(sources).not.toContain("createSupabaseAdminClient");
    expect(sources).not.toContain(".from(\"orders\").update");
    expect(sources).not.toContain(".from(\"stock_reservations\").update");
    expect(sources).not.toContain("delivery_quotes");
    expect(sources).not.toContain("create_payment");
    expect(sources).not.toMatch(/settlement complete|settlement verified|release_commission_after_settlement/i);
    expect(sources).not.toContain("withdrawal");
  });
});
