revoke all on function public.get_customer_order_safe(uuid) from public;
revoke all on function public.get_customer_order_safe(uuid) from anon;
grant execute on function public.get_customer_order_safe(uuid) to authenticated;

comment on function public.get_customer_order_safe(uuid)
  is 'Customer-only read boundary for a single own order. Returns public/customer-safe labels, snapshots, totals, Pay on Delivery status, and reservation status without exposing supplier base price, margins, commissions, settlements, private contacts, risk data, or internal operational data.';
