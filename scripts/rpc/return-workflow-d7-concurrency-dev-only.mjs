#!/usr/bin/env node
/* global console, process */
// DEVELOPMENT ONLY. Runs true two-process D7 return workflow RPC concurrency checks.
// Do not run against production. The runner prints only safe scenario summaries.

import { randomUUID } from "node:crypto";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";

const marker = `dev_d7_concurrency_${Date.now()}_${randomUUID().replaceAll("-", "").slice(0, 10)}`;
const tmpRoot = await mkdtemp(path.join(tmpdir(), "risellar-d7-concurrency-"));

const q = (value) => `'${String(value).replaceAll("'", "''")}'`;
const uuid = () => randomUUID();
const idList = (items) => items.map((item) => `${q(item)}::uuid`).join(", ");

const ids = {
  customerProfile: uuid(),
  supplierProfile: uuid(),
  otherSupplierProfile: uuid(),
  resellerProfile: uuid(),
  supportProfile: uuid(),
  adminProfile: uuid(),
  customer: uuid(),
  supplier: uuid(),
  otherSupplier: uuid(),
  reseller: uuid(),
  shop: uuid(),
  product: uuid(),
  otherProduct: uuid(),
  variant: uuid(),
  otherVariant: uuid(),
  listing: uuid(),
  otherListing: uuid(),
};

const scenarios = [
  ["a_same_key_request", "under_review", null],
  ["b_duplicate_active_request", "under_review", null],
  ["c_approve_vs_reject", "return_review", "requested"],
  ["d_transit_vs_reject", "return_review", "approved"],
  ["e_received_vs_reject", "return_review", "approved"],
  ["f_two_supplier_receipts", "return_review", "approved"],
  ["g_two_condition_reports", "return_review", "received"],
  ["h_accept_vs_decline", "return_review", "inspected"],
  ["i_complete_vs_condition", "return_review", "received"],
  ["j_request_vs_dispute_closure", "under_review", null],
  ["k_accept_vs_refund_review", "return_review", "inspected"],
].map(([name, disputeStatus, returnStatus], index) => ({
  name,
  disputeStatus,
  returnStatus,
  orderId: uuid(),
  itemId: uuid(),
  disputeId: uuid(),
  returnId: returnStatus ? uuid() : null,
  orderNumber: `D7CONC-${index + 1}-${marker.slice(-8).toUpperCase()}`,
  reason: [
    "return_requested",
    "return_requested",
    "return_requested",
    "return_requested",
    "return_requested",
    "return_requested",
    "return_requested",
    "return_requested",
    "return_requested",
    "return_requested",
    "return_requested",
  ][index],
}));

const clerk = {
  customer: `${marker}_customer`,
  supplier: `${marker}_supplier`,
  otherSupplier: `${marker}_other_supplier`,
  support: `${marker}_support`,
  admin: `${marker}_admin`,
};

async function runSupabaseSql(name, sql, options = {}) {
  const filePath = path.join(tmpRoot, `${name}.sql`);
  await writeFile(filePath, sql, "utf8");

  return await new Promise((resolve, reject) => {
    const child = spawn("npx", ["supabase", "db", "query", "--linked", "--file", filePath], {
      cwd: process.cwd(),
      env: {
        ...process.env,
        SUPABASE_TELEMETRY_DISABLED: "1",
        DO_NOT_TRACK: "1",
      },
      shell: process.platform === "win32",
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) {
        if (!options.quiet) process.stdout.write(stdout);
        resolve({ stdout, stderr });
      } else {
        reject(new Error(`${name} failed: ${stderr || stdout || `supabase db query exited with ${code}`}`));
      }
    });
  });
}

const scenarioByName = (name) => scenarios.find((scenario) => scenario.name === name);
const scenarioIds = () => idList(scenarios.map((scenario) => scenario.disputeId));
const returnIds = () => idList(scenarios.filter((scenario) => scenario.returnId).map((scenario) => scenario.returnId));
const orderIds = () => idList(scenarios.map((scenario) => scenario.orderId));
const itemIds = () => idList(scenarios.map((scenario) => scenario.itemId));
const profileIds = () =>
  idList([ids.customerProfile, ids.supplierProfile, ids.otherSupplierProfile, ids.resellerProfile, ids.supportProfile, ids.adminProfile]);

