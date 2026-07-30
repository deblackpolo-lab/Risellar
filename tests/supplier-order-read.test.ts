import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migrationPath = join(process.cwd(), "supabase/migrations/20260730130000_supplier_order_safe_read_rpc.sql");
const sqlTestPath = join(process.cwd(), "scripts/rpc/supplier-order-safe-read-rpc-tests-dev-only.sql");

const migration = readFileSync(migrationPath, "utf8");
const sqlTest = readFileSync(sqlTestPath, "utf8");

const returnedFields = (functionName: string) => {
  const match = migration.match(new RegExp(`create or replace function public\\.${functionName}[\\s\\S]*?returns table \\(([\\s\\S]*?)\\)\\s*language`, "i"));

  if (!match) {
    throw new Error(`Missing return contract for ${functionName}`);
  }

  return match[1];
};

describe("Supplier order safe read RPC foundation", () => {
  it("creates narrow list and detail RPC signatures without supplier id browser input", () => {
    expect(migration).toContain("create or replace function public.list_supplier_orders_safe(");
    expect(migration).toContain("p_status text default null");
    expect(migration).toContain("p_limit integer default 50");
    expect(migration).toContain("p_cursor_created_at timestamptz default null");
    expect(migration).toContain("p_cursor_order_id uuid default null");
    expect(migration).toContain("create or replace function public.get_supplier_order_safe(p_order_id uuid)");
    expect(migration).not.toMatch(/p_supplier_id|supplier_id uuid default|target_supplier_id uuid/i);
  });

  it("returns only supplier-safe list and detail fields", () => {
    const listFields = returnedFields("list_supplier_orders_safe");
    const detailFields = returnedFields("get_supplier_order_safe");

    for (const field of [
      "order_id",
      "order_number",
      "order_status_label",
      "is_supplier_actionable",
      "product_name",
      "quantity",
      "supplier_amount_expected",
      "payment_method_label",
      "payment_status_label",
      "reservation_status_label"
    ]) {
      expect(listFields).toContain(field);
      expect(detailFields).toContain(field);
    }

    for (const forbidden of [
      "customer_id",
      "customer_email",
      "clerk_user_id",
      "reseller_id",
      "supplier_id",
      "platform_margin",
      "reseller_margin",
      "commission",
      "settlement",
      "risk_level",
      "total_stock_quantity",
      "reserved_stock_quantity",
      "sold_stock_quantity"
    ]) {
      expect(listFields).not.toContain(forbidden);
      expect(detailFields).not.toContain(forbidden);
    }
  });

  it("uses server-side active supplier-owner resolution and blocks admin_staff bypass", () => {
    expect(migration).toContain("v_profile_id := public.current_profile_id()");
    expect(migration).toContain("p.primary_role = 'supplier_owner'");
    expect(migration).toContain("s.supplier_status = 'active'");
    expect(migration).toContain("s.verification_status = 'approved'");
    expect(migration).toContain("from public.admin_staff a");
    expect(migration).toContain("raise exception 'SUPPLIER_REQUIRED'");
  });

  it("keeps the RPCs read-only and does not add supplier decision behavior", () => {
    const functionBodies = migration.replace(/comment on function[\s\S]*/i, "");

    expect(functionBodies).not.toMatch(/\binsert\s+into\s+public\.(orders|order_items|stock_reservations|inventory_movements|supplier_settlements|reseller_commissions|withdrawals)\b/i);
    expect(functionBodies).not.toMatch(/\bupdate\s+public\.(orders|product_variants|stock_reservations)\b/i);
    expect(functionBodies).not.toMatch(/\bdelete\s+from\s+public\./i);
    expect(functionBodies).not.toContain("supplier_accept_order");
    expect(functionBodies).not.toContain("supplier_reject_order");
    expect(functionBodies).not.toContain("supplier_confirmed");
    expect(functionBodies).not.toContain("supplier_rejected");
    expect(functionBodies).not.toContain("reservation_released");
    expect(functionBodies).not.toContain("payment_collection_status =");
  });

  it("revokes public/anon execution and grants authenticated execution only", () => {
    expect(migration).toContain("revoke all on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid) from public");
    expect(migration).toContain("revoke all on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid) from anon");
    expect(migration).toContain("grant execute on function public.list_supplier_orders_safe(text, integer, timestamptz, uuid) to authenticated");
    expect(migration).toContain("revoke all on function public.get_supplier_order_safe(uuid) from public");
    expect(migration).toContain("revoke all on function public.get_supplier_order_safe(uuid) from anon");
    expect(migration).toContain("grant execute on function public.get_supplier_order_safe(uuid) to authenticated");
  });

  it("maps current status and reservation enum values without inventing decision states", () => {
    expect(migration).toContain("when 'placed_pending_confirmation' then 'New order - confirm or reject'");
    expect(migration).toContain("when 'supplier_preparing' then 'Preparing'");
    expect(migration).toContain("when 'reserved' then 'Stock reserved'");
    expect(migration).toContain("when 'released' then 'Reservation released'");
    expect(migration).not.toContain("when 'supplier_confirmed'");
    expect(migration).not.toContain("when 'supplier_rejected'");
  });

  it("adds a development-only rollback SQL harness with the required boundary coverage", () => {
    expect(sqlTest).toContain("DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION");
    expect(sqlTest).toContain("begin;");
    expect(sqlTest).toContain("rollback;");
    expect(sqlTest).toContain("supplier_owner can list own orders");
    expect(sqlTest).toContain("supplier cannot list another supplier order");
    expect(sqlTest).toContain("customer blocked from supplier list");
    expect(sqlTest).toContain("reseller blocked from supplier list");
    expect(sqlTest).toContain("admin_staff blocked from supplier list");
    expect(sqlTest).toContain("anonymous blocked from supplier list");
    expect(sqlTest).toContain("read flow changes no order status");
    expect(sqlTest).toContain("no payment delivery preparation finance side effects");
  });
});
