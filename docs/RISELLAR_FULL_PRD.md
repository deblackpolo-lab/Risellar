# Risellar Full Product Requirements Document

## 1. Executive Summary

Risellar is a Ghana reseller marketplace where suppliers list products, resellers sell those products without holding stock, customers buy through reseller shops or links, and Risellar controls pricing, stock reservation, supplier settlement, reseller commission, and marketplace trust.

Risellar serves four main groups:

- Customers who want safer buying and Pay on Delivery.
- Resellers who want to earn without buying inventory.
- Suppliers who want more sales through a reseller network.
- Admin operators who must control approvals, delivery coordination, settlements, commissions, disputes, and risk.

Ghana needs this model because many customers fear scams and prefer to pay only when the item arrives. At MVP, some suppliers may also prefer to receive customer money directly before trusting a platform with settlement. Risellar handles this by allowing Pay on Delivery while requiring suppliers to immediately settle Risellar's share after customer payment. Reseller commission is released only after settlement is verified.

Risellar is not a simple ecommerce clone or listing app. It is a controlled trust marketplace with stock reservation, price snapshots, supplier restrictions, admin operations queues, audit logs, and Ghana-specific manual communication flows.

## 2. Product Vision

Risellar's vision is to turn everyday Ghanaians into trusted resellers who can sell supplier products without buying stock, while helping suppliers reach more customers and giving customers a safer Pay on Delivery buying flow.

The product should make it possible for:

- A student in Legon to sell approved products without capital.
- A beauty supplier in Kumasi to get sales from many resellers.
- A customer in Madina to buy through a trusted reseller link and pay when the item arrives.
- Risellar to earn from platform margins, supplier promotions, and future reseller tools.

The experience must feel trustworthy, Ghana-friendly, operationally controlled, and simple enough for everyday users.

## 3. Problem Statement

Risellar solves a trust and distribution problem in Ghana's informal and social-commerce market.

Key problems:

- Customers fear online scams.
- Customers prefer Pay on Delivery.
- Resellers lack capital to buy stock.
- Suppliers need more sales channels.
- Suppliers may not trust platforms to receive customer money first.
- Delivery prices are unpredictable.
- Stock can be oversold if many resellers promote the same item.
- Supplier settlement can fail if not tracked.
- Reseller commission can be lost if supplier payment and settlement are not controlled.
- Admin teams need strong operational tools.
- Ghana marketplace trust requires verification, restrictions, audit logs, and clear communication.

## 4. Target Market and Users

Customer:

- Buys through reseller shops or product links.
- Wants Pay on Delivery.
- Wants clear product, price, delivery, order, and support information.

Reseller:

- Student, general public seller, influencer, WhatsApp seller, beauty plug, campus seller, or niche community seller.
- Wants to sell products without holding stock.
- Wants clear profit, commission status, and withdrawal tracking.

Supplier:

- Product owner, wholesaler, shop owner, beauty supplier, gadget shop, fashion supplier, or home/lifestyle seller.
- Wants more sales through reseller distribution.
- Needs stock, product, order, and settlement tools.

Inventory Manager:

- Supplier staff member who manages products, variants, stock, restocks, and order preparation.

Admin:

- Risellar operator managing supplier/product approvals, orders, settlements, commissions, risk, delivery coordination, disputes, promotions, and support.

Support Staff and Finance Staff:

- Future or limited roles for ticket handling, settlement verification, withdrawal processing, and operational follow-up.

## 5. Ghana Market Assumptions

- Pay on Delivery is critical for customer trust.
- Many customers will not pay online before receiving goods.
- Customer phone/WhatsApp contact is still needed, but phone OTP is deferred for MVP.
- Email/Google login through Clerk is acceptable for MVP to reduce cost and complexity.
- Delivery may be arranged manually or outside the platform.
- Delivery riders/drivers are not platform users in MVP.
- Suppliers may receive customer payment directly at MVP.
- Supplier must immediately settle Risellar's share after receiving customer payment.
- Reseller commission is only released after supplier settlement is verified.
- Trust and fraud controls are central, not optional.

## 6. Product Goals

- Let resellers sell without holding stock.
- Let suppliers gain sales through resellers.
- Let customers order safely with account creation and Pay on Delivery.
- Track supplier settlement clearly.
- Prevent multiple sales of the last stock.
- Protect reseller commission.
- Give admin full operational visibility.
- Build a strong PWA/web platform before backend automation.
- Keep UI consistent with the mandatory brand/UI guide.

## 7. Non-Goals / Out of Scope

MVP does not include:

