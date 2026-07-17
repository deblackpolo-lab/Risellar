# Risellar RLS Test Fixture Plan

## Scope

This is a development-only fixture plan. Do not use production data, real customers, real orders, real phone numbers, or real payout details.

The fixtures are designed to test RLS boundaries in the confirmed development Supabase project without Docker.

## Identity Fixtures

Use deterministic fake Clerk subjects. These are not real Clerk user IDs:

| Fixture | Clerk subject | Role |
| --- | --- | --- |
| customer A | `dev_clerk_customer_a` | `customer` |
| customer B | `dev_clerk_customer_b` | `customer` |
| reseller A | `dev_clerk_reseller_a` | `reseller` |
| reseller B | `dev_clerk_reseller_b` | `reseller` |
| supplier owner A | `dev_clerk_supplier_owner_a` | `supplier_owner` |
| supplier owner B | `dev_clerk_supplier_owner_b` | `supplier_owner` |
| supplier A inventory manager | `dev_clerk_supplier_a_inventory_manager` | `supplier_inventory_manager` |
| support operator | `dev_clerk_support_operator` | `admin_staff.admin_role = support_staff` |
| finance operator | `dev_clerk_finance_operator` | `admin_staff.admin_role = finance_staff` |
| admin user | `dev_clerk_admin` | `admin_staff.admin_role = admin` |
| super admin user | `dev_clerk_super_admin` | `admin_staff.admin_role = super_admin` |

Use `example.invalid` emails only.

Admin/support/finance/super-admin test profiles cannot be inserted with admin-like `profiles.primary_role` values because the schema intentionally prevents direct self-admin signup. Create their `profiles` rows with an allowed non-admin role, then create matching `admin_staff` rows with the desired `admin_role`.

## Entity Fixtures

| Fixture group | Records |
| --- | --- |
| Customers | customer A, customer B |
| Resellers | reseller A, reseller B |
| Shops | reseller A shop, reseller B shop |
| Suppliers | supplier A, supplier B |
| Supplier team | supplier A inventory manager with controlled permissions |
| Products | supplier A product/variant/image, supplier B product/variant/image |
| Listings | reseller A listing for supplier A product, reseller B listing for supplier B product |
| Orders | order A linking customer A/reseller A/supplier A; order B linking customer B/reseller B/supplier B |
| Finance | settlement A/B, commission A/B, withdrawal A/B |
| Support | dispute A/B, return A/B, notifications A/B |
| Audit | audit log for admin action and user action |

## Permission Fixtures

Supplier A inventory manager should have:

```json
{
  "products.create": true,
  "products.update": true,
  "stock.adjust": true
}
```

Negative tests should remove or omit one permission at a time to prove permission-gated inserts fail.

## Sensitive Data Rules

Use fake values only:

- Emails: `*@example.invalid`
- Phone fields: omitted or fake placeholders
- Storage paths: `dev-only/...`
- Payout/account fields: masked placeholders only
- No Ghana Card, MoMo, bank, production order, or real customer data

## Cleanup Plan

Fixtures should be inserted with identifiable prefixes:

- `dev-rls-`
- `RLS-DEV-`

Cleanup should target only those development fixture rows.

Do not use destructive database resets.

Recommended cleanup style:

```sql
-- Development only.
-- Delete only rows with dev fixture identifiers and in child-to-parent order.
```

No cleanup SQL should be run without explicit approval.

## Run Strategy

Preferred execution options without Docker:

1. Supabase SQL Editor on the confirmed development project.
2. `npx supabase db query --linked --file scripts/rls/rls-fixtures-dev-only.sql` after explicit approval.
3. `psql` against the development database if the user installs PostgreSQL client tools.

Do not run fixture inserts until explicitly approved.