function setupSql() {
  const orderRows = scenarios
    .map(
      (scenario) =>
        `(${q(scenario.orderId)}, ${q(scenario.orderNumber)}, ${q(ids.customer)}, ${q(ids.reseller)}, ${q(ids.shop)}, 'delivered', 'not_collected', 'delivered', 125, 125, 'GHS')`,
    )
    .join(",\n    ");
  const itemRows = scenarios
    .map(
      (scenario) =>
        `(${q(scenario.itemId)}, ${q(scenario.orderId)}, ${q(ids.supplier)}, ${q(ids.product)}, ${q(ids.variant)}, ${q(ids.listing)}, 1, 100, 10, 15, 110, 125, 125, 100, 15)`,
    )
    .join(",\n    ");
  const disputeRows = scenarios
    .map(
      (scenario) =>
        `(${q(scenario.disputeId)}, ${q(scenario.orderId)}, ${q(ids.customerProfile)}, 'customer', 'order_item', ${q(ids.supplier)}, ${q(scenario.itemId)}, 'post_completion', 'return_requested', 'D7 concurrency return dispute.', 'return', ${q(scenario.disputeStatus)}, true)`,
    )
    .join(",\n    ");
  const returnRows = scenarios
    .filter((scenario) => scenario.returnId)
    .map((scenario) => {
      const approved = ["approved", "received", "inspected"].includes(scenario.returnStatus);
      const received = ["received", "inspected"].includes(scenario.returnStatus);
      const inspected = scenario.returnStatus === "inspected";
      return `(${q(scenario.returnId)}, ${q(scenario.disputeId)}, ${q(scenario.orderId)}, ${q(scenario.itemId)}, ${q(ids.customerProfile)}, ${q(ids.supplier)}, 1, ${approved ? "1" : "null"}, 'customer_returns_to_supplier', ${approved ? "'customer_returns_to_supplier'" : "null"}, ${q(scenario.returnStatus)}, ${received ? "now()" : "null"}, ${inspected ? "'damaged'" : "'inspection_pending'"}, ${inspected ? "'damaged_stock_review_required'" : "'pending'"}, ${inspected ? "now()" : "null"})`;
    })
    .join(",\n    ");

  return `
create table if not exists public.__dev_d7_concurrency_results (
  marker text not null,
  scenario text not null,
  actor_label text not null,
  ok boolean not null,
  result_code text not null,
  row_count integer not null default 0,
  backend_pid integer not null,
  call_started_at timestamptz not null,
  call_finished_at timestamptz not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key (marker, scenario, actor_label)
);

create table if not exists public.__dev_d7_concurrency_counts (
  marker text not null,
  table_name text not null,
  row_count bigint not null,
  primary key (marker, table_name)
);

grant select, insert, update, delete on public.__dev_d7_concurrency_results to authenticated;

drop function if exists public.__dev_d7_concurrency_record(text, text, text, boolean, text, integer, integer, timestamptz, timestamptz);

create or replace function public.__dev_d7_concurrency_record(
  p_marker text,
  p_scenario text,
  p_actor_label text,
  p_ok boolean,
  p_result_code text,
  p_row_count integer,
  p_backend_pid integer,
  p_call_started_at timestamptz,
  p_call_finished_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.__dev_d7_concurrency_results(marker, scenario, actor_label, ok, result_code, row_count, backend_pid, call_started_at, call_finished_at)
  values (p_marker, p_scenario, p_actor_label, p_ok, p_result_code, p_row_count, p_backend_pid, p_call_started_at, p_call_finished_at)
  on conflict (marker, scenario, actor_label) do update
    set ok = excluded.ok,
        result_code = excluded.result_code,
        row_count = excluded.row_count,
        backend_pid = excluded.backend_pid,
        call_started_at = excluded.call_started_at,
        call_finished_at = excluded.call_finished_at,
        created_at = clock_timestamp();
end;
$$;

revoke all on function public.__dev_d7_concurrency_record(text, text, text, boolean, text, integer, integer, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.__dev_d7_concurrency_record(text, text, text, boolean, text, integer, integer, timestamptz, timestamptz) to authenticated;

insert into public.__dev_d7_concurrency_counts(marker, table_name, row_count)
values
  (${q(marker)}, 'orders', (select count(*) from public.orders)),
  (${q(marker)}, 'order_items', (select count(*) from public.order_items)),
  (${q(marker)}, 'stock_reservations', (select count(*) from public.stock_reservations)),
  (${q(marker)}, 'product_variants', (select count(*) from public.product_variants)),
  (${q(marker)}, 'inventory_movements', (select count(*) from public.inventory_movements)),
  (${q(marker)}, 'delivery_arrangements', (select count(*) from public.delivery_arrangements)),
  (${q(marker)}, 'supplier_payment_reports', (select count(*) from public.supplier_payment_reports)),
  (${q(marker)}, 'settlements', (select count(*) from public.settlements)),
  (${q(marker)}, 'commissions', (select count(*) from public.commissions)),
  (${q(marker)}, 'withdrawals', (select count(*) from public.withdrawals)),
  (${q(marker)}, 'returns', (select count(*) from public.returns)),
  (${q(marker)}, 'notification_outbox', (select count(*) from public.notification_outbox)),
  (${q(marker)}, 'notification_provider_events', (select count(*) from public.notification_provider_events))
on conflict (marker, table_name) do update set row_count = excluded.row_count;

insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
values
  (${q(ids.customerProfile)}, ${q(clerk.customer)}, 'd7-concurrency-customer@example.test', 'D7 Concurrency Customer', 'customer', 'active'),
  (${q(ids.supplierProfile)}, ${q(clerk.supplier)}, 'd7-concurrency-supplier@example.test', 'D7 Concurrency Supplier', 'supplier_owner', 'active'),
  (${q(ids.otherSupplierProfile)}, ${q(clerk.otherSupplier)}, 'd7-concurrency-other-supplier@example.test', 'D7 Concurrency Other Supplier', 'supplier_owner', 'active'),
  (${q(ids.resellerProfile)}, ${q(`${marker}_reseller`)}, 'd7-concurrency-reseller@example.test', 'D7 Concurrency Reseller', 'reseller', 'active'),
  (${q(ids.supportProfile)}, ${q(clerk.support)}, 'd7-concurrency-support@example.test', 'D7 Concurrency Support', 'customer', 'active'),
  (${q(ids.adminProfile)}, ${q(clerk.admin)}, 'd7-concurrency-admin@example.test', 'D7 Concurrency Admin', 'customer', 'active');

insert into public.customers(id, profile_id, customer_status)
values (${q(ids.customer)}, ${q(ids.customerProfile)}, 'active');

insert into public.admin_staff(id, profile_id, admin_role, staff_status)
values
  (gen_random_uuid(), ${q(ids.supportProfile)}, 'support_staff', 'active'),
  (gen_random_uuid(), ${q(ids.adminProfile)}, 'admin', 'active');

insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
values
  (${q(ids.supplier)}, ${q(ids.supplierProfile)}, 'D7 Concurrency Supplier', 'active', 'approved', 'D7 Concurrency Supplier'),
  (${q(ids.otherSupplier)}, ${q(ids.otherSupplierProfile)}, 'D7 Concurrency Other Supplier', 'active', 'approved', 'D7 Concurrency Other Supplier');

insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
values (${q(ids.reseller)}, ${q(ids.resellerProfile)}, 'qa', 'approved', 'active');

insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status)
values (${q(ids.shop)}, ${q(ids.reseller)}, ${q(`d7-concurrency-${marker.slice(-10)}`)}, 'D7 Concurrency Shop', 'active');

insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, created_by_profile_id)
values
  (${q(ids.product)}, ${q(ids.supplier)}, 'QA', 'D7 Concurrency Product', ${q(`d7-concurrency-product-${marker.slice(-10)}`)}, 'Development-only D7 concurrency product.', 'active', 'approved', 100, 10, 20, ${q(ids.supplierProfile)}),
  (${q(ids.otherProduct)}, ${q(ids.otherSupplier)}, 'QA', 'D7 Concurrency Other Product', ${q(`d7-concurrency-other-product-${marker.slice(-10)}`)}, 'Development-only D7 concurrency other product.', 'active', 'approved', 110, 10, 20, ${q(ids.otherSupplierProfile)});

insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, returned_stock_quantity, variant_status)
values
  (${q(ids.variant)}, ${q(ids.product)}, 'D7-CONC-A', 'Default', 40, 4, 2, 0, 'active'),
  (${q(ids.otherVariant)}, ${q(ids.otherProduct)}, 'D7-CONC-B', 'Default', 40, 4, 2, 0, 'active');

insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
values
  (${q(ids.listing)}, ${q(ids.reseller)}, ${q(ids.shop)}, ${q(ids.product)}, ${q(ids.variant)}, 'active', 15, 125, 'd7-conc-listing-a'),
  (${q(ids.otherListing)}, ${q(ids.reseller)}, ${q(ids.shop)}, ${q(ids.otherProduct)}, ${q(ids.otherVariant)}, 'active', 15, 135, 'd7-conc-listing-b');

insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, total_payable_amount, currency_code)
values
    ${orderRows};

insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
values
    ${itemRows};

insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, affected_order_item_id, dispute_category, reason_code, description, requested_outcome, status, return_review_required)
values
    ${disputeRows};

${returnRows ? `insert into public.order_item_returns(id, dispute_id, order_id, order_item_id, customer_profile_id, supplier_id, requested_quantity, approved_quantity, requested_method, approved_method, status, received_at, inspection_condition, inventory_outcome, inspected_at)\nvalues\n    ${returnRows};` : ""}
`;
}