- Native mobile app.
- Rider/delivery driver app.
- Automated WhatsApp Business API.
- Phone OTP.
- Full online payment automation.
- Real-time map tracking.
- Advanced fraud ML.
- Multi-country support.
- Complex subscriptions.
- Fully automated refunds.
- AI product recommendations.
- Native iOS/Android build.

## 8. Success Metrics

Business metrics:

- Number of approved suppliers.
- Number of active resellers.
- Number of approved products available.
- Number of reseller shops created.
- Number of customer orders placed.
- Customer order completion rate.
- Repeat customer rate.
- Promotion conversion rate.

Trust/operations metrics:

- Customer confirmation rate.
- Average time to customer confirmation.
- Supplier settlement success rate.
- Average settlement time.
- Supplier overdue settlement count.
- Reseller commission released.
- Withdrawal success rate.
- Stock reservation failure rate.
- Product complaint rate.
- Dispute resolution time.

## 9. Platform Direction

Risellar is not a native mobile app.

Approved platform direction:

- Reseller: PWA/mobile-first web experience.
- Supplier: PWA/mobile-first web experience.
- Customer: mobile web checkout with account creation.
- Admin: desktop web dashboard.

Later technical direction:

- Next.js App Router.
- TypeScript.
- Tailwind CSS.
- PWA/mobile-first responsive design.
- Clerk for Google/email authentication.
- Resend for transactional emails.
- Supabase/Postgres likely for backend later.

## 10. User Roles

- Customer.
- Reseller.
- Supplier Owner.
- Inventory Manager.
- Admin.
- Support Staff, future.
- Finance Staff, future.
- Super Admin.

## 11. Role Permissions Summary

| Role | Can do | Cannot do |
| --- | --- | --- |
| Customer | Buy, confirm orders, approve delivery quote, track orders, open dispute. | See supplier base price, reseller commission, supplier private contact, or settlement details. |
| Reseller | Browse approved products, add to shop, set margin within limits, share links, view commissions, request withdrawal. | Contact supplier directly, alter stock, collect outside payment, withdraw pending commission. |
| Supplier Owner | Manage products, stock, staff, fulfillment, payment received marks, settlement proof, supplier settings. | Go live before approval, bypass Risellar, access other suppliers. |
| Inventory Manager | Add/edit products, restock, update variants, mark orders ready, view inventory activity. | Change payout details, settle financial records, approve finance actions, view platform-wide data. |
| Admin | Approve suppliers/products, view all operations, manage margins, verify settlements, release commissions, restrict/suspend, handle disputes. | Perform sensitive actions without audit trail. |
| Support Staff | Future limited support/ticket follow-up. | Access broad finance/settings unless granted. |
| Finance Staff | Future settlement and withdrawal verification. | Access unrelated admin settings unless granted. |
| Super Admin | Full control and staff permissions. | Must still be audited. |

## 12. MVP Scope

MVP includes:

- Clerk Google/email auth.
- Customer account creation.
- Reseller onboarding.
- Supplier onboarding.
- Supplier verification/manual approval.
- Product creation.
- Product approval.
- Inventory/stock management.
- Inventory manager role.
- Reseller catalog.
- Reseller shop/link.
- Pricing/margin system.
- Customer checkout.
- Pay on Delivery.
- Pay Online placeholder or optional later.
- Atomic stock reservation requirement.
- Customer confirmation.
- Delivery estimate + quote approval.
- Supplier fulfillment.
- Supplier settlement due/proof/verification.
- Reseller commission pending/available.
- Manual reseller withdrawal.
- Resend email notifications.
- Manual WhatsApp templates.
- Admin operations queues.
- Audit logs.
- Basic disputes/support.
- Supplier promotions/boost requests.
- Basic trending/featured product views.

## 13. Full Product Scope

Full product scope may later include:

- Automated online payments.
- WhatsApp Business API.
- Phone OTP.
- Automated MoMo reconciliation.
- Supplier commission wallet.
- Trusted supplier daily/weekly settlement.
- Reseller Pro insights.
- Advanced promotions/campaigns.
- Waitlist/restock notifications.
- Native app later if a proven business need exists.
- Customer loyalty/reorder.
- AI captions.
- AI product recommendations.
- Advanced fraud scoring.
- Referral and campus ambassador systems.

## 14. User Journeys

Customer Pay on Delivery order:

1. Customer clicks reseller link.
2. Views product and reseller shop identity.
3. Creates/logs into account.
4. Adds quantity/variant.
5. Enters delivery details.
6. Chooses delivery estimate.
7. Chooses Pay on Delivery.
8. Places order.
9. Stock reservation occurs.
10. Confirms order.
11. Approves final delivery quote if needed.
12. Receives order.
13. Pays on delivery.
14. Tracks status or reports issue if needed.

