#!/usr/bin/env node
/* global console, process */
// DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
// D10 reseller liability / withdrawal allocation true multi-process concurrency probes.

import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const cwd = process.cwd();
const npxBin = process.platform === "win32" ? "npx.cmd" : "npx";
const tempDir = await mkdtemp(join(tmpdir(), "risellar-d10-"));
const runNonce = randomUUID().replaceAll("-", "").slice(0, 8);

const q = (value) => `'${String(value).replaceAll("'", "''")}'`;
const slug = (value) => value.toLowerCase().replaceAll(/[^a-z0-9]/g, "");
const clerk = (label, actor) => `d10c_${slug(label)}_${runNonce}_${actor}`;

async function runSql(label, sql, allowFailure = false) {
  const file = join(tempDir, `${label}-${randomUUID()}.sql`);
  await writeFile(file, sql, "utf8");
  try {
    const result = await execFileAsync(npxBin, ["supabase", "db", "query", "--linked", "--file", file], {
      cwd,
      maxBuffer: 1024 * 1024 * 8,
      timeout: 120000,
      shell: process.platform === "win32",
      windowsHide: true,
    });
    return { ok: true, stdout: result.stdout, stderr: result.stderr };
  } catch (error) {
    if (!allowFailure) {
      throw new Error(`${label} failed: ${error.stderr || error.stdout || error.message}`);
    }
    return { ok: false, stdout: error.stdout || "", stderr: error.stderr || "", message: error.message };
  }
}

function context(clerkId, body) {
  return `
begin;
select set_config('request.jwt.claims', jsonb_build_object('sub', ${q(clerkId)}, 'role', 'authenticated')::text, true);
set local role authenticated;
${body}
commit;
`;
}

function ids() {
  return {
    customerProfile: randomUUID(),
    supplierProfile: randomUUID(),
    resellerProfile: randomUUID(),
    financeA: randomUUID(),
    financeB: randomUUID(),
    superAdmin: randomUUID(),
    customer: randomUUID(),
    supplier: randomUUID(),
    reseller: randomUUID(),
    shop: randomUUID(),
    product: randomUUID(),
    variant: randomUUID(),
    listing: randomUUID(),
    order: randomUUID(),
    item: randomUUID(),
    settlement: randomUUID(),
    commissionA: randomUUID(),
    commissionB: randomUUID(),
    dispute: randomUUID(),
    refund: randomUUID(),
    payoutAccount: randomUUID(),
  };
}

