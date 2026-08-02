-- D9 forward patch: withdrawals has no deleted_at column, so the requested-state
-- guard must rely on withdrawal_status only.

create or replace function public.finance_d9_assert_withdrawal_review_hold_requested()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
begin
  if new.status <> 'active' or new.hold_type <> 'withdrawal_review_hold' then
    return new;
  end if;

  select r.id
  into v_reseller_id
  from public.resellers r
  left join public.commissions cm on cm.id = new.commission_id
  left join public.orders o on o.id = new.order_id
  where r.deleted_at is null
    and (
      r.profile_id = new.reseller_profile_id
      or cm.reseller_id = r.id
      or o.reseller_id = r.id
    )
  order by r.created_at asc, r.id::text asc
  limit 1;

  if v_reseller_id is null then
    raise exception 'RESELLER_HOLD_TARGET_REQUIRED' using errcode = '23514';
  end if;

  perform 1
  from public.withdrawals w
  where w.reseller_id = v_reseller_id
    and w.withdrawal_status = 'requested'
  for update;

  if not found then
    raise exception 'WITHDRAWAL_REVIEW_NOT_AVAILABLE' using errcode = '23514';
  end if;

  return new;
end;
$fn$;

revoke all on function public.finance_d9_assert_withdrawal_review_hold_requested() from public, anon, authenticated;