Reseller selling flow:

1. Reseller onboards.
2. Browses approved products.
3. Sees reseller cost and expected profit.
4. Sets selling price within allowed limit.
5. Adds product to shop.
6. Shares link.
7. Customer orders.
8. Reseller sees pending commission.
9. Supplier settlement is verified.
10. Commission becomes available.
11. Reseller requests withdrawal.

Supplier fulfillment flow:

1. Supplier onboards.
2. Submits verification.
3. Adds product.
4. Admin approves supplier/product.
5. Supplier manages stock.
6. Receives confirmed order.
7. Confirms availability.
8. Prepares item.
9. Customer pays supplier on delivery.
10. Supplier settles Risellar share.
11. Supplier uploads proof.
12. Admin verifies settlement.

Admin operations flow:

1. Approves supplier.
2. Approves product.
3. Monitors order.
4. Monitors customer confirmation.
5. Monitors delivery quote.
6. Monitors supplier fulfillment.
7. Verifies settlement.
8. Releases reseller commission.
9. Handles disputes/restrictions.

Inventory manager flow:

1. Accepts invite.
2. Adds/edits product.
3. Restocks.
4. Updates variants.
5. Marks order ready.
6. Actions are audit logged.

## 15. Core Marketplace Flow

```text
Supplier creates product
-> Admin approves supplier/product/margins
-> Reseller adds product to shop
-> Customer buys from reseller link
-> Stock is reserved atomically
-> Customer confirms order
-> Supplier prepares
-> Delivery quote is approved if needed
-> Customer pays on delivery
-> Supplier settles Risellar share
-> Admin verifies settlement
-> Reseller commission becomes available
```

This flow must preserve role privacy and pricing boundaries.

## 16. Pricing and Margin Requirements

Formula:

```text
Customer Product Price =
Supplier Base Price + Risellar Platform Margin + Reseller Margin
```

Example:

| Layer | Amount |
| --- | ---: |
| Supplier base price | GH₵300 |
| Risellar platform margin | GH₵10 |
| Reseller cost shown to reseller | GH₵310 |
| Reseller margin | GH₵30 |
| Customer product price | GH₵340 |

Requirements:

- Delivery is separate.
- Admin controls platform margin.
- Reseller margin must stay within limits.
- Existing orders keep price snapshot.
- Supplier price changes do not affect existing orders.
- Future margins may be category/product/supplier-specific.
- Admin sees all pricing layers.
- Customer sees only final product price and delivery.
- Supplier does not see reseller margin strategy.
- Reseller does not see supplier private contact.
- Server/database must calculate prices and commission.

## 17. Customer Account and Checkout Requirements

- No guest checkout.
- Customer must create/sign into Clerk account before placing order.
- Google/Gmail and email/password are MVP auth methods.
- Customer provides phone number and optional WhatsApp number.
- Customer provides delivery details, city/area/campus, address, landmark, and notes.
- Checkout must show product price, delivery estimate/range, payment method, and total estimate/final total.
- Order success must show order ID, payment method, delivery status, and next steps.
- Customer dashboard/account must allow order tracking and support/dispute entry.
- Customer email notifications use Resend.

## 18. Pay on Delivery Requirements

- Pay on Delivery is the default/trust-forward payment method.
- Customer does not pay product amount upfront.
- Customer order still requires account creation and stock reservation.
- Customer must confirm order before supplier prepares.
- Supplier may receive payment directly at MVP.
- Supplier must settle Risellar/reseller amount after payment is received.
- Reseller commission remains pending until settlement is verified.
- System must track payment collected status.
- Customer refusal/non-response must affect customer risk and order status.

## 19. Pay Online Requirements

MVP:

- Pay Online may be hidden, disabled, or shown as future/placeholder.
- Do not fake live payments.

Future:

- Customer pays Risellar.
- Payment success is verified server-side.
- Client-side payment success is not trusted.
- Risellar can automate settlement/splits later.
- Payment provider may be Paystack, Hubtel, or another approved provider.

## 20. Customer Confirmation Requirements

- New order begins as Awaiting Customer Confirmation.
- Customer can confirm in account.
- Customer can confirm through Resend email link.
- Admin can manually confirm after call/WhatsApp.
- Manual WhatsApp helper template supports confirmation follow-up.
- Recommended MVP reservation/confirmation timeout: 1 hour.
- Supplier preparation is blocked until confirmation.
- Admin must have Customer Confirmation Queue.
- Confirmation timestamp and source must be recorded.

## 21. Delivery Estimate and Delivery Quote Approval Requirements

