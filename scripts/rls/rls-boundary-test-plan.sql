-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- RLS boundary test scaffolding for the Risellar development Supabase project.
-- Do not run unless fake fixture records have been inserted and explicitly approved.

-- Supabase/PostgREST RLS helpers commonly read JWT claims from request.jwt.claims.
-- These blocks simulate authenticated requests by setting role and JWT subject.
-- If this strategy does not work in the chosen execution environment, use real
-- development Clerk/Supabase sessions or psql with equivalent role/claim settings.

begin;

-- Anonymous boundary:
set local role anon;
select 'anonymous_profiles_count_expected_0' as test_name, count(*) as observed_count from public.profiles;
select 'anonymous_products_count_expected_0' as test_name, count(*) as observed_count from public.products;

rollback;

begin;

-- Customer A boundary:
set local role authenticated;
set local request.jwt.claims = '{"sub":"dev_clerk_customer_a"}';

select 'customer_a_own_customer_rows_expected_1' as test_name, count(*) as observed_count
from public.customers;

select 'customer_a_supplier_products_expected_0' as test_name, count(*) as observed_count
from public.products;

select 'customer_a_settlements_expected_0' as test_name, count(*) as observed_count
from public.settlements;

-- Expected: direct sensitive updates should affect zero rows or fail by RLS.
-- update public.orders set payment_collection_status = 'collected' where order_number = 'RLS-DEV-ORDER-A';

rollback;

begin;

-- Reseller A boundary:
set local role authenticated;
set local request.jwt.claims = '{"sub":"dev_clerk_reseller_a"}';

select 'reseller_a_own_reseller_rows_expected_1' as test_name, count(*) as observed_count
from public.resellers;

select 'reseller_a_own_commissions_expected_positive' as test_name, count(*) as observed_count
from public.commissions;

select 'reseller_a_supplier_products_expected_0' as test_name, count(*) as observed_count
from public.products;

-- Expected: reseller cannot update supplier product base data.
-- update public.products set base_price_amount = base_price_amount + 1 where slug = 'dev-rls-supplier-a-product';

rollback;

begin;

-- Supplier owner A boundary:
set local role authenticated;
set local request.jwt.claims = '{"sub":"dev_clerk_supplier_owner_a"}';

select 'supplier_owner_a_own_supplier_rows_expected_1' as test_name, count(*) as observed_count
from public.suppliers;

select 'supplier_owner_a_own_products_expected_positive' as test_name, count(*) as observed_count
from public.products;

select 'supplier_owner_a_other_supplier_rows_expected_0' as test_name, count(*) as observed_count
from public.suppliers
where business_name = 'Dev Supplier B';

-- Expected: direct sensitive supplier updates should fail by RLS.
-- update public.suppliers set verification_status = 'approved' where business_name = 'Dev Supplier A';

rollback;

begin;

-- Supplier inventory manager A boundary:
set local role authenticated;
set local request.jwt.claims = '{"sub":"dev_clerk_supplier_a_inventory_manager"}';

select 'inventory_manager_a_supplier_products_expected_positive' as test_name, count(*) as observed_count
from public.products;

select 'inventory_manager_a_settlements_expected_0' as test_name, count(*) as observed_count
from public.settlements;

select 'inventory_manager_a_supplier_team_rows_expected_scoped' as test_name, count(*) as observed_count
from public.supplier_team_members;

rollback;

begin;

-- Support operator boundary:
set local role authenticated;
set local request.jwt.claims = '{"sub":"dev_clerk_support_operator"}';

select 'support_can_read_support_queues_expected_positive' as test_name, count(*) as observed_count
from public.disputes;

select 'support_finance_commissions_expected_0' as test_name, count(*) as observed_count
from public.commissions;

rollback;

begin;

-- Finance operator boundary:
set local role authenticated;
set local request.jwt.claims = '{"sub":"dev_clerk_finance_operator"}';

select 'finance_settlements_expected_positive' as test_name, count(*) as observed_count
from public.settlements;

select 'finance_commissions_expected_positive' as test_name, count(*) as observed_count
from public.commissions;

select 'finance_admin_staff_expected_0' as test_name, count(*) as observed_count
from public.admin_staff;

rollback;

begin;

-- Admin boundary:
set local role authenticated;
set local request.jwt.claims = '{"sub":"dev_clerk_admin"}';

select 'admin_audit_logs_expected_visible' as test_name, count(*) as observed_count
from public.audit_logs;

select 'admin_operational_profiles_expected_visible' as test_name, count(*) as observed_count
from public.profiles;

rollback;

begin;

-- Super admin boundary:
set local role authenticated;
set local request.jwt.claims = '{"sub":"dev_clerk_super_admin"}';

select 'super_admin_admin_staff_expected_visible' as test_name, count(*) as observed_count
from public.admin_staff;

-- Expected: direct deletes remain unavailable because no FOR DELETE policies exist.
-- delete from public.admin_staff where false;

rollback;
