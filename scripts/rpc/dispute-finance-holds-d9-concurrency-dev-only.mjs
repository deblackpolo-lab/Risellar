#!/usr/bin/env node
/* global console, process */
// DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
// D9 finance holds true multi-process concurrency probes.

import { execFile } from "node:child_process";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const cwd = process.cwd();
const tempDir = await mkdtemp(join(tmpdir(), "risellar-d9-"));
const npxBin = process.platform === "win32" ? "npx.cmd" : "npx";
const runNonce = randomUUID().replaceAll("-", "").slice(0, 8);

const q = (value) => `'${String(value).replaceAll("'", "''")}'`;
const slug = (value) => value.toLowerCase().replaceAll(/[^a-z0-9]/g, "");
const clerk = (label, role) => `d9c_${slug(label)}${runNonce}_${role}`;

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
    customer: randomUUID(),
    supplier: randomUUID(),
    reseller: randomUUID(),
    shop: randomUUID(),
    product: randomUUID(),
    variant: randomUUID(),
    listing: randomUUID(),
    order: randomUUID(),
    item: randomUUID(),
    reservation: randomUUID(),
    settlement: randomUUID(),
    commission: randomUUID(),
    dispute: randomUUID(),
    refund: randomUUID(),
    payoutAccount: randomUUID(),
    withdrawal: randomUUID(),
  };
}

