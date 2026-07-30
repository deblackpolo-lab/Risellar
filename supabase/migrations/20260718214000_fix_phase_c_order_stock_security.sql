-- Checkout Phase C R6 security hardening for order/stock direct-write boundaries.
-- Forward migration only. Does not enable checkout confirmation UI, payments,
-- delivery, supplier preparation, commissions, settlements, withdrawals, or refunds.

revoke insert, update, delete, truncate on table public.orders from anon, authenticated;
revoke insert, update, delete, truncate on table public.order_items from anon, authenticated;
revoke insert, update, delete, truncate on table public.stock_reservations from anon, authenticated;
revoke insert, update, delete, truncate on table public.product_variants from anon, authenticated;

grant select on table public.orders to authenticated;
grant select on table public.order_items to authenticated;
grant select on table public.stock_reservations to authenticated;
grant select on table public.product_variants to authenticated;

comment on table public.orders
  is 'Order rows are created and transitioned through audited RPC/server boundaries. Direct participant writes are revoked for checkout-created commercial data.';

comment on table public.order_items
  is 'Immutable price snapshot table. Direct authenticated writes are revoked; corrections must use audited admin/RPC paths.';

comment on table public.stock_reservations
  is 'Stock reservations are created through audited stock/order RPCs with row locks. Direct authenticated writes are revoked.';

comment on table public.product_variants
  is 'Variant stock is adjusted through audited supplier/product/stock RPCs. Direct authenticated stock writes are revoked.';
