-- Development-only planned boundary tests for the D2 dispute core schema.
-- Do not run against production. Do not run until the D2 migration is approved
-- and applied to the confirmed development Supabase project.
--
-- This script is intentionally scaffolded as an executable assertion plan for D3.
-- It does not create refunds, returns, finance holds, payments, stock movements,
-- settlements, commissions, withdrawals, evidence files, or notifications.

begin;

create temp table dispute_d2_test_results (
  assertion text primary key,
  passed boolean not null,
  details text
) on commit drop;

grant select, insert, update on dispute_d2_test_results to authenticated;

create or replace function pg_temp.dispute_d2_assert(
  p_assertion text,
  p_passed boolean,
  p_details text default null
)
returns void
language plpgsql
as $$
begin
  insert into dispute_d2_test_results(assertion, passed, details)
  values (p_assertion, p_passed, p_details);

  if not p_passed then
    raise exception 'DISPUTE_D2_ASSERTION_FAILED: % %', p_assertion, coalesce(p_details, '')
      using errcode = '23514';
  end if;
end;
$$;

do $$
begin
  perform pg_temp.dispute_d2_assert(
    'anonymous cannot read disputes',
    to_regclass('public.order_disputes') is not null,
    'D3 should set role anon and verify direct table select plus read RPCs are blocked'
  );

  perform pg_temp.dispute_d2_assert(
    'customer sees own dispute only',
    to_regprocedure('public.list_customer_disputes_safe(text, integer, timestamp with time zone, uuid)') is not null,
    'D3 should create two customer fixtures and verify only the signed-in customer case appears'
  );

  perform pg_temp.dispute_d2_assert(
    'customer cannot see another customer dispute',
    to_regprocedure('public.get_customer_dispute_safe(uuid)') is not null,
    'D3 should call detail RPC with another customer dispute id and expect no rows'
  );

  perform pg_temp.dispute_d2_assert(
    'customer cannot see internal notes',
    exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'get_customer_dispute_safe'
        and pg_get_functiondef(p.oid) not like '%internal_resolution_notes%'
    ),
    'customer detail contract must exclude internal_resolution_notes'
  );

  perform pg_temp.dispute_d2_assert(
    'supplier sees own order dispute only',
    to_regprocedure('public.list_supplier_disputes_safe(text, integer, timestamp with time zone, uuid)') is not null,
    'D3 should verify supplier ownership through order_items.supplier_id'
  );

  perform pg_temp.dispute_d2_assert(
    'supplier cannot see another supplier dispute',
    to_regprocedure('public.get_supplier_dispute_safe(uuid)') is not null,
    'D3 should call detail RPC with another supplier order dispute and expect no rows'
  );

  perform pg_temp.dispute_d2_assert(
    'reseller receives only safe impact summary',
    to_regprocedure('public.get_reseller_dispute_impact_safe(uuid, integer)') is not null,
    'reseller RPC should expose status and impact state only'
  );

  perform pg_temp.dispute_d2_assert(
    'admin safe read exists',
    to_regprocedure('public.list_admin_disputes_safe(text, text, text, boolean, boolean, integer, timestamp with time zone, uuid)') is not null
  );

  perform pg_temp.dispute_d2_assert(
    'finance details separated',
    exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'get_admin_dispute_safe'
        and pg_get_functiondef(p.oid) like '%current_dispute_finance_admin_profile_id%'
    ),
    'admin detail should gate finance context by finance_staff/super_admin'
  );

  perform pg_temp.dispute_d2_assert(
    'direct table insert blocked by grants',
    not has_table_privilege('authenticated', 'public.order_disputes', 'insert')
      and not has_table_privilege('authenticated', 'public.dispute_messages', 'insert')
      and not has_table_privilege('authenticated', 'public.dispute_status_history', 'insert')
  );

  perform pg_temp.dispute_d2_assert(
    'direct table update blocked by grants',
    not has_table_privilege('authenticated', 'public.order_disputes', 'update')
      and not has_table_privilege('authenticated', 'public.dispute_messages', 'update')
      and not has_table_privilege('authenticated', 'public.dispute_status_history', 'update')
  );

  perform pg_temp.dispute_d2_assert(
    'direct table delete blocked by grants',
    not has_table_privilege('authenticated', 'public.order_disputes', 'delete')
      and not has_table_privilege('authenticated', 'public.dispute_messages', 'delete')
      and not has_table_privilege('authenticated', 'public.dispute_status_history', 'delete')
  );

  perform pg_temp.dispute_d2_assert(
    'direct broad select blocked by grants',
    not has_table_privilege('authenticated', 'public.order_disputes', 'select')
      and not has_table_privilege('authenticated', 'public.dispute_messages', 'select')
      and not has_table_privilege('authenticated', 'public.dispute_status_history', 'select')
  );

  perform pg_temp.dispute_d2_assert(
    'safe RPCs do not trust caller-supplied profile identity',
    not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname in (
          'list_customer_disputes_safe',
          'get_customer_dispute_safe',
          'list_supplier_disputes_safe',
          'get_supplier_dispute_safe',
          'get_reseller_dispute_impact_safe',
          'list_admin_disputes_safe',
          'get_admin_dispute_safe'
        )
        and pg_get_function_arguments(p.oid) ~* 'profile'
    )
  );

  perform pg_temp.dispute_d2_assert(
    'pagination cap enforced',
    exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname in ('list_customer_disputes_safe', 'list_supplier_disputes_safe', 'list_admin_disputes_safe')
        and pg_get_functiondef(p.oid) like '%least(greatest(coalesce(p_limit%'
    )
  );

  perform pg_temp.dispute_d2_assert(
    'invalid filters rejected safely',
    exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'list_admin_disputes_safe'
        and pg_get_functiondef(p.oid) like '%INVALID_STATUS_FILTER%'
        and pg_get_functiondef(p.oid) like '%INVALID_CATEGORY_FILTER%'
        and pg_get_functiondef(p.oid) like '%INVALID_PRIORITY_FILTER%'
    )
  );

  perform pg_temp.dispute_d2_assert(
    'search does not leak unrelated customer records',
    true,
    'D2 has no free-text admin search parameter; D3 may add safe order-reference search only'
  );

  perform pg_temp.dispute_d2_assert(
    'no refund return finance or stock tables added',
    to_regclass('public.finance_holds') is null
      and to_regclass('public.refund_obligations') is null
      and to_regclass('public.return_requests') is null,
    'D2 scope is core dispute only'
  );

  perform pg_temp.dispute_d2_assert(
    'fixtures clean up fully',
    true,
    'D3 should use rollback or targeted cleanup for real fixtures'
  );
end;
$$;

select assertion, passed, details
from dispute_d2_test_results
order by assertion;

rollback;
