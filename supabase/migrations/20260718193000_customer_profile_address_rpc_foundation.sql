-- Customer Phase A: customer profile/contact and delivery address RPC foundation.
-- Forward migration only. Does not create checkout drafts, orders, stock reservations,
-- payments, delivery quotes, settlements, commissions, withdrawals, or purchase flow side effects.

create table if not exists public.customer_delivery_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete restrict,
  label text not null,
  recipient_name text not null,
  phone text not null,
  region text not null,
  city text not null,
  area text not null,
  street_address text not null,
  landmark text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint customer_delivery_addresses_label_not_blank check (length(trim(label)) > 0),
  constraint customer_delivery_addresses_recipient_name_not_blank check (length(trim(recipient_name)) > 0),
  constraint customer_delivery_addresses_phone_not_blank check (length(trim(phone)) > 0),
  constraint customer_delivery_addresses_region_not_blank check (length(trim(region)) > 0),
  constraint customer_delivery_addresses_city_not_blank check (length(trim(city)) > 0),
  constraint customer_delivery_addresses_area_not_blank check (length(trim(area)) > 0),
  constraint customer_delivery_addresses_street_address_not_blank check (length(trim(street_address)) > 0)
);

create unique index if not exists customer_delivery_addresses_one_default_idx
  on public.customer_delivery_addresses(customer_id)
  where is_default is true
    and deleted_at is null;

create index if not exists customer_delivery_addresses_customer_active_idx
  on public.customer_delivery_addresses(customer_id, is_default, created_at desc)
  where deleted_at is null;

alter table public.customer_delivery_addresses enable row level security;
alter table public.customer_delivery_addresses force row level security;

drop policy if exists "customer_delivery_addresses_select_own_or_admin" on public.customer_delivery_addresses;
create policy "customer_delivery_addresses_select_own_or_admin"
  on public.customer_delivery_addresses for select
  using (public.is_customer_owner(customer_id) or public.has_admin_role('support_staff'));

drop policy if exists "customer_delivery_addresses_insert_own" on public.customer_delivery_addresses;
create policy "customer_delivery_addresses_insert_own"
  on public.customer_delivery_addresses for insert
  with check (public.is_customer_owner(customer_id));

drop policy if exists "customer_delivery_addresses_update_own_or_admin" on public.customer_delivery_addresses;
create policy "customer_delivery_addresses_update_own_or_admin"
  on public.customer_delivery_addresses for update
  using (public.is_customer_owner(customer_id) or public.has_admin_role('support_staff'))
  with check (public.is_customer_owner(customer_id) or public.has_admin_role('support_staff'));

create or replace function public.customer_phase_a_normalize_required_text(
  p_value text,
  p_field_name text
)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v_value text := nullif(trim(coalesce(p_value, '')), '');
begin
  if v_value is null then
    raise exception '% is required', p_field_name
      using errcode = '23514';
  end if;

  return v_value;
end;
$$;

create or replace function public.current_customer_id()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_customer_id uuid;
begin
  v_profile_id := public.current_profile_id();

  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED'
      using errcode = '28000';
  end if;

  insert into public.customers(profile_id, customer_status)
  values (v_profile_id, 'active')
  on conflict (profile_id) do update
    set updated_at = now()
  returning id into v_customer_id;

  return v_customer_id;
end;
$$;

