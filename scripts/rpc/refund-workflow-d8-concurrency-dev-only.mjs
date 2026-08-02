#!/usr/bin/env node
/* global console, process */
// DEVELOPMENT ONLY. Runs true multi-process D8 refund workflow RPC concurrency checks.
// Do not run against production. Output is limited to safe scenario summaries.

import { randomUUID } from "node:crypto";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";

const marker = `dev_d8_concurrency_${Date.now()}_${randomUUID().replaceAll("-", "").slice(0, 10)}`;
const tmpRoot = await mkdtemp(path.join(tmpdir(), "risellar-d8-concurrency-"));

const q = (value) => `'${String(value).replaceAll("'", "''")}'`;
const uuid = () => randomUUID();
const idList = (items) => items.map((item) => `${q(item)}::uuid`).join(", ");

const ids = {
  customerProfile: uuid(),
  supplierProfile: uuid(),
  resellerProfile: uuid(),
  financeProfile: uuid(),
  financeBProfile: uuid(),
  supportProfile: uuid(),
  customer: uuid(),
  supplier: uuid(),
  reseller: uuid(),
  shop: uuid(),
  product: uuid(),
  variant: uuid(),
  listing: uuid(),
};

const clerk = {
  customer: `${marker}_customer`,
  supplier: `${marker}_supplier`,
  finance: `${marker}_finance`,
  financeB: `${marker}_finance_b`,
  support: `${marker}_support`,
};

const scenarios = [
  ["a_same_key_approval", "under_review", null],
  ["b_same_scope_different_keys", "under_review", null],
  ["c_partial_cap_a", "under_review", null],
  ["c_partial_cap_b", "under_review", null],
  ["d_full_vs_partial_a", "under_review", null],
  ["d_full_vs_partial_b", "under_review", null],
  ["e_supplier_report_twice", "under_review", null],
  ["f_report_vs_reject", "under_review", null],
  ["g_customer_confirm_vs_dispute", "under_review", null],
  ["h_verify_vs_reject", "under_review", null],
  ["i_complete_vs_reject", "under_review", null],
  ["j_approval_vs_dispute_closure", "under_review", null],
  ["k_approval_vs_return_decline", "return_review", "accepted"],
  ["l_two_finance_verify", "under_review", null],
].map(([name, disputeStatus, returnStatus], index) => ({
  name,
  disputeStatus,
  returnStatus,
  orderId: uuid(),
  itemId: uuid(),
  disputeId: uuid(),
  refundId: uuid(),
  returnId: returnStatus ? uuid() : null,
  reasonCode: "refund_requested",
  requestedOutcome: "partial_refund",
  orderNumber: `D8CONC-${index + 1}-${marker.slice(-8).toUpperCase()}`,
}));

const byName = (name) => scenarios.find((scenario) => scenario.name === name);
const disputeIds = () => idList(scenarios.map((scenario) => scenario.disputeId));
const orderIds = () => idList(scenarios.map((scenario) => scenario.orderId));
const itemIds = () => idList(scenarios.map((scenario) => scenario.itemId));
const returnIds = () =>
  idList(scenarios.filter((scenario) => scenario.returnId).map((scenario) => scenario.returnId)) || "null::uuid";
const profileIds = () => idList([ids.customerProfile, ids.supplierProfile, ids.resellerProfile, ids.financeProfile, ids.financeBProfile, ids.supportProfile]);

// Share the same order item across the paired over-commit races.
byName("c_partial_cap_b").orderId = byName("c_partial_cap_a").orderId;
byName("c_partial_cap_b").itemId = byName("c_partial_cap_a").itemId;
byName("c_partial_cap_b").orderNumber = byName("c_partial_cap_a").orderNumber;
byName("c_partial_cap_b").reasonCode = "product_quality_issue";
byName("d_full_vs_partial_b").orderId = byName("d_full_vs_partial_a").orderId;
byName("d_full_vs_partial_b").itemId = byName("d_full_vs_partial_a").itemId;
byName("d_full_vs_partial_b").orderNumber = byName("d_full_vs_partial_a").orderNumber;
byName("d_full_vs_partial_a").requestedOutcome = "full_refund";
byName("d_full_vs_partial_b").reasonCode = "item_not_as_described";

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

