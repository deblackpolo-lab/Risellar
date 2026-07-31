-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Reseller withdrawal idempotency/concurrency guard.
-- Uses transaction-scoped fake fixture rows and rolls back all changes.

begin;

create temp table reseller_withdrawal_concurrency_results (
  test_name text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on reseller_withdrawal_concurrency_results to authenticated;

create or replace function pg_temp.reseller_withdrawal_concurrency_record(
  p_test_name text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into reseller_withdrawal_concurrency_results(test_name, passed, details)
  values (p_test_name, coalesce(p_passed, false), p_details)
  on conflict (test_name) do update
    set passed = excluded.passed,
        details = excluded.details;
end;
$$;

create or replace function pg_temp.reseller_withdrawal_concurrency_set_context(p_clerk_user_id text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_clerk_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

create or replace function pg_temp.reseller_withdrawal_concurrency_reset_context()
returns void
language plpgsql
as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}'::text, true);
end;
$$;

create or replace function pg_temp.reseller_withdrawal_concurrency_expect_blocked(
  p_test_name text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  perform pg_temp.reseller_withdrawal_concurrency_record(p_test_name, false, 'operation unexpectedly succeeded');
exception when others then
  perform pg_temp.reseller_withdrawal_concurrency_record(p_test_name, true, sqlerrm);
end;
$$;

do $$
declare
  v_reseller_profile_id uuid := gen_random_uuid();
  v_finance_profile_id uuid := gen_random_uuid();
  v_reseller_id uuid := gen_random_uuid();
  v_payout_account_id uuid;
  v_withdrawal_id uuid;
  v_retry_withdrawal_id uuid;
  v_available_after_first numeric;
  v_available_after_retry numeric;
  v_pending_after_first numeric;
  v_pending_after_retry numeric;
  v_withdrawn_after_paid numeric;
  v_withdrawn_after_retry numeric;
  v_paid_at_first timestamptz;
  v_paid_at_retry timestamptz;
  v_request_audit_after_first bigint;
  v_request_audit_after_retry bigint;
  v_paid_audit_after_first bigint;
  v_paid_audit_after_retry bigint;
begin
  perform pg_temp.reseller_withdrawal_concurrency_reset_context();

  insert into public.profiles(id, clerk_user_id, email, full_name, primary_role, account_status)
  values
    (v_reseller_profile_id, 'dev_withdrawal_concurrency_reseller', 'dev-withdrawal-concurrency-reseller@example.invalid', 'Dev Withdrawal Concurrency Reseller', 'reseller', 'active'),
    (v_finance_profile_id, 'dev_withdrawal_concurrency_finance', 'dev-withdrawal-concurrency-finance@example.invalid', 'Dev Withdrawal Concurrency Finance', 'customer', 'active');

  insert into public.admin_staff(profile_id, admin_role, permissions, staff_status)
  values (v_finance_profile_id, 'finance_staff', '{}'::jsonb, 'active');

  insert into public.resellers(
    id,
    profile_id,
    reseller_type,
    approval_status,
    payout_status,
    commission_available_amount,
    commission_pending_amount,
    commission_pending_withdrawal_amount,
    commission_withdrawn_amount,
    payout_details_masked
  )
  values (v_reseller_id, v_reseller_profile_id, 'individual', 'approved', 'active', 100.00, 0, 0, 0, '{}'::jsonb);

  insert into public.reseller_payout_accounts(reseller_id, payout_method, account_name, mobile_money_network, phone_number, is_default, account_status)
  values (v_reseller_id, 'mobile_money', 'Dev Withdrawal Concurrency Account', 'mtn_momo', '+233000000000', true, 'active')
  returning id into v_payout_account_id;

  perform pg_temp.reseller_withdrawal_concurrency_set_context('dev_withdrawal_concurrency_reseller');

  select withdrawal_id
  into v_withdrawal_id
  from public.reseller_request_withdrawal(40.00, v_payout_account_id, 'dev-withdrawal-concurrency-request-key');

  select commission_available_amount, commission_pending_withdrawal_amount
  into v_available_after_first, v_pending_after_first
  from public.resellers
  where id = v_reseller_id;

  perform pg_temp.reseller_withdrawal_concurrency_reset_context();

  select count(*) into v_request_audit_after_first
  from public.audit_logs
  where target_entity_id = v_withdrawal_id
    and action = 'reseller_withdrawal_requested';

  perform pg_temp.reseller_withdrawal_concurrency_set_context('dev_withdrawal_concurrency_reseller');

  select withdrawal_id
  into v_retry_withdrawal_id
  from public.reseller_request_withdrawal(40.00, v_payout_account_id, 'dev-withdrawal-concurrency-request-key');

  select commission_available_amount, commission_pending_withdrawal_amount
  into v_available_after_retry, v_pending_after_retry
  from public.resellers
  where id = v_reseller_id;

  perform pg_temp.reseller_withdrawal_concurrency_reset_context();

  select count(*) into v_request_audit_after_retry
  from public.audit_logs
  where target_entity_id = v_withdrawal_id
    and action = 'reseller_withdrawal_requested';

  perform pg_temp.reseller_withdrawal_concurrency_record('same-key request returns same withdrawal', v_retry_withdrawal_id = v_withdrawal_id);
  perform pg_temp.reseller_withdrawal_concurrency_record('same-key request does not deduct twice', v_available_after_retry = v_available_after_first and v_available_after_retry = 60.00);
  perform pg_temp.reseller_withdrawal_concurrency_record('same-key request does not reserve twice', v_pending_after_retry = v_pending_after_first and v_pending_after_retry = 40.00);
  perform pg_temp.reseller_withdrawal_concurrency_record('same-key request creates one audit event', v_request_audit_after_retry = v_request_audit_after_first and v_request_audit_after_retry = 1);

  perform pg_temp.reseller_withdrawal_concurrency_set_context('dev_withdrawal_concurrency_finance');

  select paid_at, withdrawn_amount
  into v_paid_at_first, v_withdrawn_after_paid
  from public.admin_mark_reseller_withdrawal_paid(v_withdrawal_id, 'DEV-WITHDRAWAL-CONCURRENCY-PAYOUT', null, 'dev-withdrawal-concurrency-payout-key');

  perform pg_temp.reseller_withdrawal_concurrency_reset_context();

  select count(*) into v_paid_audit_after_first
  from public.audit_logs
  where target_entity_id = v_withdrawal_id
    and action = 'reseller_withdrawal_paid';

  perform pg_temp.reseller_withdrawal_concurrency_set_context('dev_withdrawal_concurrency_finance');

  select paid_at, withdrawn_amount
  into v_paid_at_retry, v_withdrawn_after_retry
  from public.admin_mark_reseller_withdrawal_paid(v_withdrawal_id, 'DEV-WITHDRAWAL-CONCURRENCY-PAYOUT', null, 'dev-withdrawal-concurrency-payout-key');

  perform pg_temp.reseller_withdrawal_concurrency_reset_context();

  select count(*) into v_paid_audit_after_retry
  from public.audit_logs
  where target_entity_id = v_withdrawal_id
    and action = 'reseller_withdrawal_paid';

  perform pg_temp.reseller_withdrawal_concurrency_record('same-key payout preserves paid timestamp', v_paid_at_retry = v_paid_at_first);
  perform pg_temp.reseller_withdrawal_concurrency_record('same-key payout does not credit withdrawn twice', v_withdrawn_after_retry = v_withdrawn_after_paid and v_withdrawn_after_retry = 40.00);
  perform pg_temp.reseller_withdrawal_concurrency_record('same-key payout creates one audit event', v_paid_audit_after_retry = v_paid_audit_after_first and v_paid_audit_after_retry = 1);

  perform pg_temp.reseller_withdrawal_concurrency_set_context('dev_withdrawal_concurrency_finance');

  perform pg_temp.reseller_withdrawal_concurrency_expect_blocked(
    'paid conflicting retry blocked',
    format($sql$select count(*) from public.admin_mark_reseller_withdrawal_paid(%L::uuid, 'DEV-WITHDRAWAL-CONFLICT', null, 'dev-withdrawal-concurrency-payout-key')$sql$, v_withdrawal_id)
  );
end;
$$;

select *
from reseller_withdrawal_concurrency_results
order by test_name;

do $$
begin
  if exists (select 1 from reseller_withdrawal_concurrency_results where not passed) then
    raise exception 'Reseller withdrawal concurrency tests failed';
  end if;
end;
$$;

rollback;