function setupSql(scenario, x, options = {}) {
  const scenarioSlug = slug(scenario);
  const suffix = `${scenarioSlug}${runNonce}`;
  const orderRef = `${runNonce}-${scenarioSlug.slice(0, 10)}`;
  const orderStatus = options.verified ? "completed" : "payment_reported";
  const paymentStatus = options.verified ? "settlement_verified" : "supplier_reported";
  const settlementStatus = options.verified ? "paid" : "due";
  const commissionStatus = options.verified ? "available" : "awaiting_supplier_settlement";
  const resellerAvailable = options.verified ? "130.00" : "100.00";
  const resellerPending = options.verified ? "30.00" : "60.00";

  return `
begin;
insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
values
  (${q(x.customerProfile)}, ${q(`d9c_${suffix}_customer`)}, ${q(`d9c-${suffix}-customer@example.invalid`)}, 'D9C Customer', 'customer', 'active'),
  (${q(x.supplierProfile)}, ${q(`d9c_${suffix}_supplier`)}, ${q(`d9c-${suffix}-supplier@example.invalid`)}, 'D9C Supplier', 'supplier_owner', 'active'),
  (${q(x.resellerProfile)}, ${q(`d9c_${suffix}_reseller`)}, ${q(`d9c-${suffix}-reseller@example.invalid`)}, 'D9C Reseller', 'reseller', 'active'),
  (${q(x.financeA)}, ${q(`d9c_${suffix}_finance_a`)}, ${q(`d9c-${suffix}-finance-a@example.invalid`)}, 'D9C Finance A', 'customer', 'active'),
  (${q(x.financeB)}, ${q(`d9c_${suffix}_finance_b`)}, ${q(`d9c-${suffix}-finance-b@example.invalid`)}, 'D9C Finance B', 'customer', 'active');
insert into public.admin_staff(profile_id, admin_role, permissions, staff_status)
values (${q(x.financeA)}, 'finance_staff', '{}'::jsonb, 'active'), (${q(x.financeB)}, 'finance_staff', '{}'::jsonb, 'active');
insert into public.customers(id, profile_id, customer_status) values (${q(x.customer)}, ${q(x.customerProfile)}, 'active');
insert into public.suppliers(id, owner_profile_id, business_name, supplier_status, verification_status)
values (${q(x.supplier)}, ${q(x.supplierProfile)}, ${q(`D9C Supplier ${suffix}`)}, 'active', 'approved');
insert into public.resellers(id, profile_id, reseller_type, approval_status, payout_status, commission_available_amount, commission_pending_amount, commission_pending_withdrawal_amount, commission_withdrawn_amount)
values (${q(x.reseller)}, ${q(x.resellerProfile)}, 'individual', 'approved', 'active', ${resellerAvailable}, ${resellerPending}, 0, 0);
insert into public.reseller_shops(id, reseller_id, shop_slug, display_name, shop_status, visibility)
values (${q(x.shop)}, ${q(x.reseller)}, ${q(`d9c-${suffix}`)}, 'D9C Shop', 'active', 'public');
insert into public.products(id, supplier_id, category, name, slug, product_status, approval_status, base_price_amount, platform_margin_amount, max_reseller_margin_amount, currency_code)
values (${q(x.product)}, ${q(x.supplier)}, 'D9C', 'D9C Product', ${q(`d9c-product-${suffix}`)}, 'active', 'approved', 100, 20, 30, 'GHS');
insert into public.product_variants(id, product_id, sku, variant_name, total_stock_quantity, reserved_stock_quantity, sold_stock_quantity, variant_status)
values (${q(x.variant)}, ${q(x.product)}, ${q(`D9C-${suffix}`)}, 'D9C', 20, 1, 0, 'active');
insert into public.reseller_products(id, reseller_id, shop_id, product_id, variant_id, listing_status, reseller_margin_amount, customer_product_price_amount, share_slug)
values (${q(x.listing)}, ${q(x.reseller)}, ${q(x.shop)}, ${q(x.product)}, ${q(x.variant)}, 'active', 30, 150, ${q(`d9c-listing-${suffix}`)});
insert into public.orders(id, order_number, customer_id, reseller_id, shop_id, order_status, payment_collection_status, delivery_status, subtotal_product_amount, final_delivery_amount, total_payable_amount, currency_code, completed_at)
values (${q(x.order)}, ${q(`D9C-${orderRef.toUpperCase()}`)}, ${q(x.customer)}, ${q(x.reseller)}, ${q(x.shop)}, ${q(orderStatus)}, ${q(paymentStatus)}, 'delivered', 150, 0, 150, 'GHS', ${options.verified ? "now()" : "null"});
insert into public.order_items(id, order_id, supplier_id, product_id, variant_id, reseller_product_id, quantity, supplier_base_price_snapshot_amount, platform_margin_snapshot_amount, reseller_margin_snapshot_amount, reseller_cost_snapshot_amount, customer_product_price_snapshot_amount, line_total_amount, settlement_due_amount, commission_amount)
values (${q(x.item)}, ${q(x.order)}, ${q(x.supplier)}, ${q(x.product)}, ${q(x.variant)}, ${q(x.listing)}, 1, 100, 20, 30, 120, 150, 150, 50, 30);
insert into public.stock_reservations(id, reservation_reference, customer_id, reseller_id, reseller_product_id, product_id, variant_id, order_id, quantity, reservation_status, expires_at, committed_at)
values (${q(x.reservation)}, ${q(`D9C-RES-${suffix}`)}, ${q(x.customer)}, ${q(x.reseller)}, ${q(x.listing)}, ${q(x.product)}, ${q(x.variant)}, ${q(x.order)}, 1, 'committed', now() + interval '1 day', now());
insert into public.settlements(id, supplier_id, order_id, settlement_status, due_amount, paid_amount, outstanding_amount, verified_at)
values (${q(x.settlement)}, ${q(x.supplier)}, ${q(x.order)}, ${q(settlementStatus)}, 50, ${options.verified ? "50" : "0"}, ${options.verified ? "0" : "50"}, ${options.verified ? "now()" : "null"});
insert into public.supplier_payment_reports(order_id, supplier_id, reported_by_profile_id, reported_amount, currency_code, idempotency_key)
values (${q(x.order)}, ${q(x.supplier)}, ${q(x.supplierProfile)}, 150, 'GHS', ${q(`d9c-pay-${suffix}`)});
insert into public.commissions(id, reseller_id, order_id, order_item_id, settlement_id, commission_status, commission_amount, available_at)
values (${q(x.commission)}, ${q(x.reseller)}, ${q(x.order)}, ${q(x.item)}, ${q(x.settlement)}, ${q(commissionStatus)}, 30, ${options.verified ? "now()" : "null"});
insert into public.order_disputes(id, order_id, opened_by_profile_id, opened_by_role, dispute_category, reason_code, requested_outcome, status, finance_review_required, scope_type, affected_supplier_id, affected_order_item_id)
values (${q(x.dispute)}, ${q(x.order)}, ${q(x.customerProfile)}, 'customer', 'post_completion', 'refund_requested', 'partial_refund', ${q(options.closed ? "closed" : "under_review")}, ${options.closed ? "false" : "true"}, 'order_item', ${q(x.supplier)}, ${q(x.item)});
insert into public.order_refunds(id, dispute_id, order_id, order_item_id, customer_profile_id, affected_supplier_id, refund_type, status, responsibility_code, responsible_party_role, approved_amount, currency_code, item_amount_component, delivery_fee_component, goodwill_component, approved_by_profile_id, verified_by_profile_id, verified_at)
values (${q(x.refund)}, ${q(x.dispute)}, ${q(x.order)}, ${q(x.item)}, ${q(x.customerProfile)}, ${q(x.supplier)}, 'partial_refund', 'verified', 'supplier_responsible', 'supplier', 30, 'GHS', 30, 0, 0, ${q(x.financeA)}, ${q(x.financeA)}, now());
${options.pendingWithdrawal ? `insert into public.reseller_payout_accounts(id, reseller_id, payout_method, mobile_money_network, account_name, phone_number, account_status, is_default) values (${q(x.payoutAccount)}, ${q(x.reseller)}, 'mobile_money', 'mtn_momo', 'D9C Payout', '+233000000000', 'active', true);
insert into public.withdrawals(id, reseller_id, requested_amount, withdrawal_status, payout_account_id, currency_code, request_reference, requested_by_profile_id) values (${q(x.withdrawal)}, ${q(x.reseller)}, 30, 'requested', ${q(x.payoutAccount)}, 'GHS', ${q(`D9C-WD-${suffix}`)}, ${q(x.resellerProfile)});
update public.resellers set commission_available_amount = commission_available_amount - 30, commission_pending_withdrawal_amount = commission_pending_withdrawal_amount + 30 where id = ${q(x.reseller)};` : ""}
commit;
`;
}

