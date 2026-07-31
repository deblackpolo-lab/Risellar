-- Fix ambiguous output-column reference in reseller_upsert_payout_account.
-- Forward-only patch for DEVELOPMENT-tested withdrawal Phase 1 RPCs.

create or replace function public.reseller_upsert_payout_account(
  p_account_name text,
  p_mobile_money_network text,
  p_phone_number text,
  p_idempotency_key text default null
)
returns table (
  payout_account_id uuid,
  payout_method text,
  account_name text,
  mobile_money_network text,
  phone_number_masked text,
  is_default boolean,
  account_status text
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
  v_account_id uuid;
  v_account_name text := nullif(trim(coalesce(p_account_name, '')), '');
  v_network text := nullif(trim(coalesce(p_mobile_money_network, '')), '');
  v_phone text := nullif(trim(coalesce(p_phone_number, '')), '');
begin
  v_reseller_id := public.current_verified_reseller_id();

  if v_account_name is null or length(v_account_name) > 120 then
    raise exception 'PAYOUT_ACCOUNT_REQUIRED' using errcode = '22023';
  end if;

  if v_network is null or v_network not in ('mtn_momo', 'telecel_cash', 'airteltigo_money') then
    raise exception 'PAYOUT_ACCOUNT_REQUIRED' using errcode = '22023';
  end if;

  if v_phone is null or length(v_phone) > 32 or v_phone !~ '^[+0-9 ()-]{7,32}$' then
    raise exception 'PAYOUT_ACCOUNT_REQUIRED' using errcode = '22023';
  end if;

  update public.reseller_payout_accounts as rpa
  set is_default = false,
      updated_at = now()
  where rpa.reseller_id = v_reseller_id
    and rpa.deleted_at is null
    and rpa.is_default is true;

  insert into public.reseller_payout_accounts(
    reseller_id,
    payout_method,
    account_name,
    mobile_money_network,
    phone_number,
    is_default,
    account_status
  )
  values (
    v_reseller_id,
    'mobile_money',
    v_account_name,
    v_network,
    v_phone,
    true,
    'active'
  )
  returning id into v_account_id;

  perform public.create_audit_log_entry(
    'reseller_payout_account_saved',
    'reseller_payout_accounts',
    v_account_id,
    'reseller_saved_withdrawal_account',
    null,
    jsonb_build_object(
      'reseller_id', v_reseller_id,
      'payout_method', 'mobile_money',
      'mobile_money_network', v_network,
      'phone_masked', public.mask_payout_value(v_phone),
      'idempotency_key_present', p_idempotency_key is not null
    )
  );

  return query
  select
    a.id,
    a.payout_method,
    a.account_name,
    a.mobile_money_network,
    public.mask_payout_value(a.phone_number),
    a.is_default,
    a.account_status::text
  from public.reseller_payout_accounts a
  where a.id = v_account_id;
end;
$fn$;

revoke all on function public.reseller_upsert_payout_account(text, text, text, text) from public, anon, authenticated;
grant execute on function public.reseller_upsert_payout_account(text, text, text, text) to authenticated;

comment on function public.reseller_upsert_payout_account(text, text, text, text)
  is 'Reseller-owner payout account setup for withdrawal requests. Uses qualified table aliases so output column names cannot shadow table columns.';