function setContextSql(clerkUserId) {
  return `
perform set_config('request.jwt.claims', jsonb_build_object('sub', ${q(clerkUserId)}, 'role', 'authenticated')::text, true);
set local role authenticated;
`;
}

function actorSql(actorLabel, scenarioName, clerkUserId, bodySql) {
  return `
do $$
declare
  v_started_at timestamptz := clock_timestamp();
  v_finished_at timestamptz;
  v_count integer := 0;
  v_code text := 'ok';
begin
  ${setContextSql(clerkUserId)}
  perform pg_sleep(0.25);
  begin
    ${bodySql}
    get diagnostics v_count = row_count;
  exception when others then
    v_code := sqlstate || ':' || sqlerrm;
  end;
  v_finished_at := clock_timestamp();
  perform public.__dev_d7_concurrency_record(${q(marker)}, ${q(scenarioName)}, ${q(actorLabel)}, v_code = 'ok', v_code, v_count, pg_backend_pid(), v_started_at, v_finished_at);
end;
$$;`;
}

function resultPairOkSql(scenarioName) {
  return `
  and (select count(distinct backend_pid) from public.__dev_d7_concurrency_results where marker = ${q(marker)} and scenario = ${q(scenarioName)}) = 2
  and (select count(*) from public.__dev_d7_concurrency_results where marker = ${q(marker)} and scenario = ${q(scenarioName)}) = 2
`;
}

