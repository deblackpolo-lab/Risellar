#!/usr/bin/env node
/* global console, process */
// DEVELOPMENT ONLY. Runs true two-process D6 dispute RPC concurrency checks.
// Do not run against production. The runner prints only safe scenario summaries.

import { randomUUID } from "node:crypto";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";

const marker = `dev_d6_concurrency_${Date.now()}_${randomUUID().replaceAll("-", "").slice(0, 10)}`;
const tmpRoot = await mkdtemp(path.join(tmpdir(), "risellar-d6-concurrency-"));

const q = (value) => `'${String(value).replaceAll("'", "''")}'`;
const uuid = () => randomUUID();

const ids = {
  customerProfile: uuid(),
  supplierProfile: uuid(),
  otherSupplierProfile: uuid(),
  resellerProfile: uuid(),
  supportAProfile: uuid(),
  supportBProfile: uuid(),
  financeProfile: uuid(),
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
  ["a_same_key_assignment", "open"],
  ["b_competing_assignees", "open"],
  ["c_customer_request_response", "open"],
  ["d_supplier_request_response", "open"],
  ["e_competing_status", "under_review"],
  ["f_competing_resolutions", "under_review"],
  ["g_resolution_closure", "under_review"],
  ["h_closure_customer_response", "resolved_customer"],
  ["i_closure_supplier_response", "resolved_supplier"],
  ["j_same_key_information", "open"],
  ["k_different_key_information", "open"],
  ["l_same_key_resolution", "under_review"],
].map(([name, status], index) => ({
  name,
  status,
  orderId: uuid(),
  itemId: uuid(),
  disputeId: uuid(),
  orderNumber: `D6CONC-${index + 1}-${marker.slice(-8).toUpperCase()}`,
  reason: [
    "delivery_delay",
    "customer_paid_not_reported",
    "delivery_not_arranged",
    "supplier_reported_customer_disagrees",
    "wrong_item_received",
    "damaged_item_received",
    "incomplete_order",
    "item_not_as_described",
    "product_quality_issue",
    "return_requested",
    "refund_requested",
    "wrong_amount_collected",
  ][index],
  outcome: [
    "information_only",
    "redelivery",
    "replacement",
    "partial_refund",
    "full_refund",
    "return",
    "other",
    "delivery_fee_refund",
    "accounting_correction",
    "information_only",
    "redelivery",
    "replacement",
  ][index],
}));

const clerk = {
  customer: `${marker}_customer`,
  supplier: `${marker}_supplier`,
  otherSupplier: `${marker}_other_supplier`,
  supportA: `${marker}_support_a`,
  supportB: `${marker}_support_b`,
};

const idList = (items) => items.map((item) => `${q(item)}::uuid`).join(", ");
const disputeIds = () => idList(scenarios.map((scenario) => scenario.disputeId));
const orderIds = () => idList(scenarios.map((scenario) => scenario.orderId));
const itemIds = () => idList(scenarios.map((scenario) => scenario.itemId));
const profileIds = () =>
  idList([
    ids.customerProfile,
    ids.supplierProfile,
    ids.otherSupplierProfile,
    ids.resellerProfile,
    ids.supportAProfile,
    ids.supportBProfile,
    ids.financeProfile,
  ]);

async function runSupabaseSql(name, sql, options = {}) {
  const filePath = path.join(tmpRoot, `${name}.sql`);
  await writeFile(filePath, sql, "utf8");

  return await new Promise((resolve, reject) => {
    const child = spawn("npx", ["supabase", "db", "query", "--linked", "--file", filePath], {
      cwd: process.cwd(),
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
        if (!options.quiet) {
          process.stdout.write(stdout);
        }
        resolve({ stdout, stderr });
      } else {
        const safeError = stderr || stdout || `supabase db query exited with ${code}`;
        reject(new Error(`${name} failed: ${safeError}`));
      }
    });
  });
}

