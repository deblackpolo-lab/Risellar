-- Risellar Supabase schema and RLS foundation.
-- Safe local migration draft only: no secrets, no production connection details.

create extension if not exists pgcrypto;

create type public.user_role as enum (
  'customer',
  'reseller',
  'supplier_owner',
  'supplier_inventory_manager',
  'support_staff',
  'finance_staff',
  'admin',
  'super_admin'
);

create type public.account_status as enum ('active', 'pending', 'restricted', 'suspended', 'closed');
create type public.approval_status as enum ('draft', 'pending_review', 'approved', 'needs_changes', 'rejected', 'hidden', 'suspended', 'archived');
create type public.risk_level as enum ('low', 'medium', 'high', 'restricted', 'suspended');
create type public.staff_status as enum ('invited', 'active', 'restricted', 'removed');
create type public.supplier_role as enum ('owner', 'supplier_inventory_manager');
create type public.product_status as enum ('draft', 'pending_approval', 'approved', 'active', 'rejected', 'needs_changes', 'price_change_pending', 'needs_reseller_review', 'out_of_stock', 'hidden', 'suspended', 'archived');
create type public.variant_status as enum ('active', 'low_stock', 'out_of_stock', 'hidden', 'archived');
create type public.image_status as enum ('pending_review', 'active', 'hidden', 'rejected', 'archived');
create type public.listing_status as enum ('draft', 'active', 'needs_review', 'out_of_stock', 'hidden', 'restricted', 'suspended', 'archived');
create type public.stock_movement_type as enum ('initial_stock', 'restock', 'reservation_created', 'reservation_released', 'sale_committed', 'order_cancelled_release', 'manual_adjustment', 'return_restock', 'damage', 'correction');
create type public.reservation_status as enum ('pending', 'reserved', 'committed', 'released', 'expired', 'failed');
create type public.order_status as enum ('draft', 'placed_pending_confirmation', 'customer_confirmed', 'delivery_quote_pending', 'delivery_quote_ready', 'delivery_quote_approved', 'supplier_preparing', 'ready_for_pickup_or_dispatch', 'out_for_delivery', 'delivered_payment_pending', 'payment_collected', 'settlement_due', 'completed', 'cancelled', 'customer_refused', 'failed', 'disputed');
create type public.payment_method as enum ('pay_on_delivery', 'pay_online_disabled', 'pay_online');
create type public.payment_collection_status as enum ('not_collected', 'pending', 'collected', 'failed', 'refunded', 'disputed');
create type public.delivery_status as enum ('estimate_selected', 'quote_pending', 'quote_ready', 'quote_approved', 'quote_rejected', 'ready', 'out_for_delivery', 'delivered', 'failed', 'cancelled');
create type public.confirmation_status as enum ('pending', 'confirmed', 'expired', 'cancelled', 'manual_confirmed');
create type public.delivery_quote_status as enum ('pending', 'quoted', 'approved', 'rejected', 'expired', 'cancelled');
create type public.settlement_status as enum ('not_due', 'due', 'proof_submitted', 'verifying', 'partially_settled', 'paid', 'overdue', 'disputed', 'written_off');
create type public.commission_status as enum ('pending_order', 'awaiting_customer_confirmation', 'awaiting_delivery_payment', 'awaiting_supplier_settlement', 'available', 'withdrawal_requested', 'paid', 'cancelled', 'held', 'disputed', 'adjusted');
create type public.withdrawal_status as enum ('requested', 'processing', 'paid', 'failed', 'rejected', 'cancelled');
create type public.dispute_status as enum ('open', 'under_review', 'waiting_for_customer', 'waiting_for_supplier', 'waiting_for_reseller', 'resolved', 'rejected', 'escalated');
create type public.return_status as enum ('requested', 'approved', 'rejected', 'returned_to_supplier', 'refund_pending', 'refund_completed', 'refund_rejected', 'cancelled');
create type public.notification_channel as enum ('in_app', 'email', 'manual_whatsapp');
create type public.notification_status as enum ('queued', 'sent', 'failed', 'read', 'dismissed');
create type public.admin_action_status as enum ('requested', 'approved', 'rejected', 'applied', 'cancelled');

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  clerk_user_id text not null unique,
  email text not null,
  full_name text,
  phone text,
  whatsapp text,
  primary_role public.user_role not null default 'customer',
  account_status public.account_status not null default 'active',
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint profiles_email_not_blank check (length(trim(email)) > 0),
  constraint profiles_no_self_admin_signup check (primary_role not in ('admin', 'super_admin', 'finance_staff', 'support_staff'))
);

