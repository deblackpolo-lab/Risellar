import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migrationPath = join(process.cwd(), "supabase/migrations/20260730140000_supplier_order_accept_reject_rpc.sql");
const boundaryTestPath = join(process.cwd(), "scripts/rpc/supplier-order-decision-rpc-tests-dev-only.sql");
const concurrencyTestPath = join(process.cwd(), "scripts/rpc/supplier-order-decision-concurrency-tests-dev-only.sql");

const readIfExists = (path: string) => (existsSync(path) ? readFileSync(path, "utf8") : "");

const migration = readIfExists(migrationPath);
const boundaryTest = readIfExists(boundaryTestPath);
const concurrencyTest = readIfExists(concurrencyTestPath);

const functionSignature = (name: string) => {
  const match = migration.match(new RegExp(`create or replace function public\\.${name}\\(([\\s\\S]*?)\\)\\s*returns`, "i"));

  if (!match) {
    throw new Error(`Missing ${name} signature`);
  }

  return match[1];
};

const functionBody = (name: string) => {
  const match = migration.match(new RegExp(`create or replace function public\\.${name}\\([\\s\\S]*?\\$\\$([\\s\\S]*?)\\$\\$;`, "i"));

  if (!match) {
    throw new Error(`Missing ${name} body`);
  }

  return match[1];
};

