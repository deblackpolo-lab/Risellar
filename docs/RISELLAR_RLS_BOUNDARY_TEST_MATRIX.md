# Risellar RLS Boundary Test Matrix

## Scope

This matrix covers the current Supabase schema/RLS foundation after `20260717000000_risellar_schema_rls_foundation.sql` was applied to the confirmed development Supabase project.

Production remains blocked.

## Identity Model Under Test

RLS does not use `auth.uid()`.

The migration uses `auth.jwt() ->> 'sub'` through `public.jwt_subject()`, then maps that subject to `public.profiles.clerk_user_id` through `public.current_profile_id()`.

Role and ownership checks are relational:

- `profiles.primary_role`
- `admin_staff.admin_role`
- `customers.profile_id`
- `resellers.profile_id`
- `suppliers.owner_profile_id`
- `supplier_team_members.profile_id`
- order/product/settlement/commission ownership relationships

## Protected Tables

All 24 application tables have RLS enabled and forced:

| Domain | Tables |
| --- | --- |
| Identity/admin | `profiles`, `admin_staff` |
| Customer/reseller/supplier | `customers`, `resellers`, `reseller_shops`, `suppliers`, `supplier_team_members` |
| Catalog/stock | `products`, `product_variants`, `product_images`, `inventory_movements`, `reseller_products`, `stock_reservations` |
| Orders/delivery | `orders`, `order_items`, `delivery_quotes` |
| Finance | `settlements`, `commissions`, `withdrawals` |
| Support/audit | `disputes`, `returns`, `notifications`, `audit_logs`, `admin_actions` |

## Role Matrix

Legend:

- Allow: query should return own/scoped rows or mutation should pass.
- Deny: query should return zero rows or mutation should fail by RLS/check constraint.
- Admin path: allowed only for appropriate admin/support/finance role and still requires future audited RPCs before production.

| Role | Boundary | Tables / Operations | Expected |
| --- | --- | --- | --- |
| anonymous | Cannot access private data | `select` from all protected tables | Deny |
| anonymous | Cannot write protected data | `insert`, `update`, `delete` on all protected tables | Deny |
| customer A | Can read own profile/customer row | `profiles`, `customers` | Allow own only |
| customer A | Cannot read customer B | `profiles`, `customers`, `orders`, `disputes`, `returns`, `notifications` | Deny other user's rows |
| customer A | Can read own order/support rows | `orders`, `order_items`, `delivery_quotes`, `disputes`, `returns`, `notifications` | Allow own participant rows |
| customer A | Cannot see supplier private product tables directly | `products`, `product_variants`, `product_images`, `inventory_movements`, `settlements` | Deny |
| customer A | Cannot mutate sensitive fields | `profiles`, `customers`, `orders`, `order_items`, `settlements`, `commissions` | Deny direct updates |
| reseller A | Can read own reseller/shop/listings | `resellers`, `reseller_shops`, `reseller_products` | Allow own only |
| reseller A | Cannot read reseller B | `resellers`, `reseller_shops`, `reseller_products`, `commissions`, `withdrawals` | Deny other reseller rows |
| reseller A | Can read own order/commission/withdrawal rows | `orders`, `order_items`, `commissions`, `withdrawals` | Allow own scoped rows |
| reseller A | Cannot update supplier base product data | `products`, `product_variants`, `inventory_movements` | Deny |
| reseller A | Cannot change listing ownership or price snapshots directly | `reseller_products`, `order_items` | Deny direct updates |
| supplier owner A | Can read own supplier/team/product/stock/order/settlement rows | `suppliers`, `supplier_team_members`, `products`, `product_variants`, `product_images`, `inventory_movements`, `order_items`, `settlements` | Allow own supplier rows |
| supplier owner A | Cannot read supplier B | supplier-scoped tables | Deny other supplier rows |
| supplier owner A | Can manage supplier team as owner | `supplier_team_members` insert/update | Allow owner-scoped |
| supplier owner A | Cannot directly mutate verification/risk/settlement/status fields | `suppliers`, `settlements`, `products`, `product_variants`, `product_images` | Deny unless admin/RPC path |
| supplier inventory manager A | Can read supplier A operational rows | `products`, `product_variants`, `product_images`, `inventory_movements`, supplier order items | Allow scoped by membership |
| supplier inventory manager A | Can insert only permission-gated operational rows | product/media/stock inserts if fixture grants permissions | Allow only with matching permission |
| supplier inventory manager A | Cannot access supplier finance/payout/verification/staff admin | `settlements`, `supplier_team_members`, `suppliers` sensitive updates | Deny |
| supplier inventory manager A | Cannot access supplier B | supplier-scoped tables | Deny |
| support_staff | Can read support/admin queues as designed | `profiles`, `customers`, `resellers`, `suppliers`, `orders`, `disputes`, `returns`, `notifications`, `admin_actions` | Admin path |
| support_staff | Can update support-owned workflow rows | `orders`, `delivery_quotes`, `disputes`, `returns`, `notifications` | Admin path, future audited RPC required |
| support_staff | Cannot manage admin staff or finance-only tables | `admin_staff`, settlement/commission mutations | Deny |
| finance_staff | Can read/write finance scaffolding | `settlements`, `commissions`, `withdrawals` | Admin path, future audited RPC required |
| finance_staff | Cannot manage admin staff/supplier team/product ownership | `admin_staff`, `supplier_team_members`, `products` | Deny |
| admin | Can read broad operational data | most operational tables via `has_admin_role('support_staff')` or admin checks | Admin path |
| admin | Can perform foundation admin writes | selected admin/update policies | Admin path, future audited RPC required |
| super_admin | Can manage admin staff | `admin_staff` insert/update | Allow |
| super_admin | No direct deletes | all protected tables | Deny |

## Mutation Boundaries

These mutation classes must be tested as blocked for normal users:

- Direct deletes on every protected table.
- Updates to role/status/risk/approval fields.
- Updates to settlement, commission, payout, withdrawal fields.
- Updates to admin/internal notes and audit fields.
- Updates to ownership foreign keys.
- Updates to immutable price snapshot fields in `order_items`.
- Product base price/platform margin updates from reseller/customer contexts.

## Minimum Pass Criteria

RLS is ready for development app wiring only when:

- Every role can read only its own/scoped rows.
- Cross-tenant reads return zero rows.
- Normal roles cannot directly update sensitive fields.
- Direct deletes are unavailable.
- Finance/admin scaffolding works only for the correct admin role rows.
- Audit log reads are admin-only.
- Audit log inserts only pass for actor/admin conditions.
- Tests run against development only and use fake fixture records.