- Delivery is separate from product price.
- No rider app in MVP.
- Checkout shows delivery estimate ranges.
- Final quote may be confirmed after route/supplier/admin review.
- Customer must approve final quote before dispatch if final quote is required.
- Customer can reject quote and cancel before dispatch.
- Admin can store delivery notes/contact where needed.

Estimate examples:

| Option | Estimate |
| --- | --- |
| Express / Same Day | GH₵50-100 |
| Next Day | GH₵30-50 |
| Standard | GH₵20-40 |
| Campus / Specific Day | GH₵10-25 |
| Customer-arranged pickup/delivery | Manual |
| Supplier-arranged delivery | Manual |

## 22. Supplier Onboarding and Verification Requirements

Supplier onboarding must capture:

- Business details.
- Owner details.
- Email auth identity.
- Phone contact.
- Location.
- Product category.
- Ghana Card or approved document upload support.
- Payout details.
- Supplier agreement.
- Settlement obligations.

Requirements:

- Supplier cannot go live until approved.
- Supplier cannot receive orders before approval.
- Supplier verification documents are private.
- Admin can approve, reject, or request more information.
- Supplier must agree not to bypass Risellar/resellers.
- Supplier must understand immediate settlement obligation.

## 23. Supplier Product and Inventory Requirements

Supplier product creation supports:

- Product name.
- Category.
- Product images.
- Description.
- Supplier base price.
- Stock quantity.
- Variants where relevant.
- Low stock threshold.
- Product status.

Inventory requirements:

- Track total, reserved, available, sold, returned stock.
- Track stock movements.
- Support restock.
- Support variant stock.
- Show low stock and out-of-stock alerts.
- Out-of-stock products cannot be ordered.
- Inventory manager can manage operational product/stock fields.

## 24. Stock Reservation Requirements

Stock reservation must protect shared supplier stock across many resellers.

Rules:

- Reseller adding a product to shop does not reduce stock.
- Customer viewing or adding to cart does not reduce stock.
- Customer placing order triggers server-side reservation.
- Reservation must be atomic/database-safe.
- Order is created only if reservation succeeds.
- Variant stock must be reserved at variant level.
- Reservation expires if customer does not confirm in time.
- Confirmed orders keep reservation active.
- Cancelled/refused/expired orders release stock.
- Delivered/paid orders convert reservation to sale.
- Customer sees clear failure message if item was just reserved.
- Reseller sees out-of-stock state for affected listings.
- Admin sees reservation status, expiry, release reason, and related order.

## 25. Supplier Staff / Inventory Manager Requirements

- Supplier Owner can invite staff by email.
- Inventory Manager access is limited to supplier workspace.
- Inventory Manager can add/edit products, restock, update variants, view stock/order preparation, and mark ready.
- Inventory Manager cannot change payout details.
- Inventory Manager cannot settle or approve financial records.
- Inventory Manager cannot access other suppliers.
- Permission changes and inventory actions must be audited.

## 26. Product Approval Requirements

Admin product review must cover:

- Product identity and clarity.
- Category eligibility.
- Product images.
- Description accuracy.
- Supplier stock ownership/control.
- Base price reasonableness.
- Variant stock.
- Prohibited product risk.
- Dangerous claims.

Product statuses:

- Draft.
- Pending Approval.
- Approved.
- Active.
- Rejected.
- Needs Changes.
- Hidden.
- Suspended.
- Archived.

Prohibited products include prescription medicine, unsafe bleaching/skincare products, alcohol, vapes/nicotine, weapons, counterfeit goods, adult products, betting/gambling products, stolen goods, unverified supplements, and illegal/unsafe items.

## 27. Price Change Requirements

- Existing orders keep price snapshots.
- Supplier can request price change.
- MVP supplier base price changes require admin approval or reseller listing review.
- Reseller must be notified when a shop product changes price.
- Customer links show updated final price only after approval/review.
- Major price change can move product/listing to Needs Reseller Review.
- Admin decisions must be audited.

## 28. Reseller Onboarding Requirements

Reseller onboarding captures:

- Full name.
- Email from Clerk.
- Phone/WhatsApp.
- Reseller type.
- Location/campus/area.
- Category interests.
- Shop setup.
- MoMo payout info.
- Code of conduct.
- Agreement to rules.

Reseller approval policy should be configurable. Recommended MVP default: allow low-risk reseller onboarding but restrict suspicious accounts through admin/risk review.

## 29. Reseller Shop and Product Link Requirements

- Each reseller gets a unique shop slug.
- Product links must identify reseller/shop/listing.
- Link used at checkout receives commission attribution.
- Reseller can share to WhatsApp or copy link.
- Shop can have statuses such as Active, Restricted, Suspended, Hidden.
- Admin can review, restrict, or suspend reseller shops.
- Product links must not expose supplier private contact or internal pricing layers.

