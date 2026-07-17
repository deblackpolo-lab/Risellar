-- Role onboarding requests and audited request/review RPC foundation.
-- Code/schema foundation only. Do not apply to production until development
-- migration execution and boundary tests pass.

create table public.role_onboarding_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete restrict,
  requested_role public.user_role not null,
  status text not null default 'pending',
  business_name text,
  contact_phone text,
  notes text,
  submitted_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete restrict,
  reviewed_at timestamptz,
  review_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint role_onboarding_requests_requested_role_check
    check (requested_role in ('reseller', 'supplier_owner')),
  constraint role_onboarding_requests_status_check
    check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  constraint role_onboarding_requests_pending_review_state_check
    check (
      (
        status = 'pending'
        and reviewed_by is null
        and reviewed_at is null
      )
      or (
        status in ('approved', 'rejected')
        and reviewed_by is not null
        and reviewed_at is not null
      )
      or status = 'cancelled'
    ),
  constraint role_onboarding_requests_business_name_not_blank
    check (business_name is null or length(trim(business_name)) > 0),
  constraint role_onboarding_requests_contact_phone_not_blank
    check (contact_phone is null or length(trim(contact_phone)) > 0)
);

create unique index role_onboarding_requests_one_pending_role_idx
  on public.role_onboarding_requests (profile_id, requested_role)
  where status = 'pending';

create index role_onboarding_requests_profile_status_idx
  on public.role_onboarding_requests (profile_id, status, submitted_at desc);

create index role_onboarding_requests_review_queue_idx
  on public.role_onboarding_requests (status, submitted_at asc)
  where status = 'pending';

create or replace function public.touch_role_onboarding_request_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger role_onboarding_requests_touch_updated_at
  before update on public.role_onboarding_requests
  for each row
  execute function public.touch_role_onboarding_request_updated_at();

alter table public.role_onboarding_requests enable row level security;
alter table public.role_onboarding_requests force row level security;

create policy "role_onboarding_requests_select_own_or_admin"
  on public.role_onboarding_requests for select
  using (
    profile_id = public.current_profile_id()
    or public.has_admin_role('admin')
  );

create policy "role_onboarding_requests_insert_own_pending_customer"
  on public.role_onboarding_requests for insert
  with check (
    profile_id = public.current_profile_id()
    and requested_role in ('reseller', 'supplier_owner')
    and status = 'pending'
    and reviewed_by is null
    and reviewed_at is null
    and exists (
      select 1
      from public.profiles p
      where p.id = public.current_profile_id()
        and p.primary_role = 'customer'
        and p.account_status = 'active'
        and p.deleted_at is null
    )
  );

