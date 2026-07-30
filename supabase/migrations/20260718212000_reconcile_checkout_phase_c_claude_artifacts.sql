-- Checkout Phase C reconciliation cleanup for verified Claude-era DEVELOPMENT artifacts.
-- This migration is guarded for contaminated DEVELOPMENT and clean environments.
-- It must run before the approved create_order_from_checkout_draft migration.

do $$
declare
  v_count bigint;
  v_updated_count bigint;
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

    if v_count <> 23 then
      raise exception 'CLAUDE_EXPIRES_AT_COUNT_MISMATCH'
        using errcode = 'P0001',
              detail = 'orders.expires_at non-null count differs from reviewed DEVELOPMENT backup evidence.';
    end if;

    execute $sql$
      select count(*)
      from public.orders
      where expires_at is not null
        and order_status <> 'placed_pending_confirmation'
    $sql$
      into v_count;

    if v_count <> 0 then
      raise exception 'CLAUDE_EXPIRES_AT_STATUS_MISMATCH'
        using errcode = 'P0001',
              detail = 'Reviewed orders.expires_at rows are not all placed_pending_confirmation.';
    end if;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'orders'
        and column_name = 'customer_confirmation_status'
    ) then
      execute $sql$
        select count(*)
        from public.orders
        where expires_at is not null
          and customer_confirmation_status <> 'pending'
      $sql$
        into v_count;

      if v_count <> 0 then
        raise exception 'CLAUDE_EXPIRES_AT_STATUS_MISMATCH'
          using errcode = 'P0001',
                detail = 'Reviewed orders.expires_at rows are not all pending customer confirmation.';
      end if;
    end if;

    execute 'select count(*) from public.orders where expires_at is not null and expires_at >= now()'
      into v_count;

    if v_count <> 0 then
      raise exception 'CLAUDE_EXPIRES_AT_NOT_FULLY_EXPIRED'
        using errcode = 'P0001',
              detail = 'Reviewed orders.expires_at rows are not all expired.';
    end if;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'orders'
        and column_name = 'confirmed_at'
    ) then
      execute 'select count(*) from public.orders where expires_at is not null and confirmed_at is not null'
        into v_count;

      if v_count <> 0 then
        raise exception 'CLAUDE_EXPIRES_AT_DEPENDENCY_FOUND'
          using errcode = 'P0001',
                detail = 'Reviewed orders.expires_at rows have confirmation data.';
      end if;
    end if;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'orders'
        and column_name = 'confirmation_source'
    ) then
      execute 'select count(*) from public.orders where expires_at is not null and confirmation_source is not null'
        into v_count;

      if v_count <> 0 then
        raise exception 'CLAUDE_EXPIRES_AT_DEPENDENCY_FOUND'
          using errcode = 'P0001',
                detail = 'Reviewed orders.expires_at rows have confirmation source data.';
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
        execute format('select count(*) from public.orders where expires_at is not null and %I is not null', v_column)
          into v_count;

        if v_count <> 0 then
          raise exception 'CLAUDE_EXPIRES_AT_DEPENDENCY_FOUND'
            using errcode = 'P0001',
                  detail = format('Reviewed orders.expires_at rows have populated public.orders.%I data.', v_column);
        end if;
      end if;
    end loop;

    if to_regclass('public.stock_reservations') is not null then
      execute $sql$
        select count(distinct o.id)
        from public.orders o
        join public.stock_reservations sr on sr.order_id = o.id
        where o.expires_at is not null
      $sql$
        into v_count;

      if v_count <> 0 then
        raise exception 'CLAUDE_EXPIRES_AT_DEPENDENCY_FOUND'
          using errcode = 'P0001',
                detail = 'Reviewed orders.expires_at rows are linked to stock reservations.';
      end if;
    end if;

    if to_regclass('public.delivery_quotes') is not null
      and exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'delivery_quotes'
          and column_name = 'order_id'
      )
    then
      execute $sql$
        select count(distinct o.id)
        from public.orders o
        join public.delivery_quotes dq on dq.order_id = o.id
        where o.expires_at is not null
      $sql$
        into v_count;

      if v_count <> 0 then
        raise exception 'CLAUDE_EXPIRES_AT_DEPENDENCY_FOUND'
          using errcode = 'P0001',
                detail = 'Reviewed orders.expires_at rows are linked to delivery quotes.';
      end if;
    end if;

    if to_regclass('public.commissions') is not null
      and exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'commissions'
          and column_name = 'order_item_id'
      )
      and to_regclass('public.order_items') is not null
    then
      execute $sql$
        select count(distinct o.id)
        from public.orders o
        join public.order_items oi on oi.order_id = o.id
        join public.commissions c on c.order_item_id = oi.id
        where o.expires_at is not null
      $sql$
        into v_count;

      if v_count <> 0 then
        raise exception 'CLAUDE_EXPIRES_AT_DEPENDENCY_FOUND'
          using errcode = 'P0001',
                detail = 'Reviewed orders.expires_at rows are linked to commissions.';
      end if;
    elsif to_regclass('public.commissions') is not null
      and exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'commissions'
          and column_name = 'order_id'
      )
    then
      execute $sql$
        select count(distinct o.id)
        from public.orders o
        join public.commissions c on c.order_id = o.id
        where o.expires_at is not null
      $sql$
        into v_count;

      if v_count <> 0 then
        raise exception 'CLAUDE_EXPIRES_AT_DEPENDENCY_FOUND'
          using errcode = 'P0001',
                detail = 'Reviewed orders.expires_at rows are linked to commissions.';
      end if;
    end if;

    if to_regclass('public.settlements') is not null
      and exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'settlements'
          and column_name = 'order_id'
      )
    then
      execute $sql$
        select count(distinct o.id)
        from public.orders o
        join public.settlements s on s.order_id = o.id
        where o.expires_at is not null
      $sql$
        into v_count;

      if v_count <> 0 then
        raise exception 'CLAUDE_EXPIRES_AT_DEPENDENCY_FOUND'
          using errcode = 'P0001',
                detail = 'Reviewed orders.expires_at rows are linked to settlements.';
      end if;
    end if;

    if to_regclass('public.withdrawal_requests') is not null
      and exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'withdrawal_requests'
          and column_name = 'order_id'
      )
    then
      execute $sql$
        select count(distinct o.id)
        from public.orders o
        join public.withdrawal_requests wr on wr.order_id = o.id
        where o.expires_at is not null
      $sql$
        into v_count;

      if v_count <> 0 then
        raise exception 'CLAUDE_EXPIRES_AT_DEPENDENCY_FOUND'
          using errcode = 'P0001',
                detail = 'Reviewed orders.expires_at rows are linked to withdrawals.';
      end if;
    end if;

    if to_regclass('public.payments') is not null
      and exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'payments'
          and column_name = 'order_id'
      )
    then
      execute $sql$
        select count(distinct o.id)
        from public.orders o
        join public.payments p on p.order_id = o.id
        where o.expires_at is not null
      $sql$
        into v_count;

      if v_count <> 0 then
        raise exception 'CLAUDE_EXPIRES_AT_DEPENDENCY_FOUND'
          using errcode = 'P0001',
                detail = 'Reviewed orders.expires_at rows are linked to payments.';
      end if;
    end if;

    if to_regclass('public.audit_logs') is not null then
      execute $sql$
        select count(*)
        from public.audit_logs
        where action in ('create_order_from_draft', 'prepare_supplier_for_order')
      $sql$
        into v_count;

      if v_count <> 0 then
        raise exception 'CLAUDE_EXPIRES_AT_DEPENDENCY_FOUND'
          using errcode = 'P0001',
                detail = 'Stale Claude-flow audit events exist.';
      end if;
    end if;

    select count(*)
    into v_count
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'orders'
      and indexdef ilike '%expires_at%'
      and indexname <> 'idx_orders_expires_confirm_pending';

    if v_count <> 0 then
      raise exception 'CLAUDE_EXPIRES_AT_SCHEMA_DEPENDENCY_FOUND'
        using errcode = 'P0001',
              detail = 'Unexpected index dependency on public.orders.expires_at exists.';
    end if;

    select count(*)
    into v_count
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'orders'
      and pg_get_constraintdef(c.oid) ilike '%expires_at%';

    if v_count <> 0 then
      raise exception 'CLAUDE_EXPIRES_AT_SCHEMA_DEPENDENCY_FOUND'
        using errcode = 'P0001',
              detail = 'Unexpected constraint dependency on public.orders.expires_at exists.';
    end if;

    select count(*)
    into v_count
    from pg_trigger tg
    join pg_class t on t.oid = tg.tgrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'orders'
      and not tg.tgisinternal
      and pg_get_triggerdef(tg.oid) ilike '%expires_at%';

    if v_count <> 0 then
      raise exception 'CLAUDE_EXPIRES_AT_SCHEMA_DEPENDENCY_FOUND'
        using errcode = 'P0001',
              detail = 'Unexpected trigger dependency on public.orders.expires_at exists.';
    end if;

    select count(*)
    into v_count
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname not in ('create_order_from_draft', 'prepare_supplier_for_order')
      and (
        pg_get_functiondef(p.oid) ilike '%orders.expires_at%'
        or pg_get_functiondef(p.oid) ilike '%o.expires_at%'
      );

    if v_count <> 0 then
      raise exception 'CLAUDE_EXPIRES_AT_SCHEMA_DEPENDENCY_FOUND'
        using errcode = 'P0001',
              detail = 'Unexpected function dependency on public.orders.expires_at exists.';
    end if;

    update public.orders
    set expires_at = null
    where expires_at is not null;

    get diagnostics v_updated_count = row_count;

    if v_updated_count <> 23 then
      raise exception 'CLAUDE_EXPIRES_AT_UPDATE_COUNT_MISMATCH'
        using errcode = 'P0001',
              detail = 'orders.expires_at cleanup updated a count different from reviewed DEVELOPMENT evidence.';
    end if;

    execute 'select count(*) from public.orders where expires_at is not null'
      into v_count;

    if v_count <> 0 then
      raise exception 'CLAUDE_EXPIRES_AT_ZERO_REMAIN_FAILED'
        using errcode = 'P0001',
              detail = 'orders.expires_at non-null values remain after reviewed cleanup update.';
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