function setupSql() {
  return `
create table if not exists public.__dev_d6_concurrency_results (
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

alter table public.__dev_d6_concurrency_results
  add column if not exists backend_pid integer not null default pg_backend_pid(),
  add column if not exists call_started_at timestamptz not null default clock_timestamp(),
  add column if not exists call_finished_at timestamptz not null default clock_timestamp();

create table if not exists public.__dev_d6_concurrency_counts (
  marker text not null,
  table_name text not null,
  row_count bigint not null,
  primary key (marker, table_name)
);

grant select, insert, update, delete on public.__dev_d6_concurrency_results to authenticated;

drop function if exists public.__dev_d6_concurrency_record(text, text, text, boolean, text, integer);

create or replace function public.__dev_d6_concurrency_record(
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
  insert into public.__dev_d6_concurrency_results(marker, scenario, actor_label, ok, result_code, row_count, backend_pid, call_started_at, call_finished_at)
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

revoke all on function public.__dev_d6_concurrency_record(text, text, text, boolean, text, integer, integer, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.__dev_d6_concurrency_record(text, text, text, boolean, text, integer, integer, timestamptz, timestamptz) to authenticated;

insert into public.__dev_d6_concurrency_counts(marker, table_name, row_count)
values
  (${q(marker)}, 'orders', (select count(*) from public.orders)),
  (${q(marker)}, 'order_items', (select count(*) from public.order_items)),
  (${q(marker)}, 'stock_reservations', (select count(*) from public.stock_reservations)),
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
  (${q(ids.customerProfile)}, ${q(clerk.customer)}, 'd6-concurrency-customer@example.test', 'D6 Concurrency Customer', 'customer', 'active'),
  (${q(ids.supplierProfile)}, ${q(clerk.supplier)}, 'd6-concurrency-supplier@example.test', 'D6 Concurrency Supplier', 'supplier_owner', 'active'),
  (${q(ids.otherSupplierProfile)}, ${q(clerk.otherSupplier)}, 'd6-concurrency-other-supplier@example.test', 'D6 Concurrency Other Supplier', 'supplier_owner', 'active'),
  (${q(ids.resellerProfile)}, ${q(`${marker}_reseller`)}, 'd6-concurrency-reseller@example.test', 'D6 Concurrency Reseller', 'reseller', 'active'),
  (${q(ids.supportAProfile)}, ${q(clerk.supportA)}, 'd6-concurrency-support-a@example.test', 'D6 Concurrency Support A', 'customer', 'active'),
  (${q(ids.supportBProfile)}, ${q(clerk.supportB)}, 'd6-concurrency-support-b@example.test', 'D6 Concurrency Support B', 'customer', 'active'),
  (${q(ids.financeProfile)}, ${q(`${marker}_finance`)}, 'd6-concurrency-finance@example.test', 'D6 Concurrency Finance', 'customer', 'active');

insert into public.customers(id, profile_id, customer_status)
values (${q(ids.customer)}, ${q(ids.customerProfile)}, 'active');

insert into public.admin_staff(id, profile_id, admin_role, staff_status)
values
  (gen_random_uuid(), ${q(ids.supportAProfile)}, 'support_staff', 'active'),
  (gen_random_uuid(), ${q(ids.supportBProfile)}, 'support_staff', 'active'),
  (gen_random_uuid(), ${q(ids.financeProfile)}, 'finance_staff', 'active');

insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
values
  (${q(ids.supplier)}, ${q(ids.supplierProfile)}, 'D6 Concurrency Supplier', 'active', 'approved', 'D6 Concurrency Supplier'),
  (${q(ids.otherSupplier)}, ${q(ids.otherSupplierProfile)}, 'D6 Concurrency Other Supplier', 'active', 'approved', 'D6 Concurrency Other Supplier');

insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
values (${q(ids.reseller)}, ${q(ids.resellerProfile)}, 'qa', 'approved', 'active');

insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status)
values (${q(ids.shop)}, ${q(ids.reseller)}, ${q(`d6-concurrency-${marker.slice(-10)}`)}, 'D6 Concurrency Shop', 'active');

insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, created_by_profile_id)
values
  (${q(ids.product)}, ${q(ids.supplier)}, 'QA', 'D6 Concurrency Product', ${q(`d6-concurrency-product-${marker.slice(-10)}`)}, 'Development-only D6 concurrency product.', 'active', 'approved', 100, 10, 20, ${q(ids.supplierProfile)}),
  (${q(ids.otherProduct)}, ${q(ids.otherSupplier)}, 'QA', 'D6 Concurrency Other Product', ${q(`d6-concurrency-other-product-${marker.slice(-10)}`)}, 'Development-only D6 concurrency other product.', 'active', 'approved', 110, 10, 20, ${q(ids.otherSupplierProfile)});

insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
values
  (${q(ids.variant)}, ${q(ids.product)}, ${q(`D6C-${marker.slice(-8).toUpperCase()}`)}, 'Default', 10, 0, 0, 'active'),
  (${q(ids.otherVariant)}, ${q(ids.otherProduct)}, ${q(`D6CO-${marker.slice(-8).toUpperCase()}`)}, 'Default', 10, 0, 0, 'active');

insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
values
  (${q(ids.listing)}, ${q(ids.reseller)}, ${q(ids.shop)}, ${q(ids.product)}, ${q(ids.variant)}, 'active', 15, 125, ${q(`d6-concurrency-listing-${marker.slice(-10)}`)}),
  (${q(ids.otherListing)}, ${q(ids.reseller)}, ${q(ids.shop)}, ${q(ids.otherProduct)}, ${q(ids.otherVariant)}, 'active', 15, 135, ${q(`d6-concurrency-other-listing-${marker.slice(-10)}`)});

insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, total_payable_amount, currency_code)
values
${scenarios
  .map(
    (scenario) =>
      `  (${q(scenario.orderId)}, ${q(scenario.orderNumber)}, ${q(ids.customer)}, ${q(ids.reseller)}, ${q(ids.shop)}, 'delivered', 'not_collected', 'delivered', 125, 125, 'GHS')`,
  )
  .join(",\n")};

insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
values
${scenarios
  .map((scenario) => {
    const useOther = scenario.name === "i_closure_supplier_response";
    return `  (${q(scenario.itemId)}, ${q(scenario.orderId)}, ${q(useOther ? ids.otherSupplier : ids.supplier)}, ${q(useOther ? ids.otherProduct : ids.product)}, ${q(useOther ? ids.otherVariant : ids.variant)}, ${q(useOther ? ids.otherListing : ids.listing)}, 1, 100, 10, 15, 110, 125, 125, 100, 15)`;
  })
  .join(",\n")};

insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, dispute_category, reason_code, description, requested_outcome, status, customer_action_required, supplier_action_required, resolution_code, resolved_at)
values
${scenarios
  .map((scenario) => {
    const supplierId = scenario.name === "i_closure_supplier_response" ? ids.otherSupplier : ids.supplier;
    const resolution =
      scenario.status === "resolved_customer"
        ? "'customer_favoured', now()"
        : scenario.status === "resolved_supplier"
          ? "'supplier_favoured', now()"
          : "null, null";
    return `  (${q(scenario.disputeId)}, ${q(scenario.orderId)}, ${q(ids.customerProfile)}, 'customer', 'supplier', ${q(supplierId)}, 'delivery', ${q(scenario.reason)}, 'Development-only D6 concurrency fixture.', ${q(scenario.outcome)}, ${q(scenario.status)}, false, false, ${resolution})`;
  })
  .join(",\n")};
`;
}