create or replace function public.submit_role_onboarding_request(
  p_requested_role public.user_role,
  p_business_name text default null,
  p_contact_phone text default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_profile public.profiles%rowtype;
  v_request_id uuid;
  v_business_name text;
  v_contact_phone text;
  v_notes text;
begin
  select *
  into v_actor_profile
  from public.profiles
  where id = public.current_profile_id()
  for update;

  if not found then
    raise exception 'Authenticated active profile is required to submit role onboarding requests';
  end if;

  if v_actor_profile.primary_role <> 'customer' then
    raise exception 'Only customer profiles can request reseller or supplier onboarding';
  end if;

  if p_requested_role not in ('reseller', 'supplier_owner') then
    raise exception 'Requested role is not eligible for self-service onboarding';
  end if;

  if exists (
    select 1
    from public.role_onboarding_requests r
    where r.profile_id = v_actor_profile.id
      and r.requested_role = p_requested_role
      and r.status = 'pending'
  ) then
    raise exception 'A pending onboarding request already exists for this role';
  end if;

  v_business_name := nullif(trim(coalesce(p_business_name, '')), '');
  v_contact_phone := nullif(trim(coalesce(p_contact_phone, '')), '');
  v_notes := nullif(trim(coalesce(p_notes, '')), '');

  insert into public.role_onboarding_requests (
    profile_id,
    requested_role,
    status,
    business_name,
    contact_phone,
    notes
  )
  values (
    v_actor_profile.id,
    p_requested_role,
    'pending',
    v_business_name,
    v_contact_phone,
    v_notes
  )
  returning id into v_request_id;

  perform public.create_audit_log_entry(
    'submit_role_onboarding_request',
    'role_onboarding_requests',
    v_request_id,
    'role_onboarding_request_submitted',
    null,
    jsonb_build_object(
      'requested_role', p_requested_role,
      'status', 'pending',
      'profile_id', v_actor_profile.id
    )
  );

  return v_request_id;
end;
$$;

create or replace function public.review_role_onboarding_request(
  p_request_id uuid,
  p_decision text,
  p_review_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reviewer_profile_id uuid;
  v_request public.role_onboarding_requests%rowtype;
  v_existing_role public.user_role;
  v_review_notes text;
  v_supplier_business_name text;
begin
  v_reviewer_profile_id := public.current_profile_id();

  if v_reviewer_profile_id is null then
    raise exception 'Authenticated active profile is required to review role onboarding requests';
  end if;

  if not public.has_admin_role('admin') then
    raise exception 'Admin role is required to review role onboarding requests';
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'Review decision must be approved or rejected';
  end if;

  select *
  into v_request
  from public.role_onboarding_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Role onboarding request not found';
  end if;

  if v_request.status <> 'pending' then
    raise exception 'Only pending onboarding requests can be reviewed';
  end if;

  if v_request.profile_id = v_reviewer_profile_id then
    raise exception 'Reviewers cannot approve or reject their own onboarding requests';
  end if;

  select p.primary_role
  into v_existing_role
  from public.profiles p
  where p.id = v_request.profile_id
    and p.account_status = 'active'
    and p.deleted_at is null
  for update;

  if not found then
    raise exception 'Requester profile is not active';
  end if;

  if v_existing_role <> 'customer' then
    raise exception 'Only customer profiles can be promoted through onboarding review';
  end if;

  v_review_notes := nullif(trim(coalesce(p_review_notes, '')), '');

  if p_decision = 'approved' then
    update public.profiles
    set primary_role = v_request.requested_role,
        updated_at = now()
    where id = v_request.profile_id
      and primary_role = 'customer';

    if v_request.requested_role = 'reseller' then
      insert into public.resellers (
        profile_id,
        reseller_type,
        approval_status,
        payout_status
      )
      values (
        v_request.profile_id,
        'role_onboarding_approved',
        'approved',
        'active'
      )
      on conflict (profile_id) do nothing;
    elsif v_request.requested_role = 'supplier_owner' then
      v_supplier_business_name := coalesce(
        nullif(trim(coalesce(v_request.business_name, '')), ''),
        'Development supplier onboarding'
      );

      insert into public.suppliers (
        owner_profile_id,
        business_name,
        public_display_name,
        supplier_status,
        verification_status
      )
      select
        v_request.profile_id,
        v_supplier_business_name,
        v_supplier_business_name,
        'pending',
        'pending_review'
      where not exists (
        select 1
        from public.suppliers s
        where s.owner_profile_id = v_request.profile_id
          and s.deleted_at is null
      );
    end if;
  end if;

  update public.role_onboarding_requests
  set status = p_decision,
      reviewed_by = v_reviewer_profile_id,
      reviewed_at = now(),
      review_notes = v_review_notes
  where id = p_request_id;

  perform public.create_audit_log_entry(
    'review_role_onboarding_request',
    'role_onboarding_requests',
    p_request_id,
    coalesce(v_review_notes, 'role_onboarding_request_reviewed'),
    jsonb_build_object(
      'status', v_request.status,
      'requested_role', v_request.requested_role,
      'profile_role', v_existing_role
    ),
    jsonb_build_object(
      'status', p_decision,
      'requested_role', v_request.requested_role,
      'reviewed_by', v_reviewer_profile_id
    )
  );

  return p_request_id;
end;
$$;

revoke all on public.role_onboarding_requests from public;
grant select, insert on public.role_onboarding_requests to authenticated;

revoke all on function public.touch_role_onboarding_request_updated_at() from public;

revoke all on function public.submit_role_onboarding_request(public.user_role, text, text, text) from public;
grant execute on function public.submit_role_onboarding_request(public.user_role, text, text, text) to authenticated;

revoke all on function public.review_role_onboarding_request(uuid, text, text) from public;
grant execute on function public.review_role_onboarding_request(uuid, text, text) to authenticated;

comment on table public.role_onboarding_requests
  is 'Audited role onboarding request queue. Customers may submit reseller/supplier_owner requests; admins review through RPC only.';

comment on function public.submit_role_onboarding_request(public.user_role, text, text, text)
  is 'Customer-only audited role onboarding submission. Blocks admin, super_admin, supplier_inventory_manager, and customer self-promotion requests.';

comment on function public.review_role_onboarding_request(uuid, text, text)
  is 'Admin-only audited onboarding review RPC. Prevents self-review and direct client status/review-field mutation.';

