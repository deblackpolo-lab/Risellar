# Risellar Backend Security Phase 1 Audited RPC and Storage Report

## A. Summary

Backend Security Phase 1 adds a conservative audited operations foundation without connecting frontend flows to live database writes.

The new migration creates controlled RPCs for order confirmation, delivery quote transitions, expired reservation release, supplier settlement proof and verification flows, commission release and withdrawal review, manual override recording, audit log insertion, security-invoker operational views, restricted grants, and a guarded product image storage bucket/policy foundation.

This is safe to apply to the confirmed development Supabase project after approval. It is not a production-apply recommendation.

## B. RPCs/functions created

Migration:

- `supabase/migrations/20260717194000_audited_rpcs_views_grants_storage_foundation.sql`

Created:

- `public.create_audit_log_entry`
- `public.admin_manual_override_record`
- `public.confirm_customer_order`
- `public.release_expired_reservation`
- `public.mark_order_ready_for_delivery`
- `public.record_delivery_quote`
- `public.approve_delivery_quote`
- `public.submit_supplier_settlement_proof`
- `public.verify_supplier_settlement`
- `public.mark_settlement_overdue`
- `public.restrict_supplier_for_overdue_settlement`
- `public.mark_commission_pending`
- `public.release_commission_after_settlement`
- `public.request_commission_withdrawal`
- `public.approve_or_reject_withdrawal`
- `public.storage_path_supplier_id`

Deferred instead of unsafe implementation:

- `create_order_with_snapshot`
- `reserve_stock_for_order`
- broad `admin_update_sensitive_status`

Reason: full checkout/order creation needs an idempotency contract, cart/input payload contract, delivery handling, and stronger boundary tests before exposing a single order-creation RPC. The migration avoids trusting client-sent price snapshots or inventing incomplete checkout rules.

## C. Views created

Created security-invoker views:

- `public.supplier_settlement_summary`
- `public.reseller_commission_summary`
- `public.supplier_product_image_review_queue`

The views rely on table RLS as the authoritative boundary and are granted only to `authenticated`.

## D. Grants/revokes added

The migration revokes function/view access from `public` and grants narrow authenticated access for RPC entry points that validate caller role or ownership internally.

No anonymous mutation path and no client DELETE path were added.

## E. Storage policies created or deferred

Created a guarded storage foundation that only runs if `storage.buckets` and `storage.objects` exist:

- creates private `product-images` bucket if absent
- adds authenticated supplier/admin select policy
- adds authenticated supplier insert policy
- adds authenticated supplier update policy
- parses supplier ownership from paths shaped as `supplier_id/product_id/file_name`

Deferred:

- public-read policy for approved product images
- settlement proof bucket policies
- supplier verification proof policies
- dispute/return evidence bucket policies

Reason: public image reads need an approval-aware object/metadata contract. Sensitive proof buckets need separate private access tests before they should be added.

## F. Audit enforcement approach

Sensitive RPCs are `SECURITY DEFINER` only where needed to perform controlled table mutations blocked by direct RLS. Each such function:

- sets `search_path = public`
- validates the current active profile
- validates ownership or admin/finance/support role
- writes an audit log entry in the same transaction
- avoids direct client DELETE paths
- avoids changing immutable order price snapshots

## G. What is implemented now

Implemented now:

- customer order confirmation through audited RPC
- customer delivery quote approval through audited RPC
- supplier/support delivery quote recording through audited RPC
- supplier/support ready-for-delivery transition through audited RPC
- support/admin expired reservation release with stock counter adjustment
- supplier-owner settlement proof metadata submission
- finance/admin settlement verification, overdue marking, and supplier restriction
- finance/admin commission release only after linked settlement is paid
- reseller-owned withdrawal request with available-balance lock
- finance/admin withdrawal approval or rejection
- manual override recording with reason and audit trail
- security-invoker summary/review views
- guarded private product image storage bucket/policies

## H. What remains deferred

Deferred:

- full checkout `create_order_with_snapshot`
- first-class `reserve_stock_for_order`
- idempotent checkout/reservation protection
- reservation commit on paid/delivered order completion
- payment collection and settlement creation automation
- settlement proof private bucket policy
- production-ready public approved product image read policy
- storage policy boundary tests
- RPC boundary tests
- frontend/server-action integration

## I. Security risks addressed

Addressed:

- no client-supplied order price snapshot mutation
- no direct normal-user settlement verification
- no direct normal-user commission release
- no direct normal-user withdrawal approval
- supplier settlement proof uses private storage paths, not public URLs
- product image storage writes are supplier-path constrained
- finance/admin-sensitive operations are coupled to audit log writes
- direct broad grants were not added

## J. Security risks still remaining

Remaining:

- RPC boundary tests have not been created or run yet.
- Storage object policies have only been dry-run validated, not boundary tested.
- Full checkout/reservation concurrency is still blocked until idempotency and stock-lock tests are implemented.
- Production remains blocked until development application and RPC/storage RLS tests pass.

## K. Dry-run result

`npx supabase db push --dry-run` passed.

Output summary:

- Dry-run mode confirmed migrations would not be pushed.
- Connected to the linked remote database.
- Would apply `20260717194000_audited_rpcs_views_grants_storage_foundation.sql`.
- Finished without SQL errors.

No real `npx supabase db push` was run.

## L. Commands run/results

- `git status --short` - showed only the new migration before report creation.
- `git diff --check` - passed.
- `npm test` - passed, 19 test files and 85 tests.
- `npm run typecheck` - passed.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npx supabase --version` - `2.109.1`.
- `git check-ignore -v .env.local` - `.env.local` ignored by `.gitignore`.
- `git check-ignore -v supabase/.temp/` - `supabase/.temp/` ignored by `.gitignore`.
- `npx supabase status` - did not provide useful linked-project evidence because local Docker is unavailable on this machine.
- `npx supabase db push --dry-run` - passed; one migration would be applied.

## M. Secret scan result

No real secret values were found in the new migration.

Repository scans produced expected documentation/placeholders only, including `.env.example` placeholder key names and historical reports that mention secret-scan terms. No `.env.local` was staged or committed.

## N. Files changed

Created:

- `supabase/migrations/20260717194000_audited_rpcs_views_grants_storage_foundation.sql`
- `docs/RISELLAR_BACKEND_SECURITY_PHASE_1_AUDITED_RPC_STORAGE_REPORT.md`

## O. Current git status

At report creation time, the working tree contains these untracked files:

- `supabase/migrations/20260717194000_audited_rpcs_views_grants_storage_foundation.sql`
- `docs/RISELLAR_BACKEND_SECURITY_PHASE_1_AUDITED_RPC_STORAGE_REPORT.md`

## P. Whether real db push is recommended for development

Yes, after explicit user approval, it is reasonable to apply this migration to the confirmed development Supabase project only.

Recommended next step is a development-only `npx supabase db push`, followed by RPC/storage boundary test scaffolding and execution. Production remains blocked.
