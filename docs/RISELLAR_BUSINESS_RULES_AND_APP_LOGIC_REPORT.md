# Risellar Business Rules and App Logic Report

## A. Summary of Document Created

Created `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC.md` as the main business logic source of truth for Risellar. It defines rules for roles, authentication, customer buying, reseller selling, supplier onboarding, product lifecycle, pricing, stock reservation, Pay on Delivery, delivery quote approval, fulfillment, settlement, commission, withdrawals, risk, promotions, notifications, support, returns, audit logs, admin queues, security, MVP boundaries, and future features.

## B. Key Business Rules Captured

- Risellar remains a controlled Ghana reseller marketplace, not an open supplier-to-reseller contact marketplace.
- Platform direction is fixed: reseller and supplier are mobile-first PWAs, customer is mobile web checkout, admin is desktop web dashboard.
- MVP auth uses Clerk with Google/Gmail and email/password; no phone OTP at MVP.
- No guest checkout; customers must create accounts before ordering.
- Supplier base price, platform margin, reseller margin, and customer price are separate pricing layers.
- Delivery is separate from product price.
- Stock reservation happens only at order placement and must be atomic/database-safe.
- Pay on Delivery is the default trust model.
- Supplier may receive customer payment directly at MVP, but must immediately settle Risellar's share.
- Reseller commission becomes available only after supplier settlement is verified.
- Supplier overdue settlement triggers warning, restrictions, hidden products, blocked orders, or suspension.
- Admin operations queues and audit logs are mandatory for sensitive workflows.

## C. Assumptions Made

- The recommended MVP customer confirmation/reservation timeout is 1 hour, matching the source brief.
- Supplier settlement is immediate at MVP, not weekly.
- Pay Online may be disabled or placeholder unless a real payment integration exists.
- Finance Staff and Support Staff are future or limited roles unless specifically approved for MVP.
- Delivery/rider users are outside MVP; delivery is supplier/customer/admin coordinated.

## D. Open Questions

- Whether reseller onboarding requires admin approval at MVP.
- Exact minimum withdrawal amount.
- Exact supplier outstanding settlement limit before order blocking.
- Default delivery owner by category/area.
- Payment provider for Pay Online.
- Launch product categories.
- Who can view Ghana Card documents.
- Whether Finance Staff is MVP or future.
- Audit log retention period.

## E. Files Created/Changed

- Created `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC.md`
- Created `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC_REPORT.md`

## F. Current Git Status

```text
?? docs/
```

## G. Recommended Next Step

Review and approve the business rules document. After approval, the next logical document is the Risellar PRD, which should follow both the business rules document and the mandatory brand/UI guide.