## 30. Reseller Commission Requirements

Commission lifecycle:

- Pending.
- Awaiting Customer Confirmation.
- Awaiting Delivery/Payment.
- Awaiting Supplier Settlement.
- Available.
- Withdrawal Requested.
- Paid.
- Cancelled.
- Disputed.

Requirements:

- Commission is calculated from price snapshot.
- Commission remains pending until supplier settlement is verified.
- Cancelled/refused orders cancel commission.
- Disputes can hold commission.
- Partial supplier settlement can keep commission pending.
- Admin override requires reason and audit log.

## 31. Supplier Settlement Requirements

Settlement is critical to MVP.

MVP settlement flow:

1. Customer pays supplier/supplier delivery arrangement on delivery.
2. Supplier keeps base price.
3. Supplier immediately sends Risellar the platform margin + reseller commission.
4. Supplier uploads proof/reference.
5. Admin/finance verifies.
6. Reseller commission becomes available.

Example:

| Item | Amount |
| --- | ---: |
| Customer product price | GH₵340 |
| Supplier base price | GH₵300 |
| Platform margin | GH₵10 |
| Reseller commission | GH₵30 |
| Supplier settlement due | GH₵40 |

Requirements:

- Settlement due immediately after payment collected.
- Settlement ledger tracks every amount.
- Proof upload required.
- Admin verification required.
- Partial settlement supported.
- Overdue settlement triggers restrictions.
- Future trusted suppliers may get daily/weekly settlement terms.

## 32. Withdrawal Requirements

- Reseller can withdraw available balance only.
- Pending commission cannot be withdrawn.
- Minimum withdrawal amount is configurable.
- Recommended MVP default: GH₵50, unless business chooses GH₵20.
- MoMo payout details required.
- Manual admin/finance approval may be required at MVP.
- Withdrawal statuses: Requested, Processing, Paid, Failed, Rejected, Cancelled.
- Failed/rejected withdrawals must show reason.

## 33. Promotions / Boosting Requirements

- Supplier can request paid boost, example GH₵10-20 or admin-configured amount.
- Boosted products may appear as Featured/Sponsored.
- Admin approval/payment proof may be required.
- Promotion performance metrics should be tracked.

Eligibility:

- Supplier verified.
- Product approved.
- Product in stock.
- No overdue supplier settlement.
- Product not restricted.
- Complaint rate acceptable.

Promotion statuses:

- Draft.
- Pending Payment.
- Pending Approval.
- Active.
- Paused.
- Completed.
- Rejected.
- Cancelled.

Paid promotion must never override trust and safety.

## 34. Reseller Trending / Top-Selling Insights Requirements

MVP/free:

- Trending products.
- Featured/sponsored products.
- Basic top-selling products.
- Suggested price/profit.
- Stock availability.

Future Pro:

- High-profit products.
- Low competition products.
- Area/campus trends.
- WhatsApp captions.
- Early access to hot products.

Rules:

- Do not expose sensitive supplier-wide sales data.
- Do not recommend restricted/out-of-stock products as sellable.
- Sponsored products must still meet trust requirements.

## 35. Admin Dashboard Requirements

Admin dashboard is desktop-first.

Admin modules:

- Overview.
- Products.
- Orders.
- Customers.
- Resellers.
- Suppliers.
- Supplier approvals.
- Product approvals.
- Settlements.
- Commissions.
- Withdrawals.
- Delivery quotes.
- Disputes/support.
- Promotions.
- Inventory monitoring.
- Risk/fraud.
- Audit logs.
- Staff permissions.

Admin must see all pricing layers, operational statuses, risk flags, queue counts, and audit trails.

## 36. Admin Operations Queue Requirements

Required queues:

- Customer Confirmation Queue.
- Supplier Availability Queue.
- Supplier Preparation Queue.
- Delivery Quote Queue.
- Settlement Due Queue.
- Overdue Settlement Queue.
- Commission Release Queue.
- Product Approval Queue.
- Supplier Approval Queue.
- Withdrawal Request Queue.
- Dispute Queue.
- Failed Delivery Queue.
- Stock Issue Queue.
- Promotion Approval Queue.
- Risk Review Queue.

Each queue needs count, priority, status, quick actions, filters, and audit trail.

## 37. Risk, Fraud, and Restriction Requirements

Supplier risk triggers:

- Late settlement.
- Fake/wrong product.
- Cancellation.
- Out-of-stock after order.
- Dispute rate.
- Fulfillment delay.

Reseller risk triggers:

- Fake orders.
- Customer complaints.
- Misleading claims.
- Outside payment attempts.
- High cancellation rate.

Customer risk triggers:

- Refused deliveries.
- Wrong address.
- No response.
- Repeated cancellations.
- Disputes.

Actions:

- Warning.
- Restriction.
- Hidden products.
- New orders blocked.
- Future pay-online-only/deposit rule.
- Suspension.
- Admin review.

## 38. Disputes, Returns, and Refund Requirements

Dispute types:

- Wrong product.
- Damaged product.
- Product not received.
- Delivery issue.
- Payment dispute.
- Missing commission.
- Settlement proof dispute.
- Price mismatch.
- Stock issue.

Dispute statuses:

- Open.
- Under Review.
- Waiting for Customer.
- Waiting for Supplier.
- Waiting for Reseller.
- Resolved.
- Rejected.
- Escalated.

Return rules by category:

- Beauty/skincare: sealed/unopened unless wrong/damaged.
- Shoes/clothing: wrong size/item or supplier fault.
- Phone accessories: wrong model/defective.
- Custom/preorder: restricted.
- Perishable items: usually no return.

MVP refunds are manual/admin-controlled. Commission and settlement can remain held during dispute.

## 39. Email Notification Requirements

Use Resend.

Email events:

- Account created/welcome.
- Customer order received.
- Customer confirm order.
- Order confirmed.
- Delivery quote ready.
- Order cancelled.
- Order dispatched.
- Order delivered.
- Reseller new order through link.
- Reseller commission pending.
- Reseller commission available.
- Supplier new confirmed order.
- Supplier product approved/rejected.
- Supplier settlement due.
- Supplier settlement overdue.
- Withdrawal requested.
- Withdrawal paid/failed.
- Dispute opened/updated.
- Account approved/rejected/suspended.

Privacy:

- Customer email cannot expose supplier private contact.
- Reseller email cannot expose supplier private contact.
- Supplier email cannot expose reseller margin strategy.
- Admin email can include operational details.

## 40. Manual WhatsApp Helper Requirements

MVP does not include WhatsApp Business API.

Admin should have copyable templates for:

- Customer confirmation.
- Delivery quote approval.
- Supplier preparation.
- Supplier settlement due.
- Settlement overdue warning.
- Dispute follow-up.

Templates must be generated from order data, avoid private data leakage, and use clear Ghana-friendly language.

Future: WhatsApp Business API automation.

## 41. Audit Log Requirements

Sensitive actions must be audit logged.

Audit events include:

- User role changed.
- Supplier approved/rejected.
- Supplier KYC reviewed.
- Product approved/rejected.
- Product price changed.
- Product stock adjusted.
- Stock reservation created/released.
- Order status changed.
- Customer confirmation marked.
- Delivery quote approved/rejected.
- Supplier marked payment received.
- Settlement proof submitted.
- Settlement verified/rejected.
- Reseller commission released.
- Withdrawal approved/rejected.
- Supplier restricted/suspended.
- Manual override performed.
- Dispute resolved.
- Promotion approved/paused/rejected.

Audit log fields:

- Actor user id.
- Actor role.
- Action.
- Entity type.
- Entity id.
- Old value.
- New value.
- Reason/note.
- Timestamp.
- Safe metadata.

## 42. Security and Privacy Requirements

- Role-based access required.
- RLS/security rules required later.
- Never trust frontend price, role, amount, margin, supplier_id, reseller_id, or commission.
- Server-side calculations required.
- Sensitive documents are private.
- Ghana Card uploads require consent and restricted admin access.
- Service role must never be exposed.
- Admin permission separation required.
- Supplier staff isolation required.
- Customers access only their own orders/account.
- Resellers access only their shop/orders/commissions.
- Suppliers access only their products/orders/settlements.
- Existing order prices cannot be changed by user actions.
- Stock reservation must be atomic.
- Sensitive actions require audit logs.

## 43. UI/UX Requirements

UI must follow:

- `docs/RISELLAR_BRAND_UI_SYSTEM_GUIDE.md`
- `docs/RISELLAR_UI_REFERENCE_IMAGE_AUDIT.md`
- `docs/RISELLAR_BRAND_UI_SYSTEM_REVIEW_REPORT.md`

Requirements:

- Use approved emerald/amber/cream/charcoal brand direction.
- Reseller, supplier, and customer surfaces are PWA/mobile-first.
- Admin is desktop-first.
- No redesign.
- Use shared components and approved tokens.
- Build design-system gallery before pages.
- Do not use random colors or spacing.
- Use Ghana-friendly copy.
- Make Pay on Delivery trust messages visible.
- Make financial breakdowns visible where role-appropriate.
- Keep status badges consistent.
- Admin money/status actions must feel controlled and auditable.