async function runRace(name, actorA, actorB, verifySql) {
  await Promise.all([
    runSupabaseSql(`${name}_a`, actorA, { quiet: true }),
    runSupabaseSql(`${name}_b`, actorB, { quiet: true }),
  ]);
  await runSupabaseSql(
    `${name}_verify`,
    `
do $$
begin
  if not (${verifySql}) then
    raise exception 'D7 concurrency scenario failed: ${name}';
  end if;
end;
$$;`,
    { quiet: true },
  );
  console.log(`PASS ${name}`);
}

function cleanupSql() {
  return `
delete from public.__dev_d7_concurrency_results where marker = ${q(marker)};
delete from public.__dev_d7_concurrency_counts where marker = ${q(marker)};
delete from public.return_actions where result_return_id in (select id from public.order_item_returns where dispute_id in (${scenarioIds()}));
delete from public.audit_logs where target_entity_id in (${returnIds() || "null::uuid"}) or target_entity_id in (${scenarioIds()});
delete from public.order_item_returns where dispute_id in (${scenarioIds()});
delete from public.dispute_status_history where dispute_id in (${scenarioIds()});
delete from public.order_disputes where id in (${scenarioIds()});
delete from public.order_items where id in (${itemIds()});
delete from public.orders where id in (${orderIds()});
delete from public.reseller_products where id in (${q(ids.listing)}::uuid, ${q(ids.otherListing)}::uuid);
delete from public.product_variants where id in (${q(ids.variant)}::uuid, ${q(ids.otherVariant)}::uuid);
delete from public.products where id in (${q(ids.product)}::uuid, ${q(ids.otherProduct)}::uuid);
delete from public.reseller_shops where id = ${q(ids.shop)}::uuid;
delete from public.resellers where id = ${q(ids.reseller)}::uuid;
delete from public.suppliers where id in (${q(ids.supplier)}::uuid, ${q(ids.otherSupplier)}::uuid);
delete from public.admin_staff where profile_id in (${q(ids.supportProfile)}::uuid, ${q(ids.adminProfile)}::uuid);
delete from public.customers where id = ${q(ids.customer)}::uuid;
delete from public.profiles where id in (${profileIds()});

do $$
begin
  if exists (select 1 from public.order_item_returns where dispute_id in (${scenarioIds()})) then
    raise exception 'D7 cleanup left return rows';
  end if;
end;
$$;`;
}