function cleanupSql(x) {
  const profileIds = [x.customerProfile, x.supplierProfile, x.resellerProfile, x.financeA, x.financeB].map(q).join(",");
  return `
begin;
delete from public.finance_actions where actor_profile_id in (${profileIds}) or target_entity_id in (${[x.dispute, x.settlement, x.commission, x.withdrawal].map(q).join(",")});
delete from public.finance_adjustments where dispute_id = ${q(x.dispute)} or order_id = ${q(x.order)};
delete from public.finance_holds where dispute_id = ${q(x.dispute)} or order_id = ${q(x.order)};
delete from public.refund_actions where dispute_id = ${q(x.dispute)} or refund_id = ${q(x.refund)};
delete from public.order_refunds where id = ${q(x.refund)};
delete from public.audit_logs where actor_profile_id in (${profileIds}) or target_entity_id in (${[x.order, x.settlement, x.commission, x.withdrawal, x.dispute].map(q).join(",")});
delete from public.withdrawals where id = ${q(x.withdrawal)} or reseller_id = ${q(x.reseller)};
delete from public.supplier_payment_reports where order_id = ${q(x.order)};
delete from public.commissions where id = ${q(x.commission)};
delete from public.settlements where id = ${q(x.settlement)};
delete from public.stock_reservations where id = ${q(x.reservation)};
delete from public.order_disputes where id = ${q(x.dispute)};
delete from public.order_items where id = ${q(x.item)};
delete from public.orders where id = ${q(x.order)};
delete from public.reseller_products where id = ${q(x.listing)};
delete from public.product_variants where id = ${q(x.variant)};
delete from public.products where id = ${q(x.product)};
delete from public.reseller_shops where id = ${q(x.shop)};
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
    raise exception 'D9 concurrency invariant failed: ${label}';
  end if;
end;
$$;
`);
  console.log(`PASS ${label}`);
}

async function scenario(label, options, leftSql, rightSql, invariantSql) {
  const x = ids();
  try {
    await runSql(`${label}-setup`, setupSql(label, x, options));
    const outcomes = await Promise.allSettled([
      runSql(`${label}-left`, context(clerk(label, "finance_a"), leftSql(x)), true),
      runSql(`${label}-right`, context(clerk(label, "finance_b"), rightSql(x)), true),
    ]);
    const participantErrors = outcomes
      .map((outcome) => (outcome.status === "fulfilled" && !outcome.value.ok ? outcome.value.stderr || outcome.value.stdout || outcome.value.message : ""))
      .filter(Boolean);
    if (participantErrors.length === outcomes.length) {
      console.error(`FAILED PARTICIPANTS ${label}: ${participantErrors.join(" | ")}`);
    }
    await expectInvariant(label, invariantSql(x));
  } finally {
    await runSql(`${label}-cleanup`, cleanupSql(x), true);
  }
}