function setupSql(label, x, options = {}) {
  const suffix = `${slug(label)}${runNonce}`;
  const disputeStatus = options.closedDispute ? "closed" : "under_review";
  const refundStatus = options.closedDispute ? "completed" : "verified";

  return `
begin;
insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
values
  (${q(x.customerProfile)}, ${q(clerk(label, "customer"))}, ${q(`d10c-${suffix}-customer@example.invalid`)}, 'D10C Customer', 'customer', 'active'),
  (${q(x.supplierProfile)}, ${q(clerk(label, "supplier"))}, ${q(`d10c-${suffix}-supplier@example.invalid`)}, 'D10C Supplier', 'supplier_owner', 'active'),
  (${q(x.resellerProfile)}, ${q(clerk(label, "reseller"))}, ${q(`d10c-${suffix}-reseller@example.invalid`)}, 'D10C Reseller', 'reseller', 'active'),
  (${q(x.financeA)}, ${q(clerk(label, "finance_a"))}, ${q(`d10c-${suffix}-finance-a@example.invalid`)}, 'D10C Finance A', 'customer', 'active'),
  (${q(x.financeB)}, ${q(clerk(label, "finance_b"))}, ${q(`d10c-${suffix}-finance-b@example.invalid`)}, 'D10C Finance B', 'customer', 'active'),
  (${q(x.superAdmin)}, ${q(clerk(label, "super"))}, ${q(`d10c-${suffix}-super@example.invalid`)}, 'D10C Super', 'customer', 'active');
insert into public.admin_staff(profile_id, admin_role, permissions, staff_status)
values
  (${q(x.financeA)}, 'finance_staff', '{}'::jsonb, 'active'),
  (${q(x.financeB)}, 'finance_staff', '{}'::jsonb, 'active'),
  (${q(x.superAdmin)}, 'super_admin', '{}'::jsonb, 'active');
insert into public.customers(id, profile_id, customer_status) values (${q(x.customer)}, ${q(x.customerProfile)}, 'active');
insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status)
values (${q(x.supplier)}, ${q(x.supplierProfile)}, ${q(`D10C Supplier ${suffix}`)}, 'active', 'approved');
insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status, commission_available_amount, commission_pending_amount, commission_pending_withdrawal_amount, commission_withdrawn_amount)
values (${q(x.reseller)}, ${q(x.resellerProfile)}, 'individual', 'approved', 'active', 60, 0, 0, 0);
insert into public.reseller_payout_accounts(id, reseller_id, payout_method, mobile_money_network, account_name, phone_number, account_status, is_default)
values (${q(x.payoutAccount)}, ${q(x.reseller)}, 'mobile_money', 'mtn_momo', 'D10C Payout', '+233000000000', 'active', true);
insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
values (${q(x.shop)}, ${q(x.reseller)}, ${q(`d10c-${suffix}`)}, 'D10C Shop', 'active', 'public');
insert into public.products(id, supplier_id, category, name, slug, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
values (${q(x.product)}, ${q(x.supplier)}, 'D10C', 'D10C Product', ${q(`d10c-product-${suffix}`)}, 'active', 'approved', 100, 20, 40, 'GHS');
insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
values (${q(x.variant)}, ${q(x.product)}, ${q(`D10C-${suffix}`)}, 'D10C', 30, 0, 0, 'active');
insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
values (${q(x.listing)}, ${q(x.reseller)}, ${q(x.shop)}, ${q(x.product)}, ${q(x.variant)}, 'active', 30, 150, ${q(`d10c-listing-${suffix}`)});
insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, final_delivery_amount, total_payable_amount, currency_code, completed_at)
values (${q(x.order)}, ${q(`D10C-${suffix.toUpperCase().slice(0, 14)}`)}, ${q(x.customer)}, ${q(x.reseller)}, ${q(x.shop)}, 'completed', 'settlement_verified', 'delivered', 150, 0, 150, 'GHS', now());
insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
values (${q(x.item)}, ${q(x.order)}, ${q(x.supplier)}, ${q(x.product)}, ${q(x.variant)}, ${q(x.listing)}, 1, 100, 20, 30, 120, 150, 150, 50, 30);
insert into public.settlements(id, supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount, verified_at)
values (${q(x.settlement)}, ${q(x.supplier)}, ${q(x.order)}, 'paid', 50, 50, 0, now());
insert into public.commissions(id, reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount, available_at)
values
  (${q(x.commissionA)}, ${q(x.reseller)}, ${q(x.order)}, ${q(x.item)}, ${q(x.settlement)}, 'available', 30, now() - interval '2 days'),
  (${q(x.commissionB)}, ${q(x.reseller)}, ${q(x.order)}, ${q(x.item)}, ${q(x.settlement)}, 'available', 30, now() - interval '1 day');
insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, description, requested_outcome, status, finance_review_required, scope_type, affected_supplier_id, affected_order_item_id, idempotency_key, closed_at)
values (${q(x.dispute)}, ${q(x.order)}, ${q(x.customerProfile)}, 'customer', 'post_completion', 'damaged_item_received', 'D10C fixture dispute', 'partial_refund', ${q(disputeStatus)}, ${options.closedDispute ? "false" : "true"}, 'order_item', ${q(x.supplier)}, ${q(x.item)}, ${q(`d10c-dispute-${suffix}`)}, ${options.closedDispute ? "now()" : "null"});
insert into public.order_refunds(id, dispute_id, order_id, order_item_id, customer_profile_id, affected_supplier_id, approved_by_profile_id, refund_type, responsibility_code, responsible_party_role, status, approved_amount, currency_code, item_amount_component, delivery_fee_component, goodwill_component, completed_at)
values (${q(x.refund)}, ${q(x.dispute)}, ${q(x.order)}, ${q(x.item)}, ${q(x.customerProfile)}, ${q(x.supplier)}, ${q(x.financeA)}, 'partial_refund', 'reseller_responsible', 'reseller', ${q(refundStatus)}, 30, 'GHS', 30, 0, 0, ${options.closedDispute ? "now()" : "null"});
commit;
`;
}