describe("Supplier order accept/reject backend contract", () => {
  it("adds explicit supplier decision states and RPCs without caller-supplied ownership or commercial fields", () => {
    expect(migration).toContain("alter type public.order_status add value if not exists 'supplier_confirmed'");
    expect(migration).toContain("alter type public.order_status add value if not exists 'supplier_rejected'");
    expect(migration).toContain("create or replace function public.supplier_accept_order(");
    expect(migration).toContain("create or replace function public.supplier_reject_order(");

    const acceptSignature = functionSignature("supplier_accept_order");
    const rejectSignature = functionSignature("supplier_reject_order");

    expect(acceptSignature).toContain("p_order_id uuid");
    expect(acceptSignature).toContain("p_idempotency_key text default null");
    expect(rejectSignature).toContain("p_reason_code text");
    expect(rejectSignature).toContain("p_reason_note text default null");

    for (const forbidden of [
      "p_supplier_id",
      "p_customer_id",
      "p_reseller_id",
      "p_product_id",
      "p_variant_id",
      "p_reservation_id",
      "p_quantity",
      "p_stock",
      "p_price",
      "p_order_status",
      "p_payment_status",
      "p_commission",
      "p_settlement"
    ]) {
      expect(`${acceptSignature}\n${rejectSignature}`).not.toMatch(new RegExp(forbidden, "i"));
    }
  });

  it("uses server-side supplier ownership, locking, idempotency, and authenticated-only execution", () => {
    const acceptBody = functionBody("supplier_accept_order");
    const rejectBody = functionBody("supplier_reject_order");
    const combined = `${acceptBody}\n${rejectBody}`;

    expect(migration).toContain("v_profile_id := public.current_profile_id()");
    expect(migration).toContain("p.primary_role = 'supplier_owner'");
    expect(migration).toContain("s.supplier_status = 'active'");
    expect(migration).toContain("s.verification_status = 'approved'");
    expect(combined).toMatch(/for update/i);
    expect(combined).toContain("supplier_decision_idempotency_key");
    expect(combined).toContain("placed_pending_confirmation");
    expect(combined).toMatch(/payment_collection_status\s*<>\s*'not_collected'/i);
    expect(migration).toContain("revoke all on function public.supplier_accept_order(uuid, text) from public");
    expect(migration).toContain("revoke all on function public.supplier_accept_order(uuid, text) from anon");
    expect(migration).toContain("grant execute on function public.supplier_accept_order(uuid, text) to authenticated");
    expect(migration).toContain("revoke all on function public.supplier_reject_order(uuid, text, text, text) from public");
    expect(migration).toContain("revoke all on function public.supplier_reject_order(uuid, text, text, text) from anon");
    expect(migration).toContain("grant execute on function public.supplier_reject_order(uuid, text, text, text) to authenticated");
  });

  it("preserves stock on accept and releases reserved stock exactly once on reject", () => {
    const acceptBody = functionBody("supplier_accept_order");
    const rejectBody = functionBody("supplier_reject_order");

    expect(acceptBody).toContain("supplier_confirmed");
    expect(acceptBody).not.toMatch(/reservation_status\s*=\s*'released'/i);
    expect(acceptBody).not.toMatch(/reserved_stock_quantity\s*=/i);

    expect(rejectBody).toContain("supplier_rejected");
    expect(rejectBody).toMatch(/reservation_status\s*=\s*'released'/i);
    expect(rejectBody).toMatch(/reserved_stock_quantity\s*=\s*pv\.reserved_stock_quantity - v_reservation\.quantity/i);
    expect(rejectBody).toContain("pv.reserved_stock_quantity >= v_reservation.quantity");
    expect(rejectBody).not.toMatch(/sold_stock_quantity\s*=/i);
    expect(rejectBody).not.toMatch(/total_stock_quantity\s*=/i);
  });

  it("audits terminal decisions without adding payment, delivery, preparation, or finance mutations", () => {
    expect(migration).toContain("supplier_order_accepted");
    expect(migration).toContain("supplier_order_rejected");
    expect(migration).toContain("stock_reservation_released");
    expect(migration).toContain("reserved_stock_decremented");

    const combinedBodies = `${functionBody("supplier_accept_order")}\n${functionBody("supplier_reject_order")}`;
    expect(combinedBodies).not.toMatch(/\binsert\s+into\s+public\.(payments|delivery_quotes|settlements|commissions|withdrawals|refunds)\b/i);
    expect(combinedBodies).not.toMatch(/\bupdate\s+public\.(payments|delivery_quotes|settlements|commissions|withdrawals|refunds)\b/i);
    expect(combinedBodies).not.toContain("supplier_preparing");
    expect(combinedBodies).not.toContain("payment_collection_status = 'collected'");
  });

  it("keeps safe-read surfaces compatible with supplier decisions and does not connect supplier UI", () => {
    expect(migration).toContain("when o.order_status::text = 'supplier_confirmed' then 'Supplier confirmed'");
    expect(migration).toContain("when o.order_status::text = 'supplier_rejected' then 'Rejected - stock released'");
    expect(migration).toContain("when o.order_status::text = 'supplier_confirmed' then 'Supplier confirmed your order'");
    expect(migration).toContain("when o.order_status::text = 'supplier_rejected' then 'Supplier could not fulfil this order'");

    for (const uiPath of [
      "app/supplier/orders/page.tsx",
      "app/supplier/orders/[id]/page.tsx",
      "components/supplier/screens.tsx"
    ]) {
      const source = readIfExists(join(process.cwd(), uiPath));
      expect(source).not.toContain("supplier_accept_order");
      expect(source).not.toContain("supplier_reject_order");
    }
  });

  it("adds active development-only decision and concurrency SQL harnesses", () => {
    expect(boundaryTest).toContain("DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION");
    expect(boundaryTest).toContain("begin;");
    expect(boundaryTest).toContain("rollback;");
    expect(boundaryTest).toContain("supplier accepts own order");
    expect(boundaryTest).toContain("supplier rejects own order");
    expect(boundaryTest).toContain("cross-supplier accept blocked");
    expect(boundaryTest).toContain("duplicate reject does not double-release");
    expect(boundaryTest).toContain("no payment delivery preparation finance side effects");
    expect(boundaryTest).toContain("fixture data rolled back");

    expect(concurrencyTest).toContain("DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION");
    expect(concurrencyTest).toContain("accept-vs-reject");
    expect(concurrencyTest).toContain("two-reject");
    expect(concurrencyTest).toContain("two-accept");
    expect(concurrencyTest).toContain("no negative reserved stock");
  });
});