try {
  await scenario(
    "a_same_key_approval",
    {},
    (x) => `select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'same-key');`,
    (x) => `select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'same-key');`,
    (x) => `(select count(*) from public.finance_holds where dispute_id = ${q(x.dispute)}::uuid and hold_type = 'settlement_verification_block') = 1`
  );

  await scenario(
    "b_same_scope_different_keys",
    {},
    (x) => `select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'scope-key-a');`,
    (x) => `select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'scope-key-b');`,
    (x) => `(select count(*) from public.finance_holds where dispute_id = ${q(x.dispute)}::uuid and hold_type = 'settlement_verification_block' and status = 'active') = 1`
  );

  await scenario(
    "c_settlement_vs_hold",
    {},
    (x) => `select count(*) from public.admin_verify_supplier_settlement(${q(x.order)}::uuid, 'D9C-RACE', null, 'verify-race');`,
    (x) => `select pg_sleep(0.05); select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'hold-race');`,
    (x) => `not (exists (select 1 from public.settlements where id = ${q(x.settlement)}::uuid and settlement_status = 'paid') and exists (select 1 from public.finance_holds where dispute_id = ${q(x.dispute)}::uuid and hold_type = 'settlement_verification_block' and status = 'active'))`
  );

  // Custom release-vs-verify setup because the hold must exist before racing.
  {
    const x = ids();
    try {
      await runSql("d_release_vs_verify-setup", setupSql("d_release_vs_verify", x, {}));
      await runSql("d_release_vs_verify-prehold", context(clerk("d_release_vs_verify", "finance_a"), `
select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'prehold-key');
`));
      await runSql("d_release_vs_verify-close", `update public.order_disputes set finance_review_required = false, status = 'closed', closed_at = now() where id = ${q(x.dispute)}::uuid;`);
      await Promise.allSettled([
        runSql("d_release_vs_verify-left", context(clerk("d_release_vs_verify", "finance_a"), `select count(*) from public.finance_release_dispute_hold((select id from public.finance_holds where dispute_id = ${q(x.dispute)}::uuid limit 1), null, null, 'release-race');`), true),
        runSql("d_release_vs_verify-right", context(clerk("d_release_vs_verify", "finance_b"), `select count(*) from public.admin_verify_supplier_settlement(${q(x.order)}::uuid, 'D9C-REL', null, 'verify-after-release');`), true),
      ]);
      await expectInvariant("d_release_vs_verify", `(select count(*) from public.finance_holds where dispute_id = ${q(x.dispute)}::uuid and status in ('active','released')) = 1 and not exists (select 1 from public.commissions where id = ${q(x.commission)}::uuid and commission_status = 'available' and exists (select 1 from public.finance_holds where dispute_id = ${q(x.dispute)}::uuid and status = 'active'))`);
    } finally {
      await runSql("d_release_vs_verify-cleanup", cleanupSql(x), true);
    }
  }

  await scenario(
    "e_commission_hold_vs_withdrawal",
    { verified: true },
    (x) => `select count(*) from public.finance_hold_reseller_commission(${q(x.commission)}::uuid, ${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'approved_refund', null, null, 'commission-hold-race');`,
    () => `select set_config('request.jwt.claims', jsonb_build_object('sub', ${q(clerk("e_commission_hold_vs_withdrawal", "reseller"))}, 'role', 'authenticated')::text, true); set local role authenticated; with acct as (select payout_account_id from public.reseller_upsert_payout_account('D9C Payout', 'mtn_momo', '+233000000000', 'withdrawal-race-account')) select count(*) from public.reseller_request_withdrawal(50, (select payout_account_id from acct), 'withdrawal-race');`,
    (x) => `not exists (select 1 from public.withdrawals where reseller_id = ${q(x.reseller)}::uuid and request_idempotency_key = 'withdrawal-race')`
  );

  await scenario(
    "f_two_finance_hold_types",
    {},
    (x) => `select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'hold-type-a');`,
    (x) => `select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'refund_accounting_hold', 'approved_refund', null, null, 'hold-type-b');`,
    (x) => `(select count(*) from public.finance_holds where dispute_id = ${q(x.dispute)}::uuid and status = 'active') = 2`
  );

  {
    const x = ids();
    try {
      await runSql("g_release_vs_cancel-setup", setupSql("g_release_vs_cancel", x, {}));
      await runSql("g_release_vs_cancel-prehold", context(clerk("g_release_vs_cancel", "finance_a"), `select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'settlement_verification_block', 'approved_refund', null, null, 'prehold-key');`));
      await runSql("g_release_vs_cancel-close", `update public.order_disputes set finance_review_required = false, status = 'closed', closed_at = now() where id = ${q(x.dispute)}::uuid;`);
      await Promise.allSettled([
        runSql("g_release_vs_cancel-left", context(clerk("g_release_vs_cancel", "finance_a"), `select count(*) from public.finance_release_dispute_hold((select hold_id from public.list_finance_holds_safe('active', 10) where dispute_id = ${q(x.dispute)}::uuid limit 1), null, null, 'release-key');`), true),
        runSql("g_release_vs_cancel-right", context(clerk("g_release_vs_cancel", "finance_b"), `select count(*) from public.finance_cancel_dispute_hold((select hold_id from public.list_finance_holds_safe('active', 10) where dispute_id = ${q(x.dispute)}::uuid limit 1), null, null, 'cancel-key');`), true),
      ]);
      await expectInvariant("g_release_vs_cancel", `(select count(*) from public.finance_holds where dispute_id = ${q(x.dispute)}::uuid and status in ('released','cancelled')) = 1`);
    } finally {
      await runSql("g_release_vs_cancel-cleanup", cleanupSql(x), true);
    }
  }

  await scenario(
    "h_hold_vs_withdrawal_payout",
    { verified: true, pendingWithdrawal: true },
    (x) => `select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'withdrawal_review_hold', 'manual_finance_review', null, null, 'withdrawal-review-hold');`,
    (x) => `select pg_sleep(0.05); select count(*) from public.admin_mark_reseller_withdrawal_paid(${q(x.withdrawal)}::uuid, 'D9C-PAYOUT', null, 'payout-race');`,
    (x) => `not (exists (select 1 from public.finance_holds where dispute_id = ${q(x.dispute)}::uuid and hold_type = 'withdrawal_review_hold' and status = 'active') and exists (select 1 from public.withdrawals where id = ${q(x.withdrawal)}::uuid and withdrawal_status = 'paid'))`
  );

  await scenario(
    "i_two_supplier_liabilities",
    { verified: true },
    (x) => `select count(*) from public.finance_review_disputed_settlement(${q(x.settlement)}::uuid, 'create_supplier_liability', null, null, 'liability-a');`,
    (x) => `select count(*) from public.finance_review_disputed_settlement(${q(x.settlement)}::uuid, 'create_supplier_liability', null, null, 'liability-b');`,
    (x) => `(select count(*) from public.finance_adjustments where refund_id = ${q(x.refund)}::uuid and adjustment_type = 'supplier_liability') = 1`
  );

  {
    const x = ids();
    try {
      await runSql("j_apply_vs_cancel-setup", setupSql("j_apply_vs_cancel", x, { verified: true }));
      await runSql("j_apply_vs_cancel-adjust", context(clerk("j_apply_vs_cancel", "finance_a"), `select count(*) from public.finance_review_disputed_settlement(${q(x.settlement)}::uuid, 'require_manual_accounting_review', null, null, 'manual-review');`));
      await Promise.allSettled([
        runSql("j_apply_vs_cancel-left", context(clerk("j_apply_vs_cancel", "finance_a"), `select count(*) from public.finance_apply_adjustment((select adjustment_id from public.list_finance_adjustments_safe('proposed', 10) where dispute_id = ${q(x.dispute)}::uuid limit 1), null, null, 'apply-key');`), true),
        runSql("j_apply_vs_cancel-right", context(clerk("j_apply_vs_cancel", "finance_b"), `select count(*) from public.finance_cancel_adjustment((select adjustment_id from public.list_finance_adjustments_safe('proposed', 10) where dispute_id = ${q(x.dispute)}::uuid limit 1), null, null, 'cancel-key');`), true),
      ]);
      await expectInvariant("j_apply_vs_cancel", `(select count(*) from public.finance_adjustments where dispute_id = ${q(x.dispute)}::uuid and status in ('applied','cancelled')) = 1`);
    } finally {
      await runSql("j_apply_vs_cancel-cleanup", cleanupSql(x), true);
    }
  }

  await scenario(
    "k_settlement_review_vs_refund_state",
    { verified: true },
    (x) => `select count(*) from public.finance_review_disputed_settlement(${q(x.settlement)}::uuid, 'create_platform_liability', null, null, 'platform-liability');`,
    (x) => `select pg_sleep(0.05); update public.order_refunds set status = 'completed' where id = ${q(x.refund)}::uuid;`,
    (x) => `(select count(*) from public.finance_adjustments where dispute_id = ${q(x.dispute)}::uuid and adjustment_type = 'platform_liability') <= 1`
  );

  await scenario(
    "l_side_effect_invariants",
    {},
    (x) => `select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'refund_accounting_hold', 'approved_refund', null, null, 'side-effect-hold');`,
    (x) => `select count(*) from public.finance_create_dispute_hold(${q(x.dispute)}::uuid, ${q(x.refund)}::uuid, 'reseller_liability_review', 'reseller_responsibility_review', null, null, 'side-effect-review');`,
    (x) => `exists (select 1 from public.product_variants where id = ${q(x.variant)}::uuid and total_stock_quantity = 20 and reserved_stock_quantity = 1 and sold_stock_quantity = 0) and not exists (select 1 from public.inventory_movements where order_id = ${q(x.order)}::uuid)`
  );
} finally {
  await rm(tempDir, { recursive: true, force: true });
}