function sessionSql({ scenario, actorLabel, clerkUserId, callSql }) {
  return `
begin;
select set_config('request.jwt.claims', jsonb_build_object('sub', ${q(clerkUserId)}, 'role', 'authenticated')::text, true);
set local role authenticated;

do $run$
declare
  v_rows integer := 0;
  v_backend_pid integer := pg_backend_pid();
  v_call_started_at timestamptz;
  v_call_finished_at timestamptz;
begin
  perform pg_sleep(5);
  v_call_started_at := clock_timestamp();
  begin
    execute ${q(`select count(*) from (with d6_concurrency_call as (${callSql}), d6_concurrency_wait as (select pg_sleep(2)) select * from d6_concurrency_call, d6_concurrency_wait) as d6_concurrency_count`)} into v_rows;
    v_call_finished_at := clock_timestamp();
    perform public.__dev_d6_concurrency_record(${q(marker)}, ${q(scenario.name)}, ${q(actorLabel)}, true, 'OK', v_rows, v_backend_pid, v_call_started_at, v_call_finished_at);
  exception when others then
    v_call_finished_at := clock_timestamp();
    perform public.__dev_d6_concurrency_record(${q(marker)}, ${q(scenario.name)}, ${q(actorLabel)}, false, sqlstate, 0, v_backend_pid, v_call_started_at, v_call_finished_at);
  end;
end;
$run$;

commit;
`;
}

