import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const migrationPath = join(process.cwd(), "supabase/migrations/20260730180000_supplier_order_delivery_arrangement_rpc.sql");
const conflictPatchPath = join(process.cwd(), "supabase/migrations/20260730183000_fix_delivery_arrangement_conflict_target.sql");
const customerEnumPatchPath = join(process.cwd(), "supabase/migrations/20260730184000_fix_delivery_arrangement_customer_enum_labels.sql");
const supplierListLabelPatchPath = join(process.cwd(), "supabase/migrations/20260730185000_fix_delivery_arranged_supplier_list_label.sql");
const boundaryScriptPath = join(process.cwd(), "scripts/rpc/supplier-order-delivery-arrangement-rpc-tests-dev-only.sql");
const concurrencyScriptPath = join(process.cwd(), "scripts/rpc/supplier-order-delivery-arrangement-concurrency-tests-dev-only.sql");

function read(path: string) {
  return existsSync(path) ? readFileSync(path, "utf8") : "";
}

function functionBody(source: string, name: string) {
  const match = source.match(new RegExp(`create or replace function public\\.${name}\\([\\s\\S]*?\\n\\$\\$;`, "i"));
  return match?.[0] ?? "";
}

describe("Supplier delivery arrangement Phase 1 contract", () => {
  const migration = read(migrationPath);
  const conflictPatch = read(conflictPatchPath);
  const customerEnumPatch = read(customerEnumPatchPath);
  const supplierListLabelPatch = read(supplierListLabelPatchPath);
  const boundaryScript = read(boundaryScriptPath);
  const concurrencyScript = read(concurrencyScriptPath);

  it("adds a narrow delivery_arranged status, storage table, and supplier RPC signature", () => {
    expect(migration).toContain("add value if not exists 'delivery_arranged'");
    expect(migration).toContain("create table if not exists public.delivery_arrangements");
    expect(migration).toContain("order_id uuid not null unique");
    expect(migration).toContain("delivery_method text not null");
    expect(migration).toContain("supplier_private_note text");
    expect(migration).toContain("create or replace function public.supplier_arrange_order_delivery(");

    const body = functionBody(migration, "supplier_arrange_order_delivery");
    expect(body).toContain("p_order_id uuid");
    expect(body).toContain("p_delivery_method text");
    expect(body).not.toContain("p_supplier_id");
    expect(body).not.toContain("p_currency");
    expect(body).not.toContain("p_order_status");
    expect(body).not.toContain("p_payment_status");
    expect(body).not.toContain("p_stock");
  });

  it("validates actionability, controlled methods, fields, row locks, and one-arrangement idempotency", () => {
    const body = functionBody(migration, "supplier_arrange_order_delivery");
    expect(body).toContain("for update");
    expect(body).toContain("ready_for_delivery");
    expect(body).toContain("delivery_arranged");
    expect(body).toContain("ready_for_delivery_at is null");
    expect(body).toContain("payment_collection_status");
    expect(body).toContain("not_collected");
    expect(body).toContain("reservation_status");
    expect(body).toContain("reserved");
    expect(body).toContain("INVALID_DELIVERY_METHOD");
    expect(body).toContain("INVALID_DELIVERY_FEE");
    expect(body).toContain("DELIVERY_FEE_TOO_HIGH");
    expect(body).toContain("EXPECTED_DATE_IN_PAST");
    expect(body).toContain("FIELD_TOO_LONG");
    expect(body).toContain("CONFLICTING_RETRY");
    expect(body).toContain("on conflict (order_id) do nothing");
    expect(body).toContain("supplier_order_delivery_arranged");
  });

  it("uses a named delivery arrangement conflict target to avoid PL/pgSQL output-column ambiguity", () => {
    expect(conflictPatch).toContain("on conflict on constraint delivery_arrangements_order_id_key do nothing");
    expect(conflictPatch).not.toContain("on conflict (order_id) do nothing");
  });

  it("preserves reservation, stock, payment, and commercial snapshots", () => {
    const body = functionBody(migration, "supplier_arrange_order_delivery");
    expect(body).not.toMatch(/update\s+public\.stock_reservations/i);
    expect(body).not.toMatch(/update\s+public\.product_variants/i);
    expect(body).not.toMatch(/update\s+public\.payments/i);
    expect(body).not.toMatch(/insert\s+into\s+public\.(delivery_quotes|payments|commissions|settlements|withdrawals|refunds|order_cancellations)/i);
    expect(body).not.toMatch(/uber|bolt|yango|glovo|gps|tracking/i);
    expect(body).not.toMatch(/supplier_private_note[^)]*metadata/i);
  });

  it("updates supplier and customer safe reads without leaking private notes", () => {
    expect(migration).toContain("when o.order_status::text = 'delivery_arranged' then 'Delivery arranged'");
    expect(migration).toContain("when o.order_status::text = 'delivery_arranged' then 'Delivery arrangement confirmed'");
    expect(migration).toContain("delivery_arrangement_method_label");
    expect(migration).toContain("delivery_arrangement_customer_instruction");
    expect(migration).toContain("delivery_arrangement_supplier_private_note");

    const customerBody = functionBody(migration, "get_customer_order_safe");
    expect(customerBody).toContain("da.customer_instruction");
    expect(customerBody).not.toContain("da.supplier_private_note");
    expect(customerBody).not.toContain("da.idempotency_key");
    expect(customerBody).not.toContain("arranged_by_profile_id");
  });

  it("casts customer-safe read enum labels to text before comparing literals", () => {
    expect(customerEnumPatch).toContain("case o.customer_confirmation_status::text");
    expect(customerEnumPatch).toContain("case o.delivery_quote_status::text");
    expect(customerEnumPatch).not.toContain("case o.customer_confirmation_status\n");
    expect(customerEnumPatch).not.toContain("case o.delivery_quote_status\n");
  });

  it("adds delivery_arranged to supplier order list labels", () => {
    expect(supplierListLabelPatch).toContain("create or replace function public.list_supplier_orders_safe(");
    expect(supplierListLabelPatch).toContain("when o.order_status::text = 'delivery_arranged' then 'Delivery arranged'");
  });

  it("keeps execute grants narrow and does not broaden direct table access", () => {
    expect(migration).toContain("revoke all on function public.supplier_arrange_order_delivery");
    expect(migration).toContain("from public");
    expect(migration).toContain("from anon");
    expect(migration).toContain("grant execute on function public.supplier_arrange_order_delivery");
    expect(migration).toContain("to authenticated");
    expect(migration).not.toMatch(/grant\s+(insert|update|delete|all)\s+on\s+public\.delivery_arrangements\s+to\s+authenticated/i);
    expect(migration).not.toMatch(/using\s*\(\s*true\s*\)|with check\s*\(\s*true\s*\)/i);
  });

  it("adds rollback-backed boundary and concurrency harnesses with the required assertions", () => {
    expect(boundaryScript).toContain("rollback");
    expect(boundaryScript).toContain("supplier arranges delivery for own ready order");
    expect(boundaryScript).toContain("conflicting retry blocked");
    expect(boundaryScript).toContain("customer blocked");
    expect(boundaryScript).toContain("reseller blocked");
    expect(boundaryScript).toContain("admin_staff blocked");
    expect(boundaryScript).toContain("anonymous blocked");
    expect(boundaryScript).toContain("supplier private note hidden from customer safe read");
    expect(boundaryScript).toContain("no delivery provider side effects");

    expect(concurrencyScript).toContain("rollback");
    expect(concurrencyScript).toContain("one arrangement row");
    expect(concurrencyScript).toContain("no mixed arrangement fields");
  });
});