function setupSql() {
  const uniqueOrders = [...new Map(scenarios.map((scenario) => [scenario.orderId, scenario])).values()];
  const uniqueItems = [...new Map(scenarios.map((scenario) => [scenario.itemId, scenario])).values()];

  const orderRows = uniqueOrders
    .map(
      (scenario) =>
        `(${q(scenario.orderId)}, ${q(scenario.orderNumber)}, ${q(ids.customer)}, ${q(ids.reseller)}, ${q(ids.shop)}, 'delivered', 'supplier_reported', 'delivered', 125, 20, 145, 'GHS')`,
    )
    .join(",\n    ");
  const itemRows = uniqueItems
    .map(
      (scenario) =>
        `(${q(scenario.itemId)}, ${q(scenario.orderId)}, ${q(ids.supplier)}, ${q(ids.product)}, ${q(ids.variant)}, ${q(ids.listing)}, 1, 100, 10, 15, 110, 125, 125, 100, 15)`,
    )
    .join(",\n    ");
  const disputeRows = scenarios
    .map(
      (scenario) =>
        `(${q(scenario.disputeId)}, ${q(scenario.orderId)}, ${q(ids.customerProfile)}, 'customer', 'order_item', ${q(ids.supplier)}, ${q(scenario.itemId)}, 'post_completion', ${q(scenario.reasonCode)}, 'D8 concurrency refund dispute.', ${q(scenario.requestedOutcome)}, ${q(scenario.disputeStatus)})`,
    )
    .join(",\n    ");
  const seededRefundRows = scenarios
    .filter((scenario) => ["e_supplier_report_twice", "f_report_vs_reject", "g_customer_confirm_vs_dispute", "h_verify_vs_reject", "i_complete_vs_reject", "l_two_finance_verify"].includes(scenario.name))
    .map((scenario) => {
      const reported = ["g_customer_confirm_vs_dispute", "h_verify_vs_reject", "i_complete_vs_reject", "l_two_finance_verify"].includes(scenario.name);
      return `(${q(scenario.refundId)}, ${q(scenario.disputeId)}, ${q(scenario.orderId)}, ${q(scenario.itemId)}, ${q(ids.customerProfile)}, ${q(ids.supplier)}, 'partial_refund', ${reported ? "'reported_sent'" : "'awaiting_responsible_party'"}, 'supplier_responsible', 'supplier', 50, 'GHS', 50, 0, 0, ${q(ids.financeProfile)}, now(), ${reported ? `${q(ids.supplierProfile)}` : "null"}, ${reported ? "now()" : "null"}, ${reported ? "'cash'" : "null"}, ${reported ? "'REF-MASKED'" : "null"}, ${reported ? "'pending'" : "'not_requested'"})`;
    })
    .join(",\n    ");
  const returnRows = scenarios
    .filter((scenario) => scenario.returnId)
    .map(
      (scenario) =>
        `(${q(scenario.returnId)}, ${q(scenario.disputeId)}, ${q(scenario.orderId)}, ${q(scenario.itemId)}, ${q(ids.customerProfile)}, ${q(ids.supplier)}, 1, 1, 'customer_returns_to_supplier', 'customer_returns_to_supplier', 'supplier', 'opened_sellable', 'no_stock_change', ${q(scenario.returnStatus)}, now(), now(), now())`,
    )
    .join(",\n    ");

  return `
create table if not exists public.__dev_d8_concurrency_results (
  marker text not null,
  scenario text not null,
  actor_label text not null,
  ok boolean not null,
  result_code text not null,
  backend_pid integer not null,
  call_started_at timestamptz not null,
  call_finished_at timestamptz not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key (marker, scenario, actor_label)
);

create table if not exists public.__dev_d8_concurrency_counts (
  marker text not null,
  table_name text not null,
  row_count bigint not null,
  primary key (marker, table_name)
);

grant select, insert, update, delete on public.__dev_d8_concurrency_results to authenticated;

drop function if exists public.__dev_d8_concurrency_record(text, text, text, boolean, text, integer, timestamptz, timestamptz);

create or replace function public.__dev_d8_concurrency_record(
  p_marker text,
  p_scenario text,
  p_actor_label text,
  p_ok boolean,
  p_result_code text,
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
  insert into public.__dev_d8_concurrency_results(marker, scenario, actor_label, ok, result_code, backend_pid, call_started_at, call_finished_at)
  values (p_marker, p_scenario, p_actor_label, p_ok, p_result_code, p_backend_pid, p_call_started_at, p_call_finished_at)
  on conflict (marker, scenario, actor_label) do update
    set ok = excluded.ok,
        result_code = excluded.result_code,
        backend_pid = excluded.backend_pid,
        call_started_at = excluded.call_started_at,
        call_finished_at = excluded.call_finished_at,
        created_at = clock_timestamp();
end;
$$;

revoke all on function public.__dev_d8_concurrency_record(text, text, text, boolean, text, integer, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.__dev_d8_concurrency_record(text, text, text, boolean, text, integer, timestamptz, timestamptz) to authenticated;

insert into public.__dev_d8_concurrency_counts(marker, table_name, row_count)
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
  (${q(marker)}, 'order_item_returns', (select count(*) from public.order_item_returns)),
  (${q(marker)}, 'notification_outbox', (select count(*) from public.notification_outbox)),
  (${q(marker)}, 'notification_provider_events', (select count(*) from public.notification_provider_events))
on conflict (marker, table_name) do update set row_count = excluded.row_count;

insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
values
  (${q(ids.customerProfile)}, ${q(clerk.customer)}, 'd8-concurrency-customer@example.test', 'D8 Concurrency Customer', 'customer', 'active'),
  (${q(ids.supplierProfile)}, ${q(clerk.supplier)}, 'd8-concurrency-supplier@example.test', 'D8 Concurrency Supplier', 'supplier_owner', 'active'),
  (${q(ids.resellerProfile)}, ${q(`${marker}_reseller`)}, 'd8-concurrency-reseller@example.test', 'D8 Concurrency Reseller', 'reseller', 'active'),
  (${q(ids.financeProfile)}, ${q(clerk.finance)}, 'd8-concurrency-finance@example.test', 'D8 Concurrency Finance', 'customer', 'active'),
  (${q(ids.financeBProfile)}, ${q(clerk.financeB)}, 'd8-concurrency-finance-b@example.test', 'D8 Concurrency Finance B', 'customer', 'active'),
  (${q(ids.supportProfile)}, ${q(clerk.support)}, 'd8-concurrency-support@example.test', 'D8 Concurrency Support', 'customer', 'active');

insert into public.customers(id, profile_id, customer_status)
values (${q(ids.customer)}, ${q(ids.customerProfile)}, 'active');

insert into public.admin_staff(id, profile_id, admin_role, staff_status)
values
  (gen_random_uuid(), ${q(ids.financeProfile)}, 'finance_staff', 'active'),
  (gen_random_uuid(), ${q(ids.financeBProfile)}, 'finance_staff', 'active'),
  (gen_random_uuid(), ${q(ids.supportProfile)}, 'admin', 'active');

insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status, public_display_name)
values (${q(ids.supplier)}, ${q(ids.supplierProfile)}, 'D8 Concurrency Supplier', 'active', 'approved', 'D8 Concurrency Supplier');

insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status)
values (${q(ids.reseller)}, ${q(ids.resellerProfile)}, 'qa', 'approved', 'active');

insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status)
values (${q(ids.shop)}, ${q(ids.reseller)}, ${q(`d8-concurrency-${marker.slice(-10)}`)}, 'D8 Concurrency Shop', 'active');

insert into public.products(id, supplier_id, category, name, slug, description, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, created_by_profile_id)
values (${q(ids.product)}, ${q(ids.supplier)}, 'QA', 'D8 Concurrency Product', ${q(`d8-concurrency-product-${marker.slice(-10)}`)}, 'Development-only D8 concurrency product.', 'active', 'approved', 100, 10, 20, ${q(ids.supplierProfile)});

insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, returned_stock_quantity, variant_status)
values (${q(ids.variant)}, ${q(ids.product)}, 'D8-CONC', 'Default', 40, 4, 2, 0, 'active');

insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
values (${q(ids.listing)}, ${q(ids.reseller)}, ${q(ids.shop)}, ${q(ids.product)}, ${q(ids.variant)}, 'active', 15, 125, 'd8-conc-listing');

insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, final_delivery_amount, total_payable_amount, currency_code)
values
    ${orderRows};

insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
values
    ${itemRows};

insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, scope_type, affected_supplier_id, affected_order_item_id, dispute_category, reason_code, description, requested_outcome, status)
values
    ${disputeRows};

${returnRows ? `insert into public.order_item_returns(id, dispute_id, order_id, order_item_id, customer_profile_id, supplier_id, requested_quantity, approved_quantity, requested_method, approved_method, delivery_fee_responsibility, inspection_condition, inventory_outcome, status, requested_at, approved_at, accepted_at)\nvalues\n    ${returnRows};` : ""}

insert into public.order_refunds(id, dispute_id, order_id, order_item_id, customer_profile_id, affected_supplier_id, refund_type, status, responsibility_code, responsible_party_role, approved_amount, currency_code, item_amount_component, delivery_fee_component, goodwill_component, approved_by_profile_id, approved_at, reported_sent_by_profile_id, reported_sent_at, refund_method, external_reference_masked, customer_confirmation_status)
values
    ${seededRefundRows};
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
  v_code text := 'ok';
begin
  ${setContextSql(clerkUserId)}
  set local lock_timeout = '5s';
  set local statement_timeout = '25s';
  perform pg_sleep(0.25);
  begin
    ${bodySql}
  exception when others then
    v_code := sqlstate || ':' || sqlerrm;
  end;
  v_finished_at := clock_timestamp();
  perform public.__dev_d8_concurrency_record(${q(marker)}, ${q(scenarioName)}, ${q(actorLabel)}, v_code = 'ok', v_code, pg_backend_pid(), v_started_at, v_finished_at);
end;
$$;`;
}