function assertSql(label, conditionSql) {
  return `
do $assert$
begin
  if not (${conditionSql}) then
    raise exception ${q(`D6_CONCURRENCY_ASSERT_FAILED: ${label}`)};
  end if;
end;
$assert$;`;
}

function resultCount(scenario, okPredicate) {
  return `(select count(*) from public.__dev_d6_concurrency_results where marker = ${q(marker)} and scenario = ${q(scenario.name)} and ${okPredicate})`;
}

function verifySql(scenario, assertions) {
  const sessionAssertions = [
    assertSql(
      `${scenario.name} used independent sessions`,
      `(select count(distinct backend_pid) from public.__dev_d6_concurrency_results where marker = ${q(marker)} and scenario = ${q(scenario.name)}) = 2`,
    ),
    assertSql(
      `${scenario.name} call windows overlapped`,
      `(select max(call_started_at) <= min(call_finished_at) from public.__dev_d6_concurrency_results where marker = ${q(marker)} and scenario = ${q(scenario.name)})`,
    ),
  ];
  return sessionAssertions.concat(assertions).join("\n") + `\nselect ${q(scenario.name)} as scenario, 'passed' as result;\n`;
}

function cleanupSql({ dropTables = true } = {}) {
  return `
delete from public.audit_logs
where actor_profile_id in (${profileIds()})
   or target_entity_id in (${disputeIds()})
   or target_entity_id in (
     select dm.id
     from public.dispute_messages dm
     where dm.dispute_id in (${disputeIds()})
   );
delete from public.dispute_admin_actions where dispute_id in (${disputeIds()});
delete from public.dispute_status_history where dispute_id in (${disputeIds()});
delete from public.dispute_messages where dispute_id in (${disputeIds()});
delete from public.order_disputes where id in (${disputeIds()});
delete from public.order_items where id in (${itemIds()});
delete from public.orders where id in (${orderIds()});
delete from public.reseller_products where id in (${q(ids.listing)}::uuid, ${q(ids.otherListing)}::uuid);
delete from public.product_variants where id in (${q(ids.variant)}::uuid, ${q(ids.otherVariant)}::uuid);
delete from public.products where id in (${q(ids.product)}::uuid, ${q(ids.otherProduct)}::uuid);
delete from public.reseller_shops where id = ${q(ids.shop)}::uuid;
delete from public.resellers where id = ${q(ids.reseller)}::uuid;
delete from public.suppliers where id in (${q(ids.supplier)}::uuid, ${q(ids.otherSupplier)}::uuid);
delete from public.admin_staff where profile_id in (${profileIds()});
delete from public.customers where id = ${q(ids.customer)}::uuid;
delete from public.profiles where id in (${profileIds()});

do $business$
begin
  if exists (
    select 1
    from public.__dev_d6_concurrency_counts c
    where c.marker = ${q(marker)}
      and (
        (c.table_name = 'orders' and c.row_count <> (select count(*) from public.orders))
        or (c.table_name = 'order_items' and c.row_count <> (select count(*) from public.order_items))
        or (c.table_name = 'stock_reservations' and c.row_count <> (select count(*) from public.stock_reservations))
        or (c.table_name = 'delivery_arrangements' and c.row_count <> (select count(*) from public.delivery_arrangements))
        or (c.table_name = 'supplier_payment_reports' and c.row_count <> (select count(*) from public.supplier_payment_reports))
        or (c.table_name = 'settlements' and c.row_count <> (select count(*) from public.settlements))
        or (c.table_name = 'commissions' and c.row_count <> (select count(*) from public.commissions))
        or (c.table_name = 'withdrawals' and c.row_count <> (select count(*) from public.withdrawals))
        or (c.table_name = 'returns' and c.row_count <> (select count(*) from public.returns))
        or (c.table_name = 'notification_outbox' and c.row_count <> (select count(*) from public.notification_outbox))
        or (c.table_name = 'notification_provider_events' and c.row_count <> (select count(*) from public.notification_provider_events))
      )
  ) then
    raise exception 'D6_CONCURRENCY_BUSINESS_COUNTS_CHANGED';
  end if;
end;
$business$;

delete from public.__dev_d6_concurrency_counts where marker = ${q(marker)};
delete from public.__dev_d6_concurrency_results where marker = ${q(marker)};
drop function if exists public.__dev_d6_concurrency_record(text, text, text, boolean, text, integer, integer, timestamptz, timestamptz);
${dropTables ? "drop table if exists public.__dev_d6_concurrency_counts; drop table if exists public.__dev_d6_concurrency_results; drop table if exists public.__dev_d6_concurrency_barriers;" : ""}
select 'cleanup' as scenario, 'passed' as result;
`;
}