## 44. Screen Map

Public/Auth:

- Splash/welcome.
- Choose role.
- Login.
- Create account.
- Forgot/reset access.
- Terms/privacy.

Customer Checkout:

- Reseller shop page.
- Product detail.
- Cart.
- Create/sign-in step.
- Delivery details.
- Delivery options.
- Payment method.
- Order review.
- Order success.
- Order tracking.
- Help/report issue.

Customer Account:

- Dashboard.
- Orders.
- Order detail.
- Addresses.
- Messages/notifications.
- Support.
- Settings.

Reseller PWA:

- Onboarding.
- Dashboard.
- Catalog.
- Product detail.
- Selling price calculator.
- Add to shop success.
- My Shop.
- Share to WhatsApp.
- Orders.
- Wallet.
- Withdraw to MoMo.
- Transactions.
- Notifications.
- Account/settings.

Supplier PWA:

- Supplier onboarding.
- Business profile.
- Verification/KYC.
- Payout setup.
- Dashboard.
- Products list.
- Add/edit product.
- Product detail.
- Update stock.
- Variants.
- Orders.
- Prepare order.
- Settlements.
- Upload proof.
- Settlement history.
- Notifications.
- Settings/support.

Inventory Manager / Supplier Staff:

- Team invite accept.
- Team members.
- Role permissions.
- Inventory dashboard.
- Stock activity.
- Access denied.

Admin Dashboard:

- Overview.
- Orders management.
- Order detail.
- Supplier settlements.
- Reseller commissions.
- Product approval.
- Supplier approval/verification.
- Delivery coordination.
- Disputes/support.
- Operations hub.
- Risk/fraud control.
- Inventory/stock alerts.
- Withdrawals.
- Promotions.
- Audit logs.
- Manual override.
- Team/staff permissions.
- Settings.

Support/Disputes:

- Open dispute.
- Dispute detail.
- Evidence upload.
- Admin dispute queue.
- Support inbox.

Promotions/Insights:

- Trending products.
- Featured/sponsored products.
- Top selling.
- Product insights.
- Pro insights locked.
- WhatsApp caption templates.

Empty/Error/Edge States:

- Empty shop.
- No orders.
- Pending commission.
- Withdrawal failed.
- Awaiting confirmation.
- Delivery quote pending.
- Order cancelled.
- Delivery failed.
- No supplier products.
- Product out of stock.
- Settlement overdue.
- Verification pending/rejected.
- Supplier suspended/restricted.
- No admin orders/approvals.
- No notifications.

## 45. Data Requirements, High-Level Only

Important data objects:

- Users/profiles.
- Roles.
- Customers.
- Resellers.
- Reseller shops.
- Suppliers.
- Supplier staff.
- Products.
- Product variants.
- Product images.
- Stock movements.
- Stock reservations.
- Reseller listings.
- Carts.
- Orders.
- Order items.
- Settlements.
- Commissions.
- Withdrawals.
- Payment proofs.
- Delivery quotes.
- Promotions.
- Disputes.
- Support tickets.
- Audit logs.
- Notification logs.
- Risk scores.

This PRD does not define full database schema or migrations.

## 46. Status System

Order statuses:

- Awaiting Customer Confirmation.
- Customer Confirmed.
- Supplier Confirming Availability.
- Preparing.
- Ready for Delivery Quote.
- Delivery Quote Pending.
- Delivery Approved.
- Out for Delivery.
- Delivered.
- Payment Collected.
- Settlement Due.
- Settlement Pending.
- Settlement Overdue.
- Completed.
- Cancelled.
- Customer Refused.
- Dispute Opened.

Product statuses:

- Draft.
- Pending Approval.
- Approved.
- Active.
- Rejected.
- Needs Changes.
- Price Change Pending.
- Needs Reseller Review.
- Out of Stock.
- Hidden.
- Suspended.
- Archived.

Settlement statuses:

- Not Due.
- Due.
- Proof Submitted.
- Verifying.
- Partially Settled.
- Paid.
- Overdue.
- Disputed.

Commission statuses:

- Pending.
- Awaiting Settlement.
- Available.
- Withdrawal Requested.
- Paid.
- Cancelled.
- Disputed.

Withdrawal statuses:

- Requested.
- Processing.
- Paid.
- Failed.
- Rejected.

Promotion statuses:

- Draft.
- Pending Payment.
- Pending Approval.
- Active.
- Paused.
- Completed.
- Rejected.
- Cancelled.

Verification statuses:

- Pending.
- Approved.
- Rejected.
- More Info Required.