try {
  await runSupabaseSql("setup", setupSql(), { quiet: true });

  const a = scenarioByName("a_same_key_request");
  await runRace(
    a.name,
    actorSql("customer_a", a.name, clerk.customer, `perform * from public.customer_request_item_return(${q(a.disputeId)}::uuid, 1, 'customer_returns_to_supplier', 'Safe concurrent note.', 'd7-conc-same-key');`),
    actorSql("customer_b", a.name, clerk.customer, `perform * from public.customer_request_item_return(${q(a.disputeId)}::uuid, 1, 'customer_returns_to_supplier', 'Safe concurrent note.', 'd7-conc-same-key');`),
    `(select count(*) from public.order_item_returns where dispute_id = ${q(a.disputeId)}::uuid) = 1
      and (select count(*) from public.return_actions where dispute_id = ${q(a.disputeId)}::uuid and action_type = 'customer_request') = 1
      ${resultPairOkSql(a.name)}`,
  );

  const b = scenarioByName("b_duplicate_active_request");
  await runRace(
    b.name,
    actorSql("customer_a", b.name, clerk.customer, `perform * from public.customer_request_item_return(${q(b.disputeId)}::uuid, 1, 'customer_returns_to_supplier', 'Safe concurrent note A.', 'd7-conc-dupe-a');`),
    actorSql("customer_b", b.name, clerk.customer, `perform * from public.customer_request_item_return(${q(b.disputeId)}::uuid, 1, 'external_courier', 'Safe concurrent note B.', 'd7-conc-dupe-b');`),
    `(select count(*) from public.order_item_returns where dispute_id = ${q(b.disputeId)}::uuid) = 1
      and (select count(*) from public.return_actions where dispute_id = ${q(b.disputeId)}::uuid and action_type = 'customer_request') = 2
      ${resultPairOkSql(b.name)}`,
  );

  const c = scenarioByName("c_approve_vs_reject");
  await runRace(
    c.name,
    actorSql("approve", c.name, clerk.support, `perform * from public.admin_approve_return(${q(c.returnId)}::uuid, 1, 'customer_returns_to_supplier', 'customer', 'Approved safely.', null, 'd7-conc-approve');`),
    actorSql("reject", c.name, clerk.admin, `perform * from public.admin_reject_return(${q(c.returnId)}::uuid, 'Rejected safely.', null, 'd7-conc-reject');`),
    `(select status in ('approved', 'rejected') from public.order_item_returns where id = ${q(c.returnId)}::uuid)
      and (select count(*) from public.return_actions where return_id = ${q(c.returnId)}::uuid and action_type in ('admin_approve', 'admin_reject')) = 1
      ${resultPairOkSql(c.name)}`,
  );

  const d = scenarioByName("d_transit_vs_reject");
  await runRace(
    d.name,
    actorSql("transit", d.name, clerk.customer, `perform * from public.customer_mark_return_in_transit(${q(d.returnId)}::uuid, 'Sent safely.', 'd7-conc-transit');`),
    actorSql("reject", d.name, clerk.admin, `perform * from public.admin_reject_return(${q(d.returnId)}::uuid, 'Late reject.', null, 'd7-conc-late-reject');`),
    `(select status = 'in_transit' from public.order_item_returns where id = ${q(d.returnId)}::uuid)
      and (select count(*) from public.return_actions where return_id = ${q(d.returnId)}::uuid and action_type = 'customer_in_transit') = 1
      ${resultPairOkSql(d.name)}`,
  );

  const e = scenarioByName("e_received_vs_reject");
  await runRace(
    e.name,
    actorSql("receive", e.name, clerk.supplier, `perform * from public.supplier_confirm_return_received(${q(e.returnId)}::uuid, 'Received safely.', 'd7-conc-receive');`),
    actorSql("reject", e.name, clerk.admin, `perform * from public.admin_reject_return(${q(e.returnId)}::uuid, 'Late reject.', null, 'd7-conc-reject-received');`),
    `(select status = 'received' from public.order_item_returns where id = ${q(e.returnId)}::uuid)
      and (select count(*) from public.return_actions where return_id = ${q(e.returnId)}::uuid and action_type = 'supplier_received') = 1
      ${resultPairOkSql(e.name)}`,
  );

  const f = scenarioByName("f_two_supplier_receipts");
  await runRace(
    f.name,
    actorSql("own_supplier", f.name, clerk.supplier, `perform * from public.supplier_confirm_return_received(${q(f.returnId)}::uuid, 'Received by owner.', 'd7-conc-own-receive');`),
    actorSql("other_supplier", f.name, clerk.otherSupplier, `perform * from public.supplier_confirm_return_received(${q(f.returnId)}::uuid, 'Wrong supplier.', 'd7-conc-other-receive');`),
    `(select status = 'received' from public.order_item_returns where id = ${q(f.returnId)}::uuid)
      and (select count(*) from public.return_actions where return_id = ${q(f.returnId)}::uuid and action_type = 'supplier_received') = 1
      ${resultPairOkSql(f.name)}`,
  );

  const g = scenarioByName("g_two_condition_reports");
  await runRace(
    g.name,
    actorSql("condition_a", g.name, clerk.supplier, `perform * from public.supplier_report_return_condition(${q(g.returnId)}::uuid, 'damaged', 'damaged_stock_review_required', 'Condition A.', 'd7-conc-condition-a');`),
    actorSql("condition_b", g.name, clerk.supplier, `perform * from public.supplier_report_return_condition(${q(g.returnId)}::uuid, 'defective', 'quarantine_review_required', 'Condition B.', 'd7-conc-condition-b');`),
    `(select status = 'inspected' from public.order_item_returns where id = ${q(g.returnId)}::uuid)
      and (select count(*) from public.return_actions where return_id = ${q(g.returnId)}::uuid and action_type = 'supplier_condition') = 1
      ${resultPairOkSql(g.name)}`,
  );

  const h = scenarioByName("h_accept_vs_decline");
  await runRace(
    h.name,
    actorSql("accept", h.name, clerk.support, `perform * from public.admin_accept_return(${q(h.returnId)}::uuid, 'Accepted safely.', null, 'd7-conc-accept');`),
    actorSql("decline", h.name, clerk.admin, `perform * from public.admin_decline_return(${q(h.returnId)}::uuid, 'Declined safely.', null, 'd7-conc-decline');`),
    `(select status in ('accepted', 'declined') from public.order_item_returns where id = ${q(h.returnId)}::uuid)
      and (select count(*) from public.return_actions where return_id = ${q(h.returnId)}::uuid and action_type in ('admin_accept', 'admin_decline')) = 1
      ${resultPairOkSql(h.name)}`,
  );

  const i = scenarioByName("i_complete_vs_condition");
  await runRace(
    i.name,
    actorSql("condition", i.name, clerk.supplier, `perform * from public.supplier_report_return_condition(${q(i.returnId)}::uuid, 'damaged', 'damaged_stock_review_required', 'Condition safely.', 'd7-conc-condition-complete');`),
    actorSql("complete", i.name, clerk.admin, `perform * from public.admin_complete_return(${q(i.returnId)}::uuid, 'Complete safely.', null, 'd7-conc-complete-early');`),
    `(select status = 'inspected' from public.order_item_returns where id = ${q(i.returnId)}::uuid)
      and (select count(*) from public.return_actions where return_id = ${q(i.returnId)}::uuid and action_type = 'supplier_condition') = 1
      ${resultPairOkSql(i.name)}`,
  );

  const j = scenarioByName("j_request_vs_dispute_closure");
  await runRace(
    j.name,
    actorSql("request", j.name, clerk.customer, `perform * from public.customer_request_item_return(${q(j.disputeId)}::uuid, 1, 'customer_returns_to_supplier', 'Safe request.', 'd7-conc-request-close');`),
    actorSql("close", j.name, clerk.admin, `perform * from public.admin_close_dispute(${q(j.disputeId)}::uuid, null, null, 'd7-conc-close-too-early');`),
    `(select count(*) from public.order_item_returns where dispute_id = ${q(j.disputeId)}::uuid) = 1
      and (select status <> 'closed' from public.order_disputes where id = ${q(j.disputeId)}::uuid)
      ${resultPairOkSql(j.name)}`,
  );

  const k = scenarioByName("k_accept_vs_refund_review");
  await runRace(
    k.name,
    actorSql("accept", k.name, clerk.support, `perform * from public.admin_accept_return(${q(k.returnId)}::uuid, 'Accepted safely.', null, 'd7-conc-accept-refund-race');`),
    actorSql("refund_review", k.name, clerk.admin, `perform * from public.admin_change_dispute_status(${q(k.disputeId)}::uuid, 'refund_review', null, null, 'd7-conc-refund-review');`),
    `(select status = 'accepted' from public.order_item_returns where id = ${q(k.returnId)}::uuid)
      and (select count(*) from public.return_actions where return_id = ${q(k.returnId)}::uuid and action_type = 'admin_accept') = 1
      ${resultPairOkSql(k.name)}`,
  );

  await runSupabaseSql(
    "side_effect_verify",
    `
do $$
begin
  if not (
    (select count(*) from public.orders) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'orders') + 11
    and (select count(*) from public.order_items) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'order_items') + 11
    and (select count(*) from public.stock_reservations) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'stock_reservations')
    and (select count(*) from public.inventory_movements) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'inventory_movements')
    and (select count(*) from public.delivery_arrangements) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'delivery_arrangements')
    and (select count(*) from public.supplier_payment_reports) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'supplier_payment_reports')
    and (select count(*) from public.settlements) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'settlements')
    and (select count(*) from public.commissions) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'commissions')
    and (select count(*) from public.withdrawals) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'withdrawals')
    and (select count(*) from public.returns) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'returns')
    and (select count(*) from public.notification_outbox) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'notification_outbox')
    and (select count(*) from public.notification_provider_events) = (select row_count from public.__dev_d7_concurrency_counts where marker = ${q(marker)} and table_name = 'notification_provider_events')
  ) then
    raise exception 'D7 side-effect invariant failed';
  end if;
end;
$$;`,
    { quiet: true },
  );

  console.log("PASS side_effect_invariants");
} finally {
  try {
    await runSupabaseSql("cleanup", cleanupSql(), { quiet: true });
    console.log("PASS cleanup");
  } finally {
    await rm(tmpRoot, { recursive: true, force: true });
  }
}