const byName = Object.fromEntries(scenarios.map((scenario) => [scenario.name, scenario]));

const raceDefinitions = [
  {
    scenario: byName.a_same_key_assignment,
    a: { actorLabel: "admin_session_a", clerkUserId: clerk.supportA, callSql: `select * from public.admin_assign_dispute('${byName.a_same_key_assignment.disputeId}'::uuid, '${ids.supportBProfile}'::uuid, 'd6-conc-assign-same')` },
    b: { actorLabel: "admin_session_b", clerkUserId: clerk.supportA, callSql: `select * from public.admin_assign_dispute('${byName.a_same_key_assignment.disputeId}'::uuid, '${ids.supportBProfile}'::uuid, 'd6-conc-assign-same')` },
    assertions: (s) => [
      assertSql(`${s.name} both calls compatible`, `${resultCount(s, "ok = true and row_count = 1")} = 2`),
      assertSql(`${s.name} one admin action`, `(select count(*) from public.dispute_admin_actions where dispute_id = '${s.disputeId}'::uuid and action_type = 'assign') = 1`),
      assertSql(`${s.name} one assignment audit`, `(select count(*) from public.audit_logs where target_entity_id = '${s.disputeId}'::uuid and action = 'dispute_assigned') = 1`),
      assertSql(`${s.name} final assigned`, `(select assigned_admin_profile_id is not null from public.order_disputes where id = '${s.disputeId}'::uuid)`),
    ],
  },
  {
    scenario: byName.b_competing_assignees,
    a: { actorLabel: "admin_session_a", clerkUserId: clerk.supportA, callSql: `select * from public.admin_assign_dispute('${byName.b_competing_assignees.disputeId}'::uuid, '${ids.supportAProfile}'::uuid, 'd6-conc-assign-a')` },
    b: { actorLabel: "admin_session_b", clerkUserId: clerk.supportB, callSql: `select * from public.admin_assign_dispute('${byName.b_competing_assignees.disputeId}'::uuid, '${ids.supportBProfile}'::uuid, 'd6-conc-assign-b')` },
    assertions: (s) => [
      assertSql(`${s.name} both assignments serialized`, `${resultCount(s, "ok = true and row_count = 1")} = 2`),
      assertSql(`${s.name} two audited assignment actions`, `(select count(*) from public.dispute_admin_actions where dispute_id = '${s.disputeId}'::uuid and action_type = 'assign') = 2`),
      assertSql(`${s.name} final assignee authorized`, `(select assigned_admin_profile_id in ('${ids.supportAProfile}'::uuid, '${ids.supportBProfile}'::uuid) from public.order_disputes where id = '${s.disputeId}'::uuid)`),
    ],
  },
  {
    scenario: byName.c_customer_request_response,
    a: { actorLabel: "admin_session", clerkUserId: clerk.supportA, callSql: `select * from public.admin_request_dispute_information('${byName.c_customer_request_response.disputeId}'::uuid, 'customer', 'Please add safe customer details.', 'Safe internal note.', 'd6-conc-cust-info')` },
    b: { actorLabel: "customer_session", clerkUserId: clerk.customer, callSql: `select * from public.customer_add_dispute_response('${byName.c_customer_request_response.disputeId}'::uuid, 'Safe customer response for review.', 'd6-conc-cust-response')` },
    assertions: (s) => [
      assertSql(`${s.name} both calls completed`, `${resultCount(s, "ok = true and row_count = 1")} = 2`),
      assertSql(`${s.name} messages preserved`, `(select count(*) from public.dispute_messages where dispute_id = '${s.disputeId}'::uuid and message_type = 'admin_request') = 1 and (select count(*) from public.dispute_messages where dispute_id = '${s.disputeId}'::uuid and author_role = 'customer') = 1`),
      assertSql(`${s.name} final flags consistent`, `(select (status = 'awaiting_customer' and customer_action_required = true and supplier_action_required = false) or (status = 'under_review' and customer_action_required = false and supplier_action_required = false) from public.order_disputes where id = '${s.disputeId}'::uuid)`),
    ],
  },
  {
    scenario: byName.d_supplier_request_response,
    a: { actorLabel: "admin_session", clerkUserId: clerk.supportA, callSql: `select * from public.admin_request_dispute_information('${byName.d_supplier_request_response.disputeId}'::uuid, 'supplier', 'Please add safe supplier details.', 'Safe internal note.', 'd6-conc-sup-info')` },
    b: { actorLabel: "supplier_session", clerkUserId: clerk.supplier, callSql: `select * from public.supplier_add_dispute_response('${byName.d_supplier_request_response.disputeId}'::uuid, 'Safe supplier response for review.', 'd6-conc-sup-response')` },
    assertions: (s) => [
      assertSql(`${s.name} both calls completed`, `${resultCount(s, "ok = true and row_count = 1")} = 2`),
      assertSql(`${s.name} messages preserved`, `(select count(*) from public.dispute_messages where dispute_id = '${s.disputeId}'::uuid and message_type = 'admin_request') = 1 and (select count(*) from public.dispute_messages where dispute_id = '${s.disputeId}'::uuid and author_role = 'supplier') = 1`),
      assertSql(`${s.name} final flags consistent`, `(select (status = 'awaiting_supplier' and supplier_action_required = true and customer_action_required = false) or (status = 'under_review' and supplier_action_required = false and customer_action_required = false) from public.order_disputes where id = '${s.disputeId}'::uuid)`),
    ],
  },
  {
    scenario: byName.e_competing_status,
    a: { actorLabel: "admin_session_a", clerkUserId: clerk.supportA, callSql: `select * from public.admin_change_dispute_status('${byName.e_competing_status.disputeId}'::uuid, 'return_review', 'Safe return review note.', null, 'd6-conc-status-return')` },
    b: { actorLabel: "admin_session_b", clerkUserId: clerk.supportB, callSql: `select * from public.admin_change_dispute_status('${byName.e_competing_status.disputeId}'::uuid, 'refund_review', 'Safe refund review note.', null, 'd6-conc-status-refund')` },
    assertions: (s) => [
      assertSql(`${s.name} one status wins`, `${resultCount(s, "ok = true and row_count = 1")} = 1 and ${resultCount(s, "ok = false")} = 1`),
      assertSql(`${s.name} one history`, `(select count(*) from public.dispute_status_history where dispute_id = '${s.disputeId}'::uuid and reason_code in ('return_review', 'refund_review')) = 1`),
      assertSql(`${s.name} final status winner`, `(select status in ('return_review', 'refund_review') and customer_action_required = false and supplier_action_required = false from public.order_disputes where id = '${s.disputeId}'::uuid)`),
    ],
  },
  {
    scenario: byName.f_competing_resolutions,
    a: { actorLabel: "admin_session_a", clerkUserId: clerk.supportA, callSql: `select * from public.admin_record_non_financial_resolution('${byName.f_competing_resolutions.disputeId}'::uuid, 'customer_favoured', 'Safe customer favoured resolution.', null, 'd6-conc-resolution-customer')` },
    b: { actorLabel: "admin_session_b", clerkUserId: clerk.supportB, callSql: `select * from public.admin_record_non_financial_resolution('${byName.f_competing_resolutions.disputeId}'::uuid, 'supplier_favoured', 'Safe supplier favoured resolution.', null, 'd6-conc-resolution-supplier')` },
    assertions: (s) => [
      assertSql(`${s.name} one resolution wins`, `${resultCount(s, "ok = true and row_count = 1")} = 1 and ${resultCount(s, "ok = false")} = 1`),
      assertSql(`${s.name} one resolution action`, `(select count(*) from public.dispute_admin_actions where dispute_id = '${s.disputeId}'::uuid and action_type = 'record_resolution') = 1`),
      assertSql(`${s.name} status matches resolution`, `(select (resolution_code = 'customer_favoured' and status = 'resolved_customer') or (resolution_code = 'supplier_favoured' and status = 'resolved_supplier') from public.order_disputes where id = '${s.disputeId}'::uuid)`),
    ],
  },
  {
    scenario: byName.g_resolution_closure,
    a: { actorLabel: "resolution_session", clerkUserId: clerk.supportA, callSql: `select * from public.admin_record_non_financial_resolution('${byName.g_resolution_closure.disputeId}'::uuid, 'customer_favoured', 'Safe resolution before closure.', null, 'd6-conc-resolve-close')` },
    b: { actorLabel: "closure_session", clerkUserId: clerk.supportB, callSql: `select * from public.admin_close_dispute('${byName.g_resolution_closure.disputeId}'::uuid, 'Safe closure note.', null, 'd6-conc-close-after-resolve')` },
    assertions: (s) => [
      assertSql(`${s.name} resolution succeeds`, `${resultCount(s, "actor_label = 'resolution_session' and ok = true and row_count = 1")} = 1`),
      assertSql(`${s.name} no closed without resolution`, `(select resolution_code = 'customer_favoured' and status in ('resolved_customer', 'closed') and closed_at is null = (status <> 'closed') from public.order_disputes where id = '${s.disputeId}'::uuid)`),
      assertSql(`${s.name} closure not duplicated`, `(select count(*) from public.dispute_admin_actions where dispute_id = '${s.disputeId}'::uuid and action_type = 'close') <= 1`),
    ],
  },
  {
    scenario: byName.h_closure_customer_response,
    a: { actorLabel: "closure_session", clerkUserId: clerk.supportA, callSql: `select * from public.admin_close_dispute('${byName.h_closure_customer_response.disputeId}'::uuid, 'Safe customer closure note.', null, 'd6-conc-close-customer')` },
    b: { actorLabel: "customer_session", clerkUserId: clerk.customer, callSql: `select * from public.customer_add_dispute_response('${byName.h_closure_customer_response.disputeId}'::uuid, 'Safe customer late response.', 'd6-conc-late-customer')` },
    assertions: (s) => [
      assertSql(`${s.name} closure wins response blocked`, `${resultCount(s, "actor_label = 'closure_session' and ok = true and row_count = 1")} = 1 and ${resultCount(s, "actor_label = 'customer_session' and ok = false")} = 1`),
      assertSql(`${s.name} no late customer message`, `(select count(*) from public.dispute_messages where dispute_id = '${s.disputeId}'::uuid and author_role = 'customer') = 0`),
      assertSql(`${s.name} final closed`, `(select status = 'closed' and closed_at is not null from public.order_disputes where id = '${s.disputeId}'::uuid)`),
    ],
  },
  {
    scenario: byName.i_closure_supplier_response,
    a: { actorLabel: "closure_session", clerkUserId: clerk.supportA, callSql: `select * from public.admin_close_dispute('${byName.i_closure_supplier_response.disputeId}'::uuid, 'Safe supplier closure note.', null, 'd6-conc-close-supplier')` },
    b: { actorLabel: "supplier_session", clerkUserId: clerk.otherSupplier, callSql: `select * from public.supplier_add_dispute_response('${byName.i_closure_supplier_response.disputeId}'::uuid, 'Safe supplier late response.', 'd6-conc-late-supplier')` },
    assertions: (s) => [
      assertSql(`${s.name} closure wins response blocked`, `${resultCount(s, "actor_label = 'closure_session' and ok = true and row_count = 1")} = 1 and ${resultCount(s, "actor_label = 'supplier_session' and ok = false")} = 1`),
      assertSql(`${s.name} no late supplier message`, `(select count(*) from public.dispute_messages where dispute_id = '${s.disputeId}'::uuid and author_role = 'supplier') = 0`),
      assertSql(`${s.name} final closed`, `(select status = 'closed' and closed_at is not null from public.order_disputes where id = '${s.disputeId}'::uuid)`),
    ],
  },
  {
    scenario: byName.j_same_key_information,
    a: { actorLabel: "admin_session_a", clerkUserId: clerk.supportA, callSql: `select * from public.admin_request_dispute_information('${byName.j_same_key_information.disputeId}'::uuid, 'customer', 'Please add safe matching details.', 'Safe matching internal note.', 'd6-conc-info-same')` },
    b: { actorLabel: "admin_session_b", clerkUserId: clerk.supportA, callSql: `select * from public.admin_request_dispute_information('${byName.j_same_key_information.disputeId}'::uuid, 'customer', 'Please add safe matching details.', 'Safe matching internal note.', 'd6-conc-info-same')` },
    assertions: (s) => [
      assertSql(`${s.name} same key both compatible`, `${resultCount(s, "ok = true and row_count = 1")} = 2`),
      assertSql(`${s.name} one admin request message`, `(select count(*) from public.dispute_messages where dispute_id = '${s.disputeId}'::uuid and message_type = 'admin_request') = 1`),
      assertSql(`${s.name} one status history`, `(select count(*) from public.dispute_status_history where dispute_id = '${s.disputeId}'::uuid and reason_code = 'admin_request') = 1`),
    ],
  },
  {
    scenario: byName.k_different_key_information,
    a: { actorLabel: "customer_request_session", clerkUserId: clerk.supportA, callSql: `select * from public.admin_request_dispute_information('${byName.k_different_key_information.disputeId}'::uuid, 'customer', 'Please add safe customer details.', null, 'd6-conc-info-customer')` },
    b: { actorLabel: "supplier_request_session", clerkUserId: clerk.supportB, callSql: `select * from public.admin_request_dispute_information('${byName.k_different_key_information.disputeId}'::uuid, 'supplier', 'Please add safe supplier details.', null, 'd6-conc-info-supplier')` },
    assertions: (s) => [
      assertSql(`${s.name} both requests preserved`, `${resultCount(s, "ok = true and row_count = 1")} = 2`),
      assertSql(`${s.name} two request messages`, `(select count(*) from public.dispute_messages where dispute_id = '${s.disputeId}'::uuid and message_type = 'admin_request') = 2`),
      assertSql(`${s.name} final request flags consistent`, `(select (status = 'awaiting_customer' and customer_action_required = true and supplier_action_required = false) or (status = 'awaiting_supplier' and supplier_action_required = true and customer_action_required = false) from public.order_disputes where id = '${s.disputeId}'::uuid)`),
    ],
  },
  {
    scenario: byName.l_same_key_resolution,
    a: { actorLabel: "admin_session_a", clerkUserId: clerk.supportA, callSql: `select * from public.admin_record_non_financial_resolution('${byName.l_same_key_resolution.disputeId}'::uuid, 'customer_favoured', 'Safe matching resolution.', null, 'd6-conc-resolution-same')` },
    b: { actorLabel: "admin_session_b", clerkUserId: clerk.supportA, callSql: `select * from public.admin_record_non_financial_resolution('${byName.l_same_key_resolution.disputeId}'::uuid, 'customer_favoured', 'Safe matching resolution.', null, 'd6-conc-resolution-same')` },
    assertions: (s) => [
      assertSql(`${s.name} same key both compatible`, `${resultCount(s, "ok = true and row_count = 1")} = 2`),
      assertSql(`${s.name} one resolution action`, `(select count(*) from public.dispute_admin_actions where dispute_id = '${s.disputeId}'::uuid and action_type = 'record_resolution') = 1`),
      assertSql(`${s.name} one resolution history`, `(select count(*) from public.dispute_status_history where dispute_id = '${s.disputeId}'::uuid and reason_code = 'resolution_recorded') = 1`),
    ],
  },
];