## 47. Acceptance Criteria

MVP acceptance criteria:

- Customer cannot place order without account.
- Order cannot be created if stock reservation fails.
- Stock reservation is server/database enforced, not frontend-only.
- Variant-level stock prevents overselling a single variant.
- Out-of-stock products cannot be ordered.
- Customer confirmation is required before supplier preparation.
- Existing orders retain price snapshot.
- Supplier price change does not alter existing orders.
- Reseller cannot set price above maximum allowed.
- Admin can see full price breakdown.
- Reseller cannot see supplier private contact.
- Customer cannot see supplier margin/commission.
- Supplier cannot see reseller margin strategy.
- Inventory manager cannot change payout details.
- Reseller commission remains pending until settlement verified.
- Supplier cannot boost product with overdue settlement.
- Supplier overdue settlement triggers admin queue/restriction logic.
- Sensitive admin actions are audited.
- Email notification is recorded/sent for key events.
- Manual WhatsApp templates can be generated without exposing private data.

## 48. MVP Implementation Phases

Phase 0: Documentation and design-system readiness.

- Approve PRD, business rules, and brand guide.
- Confirm open MVP decisions.

Phase 1: Project setup + design tokens + component gallery.

- Set up Next.js, Tailwind, token system, and design-system gallery before pages.

Phase 2: Auth and roles.

- Clerk auth, profiles, roles, access boundaries.

Phase 3: Product/supplier/reseller foundation.

- Supplier onboarding, reseller onboarding, product creation, approvals.

Phase 4: Inventory and stock reservation.

- Stock, variants, movements, atomic reservation logic.

Phase 5: Customer checkout and order confirmation.

- Customer account checkout, Pay on Delivery, confirmation, order status.

Phase 6: Supplier fulfillment and settlement.

- Confirm availability, prepare order, payment received, settlement proof/verification.

Phase 7: Reseller commission and wallet.

- Pending/available commission, withdrawal requests.

Phase 8: Admin operations queues.

- Queue dashboards, filters, actions, risk visibility.

Phase 9: Promotions and insights MVP.

- Featured/sponsored/trending products with trust rules.

Phase 10: Support/disputes/audit logs.

- Ticketing, disputes, evidence, audit coverage.

Phase 11: QA/security hardening.

- Permission, RLS, stock race, price tampering, visual QA, operational QA.

Phase 12: MVP launch prep.

- Seed launch categories, suppliers, admin SOPs, support templates.

## 49. Future Features

- Phone OTP.
- WhatsApp Business API.
- Paystack/Hubtel online payment.
- Automated MoMo reconciliation.
- Supplier commission wallet.
- Trusted supplier weekly settlement.
- Reseller Pro insights.
- Advanced promotions/campaigns.
- Referral system.
- Campus ambassador system.
- Waitlist/restock notifications.
- Advanced analytics.
- AI caption generator.
- AI product recommendations.
- Customer loyalty/reorder.
- Native app later only if proven necessary.

## 50. Open Questions

| Question | Recommended MVP default |
| --- | --- |
| Should resellers require admin approval before selling? | Allow low-risk onboarding, reserve admin restriction for suspicious behavior. |
| Minimum withdrawal amount? | GH₵50 unless business wants lower GH₵20 threshold. |
| Supplier settlement limit for new suppliers? | Keep low and configurable; block new orders after overdue threshold. |
| Delivery ownership and SLA? | Start supplier/admin coordinated by category/location; define SLA before launch. |
| Pay Online provider: Paystack or Hubtel? | Keep disabled/placeholder until provider decision. |
| Launch categories? | Start with lower-risk products: fashion, beauty accessories, phone accessories, home/lifestyle; exclude prohibited categories. |
| Ghana Card document access policy? | Super Admin/Admin only; finance/support excluded unless approved. |
| Audit log retention period? | Keep indefinitely for MVP unless storage/legal policy changes. |
| Promotion pricing? | Start GH₵10-20 manual approval, configurable later. |
| Customer risk enforcement thresholds? | Track first, restrict manually until enough data exists. |
| Supplier trusted-level criteria? | Require verified supplier, low disputes, fast fulfillment, no overdue settlements over defined period. |

## 51. Final Build Principles

- Trust first.
- Pay on Delivery first.
- Stock safety first.
- Supplier settlement visibility.
- Reseller commission protection.
- Admin operations control.
- No direct supplier-reseller/customer bypass.
- Server-side calculations.
- Audit everything important.
- UI follows brand guide.
- Build PWA first, not native app.
- Do not create PRD follow-up plans that violate business rules.
- Do not build pages before tokens, components, and design-system gallery are ready.
