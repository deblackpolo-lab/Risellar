-- D9 forward patch: make reseller hold projection resilient to historical/derived
-- finance holds by resolving reseller ownership through direct, commission, or order links.

create or replace function public.finance_d9_active_reseller_hold_amount(p_reseller_profile_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select round(coalesce(sum(fh.amount), 0), 2)
  from public.finance_holds fh
  where fh.status = 'active'
    and fh.deleted_at is null
    and fh.hold_type in ('commission_availability_hold', 'reseller_liability_review', 'withdrawal_review_hold')
    and exists (
      select 1
      from public.resellers r
      left join public.commissions cm on cm.id = fh.commission_id
      left join public.orders o on o.id = fh.order_id
      where r.profile_id = p_reseller_profile_id
        and r.deleted_at is null
        and (
          fh.reseller_profile_id = r.profile_id
          or cm.reseller_id = r.id
          or o.reseller_id = r.id
        )
    );
$$;

create or replace function public.get_reseller_finance_hold_impact_safe()
returns table (
  active_hold_count bigint,
  held_amount numeric,
  currency_code text,
  review_status text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_reseller_id uuid;
begin
  v_reseller_id := public.current_verified_reseller_id();

  return query
  select
    count(fh.id)::bigint,
    round(coalesce(sum(fh.amount), 0), 2),
    coalesce(min(fh.currency_code), 'GHS'::text),
    case when count(fh.id) > 0 then 'review_required' else 'clear' end
  from public.finance_holds fh
  left join public.commissions cm on cm.id = fh.commission_id
  left join public.orders o on o.id = fh.order_id
  where fh.status = 'active'
    and fh.deleted_at is null
    and fh.hold_type in ('commission_availability_hold', 'reseller_liability_review', 'withdrawal_review_hold')
    and exists (
      select 1
      from public.resellers r
      where r.id = v_reseller_id
        and r.deleted_at is null
        and (
          fh.reseller_profile_id = r.profile_id
          or cm.reseller_id = r.id
          or o.reseller_id = r.id
        )
    );
end;
$fn$;

revoke all on function public.finance_d9_active_reseller_hold_amount(uuid) from public, anon, authenticated;
revoke all on function public.get_reseller_finance_hold_impact_safe() from public, anon, authenticated;
grant execute on function public.get_reseller_finance_hold_impact_safe() to authenticated;