function cleanupSql(x) {
  const profileIds = [x.customerProfile, x.supplierProfile, x.resellerProfile, x.financeA, x.financeB, x.superAdmin].map(q).join(",");
  const targetIds = [x.order, x.item, x.settlement, x.commissionA, x.commissionB, x.dispute, x.refund, x.payoutAccount].map(q).join(",");
  return `
begin;
delete from public.reseller_liability_recoveries where liability_id in (select id from public.reseller_liabilities where dispute_id = ${q(x.dispute)});
delete from public.withdrawal_commission_allocations where commission_id in (${q(x.commissionA)}, ${q(x.commissionB)});
delete from public.reseller_liabilities where dispute_id = ${q(x.dispute)};
delete from public.withdrawals where reseller_id = ${q(x.reseller)};
delete from public.finance_actions where actor_profile_id in (${profileIds}) or target_entity_id in (${targetIds});
delete from public.audit_logs where actor_profile_id in (${profileIds}) or target_entity_id in (${targetIds});
delete from public.order_refunds where id = ${q(x.refund)};
delete from public.order_disputes where id = ${q(x.dispute)};
delete from public.commissions where id in (${q(x.commissionA)}, ${q(x.commissionB)});
delete from public.settlements where id = ${q(x.settlement)};
delete from public.order_items where id = ${q(x.item)};
delete from public.orders where id = ${q(x.order)};
delete from public.reseller_products where id = ${q(x.listing)};
delete from public.product_variants where id = ${q(x.variant)};
delete from public.products where id = ${q(x.product)};
delete from public.reseller_shops where id = ${q(x.shop)};
delete from public.reseller_payout_accounts where id = ${q(x.payoutAccount)};
delete from public.resellers where id = ${q(x.reseller)};
delete from public.suppliers where id = ${q(x.supplier)};
delete from public.customers where id = ${q(x.customer)};
delete from public.admin_staff where profile_id in (${profileIds});
delete from public.profiles where id in (${profileIds});
commit;
`;
}

async function expectInvariant(label, sql) {
  await runSql(`${label}-invariant`, `
do $$
begin
  if not (${sql}) then
    raise exception 'D10 concurrency invariant failed: ${label}';
  end if;
end;
$$;
`);
  console.log(`PASS ${label}`);
}

async function scenario(label, options, leftSql, rightSql, invariantSql) {
  const x = ids();
  const leftActor = options.leftActor || "finance_a";
  const rightActor = options.rightActor || "finance_b";
  try {
    await runSql(`${label}-setup`, setupSql(label, x, options));
    const outcomes = await Promise.allSettled([
      runSql(`${label}-left`, context(clerk(label, leftActor), leftSql(x)), true),
      runSql(`${label}-right`, context(clerk(label, rightActor), rightSql(x)), true),
    ]);
    const failures = outcomes
      .map((outcome) => (outcome.status === "fulfilled" && !outcome.value.ok ? outcome.value.stderr || outcome.value.stdout || outcome.value.message : ""))
      .filter(Boolean);
    if (failures.length === outcomes.length) {
      throw new Error(`${label} had no successful participant: ${failures.join(" | ")}`);
    }
    await expectInvariant(label, invariantSql(x));
  } finally {
    await runSql(`${label}-cleanup`, cleanupSql(x), true);
  }
}