function approvalSql(disputeId, key, amount, options = {}) {
  const returnArg = options.returnId ? `${q(options.returnId)}::uuid` : "null";
  const type = options.type || "partial_refund";
  return `perform * from public.admin_approve_refund_obligation(${q(disputeId)}::uuid, ${returnArg}, ${q(type)}, 1, ${amount}, 0, 0, 'supplier_responsible', 'supplier', 'Safe refund reason.', null, ${q(key)});`;
}

function supplierReportSql(refundSelector, key) {
  return `
if (${refundSelector}) is null then
  raise exception 'REFUND_FIXTURE_MAPPING_MISSING';
end if;
perform * from public.supplier_report_refund_sent((${refundSelector}), 'cash', 'REF-MASKED', null, ${q(key)});
`;
}

function resultPairSql(scenarioName) {
  return `
    (select count(*) from public.__dev_d8_concurrency_results where marker = ${q(marker)} and scenario = ${q(scenarioName)}) = 2
    and (select count(distinct backend_pid) from public.__dev_d8_concurrency_results where marker = ${q(marker)} and scenario = ${q(scenarioName)}) = 2
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
declare
  v_details text;
begin
  if not (${verifySql}) then
    select string_agg(actor_label || '=' || result_code, ', ' order by actor_label)
    into v_details
    from public.__dev_d8_concurrency_results
    where marker = ${q(marker)}
      and scenario = ${q(name)};

    raise exception 'D8 concurrency scenario failed: ${name}: %', coalesce(v_details, 'no actor rows');
  end if;
end;
$$;`,
    { quiet: true },
  );
  console.log(`PASS ${name}`);
}