create table public.admin_staff (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete restrict,
  admin_role public.user_role not null,
  permissions jsonb not null default '{}'::jsonb,
  staff_status public.staff_status not null default 'active',
  assigned_by_profile_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint admin_staff_role_check check (admin_role in ('support_staff', 'finance_staff', 'admin', 'super_admin'))
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete restrict,
  customer_status public.account_status not null default 'active',
  risk_level public.risk_level not null default 'low',
  default_address jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.resellers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete restrict,
  reseller_type text,
  approval_status public.approval_status not null default 'pending_review',
  risk_level public.risk_level not null default 'low',
  payout_status public.account_status not null default 'pending',
  commission_available_amount numeric(12,2) not null default 0,
  commission_pending_amount numeric(12,2) not null default 0,
  payout_details_masked jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint resellers_commission_available_nonnegative check (commission_available_amount >= 0),
  constraint resellers_commission_pending_nonnegative check (commission_pending_amount >= 0)
);

create table public.reseller_shops (
  id uuid primary key default gen_random_uuid(),
  reseller_id uuid not null references public.resellers(id) on delete restrict,
  shop_slug text not null unique,
  display_name text not null,
  bio text,
  shop_status public.account_status not null default 'active',
  visibility text not null default 'public',
  restricted_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint reseller_shops_slug_format check (shop_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  owner_profile_id uuid not null references public.profiles(id) on delete restrict,
  business_name text not null,
  business_type text,
  primary_category text,
  location_region text,
  location_city text,
  supplier_status public.account_status not null default 'pending',
  verification_status public.approval_status not null default 'pending_review',
  risk_level public.risk_level not null default 'low',
  trust_level text not null default 'new_supplier',
  settlement_status public.settlement_status not null default 'not_due',
  public_display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint suppliers_business_name_not_blank check (length(trim(business_name)) > 0)
);

create table public.supplier_team_members (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  supplier_role public.supplier_role not null default 'supplier_inventory_manager',
  staff_status public.staff_status not null default 'active',
  permissions jsonb not null default '{}'::jsonb,
  invited_by_profile_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (supplier_id, profile_id)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  category text,
  name text not null,
  slug text not null,
  description text,
  brand text,
  product_status public.product_status not null default 'draft',
  approval_status public.approval_status not null default 'draft',
  base_price_amount numeric(12,2) not null,
  platform_margin_amount numeric(12,2) not null default 0,
  reseller_cost_amount numeric(12,2) generated always as (base_price_amount + platform_margin_amount) stored,
  max_reseller_margin_amount numeric(12,2) not null default 0,
  max_customer_price_amount numeric(12,2) generated always as (base_price_amount + platform_margin_amount + max_reseller_margin_amount) stored,
  currency_code text not null default 'GHS',
  rejection_reason text,
  created_by_profile_id uuid references public.profiles(id) on delete set null,
  approved_by_profile_id uuid references public.profiles(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (supplier_id, slug),
  constraint products_name_not_blank check (length(trim(name)) > 0),
  constraint products_base_price_nonnegative check (base_price_amount >= 0),
  constraint products_platform_margin_nonnegative check (platform_margin_amount >= 0),
  constraint products_max_reseller_margin_nonnegative check (max_reseller_margin_amount >= 0)
);

create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  sku text,
  variant_name text,
  attributes jsonb not null default '{}'::jsonb,
  total_stock_quantity integer not null default 0,
  reserved_stock_quantity integer not null default 0,
  sold_stock_quantity integer not null default 0,
  returned_stock_quantity integer not null default 0,
  low_stock_threshold integer not null default 3,
  variant_status public.variant_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint product_variants_stock_nonnegative check (
    total_stock_quantity >= 0
    and reserved_stock_quantity >= 0
    and sold_stock_quantity >= 0
    and returned_stock_quantity >= 0
    and low_stock_threshold >= 0
  ),
  constraint product_variants_stock_not_oversold check (reserved_stock_quantity + sold_stock_quantity <= total_stock_quantity)
);

create table public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid references public.product_variants(id) on delete set null,
  storage_path text not null,
  alt_text text,
  sort_order integer not null default 0,
  image_status public.image_status not null default 'pending_review',
  is_primary boolean not null default false,
  created_by_profile_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint product_images_storage_path_not_url check (storage_path !~* '^https?://')
);

create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid not null references public.product_variants(id) on delete restrict,
  movement_type public.stock_movement_type not null,
  quantity_delta integer not null,
  previous_total_quantity integer not null,
  new_total_quantity integer not null,
  reason text,
  order_id uuid,
  created_by_profile_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint inventory_movements_quantities_nonnegative check (previous_total_quantity >= 0 and new_total_quantity >= 0)
);