try {
  await scenario(
    "same_key_liability",
    {},
    (x) => `select count(*) from public.finance_approve_reseller_liability(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, ${q(x.commissionA)}::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10c-same-liability-key');`,
    (x) => `select count(*) from public.finance_approve_reseller_liability(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, ${q(x.commissionA)}::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10c-same-liability-key');`,
    (x) => `(select count(*) from public.reseller_liabilities where dispute_id = ${q(x.dispute)}::uuid and commission_id = ${q(x.commissionA)}::uuid) = 1`
  );

  await scenario(
    "same_scope_different_keys",
    {},
    (x) => `select count(*) from public.finance_approve_reseller_liability(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, ${q(x.commissionA)}::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10c-scope-key-a');`,
    (x) => `select count(*) from public.finance_approve_reseller_liability(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, ${q(x.commissionA)}::uuid, 'commission_recovery', 'no_automatic_recovery', null, null, 'd10c-scope-key-b');`,
    (x) => `(select count(*) from public.reseller_liabilities where dispute_id = ${q(x.dispute)}::uuid and commission_id = ${q(x.commissionA)}::uuid and deleted_at is null) = 1`
  );

  await scenario(
    "two_offsets_same_liability",
    {},
    (x) => `
with approved as (
  select liability_id from public.finance_approve_reseller_liability(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, ${q(x.commissionA)}::uuid, 'commission_recovery', 'offset_future_earnings', null, null, 'd10c-offset-liability')
)
select count(*) from public.finance_enable_future_earnings_offset((select liability_id from approved), null, null, 'd10c-offset-enable');
select count(*) from public.finance_apply_future_commission_offset(${q(x.commissionB)}::uuid, 'd10c-offset-key-a');`,
    (x) => `select count(*) from public.finance_apply_future_commission_offset(${q(x.commissionB)}::uuid, 'd10c-offset-key-b');`,
    (x) => `(select coalesce(sum(amount), 0) from public.reseller_liability_recoveries where commission_id = ${q(x.commissionB)}::uuid and recovery_type = 'future_commission_offset' and status = 'applied') <= 30
      and (select outstanding_amount >= 0 and recovered_amount <= original_amount from public.reseller_liabilities where dispute_id = ${q(x.dispute)}::uuid limit 1)`
  );

  await scenario(
    "two_withdrawals_same_commission",
    { closedDispute: true, leftActor: "reseller", rightActor: "reseller" },
    (x) => `select count(*) from public.reseller_request_withdrawal(30, ${q(x.payoutAccount)}::uuid, 'd10c-withdrawal-a');`,
    (x) => `select count(*) from public.reseller_request_withdrawal(30, ${q(x.payoutAccount)}::uuid, 'd10c-withdrawal-b');`,
    (x) => `(select count(*) from public.withdrawal_commission_allocations where commission_id = ${q(x.commissionA)}::uuid and allocation_status in ('reserved', 'consumed')) <= 1
      and (select coalesce(sum(allocated_amount), 0) from public.withdrawal_commission_allocations where allocation_status in ('reserved', 'consumed') and commission_id in (${q(x.commissionA)}, ${q(x.commissionB)})) <= 60`
  );

  const allocation = ids();
  try {
    await runSql("allocation-dispute-setup", setupSql("allocation_dispute_vs_payout", allocation, { closedDispute: true }));
    await runSql("allocation-dispute-withdrawal", context(clerk("allocation_dispute_vs_payout", "reseller"), `
select count(*) from public.reseller_request_withdrawal(30, ${q(allocation.payoutAccount)}::uuid, 'd10c-allocation-race-withdrawal');
`));
    const race = await runSql("allocation-dispute-id", `
select id::text as allocation_id, withdrawal_id::text as withdrawal_id
from public.withdrawal_commission_allocations
where commission_id = ${q(allocation.commissionA)}::uuid
limit 1;
`);
    const match = race.stdout.match(/"allocation_id":\s*"([^"]+)".*"withdrawal_id":\s*"([^"]+)"/s);
    if (!match) throw new Error("allocation_dispute_vs_payout could not find allocation fixture");
    const [, allocationId, withdrawalId] = match;
    const outcomes = await Promise.allSettled([
      runSql("allocation-dispute-left", context(clerk("allocation_dispute_vs_payout", "finance_a"), `select count(*) from public.finance_mark_withdrawal_allocation_disputed(${q(allocationId)}::uuid, null, null, 'd10c-allocation-dispute');`), true),
      runSql("allocation-dispute-right", context(clerk("allocation_dispute_vs_payout", "finance_b"), `select count(*) from public.admin_mark_reseller_withdrawal_paid(${q(withdrawalId)}::uuid, 'D10C-PAYOUT', null, 'd10c-allocation-payout');`), true),
    ]);
    if (outcomes.every((outcome) => outcome.status === "fulfilled" && !outcome.value.ok)) {
      throw new Error("allocation_dispute_vs_payout had no successful participant");
    }
    await expectInvariant(
      "allocation_dispute_vs_payout",
      `(select case
          when w.withdrawal_status = 'paid' then not exists (select 1 from public.withdrawal_commission_allocations where withdrawal_id = w.id and allocation_status = 'disputed')
          else exists (select 1 from public.withdrawal_commission_allocations where withdrawal_id = w.id and allocation_status in ('reserved', 'disputed'))
        end
        from public.withdrawals w
        where w.id = ${q(withdrawalId)}::uuid)
        and (select commission_withdrawn_amount >= 0 and commission_pending_withdrawal_amount >= 0 from public.resellers where id = ${q(allocation.reseller)}::uuid)`
    );
  } finally {
    await runSql("allocation-dispute-cleanup", cleanupSql(allocation), true);
  }
} finally {
  await rm(tempDir, { recursive: true, force: true });
}