function refundIdFor(label) {
  return `${q(byName(label).refundId)}::uuid`;
}

function cleanupSql() {
  return `
delete from public.__dev_d8_concurrency_results where marker = ${q(marker)};
delete from public.__dev_d8_concurrency_counts where marker = ${q(marker)};
delete from public.refund_actions where result_refund_id in (select id from public.order_refunds where dispute_id in (${disputeIds()}));
delete from public.audit_logs where target_entity_id in (select id from public.order_refunds where dispute_id in (${disputeIds()})) or target_entity_id in (${disputeIds()});
delete from public.order_refunds where dispute_id in (${disputeIds()});
delete from public.order_item_returns where dispute_id in (${disputeIds()});
delete from public.dispute_status_history where dispute_id in (${disputeIds()});
delete from public.order_disputes where id in (${disputeIds()});
delete from public.order_items where id in (${itemIds()});
delete from public.orders where id in (${orderIds()});
delete from public.reseller_products where id = ${q(ids.listing)}::uuid;
delete from public.product_variants where id = ${q(ids.variant)}::uuid;
delete from public.products where id = ${q(ids.product)}::uuid;
delete from public.reseller_shops where id = ${q(ids.shop)}::uuid;
delete from public.resellers where id = ${q(ids.reseller)}::uuid;
delete from public.suppliers where id = ${q(ids.supplier)}::uuid;
delete from public.admin_staff where profile_id in (${q(ids.financeProfile)}::uuid, ${q(ids.financeBProfile)}::uuid, ${q(ids.supportProfile)}::uuid);
delete from public.customers where id = ${q(ids.customer)}::uuid;
delete from public.profiles where id in (${profileIds()});

do $$
begin
  if exists (select 1 from public.order_refunds where dispute_id in (${disputeIds()})) then
    raise exception 'D8 cleanup left refund rows';
  end if;
  if exists (select 1 from public.order_disputes where id in (${disputeIds()})) then
    raise exception 'D8 cleanup left dispute rows';
  end if;
end;
$$;`;
}