create table public.reseller_products (
  id uuid primary key default gen_random_uuid(),
  reseller_id uuid not null references public.resellers(id) on delete restrict,
  shop_id uuid not null references public.reseller_shops(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid references public.product_variants(id) on delete restrict,
  listing_status public.listing_status not null default 'draft',
  reseller_margin_amount numeric(12,2) not null default 0,
  customer_product_price_amount numeric(12,2) not null,
  share_slug text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (shop_id, share_slug),
  unique (reseller_id, product_id, variant_id),
  constraint reseller_products_margin_nonnegative check (reseller_margin_amount >= 0),
  constraint reseller_products_customer_price_nonnegative check (customer_product_price_amount >= 0)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  customer_id uuid not null references public.customers(id) on delete restrict,
  reseller_id uuid not null references public.resellers(id) on delete restrict,
  shop_id uuid not null references public.reseller_shops(id) on delete restrict,
  order_status public.order_status not null default 'placed_pending_confirmation',
  payment_method public.payment_method not null default 'pay_on_delivery',
  payment_collection_status public.payment_collection_status not null default 'not_collected',
  delivery_status public.delivery_status not null default 'estimate_selected',
  customer_confirmation_status public.confirmation_status not null default 'pending',
  delivery_quote_status public.delivery_quote_status not null default 'pending',
  subtotal_product_amount numeric(12,2) not null default 0,
  delivery_estimate_min_amount numeric(12,2) not null default 0,
  delivery_estimate_max_amount numeric(12,2) not null default 0,
  final_delivery_amount numeric(12,2),
  total_payable_amount numeric(12,2) not null default 0,
  currency_code text not null default 'GHS',
  delivery_address_snapshot jsonb not null default '{}'::jsonb,
  customer_contact_snapshot jsonb not null default '{}'::jsonb,
  confirmation_source text,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint orders_amounts_nonnegative check (
    subtotal_product_amount >= 0
    and delivery_estimate_min_amount >= 0
    and delivery_estimate_max_amount >= 0
    and coalesce(final_delivery_amount, 0) >= 0
    and total_payable_amount >= 0
  )
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid not null references public.product_variants(id) on delete restrict,
  reseller_product_id uuid not null references public.reseller_products(id) on delete restrict,
  quantity integer not null,
  supplier_base_price_snapshot_amount numeric(12,2) not null,
  platform_margin_snapshot_amount numeric(12,2) not null,
  reseller_margin_snapshot_amount numeric(12,2) not null,
  reseller_cost_snapshot_amount numeric(12,2) not null,
  customer_product_price_snapshot_amount numeric(12,2) not null,
  line_total_amount numeric(12,2) not null,
  settlement_due_amount numeric(12,2) not null,
  commission_amount numeric(12,2) not null,
  created_at timestamptz not null default now(),
  constraint order_items_quantity_positive check (quantity > 0),
  constraint order_items_amounts_nonnegative check (
    supplier_base_price_snapshot_amount >= 0
    and platform_margin_snapshot_amount >= 0
    and reseller_margin_snapshot_amount >= 0
    and reseller_cost_snapshot_amount >= 0
    and customer_product_price_snapshot_amount >= 0
    and line_total_amount >= 0
    and settlement_due_amount >= 0
    and commission_amount >= 0
  )
);

alter table public.inventory_movements
  add constraint inventory_movements_order_id_fkey foreign key (order_id) references public.orders(id) on delete set null;

create table public.stock_reservations (
  id uuid primary key default gen_random_uuid(),
  reservation_reference text not null unique,
  customer_id uuid not null references public.customers(id) on delete restrict,
  reseller_id uuid not null references public.resellers(id) on delete restrict,
  reseller_product_id uuid not null references public.reseller_products(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid not null references public.product_variants(id) on delete restrict,
  order_id uuid references public.orders(id) on delete restrict,
  quantity integer not null,
  reservation_status public.reservation_status not null default 'pending',
  expires_at timestamptz not null,
  released_at timestamptz,
  committed_at timestamptz,
  release_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stock_reservations_quantity_positive check (quantity > 0)
);

create table public.delivery_quotes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  quoted_by_profile_id uuid references public.profiles(id) on delete set null,
  quote_status public.delivery_quote_status not null default 'quoted',
  delivery_method text not null,
  quoted_amount numeric(12,2) not null,
  customer_approved_at timestamptz,
  customer_rejected_at timestamptz,
  expires_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_quotes_amount_nonnegative check (quoted_amount >= 0)
);

create table public.settlements (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  settlement_status public.settlement_status not null default 'not_due',
  due_amount numeric(12,2) not null default 0,
  paid_amount numeric(12,2) not null default 0,
  outstanding_amount numeric(12,2) not null default 0,
  due_at timestamptz,
  verified_at timestamptz,
  verified_by_profile_id uuid references public.profiles(id) on delete set null,
  risk_level public.risk_level not null default 'low',
  proof_storage_path text,
  proof_reference text,
  proof_uploaded_by_profile_id uuid references public.profiles(id) on delete set null,
  reviewed_by_profile_id uuid references public.profiles(id) on delete set null,
  review_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint settlements_amounts_nonnegative check (due_amount >= 0 and paid_amount >= 0 and outstanding_amount >= 0),
  constraint settlements_proof_storage_path_not_url check (proof_storage_path is null or proof_storage_path !~* '^https?://')
);

create table public.commissions (
  id uuid primary key default gen_random_uuid(),
  reseller_id uuid not null references public.resellers(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  order_item_id uuid not null references public.order_items(id) on delete restrict,
  settlement_id uuid references public.settlements(id) on delete set null,
  commission_status public.commission_status not null default 'pending_order',
  commission_amount numeric(12,2) not null,
  available_at timestamptz,
  withdrawal_id uuid,
  held_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commissions_amount_nonnegative check (commission_amount >= 0)
);

create table public.withdrawals (
  id uuid primary key default gen_random_uuid(),
  reseller_id uuid not null references public.resellers(id) on delete restrict,
  requested_amount numeric(12,2) not null,
  approved_amount numeric(12,2),
  withdrawal_status public.withdrawal_status not null default 'requested',
  provider text,
  account_name text,
  account_number_masked text,
  requested_by_profile_id uuid references public.profiles(id) on delete set null,
  approved_by_profile_id uuid references public.profiles(id) on delete set null,
  paid_by_profile_id uuid references public.profiles(id) on delete set null,
  failed_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint withdrawals_amounts_nonnegative check (requested_amount >= 0 and coalesce(approved_amount, 0) >= 0)
);

alter table public.commissions
  add constraint commissions_withdrawal_id_fkey foreign key (withdrawal_id) references public.withdrawals(id) on delete set null;

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  opened_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  order_id uuid references public.orders(id) on delete restrict,
  dispute_type text not null,
  dispute_status public.dispute_status not null default 'open',
  priority text not null default 'normal',
  assigned_to_profile_id uuid references public.profiles(id) on delete set null,
  evidence_storage_paths text[] not null default '{}',
  resolution_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.returns (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  order_item_id uuid references public.order_items(id) on delete restrict,
  requested_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  return_status public.return_status not null default 'requested',
  reason text not null,
  evidence_storage_paths text[] not null default '{}',
  reviewed_by_profile_id uuid references public.profiles(id) on delete set null,
  review_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_profile_id uuid not null references public.profiles(id) on delete restrict,
  channel public.notification_channel not null default 'in_app',
  notification_status public.notification_status not null default 'queued',
  event_type text not null,
  title text not null,
  body text,
  related_entity_type text,
  related_entity_id uuid,
  safe_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references public.profiles(id) on delete set null,
  actor_role public.user_role,
  action text not null,
  target_entity_type text not null,
  target_entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  reason text,
  ip_address inet,
  user_agent text,
  request_id text,
  created_at timestamptz not null default now()
);

create table public.admin_actions (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid not null references public.profiles(id) on delete restrict,
  action_type text not null,
  action_status public.admin_action_status not null default 'requested',
  target_entity_type text not null,
  target_entity_id uuid,
  reason text not null,
  before_data jsonb,
  after_data jsonb,
  approved_by_profile_id uuid references public.profiles(id) on delete set null,
  applied_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint admin_actions_reason_not_blank check (length(trim(reason)) > 0)
);

create index profiles_clerk_user_id_idx on public.profiles (clerk_user_id);
create index profiles_email_idx on public.profiles (email);
create index admin_staff_profile_role_idx on public.admin_staff (profile_id, admin_role, staff_status);
create index customers_profile_id_idx on public.customers (profile_id);
create index resellers_profile_id_idx on public.resellers (profile_id);
create index suppliers_owner_profile_id_idx on public.suppliers (owner_profile_id);
create index supplier_team_members_supplier_profile_idx on public.supplier_team_members (supplier_id, profile_id, staff_status);
create index products_supplier_status_idx on public.products (supplier_id, product_status, approval_status);
create index product_variants_product_status_idx on public.product_variants (product_id, variant_status);
create index product_images_product_sort_idx on public.product_images (product_id, sort_order);
create index inventory_movements_supplier_variant_idx on public.inventory_movements (supplier_id, variant_id, created_at desc);
create index reseller_products_reseller_status_idx on public.reseller_products (reseller_id, listing_status);
create index reseller_products_shop_status_idx on public.reseller_products (shop_id, listing_status);
create index orders_customer_created_idx on public.orders (customer_id, created_at desc);
create index orders_reseller_status_idx on public.orders (reseller_id, order_status);
create index order_items_supplier_order_idx on public.order_items (supplier_id, order_id);
create index stock_reservations_variant_status_expires_idx on public.stock_reservations (variant_id, reservation_status, expires_at);
create index delivery_quotes_order_status_idx on public.delivery_quotes (order_id, quote_status);
create index settlements_supplier_status_due_idx on public.settlements (supplier_id, settlement_status, due_at);
create index commissions_reseller_status_idx on public.commissions (reseller_id, commission_status);
create index withdrawals_reseller_status_idx on public.withdrawals (reseller_id, withdrawal_status);
create index disputes_order_status_idx on public.disputes (order_id, dispute_status);
create index returns_order_status_idx on public.returns (order_id, return_status);
create index notifications_recipient_created_idx on public.notifications (recipient_profile_id, created_at desc);
create index audit_logs_target_created_idx on public.audit_logs (target_entity_type, target_entity_id, created_at desc);
create index admin_actions_target_created_idx on public.admin_actions (target_entity_type, target_entity_id, created_at desc);

create function public.jwt_subject()
returns text
language sql
stable
as $$
  select nullif(auth.jwt() ->> 'sub', '');
$$;

create function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from public.profiles p
  where p.clerk_user_id = public.jwt_subject()
    and p.deleted_at is null
    and p.account_status = 'active'
  limit 1;
$$;

create function public.has_admin_role(required_role public.user_role default 'admin')
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_staff s
    where s.profile_id = public.current_profile_id()
      and s.staff_status = 'active'
      and s.deleted_at is null
      and (
        s.admin_role = 'super_admin'
        or required_role in ('support_staff', 'finance_staff', 'admin') and s.admin_role = 'admin'
        or s.admin_role = required_role
      )
  );
$$;

create function public.is_supplier_member(target_supplier_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.suppliers s
    where s.id = target_supplier_id
      and s.owner_profile_id = public.current_profile_id()
      and s.deleted_at is null
  )
  or exists (
    select 1
    from public.supplier_team_members stm
    where stm.supplier_id = target_supplier_id
      and stm.profile_id = public.current_profile_id()
      and stm.staff_status = 'active'
      and stm.deleted_at is null
  );
$$;

create function public.is_supplier_owner(target_supplier_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.suppliers s
    where s.id = target_supplier_id
      and s.owner_profile_id = public.current_profile_id()
      and s.deleted_at is null
  );
$$;

create function public.has_supplier_permission(target_supplier_id uuid, permission_key text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_supplier_owner(target_supplier_id)
  or exists (
    select 1
    from public.supplier_team_members stm
    where stm.supplier_id = target_supplier_id
      and stm.profile_id = public.current_profile_id()
      and stm.staff_status = 'active'
      and stm.deleted_at is null
      and coalesce((stm.permissions ->> permission_key)::boolean, false)
  );
$$;

create function public.is_reseller_owner(target_reseller_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.resellers r
    where r.id = target_reseller_id
      and r.profile_id = public.current_profile_id()
      and r.deleted_at is null
  );
$$;

create function public.is_customer_owner(target_customer_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.customers c
    where c.id = target_customer_id
      and c.profile_id = public.current_profile_id()
      and c.deleted_at is null
  );
$$;

create function public.is_order_participant(target_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.orders o
    where o.id = target_order_id
      and (
        public.is_customer_owner(o.customer_id)
        or public.is_reseller_owner(o.reseller_id)
        or exists (
          select 1
          from public.order_items oi
          where oi.order_id = o.id
            and public.is_supplier_member(oi.supplier_id)
        )
      )
  );
$$;

create function public.can_insert_audit_log(actor_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select actor_id is not null
    and actor_id = public.current_profile_id();
$$;

alter table public.profiles enable row level security;
alter table public.profiles force row level security;
alter table public.admin_staff enable row level security;
alter table public.admin_staff force row level security;
alter table public.customers enable row level security;
alter table public.customers force row level security;
alter table public.resellers enable row level security;
alter table public.resellers force row level security;
alter table public.reseller_shops enable row level security;
alter table public.reseller_shops force row level security;
alter table public.suppliers enable row level security;
alter table public.suppliers force row level security;
alter table public.supplier_team_members enable row level security;
alter table public.supplier_team_members force row level security;
alter table public.products enable row level security;
alter table public.products force row level security;
alter table public.product_variants enable row level security;
alter table public.product_variants force row level security;
alter table public.product_images enable row level security;
alter table public.product_images force row level security;
alter table public.inventory_movements enable row level security;
alter table public.inventory_movements force row level security;
alter table public.reseller_products enable row level security;
alter table public.reseller_products force row level security;
alter table public.orders enable row level security;
alter table public.orders force row level security;
alter table public.order_items enable row level security;
alter table public.order_items force row level security;
alter table public.stock_reservations enable row level security;
alter table public.stock_reservations force row level security;
alter table public.delivery_quotes enable row level security;
alter table public.delivery_quotes force row level security;
alter table public.settlements enable row level security;
alter table public.settlements force row level security;
alter table public.commissions enable row level security;
alter table public.commissions force row level security;
alter table public.withdrawals enable row level security;
alter table public.withdrawals force row level security;
alter table public.disputes enable row level security;
alter table public.disputes force row level security;
alter table public.returns enable row level security;
alter table public.returns force row level security;
alter table public.notifications enable row level security;
alter table public.notifications force row level security;
alter table public.audit_logs enable row level security;
alter table public.audit_logs force row level security;
alter table public.admin_actions enable row level security;
alter table public.admin_actions force row level security;

create policy "profiles_select_own_or_admin"
  on public.profiles for select
  using (id = public.current_profile_id() or public.has_admin_role('support_staff'));

create policy "profiles_insert_self_non_admin"
  on public.profiles for insert
  with check (clerk_user_id = public.jwt_subject() and primary_role in ('customer', 'reseller', 'supplier_owner'));

create policy "profiles_update_admin_only_until_profile_rpc"
  on public.profiles for update
  using (public.has_admin_role('admin'))
  with check (public.has_admin_role('admin'));

create policy "admin_staff_select_admins"
  on public.admin_staff for select
  using (public.has_admin_role('admin'));

create policy "admin_staff_insert_super_admins"
  on public.admin_staff for insert
  with check (public.has_admin_role('super_admin'));

create policy "admin_staff_update_super_admins"
  on public.admin_staff for update
  using (public.has_admin_role('super_admin'))
  with check (public.has_admin_role('super_admin'));

create policy "customers_select_own_or_admin"
  on public.customers for select
  using (public.is_customer_owner(id) or public.has_admin_role('support_staff'));

create policy "customers_insert_own_or_admin"
  on public.customers for insert
  with check (profile_id = public.current_profile_id() or public.has_admin_role('admin'));

create policy "customers_update_support_admin_until_profile_rpc"
  on public.customers for update
  using (public.has_admin_role('support_staff'))
  with check (public.has_admin_role('support_staff'));

create policy "resellers_select_own_or_admin"
  on public.resellers for select
  using (public.is_reseller_owner(id) or public.has_admin_role('support_staff'));

create policy "resellers_insert_own_or_admin"
  on public.resellers for insert
  with check (profile_id = public.current_profile_id() or public.has_admin_role('admin'));

create policy "resellers_update_admin_only_until_reseller_rpc"
  on public.resellers for update
  using (public.has_admin_role('admin'))
  with check (public.has_admin_role('admin'));

create policy "reseller_shops_select_owner_or_admin"
  on public.reseller_shops for select
  using (public.is_reseller_owner(reseller_id) or public.has_admin_role('support_staff'));

create policy "reseller_shops_insert_owner_or_admin"
  on public.reseller_shops for insert
  with check (public.is_reseller_owner(reseller_id) or public.has_admin_role('admin'));

create policy "reseller_shops_update_admin_only_until_shop_rpc"
  on public.reseller_shops for update
  using (public.has_admin_role('admin'))
  with check (public.has_admin_role('admin'));

create policy "suppliers_select_members_or_admin"
  on public.suppliers for select
  using (public.is_supplier_member(id) or public.has_admin_role('support_staff'));

create policy "suppliers_insert_owner_or_admin"
  on public.suppliers for insert
  with check (owner_profile_id = public.current_profile_id() or public.has_admin_role('admin'));

create policy "suppliers_update_admin_only_until_supplier_rpc"
  on public.suppliers for update
  using (public.has_admin_role('admin'))
  with check (public.has_admin_role('admin'));

create policy "supplier_team_select_members_or_admin"
  on public.supplier_team_members for select
  using (public.is_supplier_member(supplier_id) or public.has_admin_role('support_staff'));

create policy "supplier_team_insert_owner_or_admin"
  on public.supplier_team_members for insert
  with check (public.is_supplier_owner(supplier_id) or public.has_admin_role('admin'));

create policy "supplier_team_update_owner_or_admin"
  on public.supplier_team_members for update
  using (public.is_supplier_owner(supplier_id) or public.has_admin_role('admin'))
  with check (public.is_supplier_owner(supplier_id) or public.has_admin_role('admin'));

create policy "products_select_supplier_or_admin"
  on public.products for select
  using (public.is_supplier_member(supplier_id) or public.has_admin_role('support_staff'));

create policy "products_insert_supplier_product_permission_or_admin"
  on public.products for insert
  with check (public.has_supplier_permission(supplier_id, 'products.create') or public.has_admin_role('admin'));

create policy "products_update_admin_only_until_product_rpc"
  on public.products for update
  using (public.has_admin_role('admin'))
  with check (public.has_admin_role('admin'));

create policy "product_variants_select_supplier_or_admin"
  on public.product_variants for select
  using (
    public.has_admin_role('support_staff')
    or exists (
      select 1 from public.products p
      where p.id = product_variants.product_id
        and public.is_supplier_member(p.supplier_id)
    )
  );

create policy "product_variants_insert_supplier_product_permission_or_admin"
  on public.product_variants for insert
  with check (
    public.has_admin_role('admin')
    or exists (
      select 1 from public.products p
      where p.id = product_variants.product_id
        and public.has_supplier_permission(p.supplier_id, 'products.create')
    )
  );

create policy "product_variants_update_admin_only_until_stock_rpc"
  on public.product_variants for update
  using (public.has_admin_role('admin'))
  with check (public.has_admin_role('admin'));

create policy "product_images_select_supplier_or_admin"
  on public.product_images for select
  using (
    public.has_admin_role('support_staff')
    or exists (
      select 1 from public.products p
      where p.id = product_images.product_id
        and public.is_supplier_member(p.supplier_id)
    )
  );

create policy "product_images_insert_supplier_or_admin"
  on public.product_images for insert
  with check (
    public.has_admin_role('admin')
    or exists (
      select 1 from public.products p
      where p.id = product_images.product_id
        and public.has_supplier_permission(p.supplier_id, 'products.update')
    )
  );

create policy "product_images_update_admin_only_until_media_rpc"
  on public.product_images for update
  using (public.has_admin_role('admin'))
  with check (public.has_admin_role('admin'));

create policy "inventory_movements_select_supplier_or_admin"
  on public.inventory_movements for select
  using (public.is_supplier_member(supplier_id) or public.has_admin_role('support_staff'));

create policy "inventory_movements_insert_stock_permission_or_admin"
  on public.inventory_movements for insert
  with check (public.has_supplier_permission(supplier_id, 'stock.adjust') or public.has_admin_role('admin'));

create policy "reseller_products_select_owner_or_admin"
  on public.reseller_products for select
  using (public.is_reseller_owner(reseller_id) or public.has_admin_role('support_staff'));

create policy "reseller_products_insert_owner_or_admin"
  on public.reseller_products for insert
  with check (public.is_reseller_owner(reseller_id) or public.has_admin_role('admin'));

create policy "reseller_products_update_admin_only_until_listing_rpc"
  on public.reseller_products for update
  using (public.has_admin_role('admin'))
  with check (public.has_admin_role('admin'));

create policy "orders_select_participants_or_admin"
  on public.orders for select
  using (public.is_order_participant(id) or public.has_admin_role('support_staff'));

create policy "orders_insert_customer_or_admin"
  on public.orders for insert
  with check (public.is_customer_owner(customer_id) or public.has_admin_role('admin'));

create policy "orders_update_support_admin_until_order_rpc"
  on public.orders for update
  using (public.has_admin_role('support_staff'))
  with check (public.has_admin_role('support_staff'));

create policy "order_items_select_participants_or_admin"
  on public.order_items for select
  using (
    public.has_admin_role('support_staff')
    or public.is_supplier_member(supplier_id)
    or exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
        and (public.is_customer_owner(o.customer_id) or public.is_reseller_owner(o.reseller_id))
    )
  );

create policy "order_items_insert_admin_only"
  on public.order_items for insert
  with check (public.has_admin_role('admin'));

create policy "stock_reservations_select_participants_or_admin"
  on public.stock_reservations for select
  using (
    public.is_customer_owner(customer_id)
    or public.is_reseller_owner(reseller_id)
    or exists (
      select 1 from public.products p
      where p.id = stock_reservations.product_id
        and public.is_supplier_member(p.supplier_id)
    )
    or public.has_admin_role('support_staff')
  );

create policy "stock_reservations_insert_admin_only_until_rpc"
  on public.stock_reservations for insert
  with check (public.has_admin_role('admin'));

create policy "delivery_quotes_select_order_participants_or_admin"
  on public.delivery_quotes for select
  using (public.is_order_participant(order_id) or public.has_admin_role('support_staff'));

create policy "delivery_quotes_insert_admin_or_supplier_member"
  on public.delivery_quotes for insert
  with check (
    public.has_admin_role('support_staff')
    or exists (
      select 1
      from public.order_items oi
      where oi.order_id = delivery_quotes.order_id
        and public.is_supplier_member(oi.supplier_id)
    )
  );

create policy "delivery_quotes_update_support_admin_until_quote_rpc"
  on public.delivery_quotes for update
  using (public.has_admin_role('support_staff'))
  with check (public.has_admin_role('support_staff'));

create policy "settlements_select_supplier_finance_admin"
  on public.settlements for select
  using (public.is_supplier_owner(supplier_id) or public.has_admin_role('finance_staff') or public.has_admin_role('admin'));

create policy "settlements_insert_finance_admin"
  on public.settlements for insert
  with check (public.has_admin_role('finance_staff') or public.has_admin_role('admin'));

create policy "settlements_update_finance_admin"
  on public.settlements for update
  using (public.has_admin_role('finance_staff') or public.has_admin_role('admin'))
  with check (public.has_admin_role('finance_staff') or public.has_admin_role('admin'));

create policy "commissions_select_reseller_finance_admin"
  on public.commissions for select
  using (public.is_reseller_owner(reseller_id) or public.has_admin_role('finance_staff') or public.has_admin_role('admin'));

create policy "commissions_insert_finance_admin"
  on public.commissions for insert
  with check (public.has_admin_role('finance_staff') or public.has_admin_role('admin'));

create policy "commissions_update_finance_admin"
  on public.commissions for update
  using (public.has_admin_role('finance_staff') or public.has_admin_role('admin'))
  with check (public.has_admin_role('finance_staff') or public.has_admin_role('admin'));

create policy "withdrawals_select_reseller_finance_admin"
  on public.withdrawals for select
  using (public.is_reseller_owner(reseller_id) or public.has_admin_role('finance_staff') or public.has_admin_role('admin'));

create policy "withdrawals_insert_reseller_or_admin"
  on public.withdrawals for insert
  with check (public.is_reseller_owner(reseller_id) or public.has_admin_role('finance_staff') or public.has_admin_role('admin'));

create policy "withdrawals_update_finance_admin"
  on public.withdrawals for update
  using (public.has_admin_role('finance_staff') or public.has_admin_role('admin'))
  with check (public.has_admin_role('finance_staff') or public.has_admin_role('admin'));

create policy "disputes_select_participants_or_admin"
  on public.disputes for select
  using (
    opened_by_profile_id = public.current_profile_id()
    or (order_id is not null and public.is_order_participant(order_id))
    or public.has_admin_role('support_staff')
  );

create policy "disputes_insert_authenticated_participant"
  on public.disputes for insert
  with check (
    opened_by_profile_id = public.current_profile_id()
    and (order_id is null or public.is_order_participant(order_id))
  );

create policy "disputes_update_support_admin"
  on public.disputes for update
  using (public.has_admin_role('support_staff'))
  with check (public.has_admin_role('support_staff'));

create policy "returns_select_participants_or_admin"
  on public.returns for select
  using (
    requested_by_profile_id = public.current_profile_id()
    or public.is_order_participant(order_id)
    or public.has_admin_role('support_staff')
  );

create policy "returns_insert_customer_participant"
  on public.returns for insert
  with check (
    requested_by_profile_id = public.current_profile_id()
    and public.is_order_participant(order_id)
  );

create policy "returns_update_support_admin"
  on public.returns for update
  using (public.has_admin_role('support_staff'))
  with check (public.has_admin_role('support_staff'));

create policy "notifications_select_recipient_or_admin"
  on public.notifications for select
  using (recipient_profile_id = public.current_profile_id() or public.has_admin_role('support_staff'));

create policy "notifications_insert_admin_only_until_notification_service"
  on public.notifications for insert
  with check (public.has_admin_role('admin'));

create policy "notifications_update_recipient_read_state_or_admin"
  on public.notifications for update
  using (recipient_profile_id = public.current_profile_id() or public.has_admin_role('support_staff'))
  with check (recipient_profile_id = public.current_profile_id() or public.has_admin_role('support_staff'));

create policy "audit_logs_select_admin_only"
  on public.audit_logs for select
  using (public.has_admin_role('admin'));

create policy "audit_logs_insert_actor_or_admin"
  on public.audit_logs for insert
  with check (public.can_insert_audit_log(actor_profile_id) or public.has_admin_role('admin'));

create policy "admin_actions_select_admins"
  on public.admin_actions for select
  using (public.has_admin_role('support_staff'));

create policy "admin_actions_insert_admins"
  on public.admin_actions for insert
  with check (public.has_admin_role('admin'));

create policy "admin_actions_update_admins"
  on public.admin_actions for update
  using (public.has_admin_role('admin'))
  with check (public.has_admin_role('admin'));

comment on table public.products is 'Base catalog table contains sensitive supplier base price and platform margin. Public/customer catalog reads must use future safe views or RPCs, not this table directly.';
comment on table public.order_items is 'Immutable price snapshot table. Updates should be avoided except through audited correction/admin override functions.';
comment on table public.stock_reservations is 'Direct inserts are admin-only until reserve_stock/create_checkout_order RPCs are implemented with row locks.';
comment on table public.audit_logs is 'Append-only audit foundation. Do not store raw secrets, unmasked payout data, or public URLs to private documents.';
comment on table public.profiles is 'Direct self-updates are intentionally blocked until a profile RPC/server action limits writes to contact fields and writes audit entries for sensitive changes.';
comment on table public.customers is 'Customer self-updates that touch delivery/contact fields should use a future column-safe profile RPC; risk/status fields are admin controlled.';
comment on table public.resellers is 'Reseller approval, risk, payout, and commission fields are admin/RPC controlled; direct owner table updates are blocked.';
comment on table public.reseller_shops is 'Shop profile edits and visibility/status changes should use column-safe server actions; direct owner updates are blocked in RLS.';
comment on table public.reseller_products is 'Listing margin/status edits should use a validated listing RPC that enforces max margin and audit rules; direct owner updates are blocked.';
comment on table public.suppliers is 'Supplier verification, risk, settlement, trust, and status fields are admin/RPC controlled; owner edits should use audited server actions.';
comment on table public.orders is 'Order, payment, delivery, and confirmation transitions must use audited RPC/server actions, not participant direct table updates.';
comment on table public.settlements is 'Finance/admin writes are allowed as a foundation only; production settlement verification must move to audited RPCs with reason metadata.';
comment on table public.commissions is 'Finance/admin writes are allowed as a foundation only; production commission release must move to audited RPCs.';
