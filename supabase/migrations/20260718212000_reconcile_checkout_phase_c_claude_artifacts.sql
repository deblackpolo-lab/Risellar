-- Checkout Phase C reconciliation cleanup for verified Claude-era DEVELOPMENT artifacts.
-- This migration is guarded for contaminated DEVELOPMENT and clean environments.
-- It must run before the approved create_order_from_checkout_draft migration.

do $$
declare
  v_count bigint;
  v_column text;
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'orders'
      and column_name = 'expires_at'
  ) then
    execute 'select count(*) from public.orders where expires_at is not null'
      into v_count;

    if v_count > 0 then
      raise exception 'CLAUDE_EXPIRES_AT_DATA_REQUIRES_BACKUP'
        using errcode = 'P0001',
              detail = 'orders.expires_at has populated DEVELOPMENT rows; back up and approve data handling before cleanup apply.';
    end if;
  end if;

  foreach v_column in array array[
    'prepared_at',
    'ready_at',
    'dispatched_at',
    'out_for_delivery_at',
    'delivered_at',
    'delivery_person_id'
  ]
  loop
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'orders'
        and column_name = v_column
    ) then
      execute format('select count(*) from public.orders where %I is not null', v_column)
        into v_count;

      if v_count > 0 then
        raise exception 'CLAUDE_PREP_DELIVERY_DATA_REQUIRES_REVIEW'
          using errcode = 'P0001',
                detail = format('public.orders.%I has populated rows and must be reviewed before cleanup apply.', v_column);
      end if;
    end if;
  end loop;

  if to_regclass('public.stock_reservations') is not null then
    execute 'select count(*) from public.stock_reservations where order_id is not null'
      into v_count;

    if v_count > 0 then
      raise exception 'CLAUDE_STOCK_RESERVATION_DEPENDENCY_REQUIRES_REVIEW'
        using errcode = 'P0001',
              detail = 'Order-linked stock reservations exist; review before Claude artifact cleanup apply.';
    end if;
  end if;

  if to_regclass('public.delivery_quotes') is not null then
    execute 'select count(*) from public.delivery_quotes'
      into v_count;

    if v_count > 0 then
      raise exception 'CLAUDE_DELIVERY_QUOTE_DEPENDENCY_REQUIRES_REVIEW'
        using errcode = 'P0001',
              detail = 'Delivery quote rows exist; review before Claude artifact cleanup apply.';
    end if;
  end if;

  if to_regclass('public.commissions') is not null then
    execute 'select count(*) from public.commissions'
      into v_count;

    if v_count > 0 then
      raise exception 'CLAUDE_COMMISSION_DEPENDENCY_REQUIRES_REVIEW'
        using errcode = 'P0001',
              detail = 'Commission rows exist; review before Claude artifact cleanup apply.';
    end if;
  end if;

  if to_regclass('public.settlements') is not null then
    execute 'select count(*) from public.settlements'
      into v_count;

    if v_count > 0 then
      raise exception 'CLAUDE_SETTLEMENT_DEPENDENCY_REQUIRES_REVIEW'
        using errcode = 'P0001',
              detail = 'Settlement rows exist; review before Claude artifact cleanup apply.';
    end if;
  end if;
end;
$$;

do $$
begin
  if to_regprocedure('public.create_order_from_draft(uuid)') is not null then
    revoke execute on function public.create_order_from_draft(uuid) from public;
    revoke execute on function public.create_order_from_draft(uuid) from anon;
    revoke execute on function public.create_order_from_draft(uuid) from authenticated;
    drop function public.create_order_from_draft(uuid);
  end if;

  if to_regprocedure('public.prepare_supplier_for_order(uuid,text)') is not null then
    revoke execute on function public.prepare_supplier_for_order(uuid, text) from public;
    revoke execute on function public.prepare_supplier_for_order(uuid, text) from anon;
    revoke execute on function public.prepare_supplier_for_order(uuid, text) from authenticated;
    drop function public.prepare_supplier_for_order(uuid, text);
  end if;
end;
$$;

drop index if exists public.idx_orders_expires_confirm_pending;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'orders'
      and column_name = 'expires_at'
  ) then
    alter table public.orders drop column expires_at;
  end if;

  alter table public.orders
    drop column if exists prepared_at,
    drop column if exists ready_at,
    drop column if exists dispatched_at,
    drop column if exists out_for_delivery_at,
    drop column if exists delivered_at,
    drop column if exists delivery_person_id;
end;
$$;