let originalError = null;

try {
  await runSupabaseSql("setup", setupSql(), { quiet: true });

  const a = byName("a_same_key_approval");
  await runRace(
    a.name,
    actorSql("finance_a", a.name, clerk.finance, approvalSql(a.disputeId, "d8-conc-a", 50)),
    actorSql("finance_b", a.name, clerk.finance, approvalSql(a.disputeId, "d8-conc-a", 50)),
    `(select count(*) from public.order_refunds where dispute_id = ${q(a.disputeId)}::uuid) = 1
      and (select count(*) from public.refund_actions where dispute_id = ${q(a.disputeId)}::uuid and action_type = 'approve_obligation') = 1
      and (select count(*) from public.__dev_d8_concurrency_results where marker = ${q(marker)} and scenario = ${q(a.name)} and ok) = 2
      and ${resultPairSql(a.name)}`,
  );

  const b = byName("b_same_scope_different_keys");
  await runRace(
    b.name,
    actorSql("finance_a", b.name, clerk.finance, approvalSql(b.disputeId, "d8-conc-b-a", 50)),
    actorSql("finance_b", b.name, clerk.finance, approvalSql(b.disputeId, "d8-conc-b-b", 50)),
    `(select count(*) from public.order_refunds where dispute_id = ${q(b.disputeId)}::uuid) = 1
      and (select count(*) from public.__dev_d8_concurrency_results where marker = ${q(marker)} and scenario = ${q(b.name)} and ok) = 1
      and ${resultPairSql(b.name)}`,
  );

  const c1 = byName("c_partial_cap_a");
  const c2 = byName("c_partial_cap_b");
  await runRace(
    "c_partial_cap",
    actorSql("partial_a", "c_partial_cap", clerk.finance, approvalSql(c1.disputeId, "d8-conc-c-a", 90)),
    actorSql("partial_b", "c_partial_cap", clerk.financeB, approvalSql(c2.disputeId, "d8-conc-c-b", 90)),
    `(select coalesce(sum(item_amount_component), 0) from public.order_refunds where order_item_id = ${q(c1.itemId)}::uuid) <= 125
      and (select count(*) from public.order_refunds where order_item_id = ${q(c1.itemId)}::uuid) = 1
      and ${resultPairSql("c_partial_cap")}`,
  );

  const d1 = byName("d_full_vs_partial_a");
  const d2 = byName("d_full_vs_partial_b");
  await runRace(
    "d_full_vs_partial",
    actorSql("full", "d_full_vs_partial", clerk.finance, approvalSql(d1.disputeId, "d8-conc-d-full", 125, { type: "full_refund" })),
    actorSql("partial", "d_full_vs_partial", clerk.financeB, approvalSql(d2.disputeId, "d8-conc-d-partial", 80)),
    `(select coalesce(sum(item_amount_component), 0) from public.order_refunds where order_item_id = ${q(d1.itemId)}::uuid) <= 125
      and (select count(*) from public.order_refunds where order_item_id = ${q(d1.itemId)}::uuid) = 1
      and ${resultPairSql("d_full_vs_partial")}`,
  );

  const e = byName("e_supplier_report_twice");
  await runRace(
    e.name,
    actorSql("supplier_a", e.name, clerk.supplier, supplierReportSql(refundIdFor(e.name), "d8-conc-e-report")),
    actorSql("supplier_b", e.name, clerk.supplier, supplierReportSql(refundIdFor(e.name), "d8-conc-e-report")),
    `(select status = 'reported_sent' from public.order_refunds where dispute_id = ${q(e.disputeId)}::uuid)
      and (select count(*) from public.refund_actions where refund_id = (${refundIdFor(e.name)}) and action_type = 'supplier_report_sent') = 1
      and (select count(*) from public.__dev_d8_concurrency_results where marker = ${q(marker)} and scenario = ${q(e.name)} and ok) = 2
      and ${resultPairSql(e.name)}`,
  );

  const f = byName("f_report_vs_reject");
  await runRace(
    f.name,
    actorSql("supplier_report", f.name, clerk.supplier, supplierReportSql(refundIdFor(f.name), "d8-conc-f-report")),
    actorSql("finance_reject", f.name, clerk.finance, `perform * from public.admin_reject_refund_report((${refundIdFor(f.name)}), 'Safe rejection reason.', null, 'd8-conc-f-reject');`),
    `(select status in ('reported_sent', 'rejected') from public.order_refunds where dispute_id = ${q(f.disputeId)}::uuid)
      and (select count(*) from public.refund_actions where refund_id = (${refundIdFor(f.name)}) and action_type in ('supplier_report_sent', 'finance_reject_report')) = 1
      and ${resultPairSql(f.name)}`,
  );

  const g = byName("g_customer_confirm_vs_dispute");
  await runRace(
    g.name,
    actorSql("confirm", g.name, clerk.customer, `perform * from public.customer_confirm_refund_received((${refundIdFor(g.name)}), true, 'Received.', 'd8-conc-g-confirm');`),
    actorSql("dispute", g.name, clerk.customer, `perform * from public.customer_confirm_refund_received((${refundIdFor(g.name)}), false, 'Not received.', 'd8-conc-g-dispute');`),
    `(select status = 'under_verification' and customer_confirmation_status in ('confirmed_received', 'disputed_not_received') from public.order_refunds where dispute_id = ${q(g.disputeId)}::uuid)
      and (select count(*) from public.refund_actions where refund_id = (${refundIdFor(g.name)}) and action_type in ('customer_confirm_received', 'customer_dispute_not_received')) = 1
      and ${resultPairSql(g.name)}`,
  );

  const h = byName("h_verify_vs_reject");
  await runRace(
    h.name,
    actorSql("verify", h.name, clerk.finance, `perform * from public.admin_verify_refund_report((${refundIdFor(h.name)}), null, 'd8-conc-h-verify');`),
    actorSql("reject", h.name, clerk.financeB, `perform * from public.admin_reject_refund_report((${refundIdFor(h.name)}), 'Safe rejection reason.', null, 'd8-conc-h-reject');`),
    `(select status in ('verified', 'rejected') from public.order_refunds where dispute_id = ${q(h.disputeId)}::uuid)
      and (select count(*) from public.refund_actions where refund_id = (${refundIdFor(h.name)}) and action_type in ('finance_verify', 'finance_reject_report')) = 1
      and ${resultPairSql(h.name)}`,
  );

  const i = byName("i_complete_vs_reject");
  await runRace(
    i.name,
    actorSql("complete", i.name, clerk.finance, `perform * from public.admin_complete_refund((${refundIdFor(i.name)}), null, 'd8-conc-i-complete');`),
    actorSql("reject", i.name, clerk.financeB, `perform * from public.admin_reject_refund_report((${refundIdFor(i.name)}), 'Safe rejection reason.', null, 'd8-conc-i-reject');`),
    `(select status in ('reported_sent', 'rejected') and status <> 'completed' from public.order_refunds where dispute_id = ${q(i.disputeId)}::uuid)
      and (select count(*) from public.refund_actions where refund_id = (${refundIdFor(i.name)}) and action_type = 'finance_complete') = 0
      and ${resultPairSql(i.name)}`,
  );

  const j = byName("j_approval_vs_dispute_closure");
  await runRace(
    j.name,
    actorSql("approval", j.name, clerk.finance, approvalSql(j.disputeId, "d8-conc-j-approve", 50)),
    actorSql("closure", j.name, clerk.support, `perform * from public.admin_close_dispute(${q(j.disputeId)}::uuid, null, null, 'd8-conc-j-close');`),
    `(select count(*) from public.order_refunds where dispute_id = ${q(j.disputeId)}::uuid) <= 1
      and not (
        (select status = 'closed' from public.order_disputes where id = ${q(j.disputeId)}::uuid)
        and exists (select 1 from public.order_refunds where dispute_id = ${q(j.disputeId)}::uuid)
      )
      and ${resultPairSql(j.name)}`,
  );

  const k = byName("k_approval_vs_return_decline");
  await runRace(
    k.name,
    actorSql("approval", k.name, clerk.finance, approvalSql(k.disputeId, "d8-conc-k-approve", 50, { returnId: k.returnId })),
    actorSql("decline", k.name, clerk.support, `perform * from public.admin_decline_return(${q(k.returnId)}::uuid, 'Safe decline reason.', null, 'd8-conc-k-decline');`),
    `(select status = 'accepted' from public.order_item_returns where id = ${q(k.returnId)}::uuid)
      and (select count(*) from public.order_refunds where dispute_id = ${q(k.disputeId)}::uuid) = 1
      and ${resultPairSql(k.name)}`,
  );

  const l = byName("l_two_finance_verify");
  await runRace(
    l.name,
    actorSql("finance_a", l.name, clerk.finance, `perform * from public.admin_verify_refund_report((${refundIdFor(l.name)}), null, 'd8-conc-l-verify-a');`),
    actorSql("finance_b", l.name, clerk.financeB, `perform * from public.admin_verify_refund_report((${refundIdFor(l.name)}), null, 'd8-conc-l-verify-b');`),
    `(select status = 'verified' from public.order_refunds where dispute_id = ${q(l.disputeId)}::uuid)
      and (select count(*) from public.refund_actions where refund_id = (${refundIdFor(l.name)}) and action_type = 'finance_verify') = 1
      and ${resultPairSql(l.name)}`,
  );

  await runSupabaseSql(
    "side_effect_verify",
    `
do $$
begin
  if exists (select 1 from public.stock_reservations where order_id in (${orderIds()})) then
    raise exception 'D8 concurrency created stock reservation side effects';
  end if;
  if exists (select 1 from public.inventory_movements where order_id in (${orderIds()})) then
    raise exception 'D8 concurrency created inventory side effects';
  end if;
  if exists (select 1 from public.settlements where order_id in (${orderIds()})) then
    raise exception 'D8 concurrency created settlement side effects';
  end if;
  if exists (select 1 from public.commissions where order_id in (${orderIds()})) then
    raise exception 'D8 concurrency created commission side effects';
  end if;
  if exists (select 1 from public.withdrawals where reseller_id = ${q(ids.reseller)}::uuid) then
    raise exception 'D8 concurrency created withdrawal side effects';
  end if;
  if exists (select 1 from public.notification_outbox where event_key like ${q(`${marker}%`)}) then
    raise exception 'D8 concurrency created notification side effects';
  end if;
  if exists (select 1 from public.order_item_returns where id in (${returnIds()}) and inventory_outcome <> 'no_stock_change') then
    raise exception 'D8 concurrency changed return inventory outcome';
  end if;
end;
$$;`,
    { quiet: true },
  );
  console.log("PASS side_effect_invariants");
} catch (error) {
  originalError = error;
} finally {
  try {
    await runSupabaseSql("cleanup", cleanupSql(), { quiet: true });
    console.log("PASS cleanup");
  } catch (cleanupError) {
    if (!originalError) {
      originalError = cleanupError;
    } else {
      console.error(`Cleanup warning: ${cleanupError.message}`);
    }
  } finally {
    await rm(tmpRoot, { recursive: true, force: true });
  }
}

if (originalError) {
  throw originalError;
}