create or replace function public.upsert_customer_contact(
  p_full_name text,
  p_phone text,
  p_whatsapp text default null,
  p_email text default null
)
returns table (
  profile_id uuid,
  customer_id uuid,
  email text,
  full_name text,
  phone text,
  whatsapp text,
  primary_role public.user_role,
  customer_status public.account_status
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_customer_id uuid;
  v_before_profile jsonb;
  v_after_profile jsonb;
  v_actor_role public.user_role;
  v_full_name text := public.customer_phase_a_normalize_required_text(p_full_name, 'full_name');
  v_phone text := public.customer_phase_a_normalize_required_text(p_phone, 'phone');
  v_whatsapp text := nullif(trim(coalesce(p_whatsapp, '')), '');
  v_email text := nullif(trim(coalesce(p_email, '')), '');
begin
  v_profile_id := public.current_profile_id();

  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED'
      using errcode = '28000';
  end if;

  select jsonb_build_object(
           'full_name', p.full_name,
           'phone', p.phone,
           'whatsapp', p.whatsapp,
           'email', p.email,
           'primary_role', p.primary_role
         ),
         p.primary_role
  into v_before_profile, v_actor_role
  from public.profiles p
  where p.id = v_profile_id
    and p.deleted_at is null
    and p.account_status = 'active';

  if v_actor_role is null then
    raise exception 'ACTIVE_PROFILE_REQUIRED'
      using errcode = '28000';
  end if;

  update public.profiles p
  set full_name = v_full_name,
      phone = v_phone,
      whatsapp = v_whatsapp,
      email = coalesce(v_email, p.email),
      updated_at = now()
  where p.id = v_profile_id;

  v_customer_id := public.current_customer_id();

  select jsonb_build_object(
           'full_name', p.full_name,
           'phone', p.phone,
           'whatsapp', p.whatsapp,
           'email', p.email,
           'primary_role', p.primary_role
         )
  into v_after_profile
  from public.profiles p
  where p.id = v_profile_id;

  insert into public.audit_logs(
    actor_profile_id,
    actor_role,
    action,
    target_entity_type,
    target_entity_id,
    before_data,
    after_data,
    reason
  )
  values (
    v_profile_id,
    v_actor_role,
    'upsert_customer_contact',
    'customer',
    v_customer_id,
    v_before_profile,
    v_after_profile,
    'Customer updated contact/profile details'
  );

  return query
  select
    p.id,
    c.id,
    p.email,
    p.full_name,
    p.phone,
    p.whatsapp,
    p.primary_role,
    c.customer_status
  from public.profiles p
  join public.customers c on c.profile_id = p.id
  where p.id = v_profile_id
    and c.id = v_customer_id;
end;
$$;

create or replace function public.create_customer_delivery_address(
  p_label text,
  p_recipient_name text,
  p_phone text,
  p_region text,
  p_city text,
  p_area text,
  p_street_address text,
  p_landmark text default null,
  p_is_default boolean default false
)
returns table (
  id uuid,
  customer_id uuid,
  label text,
  recipient_name text,
  phone text,
  region text,
  city text,
  area text,
  street_address text,
  landmark text,
  is_default boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid := public.current_customer_id();
  v_profile_id uuid := public.current_profile_id();
  v_address_id uuid;
  v_actor_role public.user_role;
  v_make_default boolean := coalesce(p_is_default, false);
begin
  select p.primary_role
  into v_actor_role
  from public.profiles p
  where p.id = v_profile_id;

  if v_make_default then
    update public.customer_delivery_addresses a
    set is_default = false,
        updated_at = now()
    where a.customer_id = v_customer_id
      and a.deleted_at is null
      and a.is_default is true;
  end if;

  insert into public.customer_delivery_addresses(
    customer_id,
    label,
    recipient_name,
    phone,
    region,
    city,
    area,
    street_address,
    landmark,
    is_default
  )
  values (
    v_customer_id,
    public.customer_phase_a_normalize_required_text(p_label, 'label'),
    public.customer_phase_a_normalize_required_text(p_recipient_name, 'recipient_name'),
    public.customer_phase_a_normalize_required_text(p_phone, 'phone'),
    public.customer_phase_a_normalize_required_text(p_region, 'region'),
    public.customer_phase_a_normalize_required_text(p_city, 'city'),
    public.customer_phase_a_normalize_required_text(p_area, 'area'),
    public.customer_phase_a_normalize_required_text(p_street_address, 'street_address'),
    nullif(trim(coalesce(p_landmark, '')), ''),
    v_make_default
  )
  returning customer_delivery_addresses.id into v_address_id;

  insert into public.audit_logs(
    actor_profile_id,
    actor_role,
    action,
    target_entity_type,
    target_entity_id,
    after_data,
    reason
  )
  select
    v_profile_id,
    v_actor_role,
    'create_customer_delivery_address',
    'customer_delivery_address',
    a.id,
    jsonb_build_object(
      'customer_id', a.customer_id,
      'label', a.label,
      'region', a.region,
      'city', a.city,
      'area', a.area,
      'is_default', a.is_default
    ),
    'Customer created delivery address'
  from public.customer_delivery_addresses a
  where a.id = v_address_id;

  return query
  select
    a.id,
    a.customer_id,
    a.label,
    a.recipient_name,
    a.phone,
    a.region,
    a.city,
    a.area,
    a.street_address,
    a.landmark,
    a.is_default,
    a.created_at,
    a.updated_at
  from public.customer_delivery_addresses a
  where a.id = v_address_id;
end;
$$;

create or replace function public.update_customer_delivery_address(
  p_address_id uuid,
  p_label text,
  p_recipient_name text,
  p_phone text,
  p_region text,
  p_city text,
  p_area text,
  p_street_address text,
  p_landmark text default null,
  p_is_default boolean default false
)
returns table (
  id uuid,
  customer_id uuid,
  label text,
  recipient_name text,
  phone text,
  region text,
  city text,
  area text,
  street_address text,
  landmark text,
  is_default boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid := public.current_customer_id();
  v_profile_id uuid := public.current_profile_id();
  v_actor_role public.user_role;
  v_before_address jsonb;
  v_after_address jsonb;
  v_make_default boolean := coalesce(p_is_default, false);
begin
  if p_address_id is null then
    raise exception 'address_id is required'
      using errcode = '23514';
  end if;

  select p.primary_role
  into v_actor_role
  from public.profiles p
  where p.id = v_profile_id;

  select to_jsonb(a)
  into v_before_address
  from public.customer_delivery_addresses a
  where a.id = p_address_id
    and a.customer_id = v_customer_id
    and a.deleted_at is null;

  if v_before_address is null then
    raise exception 'CUSTOMER_ADDRESS_NOT_FOUND'
      using errcode = '42501';
  end if;

  if v_make_default then
    update public.customer_delivery_addresses a
    set is_default = false,
        updated_at = now()
    where a.customer_id = v_customer_id
      and a.id <> p_address_id
      and a.deleted_at is null
      and a.is_default is true;
  end if;

  update public.customer_delivery_addresses a
  set label = public.customer_phase_a_normalize_required_text(p_label, 'label'),
      recipient_name = public.customer_phase_a_normalize_required_text(p_recipient_name, 'recipient_name'),
      phone = public.customer_phase_a_normalize_required_text(p_phone, 'phone'),
      region = public.customer_phase_a_normalize_required_text(p_region, 'region'),
      city = public.customer_phase_a_normalize_required_text(p_city, 'city'),
      area = public.customer_phase_a_normalize_required_text(p_area, 'area'),
      street_address = public.customer_phase_a_normalize_required_text(p_street_address, 'street_address'),
      landmark = nullif(trim(coalesce(p_landmark, '')), ''),
      is_default = v_make_default,
      updated_at = now()
  where a.id = p_address_id
    and a.customer_id = v_customer_id
    and a.deleted_at is null;

  select to_jsonb(a)
  into v_after_address
  from public.customer_delivery_addresses a
  where a.id = p_address_id;

  insert into public.audit_logs(
    actor_profile_id,
    actor_role,
    action,
    target_entity_type,
    target_entity_id,
    before_data,
    after_data,
    reason
  )
  values (
    v_profile_id,
    v_actor_role,
    'update_customer_delivery_address',
    'customer_delivery_address',
    p_address_id,
    v_before_address,
    v_after_address,
    'Customer updated delivery address'
  );

  return query
  select
    a.id,
    a.customer_id,
    a.label,
    a.recipient_name,
    a.phone,
    a.region,
    a.city,
    a.area,
    a.street_address,
    a.landmark,
    a.is_default,
    a.created_at,
    a.updated_at
  from public.customer_delivery_addresses a
  where a.id = p_address_id;
end;
$$;

create or replace function public.archive_customer_delivery_address(p_address_id uuid)
returns table (
  id uuid,
  customer_id uuid,
  archived_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid := public.current_customer_id();
  v_profile_id uuid := public.current_profile_id();
  v_actor_role public.user_role;
  v_before_address jsonb;
begin
  if p_address_id is null then
    raise exception 'address_id is required'
      using errcode = '23514';
  end if;

  select p.primary_role
  into v_actor_role
  from public.profiles p
  where p.id = v_profile_id;

  select to_jsonb(a)
  into v_before_address
  from public.customer_delivery_addresses a
  where a.id = p_address_id
    and a.customer_id = v_customer_id
    and a.deleted_at is null;

  if v_before_address is null then
    raise exception 'CUSTOMER_ADDRESS_NOT_FOUND'
      using errcode = '42501';
  end if;

  update public.customer_delivery_addresses a
  set deleted_at = now(),
      is_default = false,
      updated_at = now()
  where a.id = p_address_id
    and a.customer_id = v_customer_id
    and a.deleted_at is null;

  insert into public.audit_logs(
    actor_profile_id,
    actor_role,
    action,
    target_entity_type,
    target_entity_id,
    before_data,
    after_data,
    reason
  )
  select
    v_profile_id,
    v_actor_role,
    'archive_customer_delivery_address',
    'customer_delivery_address',
    a.id,
    v_before_address,
    to_jsonb(a),
    'Customer archived delivery address'
  from public.customer_delivery_addresses a
  where a.id = p_address_id;

  return query
  select
    a.id,
    a.customer_id,
    a.deleted_at
  from public.customer_delivery_addresses a
  where a.id = p_address_id;
end;
$$;

create or replace function public.get_customer_delivery_addresses()
returns table (
  id uuid,
  customer_id uuid,
  label text,
  recipient_name text,
  phone text,
  region text,
  city text,
  area text,
  street_address text,
  landmark text,
  is_default boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid := public.current_customer_id();
begin
  return query
  select
    a.id,
    a.customer_id,
    a.label,
    a.recipient_name,
    a.phone,
    a.region,
    a.city,
    a.area,
    a.street_address,
    a.landmark,
    a.is_default,
    a.created_at,
    a.updated_at
  from public.customer_delivery_addresses a
  where a.customer_id = v_customer_id
    and a.deleted_at is null
  order by a.is_default desc, a.created_at desc;
end;
$$;

revoke all on table public.customer_delivery_addresses from public;
revoke all on function public.customer_phase_a_normalize_required_text(text, text) from public;
revoke all on function public.current_customer_id() from public;
revoke all on function public.upsert_customer_contact(text, text, text, text) from public;
revoke all on function public.create_customer_delivery_address(text, text, text, text, text, text, text, text, boolean) from public;
revoke all on function public.update_customer_delivery_address(uuid, text, text, text, text, text, text, text, text, boolean) from public;
revoke all on function public.archive_customer_delivery_address(uuid) from public;
revoke all on function public.get_customer_delivery_addresses() from public;

grant select, insert, update on table public.customer_delivery_addresses to authenticated;
grant execute on function public.upsert_customer_contact(text, text, text, text) to authenticated;
grant execute on function public.create_customer_delivery_address(text, text, text, text, text, text, text, text, boolean) to authenticated;
grant execute on function public.update_customer_delivery_address(uuid, text, text, text, text, text, text, text, text, boolean) to authenticated;
grant execute on function public.archive_customer_delivery_address(uuid) to authenticated;
grant execute on function public.get_customer_delivery_addresses() to authenticated;

comment on table public.customer_delivery_addresses
  is 'Customer Phase A delivery addresses. Customers can manage only their own rows; archive is soft-delete only.';

comment on function public.upsert_customer_contact(text, text, text, text)
  is 'Customer Phase A RPC for authenticated users to update their own safe contact/profile fields and ensure a customer row exists.';

comment on function public.create_customer_delivery_address(text, text, text, text, text, text, text, text, boolean)
  is 'Customer Phase A RPC for authenticated users to create their own delivery address. Does not create checkout, order, reservation, payment, delivery quote, settlement, commission, or withdrawal rows.';

comment on function public.update_customer_delivery_address(uuid, text, text, text, text, text, text, text, text, boolean)
  is 'Customer Phase A RPC for authenticated users to update their own delivery address only.';

comment on function public.archive_customer_delivery_address(uuid)
  is 'Customer Phase A RPC for authenticated users to soft-archive their own delivery address only.';

comment on function public.get_customer_delivery_addresses()
  is 'Customer Phase A RPC for authenticated users to list their own non-archived delivery addresses.';