try {
  await runSupabaseSql("setup", setupSql(), { quiet: true });

  let assertionCount = 0;
  for (const race of raceDefinitions) {
    const sessionA = sessionSql({ scenario: race.scenario, ...race.a });
    const sessionB = sessionSql({ scenario: race.scenario, ...race.b });
    await Promise.all([
      runSupabaseSql(`${race.scenario.name}_a`, sessionA, { quiet: true }),
      runSupabaseSql(`${race.scenario.name}_b`, sessionB, { quiet: true }),
    ]);

    const assertions = race.assertions(race.scenario);
    assertionCount += assertions.length + 2;
    await runSupabaseSql(`${race.scenario.name}_verify`, verifySql(race.scenario, assertions), { quiet: true });
    console.log(`${race.scenario.name}: passed`);
  }

  await runSupabaseSql("cleanup", cleanupSql(), { quiet: true });
  console.log(`D6 external concurrency harness passed: ${raceDefinitions.length} scenarios, ${assertionCount} invariant checks`);
} catch (error) {
  try {
    await runSupabaseSql("cleanup_after_failure", cleanupSql(), { quiet: true });
  } catch {
    console.error("D6 concurrency cleanup failed; inspect development fixtures before retrying.");
  }
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
} finally {
  await rm(tmpRoot, { recursive: true, force: true });
}
