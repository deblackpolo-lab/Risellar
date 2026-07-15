# Risellar Full PRD Report

## A. Summary of PRD Created

Created `docs/RISELLAR_FULL_PRD.md`, a complete product requirements document for Risellar. The PRD translates the approved brand/UI guide and business rules into product requirements for future schema, RLS/security rules, screen map, UI implementation plan, backend implementation plan, test plan, and MVP roadmap.

## B. Source Documents Read

- `docs/RISELLAR_BRAND_UI_SYSTEM_GUIDE.md`
- `docs/RISELLAR_UI_REFERENCE_IMAGE_AUDIT.md`
- `docs/RISELLAR_BRAND_UI_SYSTEM_REVIEW_REPORT.md`
- `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC.md`
- `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC_REPORT.md`

## C. Major Product Decisions Captured

- Risellar is a controlled Ghana reseller marketplace.
- Platform direction is PWA/web, not native mobile.
- Reseller and supplier experiences are mobile-first PWAs.
- Customer checkout is mobile web with account creation.
- Admin is a desktop-first dashboard.
- Clerk is the MVP auth provider for Google/email login.
- Resend is the MVP transactional email provider.
- Pay on Delivery is the core Ghana trust model.
- Supplier settlement controls reseller commission release.
- Atomic stock reservation prevents overselling shared supplier stock.
- Admin queues, audit logs, and risk controls are core product requirements.

## D. MVP Scope Summary

MVP includes auth, customer accounts, reseller onboarding, supplier onboarding/verification, product approval, inventory, reseller catalog/shop links, pricing/margins, customer checkout, Pay on Delivery, stock reservation, customer confirmation, delivery estimates/quotes, supplier fulfillment, supplier settlement, reseller commissions, withdrawals, Resend emails, manual WhatsApp templates, admin queues, audit logs, disputes, promotions, and basic insights.

## E. Out-of-Scope Items

- Native mobile apps.
- Rider/delivery driver app.
- Phone OTP.
- WhatsApp Business API automation.
- Full online payment automation.
- Real-time map tracking.
- Advanced fraud ML.
- Multi-country support.
- Complex subscriptions.
- Fully automated refunds.
- AI recommendations/captions in MVP.

## F. Open Questions

- Should resellers require admin approval before selling?
- What minimum withdrawal amount should be used?
- What supplier settlement limit should apply to new suppliers?
- Who owns delivery coordination by category/location?
- Which Pay Online provider should be selected later?
- Which product categories should launch first?
- Who can view Ghana Card documents?
- How long should audit logs be retained?
- What exact promotion pricing should launch?
- What thresholds define trusted suppliers and customer risk restrictions?

## G. Assumptions Made

- Pay Online remains disabled/placeholder unless a real integration exists.
- Recommended withdrawal default is GH₵50 unless changed.
- Low-risk resellers can onboard while risk/admin controls handle suspicious accounts.
- Supplier settlement remains immediate in MVP.
- Delivery is manually coordinated outside a rider app.
- Admin review remains central for products, suppliers, settlements, disputes, and sensitive overrides.

## H. Files Created/Changed

- Created `docs/RISELLAR_FULL_PRD.md`
- Created `docs/RISELLAR_FULL_PRD_REPORT.md`

## I. Current Git Status

```text
?? docs/
```

## J. Recommended Next Step

Review and approve the PRD. After approval, the next logical documentation task is a database schema and RLS/security planning document, followed by a screen map or implementation plan that still respects the brand guide and business rules.
