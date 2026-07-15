# Risellar Business Rules and App Logic

## 1. Document Purpose

This document is the business logic source of truth for Risellar. It defines the marketplace rules, role permissions, pricing logic, order lifecycle, stock reservation rules, settlement rules, commission rules, risk controls, notification rules, and MVP boundaries that future Codex tasks must follow.

Future PRDs, database schemas, RLS/security rules, admin modules, backend logic, frontend screens, and build plans must follow this document together with:

- `docs/RISELLAR_BRAND_UI_SYSTEM_GUIDE.md`
- `docs/RISELLAR_UI_REFERENCE_IMAGE_AUDIT.md`
- `docs/RISELLAR_BRAND_UI_SYSTEM_REVIEW_REPORT.md`

This document does not build the app, define final database migrations, or create UI. It defines the rules that later work must implement.

## 2. Product Summary

Risellar is a controlled Ghana reseller marketplace. Suppliers list products they own. Risellar adds a platform margin. Resellers add their own approved margin and sell through reseller shops or product links. Customers buy through reseller links, create accounts before purchase, and can choose Pay on Delivery or Pay Online if payment integration is available.

Risellar is not an open supplier-to-reseller contact marketplace. The relationship structure is:

```text
Supplier -> Risellar/Admin -> Reseller -> Customer
```

Core trust logic:

- Customers buy from reseller-facing shops/links.
- Resellers do not hold stock.
- All resellers sell from supplier shared stock.
- Stock is reserved only when the customer places an order and the server/database confirms availability.
- Supplier settlement controls reseller commission release.
- Admin visibility and audit logging protect the marketplace.

## 3. Platform Direction

Approved platform direction:

- Reseller: PWA/mobile-first web.
- Supplier: PWA/mobile-first web.
- Customer: mobile web checkout with account creation.
- Admin: desktop web dashboard.

Risellar is not a native mobile app at MVP. Do not plan Expo, React Native, iOS, or Android implementation unless a future approved decision changes the platform direction.

## 4. Core Marketplace Model

Risellar has four core marketplace layers:

| Layer | Purpose | Key rule |
| --- | --- | --- |
| Supplier | Owns products and stock. | Supplier controls base price and fulfills confirmed orders. |
| Risellar/Admin | Controls trust, margins, approvals, operations, settlements, and risk. | Admin can see all pricing layers and operational records. |
| Reseller | Markets approved supplier products through shop/listing links. | Reseller earns commission only after successful payment and verified supplier settlement. |
| Customer | Buys through reseller shop/link. | Customer sees final customer price and delivery cost, not internal margin layers. |

Risellar must prevent marketplace bypass:

- Supplier should not directly communicate with reseller.
- Customer should not directly see supplier private contact in normal flow.
- Reseller should not see supplier private contact or supplier base pricing unless explicitly approved later.
- Reseller cannot collect customer money outside Risellar unless a future verified flow allows it.
- Supplier cannot bypass Risellar/resellers after receiving orders through the platform.

## 5. User Roles and Permissions

| Role | Core permissions | Restrictions |
| --- | --- | --- |
| Customer | Create account, manage profile, buy through reseller shops/links, confirm orders, approve delivery quote, track orders, report issues. | Cannot see supplier base price, Risellar margin, reseller commission, supplier private contact, or settlement details. |
| Reseller | Onboard, add approved products to shop, set margin within limits, share shop/product links, track orders, view pending/available commission, request withdrawals. | Cannot contact suppliers directly, alter supplier stock, bypass Risellar, see supplier private contact, or withdraw pending commission. |
| Supplier Owner | Create supplier workspace, complete verification/KYC, list products, manage stock, receive confirmed orders, prepare orders, mark payment received, submit settlement proof, invite staff. | Cannot go live before approval, cannot bypass Risellar/resellers, cannot access other suppliers, cannot ignore settlement rules. |
| Inventory Manager | Add/edit products, update stock, restock, view inventory, mark orders ready, view assigned supplier operational data. | Cannot change payout details, approve financial records, settle payments unless future finance permission exists, or view platform-wide data. |
| Admin | Approve suppliers/products, set margins, monitor orders, coordinate delivery, verify settlements, release commissions, handle disputes, restrict/suspend accounts, manage risk queues. | Must operate through audited admin tools. |
| Support Staff | Future role for ticket/order follow-up and limited customer/supplier communication. | Limited access; no sensitive finance or role settings unless granted. |
| Finance Staff | Future role for settlement verification, withdrawal processing, and finance queues. | Limited access; no broad admin settings unless granted. |
| Super Admin | Full control, staff permissions, sensitive settings, system-level overrides. | Must be manually assigned and audited. |

Users cannot choose admin, finance, support, or super admin roles for themselves. Admin roles must be manually assigned by Super Admin.

## 6. Account Creation/Authentication Rules

MVP authentication uses Clerk.

MVP supported auth methods:

- Google/Gmail login.
- Email/password login.

MVP does not include phone OTP due to budget. Customers still provide phone/WhatsApp number during profile or checkout, but phone is not OTP-verified at MVP.

Account rules:

- No guest checkout in MVP.
- Customers must create or sign into an account before placing an order.
- Suppliers can create accounts but cannot go live until approved.
- Resellers can onboard, but admin may require approval depending on risk policy.
- Admin accounts must be manually assigned.
- Use Resend for email notifications.
- All user role decisions must be enforced server-side.

## 7. Customer Account and Buying Rules

Customer flow:

1. Customer clicks a reseller product/shop link.
2. Customer views product and reseller shop identity.
3. Customer selects quantity and variant.
4. Customer signs in or creates an account.
5. Customer enters delivery details.
6. Customer chooses delivery option/estimate.
7. Customer chooses Pay on Delivery or Pay Online if available.
8. Customer places order.
9. Order is created only if stock reservation succeeds.
10. Customer confirms order.
11. Customer approves final delivery quote before dispatch if required.
12. Customer receives updates by email.

Customer account fields:

- Full name.
- Email from Clerk.
- Phone number.
- WhatsApp number, optional.
- Location/address.
- City/area/campus.
- Landmark.
- Default delivery details.

Customer can see:

- Final customer price.
- Delivery estimate or final quote.
- Payment method.
- Order status.
- Reseller shop name.
- Support/report issue entry point.

Customer cannot see:

- Supplier base price.
- Risellar platform margin.
- Reseller commission.
- Supplier private contact.
- Supplier settlement details.

Example:

A customer buying from "Ama's Picks" sees Nike Air Force 1 at GH₵340 and delivery estimate GH₵20-40. The customer does not see that supplier base price is GH₵300, platform margin is GH₵10, and reseller margin is GH₵30.

## 8. Reseller Onboarding and Selling Rules

Resellers sell supplier-owned products without holding stock.

Reseller onboarding should collect:

- Full name.
- Email from Clerk.
- Phone/WhatsApp number.
- Location/area/campus if relevant.
- Reseller type, such as student reseller, general reseller, influencer, or beauty plug.
- MoMo payout details.
- Agreement to reseller rules.

Reseller selling rules:

- Reseller can browse approved product catalog.
- Reseller can add active approved products to their shop.
- Reseller sets margin within platform limits.
- Reseller can share product/shop links.
- Reseller earns commission only after successful paid order and verified supplier settlement.
- Reseller cannot contact supplier directly.
- Reseller cannot collect customer money outside Risellar unless future verified flow allows it.
- Reseller cannot claim product availability beyond platform stock status.
- Reseller cannot alter product facts, product images, base description, or prohibited claims without approval.

## 9. Supplier Onboarding, Verification, and KYC Rules

Supplier Owner onboarding should collect:

- Business name.
- Business type/category.
- Business location.
- Contact phone and email.
- Owner full name.
- Ghana Card or approved identity document upload.
- Payout details, such as MoMo or bank account.
- Supplier agreement acceptance.

Supplier go-live rules:

- Supplier can draft products before approval if allowed.
- Supplier cannot appear in reseller catalog before admin approval.
- Supplier cannot receive orders before approval.
- KYC documents must be private.
- Admin must review supplier identity, business details, category, payout details, and risk.
- Supplier approval, rejection, or request for more information must be audit logged.

Supplier verification statuses:

- Not Started.
- Submitted.
- Pending Review.
- Approved.
- More Info Required.
- Rejected.
- Suspended.

## 10. Supplier Staff and Inventory Manager Rules

Supplier Owner can invite staff, including Inventory Manager.

Inventory Manager can:

- Add products.
- Edit product operational details.
- Update stock.
- Restock.
- Mark orders ready.
- View inventory activity.
- View supplier products and assigned orders.

Inventory Manager cannot:

- Change payout details.
- Withdraw or settle financial records.
- Approve settlement proof.
- Delete supplier account.
- View platform-wide data.
- See other suppliers' records.

Team actions must be logged:

- Staff invited.
- Staff role changed.
- Permission changed.
- Staff restricted/removed.
- Inventory action performed.

## 11. Product Lifecycle Rules

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

Lifecycle:

1. Supplier or inventory manager creates product.
2. Product enters Pending Approval.
3. Admin reviews product.
4. Admin sets or approves platform margin and reseller margin limits.
5. Product becomes Approved/Active.
6. Product appears in reseller catalog.
7. Reseller adds product to shop.
8. Customers can order through reseller links.
9. Supplier can restock or request price change.
10. Admin can hide/suspend product if risky.
11. Product can be archived if permanently unavailable.

## 12. Product Approval and Prohibited Product Rules

Admin must approve products before they are sellable.

Product approval checks:

- Product name is clear and not misleading.
- Category is allowed.
- Images are acceptable and not deceptive.
- Description matches product.
- Supplier owns or controls stock.
- Base price is realistic.
- Stock quantity is provided.
- Variant stock is defined where relevant.
- Product does not violate prohibited categories.

Prohibited product categories:

- Prescription medicine.
- Dangerous skincare or bleaching products.
- Alcohol.
- Vapes/nicotine.
- Weapons.
- Counterfeit/fake designer products.
- Adult products.
- Betting/gambling products.
- Stolen goods.
- Unverified supplements.
- Unsafe or illegal products.

Admin product decisions:

- Approve.
- Reject.
- Request Changes.
- Hide.
- Suspend.
- Archive.

Every admin product decision must be audit logged with reason.

## 13. Pricing Formula and Margin Rules

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

Delivery is separate from product price.

Visibility:

| Role | Pricing visibility |
| --- | --- |
| Supplier | Supplier base price, stock, supplier payout/base amount, settlement due after receiving customer payment. |
| Reseller | Reseller cost including Risellar margin, suggested selling price, maximum allowed price, expected profit, commission status. |
| Customer | Final product price, delivery estimate/quote, payment method. |
| Admin | All pricing layers. |

Rules:

- Existing orders keep a price snapshot.
- Supplier price changes do not affect already-created orders.
- Admin can set platform margin as fixed or percentage.
- Admin can later set category/product/supplier-specific margins.
- Reseller margin must have minimum/maximum limits where configured.
- Reseller cannot set price above maximum allowed limit.
- Server/database must calculate price and commission; never trust frontend-sent price.

## 14. Reseller Shop and Product Link Attribution Rules

Every reseller product/shop link must identify the reseller.

MVP commission attribution:

- The reseller link/shop used at checkout gets commission.

Future attribution:

- Cookie/session attribution window may be added later.
- Direct customer reorder attribution must be defined later.

Order must store:

- `reseller_id`.
- `reseller_shop_id`.
- `reseller_listing_id`.
- `product_id`.
- `product_variant_id`, if applicable.
- `customer_id`.
- Price snapshot.
- Commission snapshot.

If a customer buys from another reseller's shop, that reseller receives the commission.

## 15. Stock and Inventory Rules

All resellers sell from supplier shared stock.

Supplier stock fields:

- Total stock.
- Reserved stock.
- Available stock.
- Sold stock.
- Returned stock.
- Low stock threshold.

Variant stock:

- Track stock by variant where relevant.
- Examples: shoe size, clothing size, color, phone model, perfume size.
- If size 42 has 1 left, only size 42 has 1 left.

Stock statuses:

- In Stock.
- Low Stock.
- Only Few Left.
- Reserved.
- Out of Stock.
- Restocked.

Supplier/Inventory Manager can:

- Add product stock.
- Restock.
- Mark out of stock.
- Adjust stock with reason.
- View stock movement history.
- Set low stock threshold.

Stock movements must be logged:

- `initial_stock`.
- `restock`.
- `reservation`.
- `sale`.
- `cancellation_release`.
- `return`.
- `damage`.
- `manual_adjustment`.
- `correction`.

## 16. Stock Reservation and Race-Condition Rules

This section is critical.

Problem:

Twenty resellers can promote the same supplier product. If only one shoe is left and two customers order at the same time, the system must prevent double-selling.

Rules:

- Reseller adding product to shop does not reduce stock.
- Customer viewing product does not reduce stock.
- Customer adding product to cart does not reduce stock.
- Customer placing order triggers server-side stock reservation.
- Order is created only if stock reservation succeeds.
- Stock reservation must be atomic/database-safe.
- Do not rely on frontend stock checks only.
- If reservation fails, customer sees that the item is no longer available.
- Reserved stock expires if customer does not confirm in time.
- Recommended MVP reservation timeout: 1 hour while awaiting confirmation.
- If customer confirms, reservation remains active.
- If customer cancels/refuses before completion, stock is released after appropriate confirmation.
- Delivered/paid order converts reserved stock into sold stock.

Stock reservation statuses:

- Pending Reservation.
- Reserved.
- Confirmed.
- Expired.
- Released.
- Converted to Sale.
- Failed.

Example:

Supplier has 1 shoe left. Ama and Kojo are both promoting it. Two customers click Place Order at the same time. Only one reservation can succeed. The other customer receives: "This item was just reserved or is out of stock."

Admin visibility:

- Admin can see reservation status, expiry time, order, reseller, customer, product, variant, and release reason.

Customer messaging:

- Reservation success: "Your item is reserved. Please confirm your order to keep it."
- Reservation failure: "This item was just reserved or is out of stock."
- Reservation expired: "Your reservation expired. Please check availability before ordering again."

Reseller messaging:

- If a shared product sells out, reseller shop should show Out of Stock or hide purchase CTA.
- Reseller should receive notification if a product in their shop is no longer available.

## 17. Price Change Rules

Rules:

- Existing orders keep price snapshot.
- Supplier can request price changes.
- New/untrusted suppliers require admin approval for price changes.
- Trusted suppliers may receive faster price updates later.
- Major price changes can make reseller listings require review.
- For MVP, any supplier base price change should trigger reseller listing review or admin approval.
- Reseller should be notified if a product in their shop changes price.
- Customer links should display updated final customer price only after review/approval.

Order price snapshot:

- `supplier_base_price_at_order`.
- `platform_margin_at_order`.
- `reseller_margin_at_order`.
- `customer_product_price_at_order`.
- `delivery_estimate_selected`.
- `final_delivery_quote`, if available.

Price change statuses:

- Draft.
- Submitted.
- Pending Admin Review.
- Approved.
- Rejected.
- Needs Reseller Review.
- Applied.

## 18. Pay on Delivery Rules

Pay on Delivery is the default Ghana trust model.

Rules:

- Customer can choose Pay on Delivery.
- Customer does not pay product amount upfront.
- Customer order still requires account creation.
- Order still requires stock reservation.
- Customer must confirm order before supplier prepares.
- Delivery quote/final delivery amount may require approval before dispatch.
- Supplier may receive product payment directly from customer at MVP.
- Supplier must immediately settle Risellar/reseller amount after receiving payment.
- Reseller commission remains pending until settlement is verified.

Customer copy:

- "Pay when your item arrives."
- "Delivery cost will be confirmed before dispatch."
- "Your order must be confirmed before we process it."

Pay on Delivery risks:

- Customer may refuse delivery.
- Customer may be unreachable.
- Supplier may fail to settle after collecting payment.
- Delivery cost may change after route check.

Controls:

- Customer confirmation.
- Risk scoring.
- Supplier settlement restrictions.
- Admin operations queues.
- Audit logging.

## 19. Pay Online Rules

MVP:

- Pay Online may appear as placeholder or disabled if not integrated.
- Do not fake live payment.
- If Pay Online is not integrated, clearly mark it unavailable.

Future:

- Customer pays Risellar.
- Risellar settles supplier, reseller, and platform amounts.
- Payment success must be verified server-side.
- Do not trust client-side payment success.
- Store payment provider reference.
- Reconcile provider status before order proceeds.

Future Pay Online statuses:

- Pending Payment.
- Payment Processing.
- Paid.
- Payment Failed.
- Refunded.
- Disputed.

## 20. Customer Confirmation Rules

Order status after placing order:

- Awaiting Customer Confirmation.

MVP confirmation methods:

- Customer account button.
- Email link through Resend.
- Admin manual confirmation after call/WhatsApp.
- Manual WhatsApp helper template.

No SMS/phone OTP at MVP.

Rules:

- Supplier should not prepare until customer confirms.
- Reservation expires if customer does not confirm in time.
- Recommended MVP confirmation window: 1 hour.
- Confirmation timestamp must be recorded.
- Admin should see Customer Confirmation Queue.
- Confirmation source must be recorded: customer account, email link, admin manual, or WhatsApp follow-up.

If customer does not confirm:

- Reservation expires.
- Order becomes Confirmation Expired or Cancelled Before Dispatch.
- Stock is released.
- Reseller and customer are notified.

## 21. Delivery Estimate and Delivery Quote Approval Rules

Delivery is separate from product price.

No rider app at MVP.

Delivery options:

| Option | Estimate |
| --- | --- |
| Express / Same Day | GH₵50-100 |
| Next Day | GH₵30-50 |
| Standard | GH₵20-40 |
| Campus / Specific Day | GH₵10-25 |
| Customer-arranged pickup/delivery | Confirmed manually |
| Supplier-arranged delivery | Confirmed manually |

Rules:

- Checkout shows delivery estimate/range.
- Final delivery quote may be confirmed after supplier/admin checks route.
- Customer must approve final delivery quote before dispatch if final quote is required.
- If customer rejects final quote, order can be cancelled before dispatch.
- Delivery person/rider is not a platform user in MVP.
- Admin can store delivery notes and delivery contact where needed.
- Customer must understand delivery is separate.

Delivery statuses:

- Delivery Estimate Selected.
- Delivery Quote Pending.
- Delivery Quote Sent.
- Delivery Approved.
- Delivery Rejected.
- Out for Delivery.
- Delivered.
- Delivery Failed.

## 22. Supplier Fulfillment Rules

Supplier sees confirmed order after customer confirmation.

Supplier actions:

- Confirm availability.
- Prepare order.
- Mark ready for delivery/pickup.
- Upload packing proof, optional but recommended.
- Mark payment received if customer pays supplier.
- Submit settlement proof after sending Risellar share.

Rules:

- Supplier should not prepare before customer confirmation.
- Supplier should accept/confirm availability within configured time.
- If supplier delays, admin receives alert.
- Repeated delays affect supplier risk score.
- If product is unavailable, supplier must mark unavailable and stock must be corrected.

If product unavailable:

- Order becomes Supplier Unavailable.
- Customer and reseller are notified.
- Stock is corrected.
- Supplier reliability score decreases.
- Replacement product may be offered later.

## 23. Supplier Settlement Rules

This is one of the most important Risellar rules.

MVP money flow:

1. Customer pays supplier or supplier-arranged delivery channel on delivery.
2. Supplier keeps supplier base price.
3. Supplier immediately sends Risellar the amount owed: Risellar platform margin + reseller commission.
4. Supplier uploads proof/reference.
5. Admin/finance verifies settlement.
6. Reseller commission becomes available after verification.

Example:

| Item | Amount |
| --- | ---: |
| Customer product price | GH₵340 |
| Supplier base price | GH₵300 |
| Risellar platform margin | GH₵10 |
| Reseller commission | GH₵30 |
| Supplier must settle | GH₵40 |

Rules:

- Settlement is due immediately after supplier receives customer payment.
- Do not wait weekly at MVP.
- Weekly/daily settlement can be future trusted supplier feature.
- Supplier must upload proof or settlement reference.
- Admin/finance verifies settlement.
- Reseller commission becomes available only after settlement is verified.
- Partial settlement should be supported.
- Settlement overdue should trigger restrictions.
- Supplier dashboard must show clear settlement due amount.
- Admin settlement ledger must show all details.

Settlement statuses:

- Not Due.
- Due.
- Proof Submitted.
- Verifying.
- Partially Settled.
- Paid.
- Overdue.
- Disputed.
- Written Off / Loss, admin-only exceptional state.

## 24. Reseller Commission Lifecycle Rules

Commission states:

- Pending Order.
- Awaiting Customer Confirmation.
- Awaiting Delivery/Payment.
- Awaiting Supplier Settlement.
- Available.
- Withdrawal Requested.
- Paid.
- Cancelled.
- Disputed.

Rules:

- Commission is calculated from price snapshot.
- Commission is not available after order placement.
- Commission is not available after customer confirmation.
- Commission is not available just because supplier delivered.
- Commission becomes available only after supplier settlement is verified.
- If order is cancelled/refused, commission is cancelled.
- If supplier settlement is partial, commission may remain pending until complete.
- Admin can manually adjust only with audit log.

Commission example:

If reseller margin snapshot is GH₵30, the reseller commission for that order is GH₵30 unless a dispute, refund, cancellation, or admin audited adjustment changes it.

## 25. Withdrawal Rules

Reseller can withdraw available balance only.

Rules:

- Pending commission cannot be withdrawn.
- Minimum withdrawal amount should exist, such as GH₵20 or GH₵50.
- Withdrawal requires MoMo details.
- Withdrawal may require admin/finance approval at MVP.
- Withdrawal status must be tracked.
- Failed withdrawal must store reason and retry path.

Withdrawal statuses:

- Requested.
- Processing.
- Paid.
- Failed.
- Rejected.
- Cancelled.

Withdrawal fields should later support:

- Reseller.
- Amount.
- MoMo provider.
- MoMo number.
- Account name.
- Status.
- Failure reason.
- Admin/finance reviewer.
- Paid timestamp.

## 26. Supplier Settlement Restriction/Suspension Rules

Supplier restrictions should be rule-based where possible.

Rules:

- 1 overdue settlement: warning.
- 2 overdue settlements: products hidden from reseller catalog.
- Exceeds settlement limit: new orders blocked.
- Repeated failure: account restricted/suspended.
- Fraud: permanent ban/manual review.
- Supplier with overdue settlement cannot buy promotions/boosts.
- Supplier products auto-hide if supplier is suspended/restricted.

Supplier trust levels:

- New Supplier.
- Verified Supplier.
- Trusted Supplier.
- Restricted Supplier.
- Suspended Supplier.

New suppliers:

- Strict limits.
- Immediate settlement only.
- Low outstanding balance limit.
- Closer admin monitoring.

Trusted suppliers later:

- Larger order limits.
- Possible daily/weekly settlement.
- Faster approvals.

## 27. Risk Score Rules

Risk scores should help admin prioritize review. They should not silently punish users without clear admin visibility.

Supplier risk signals:

- Late settlements.
- Fake/wrong products.
- Cancellations.
- Out-of-stock after order.
- Disputes.
- Complaint rate.
- Fulfillment speed.
- Valid proof uploads.

Reseller risk signals:

- Fake orders.
- Customer complaints.
- Misleading claims.
- Outside payment attempts.
- Cancellation rate.
- Successful sales.

Customer risk signals:

- Cancelled orders.
- Refused deliveries.
- Wrong address.
- No response.
- Successful orders.
- Disputes.

Risk actions:

- Warning.
- Restriction.
- Hidden products.
- Pay-online-only future.
- Delivery deposit future.
- Suspension.
- Admin review.

Risk levels:

- Low.
- Medium.
- High.
- Restricted.
- Suspended.

## 28. Promotions/Boosting Rules

Supplier promotions:

- Supplier can pay GH₵10-20 or admin-configured amount to boost products.
- Promotion can push product higher in reseller catalog.
- Product may appear under Featured/Sponsored.

Boost eligibility:

- Supplier is verified.
- Product is approved.
- Product is in stock.
- Supplier has no overdue settlement.
- Product is not restricted.
- Complaint rate is acceptable.

Promotion statuses:

- Draft.
- Pending Payment.
- Pending Approval.
- Active.
- Paused.
- Completed.
- Rejected.
- Cancelled.

Promotion pauses/stops if:

- Product is out of stock.
- Supplier settlement becomes overdue.
- Product is restricted.
- Supplier is suspended.

Do not make paid promotion override trust and safety.

## 29. Reseller Trending/Top-Selling Insights Rules

Free reseller insights:

- Trending products.
- Featured/sponsored products.
- Basic top-selling products.
- Stock availability.
- Suggested price/profit.

Future Pro insights:

- Best profit products.
- Low competition products.
- Top selling in area/campus.
- WhatsApp caption templates.
- Early access to hot products.
- Advanced trend charts.

Rules:

- Insights must never recommend out-of-stock or restricted products as active selling opportunities.
- Sponsored products must still meet trust and stock requirements.
- Pro-locked areas must not block basic reseller selling.
- WhatsApp captions must not make false product claims.

## 30. Email Notification Rules Using Resend

Use Resend for MVP email notifications.

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

Privacy rules:

- Emails must not expose sensitive information to the wrong role.
- Customer emails must not expose supplier private info.
- Reseller emails must not expose supplier private info.
- Supplier emails must not expose reseller margin strategy.
- Admin emails can include operational details.

## 31. Manual WhatsApp Helper/Template Rules

MVP does not include WhatsApp Business API due to cost.

Admin should have copyable WhatsApp templates for:

- Customer confirmation.
- Delivery quote approval.
- Supplier preparation.
- Supplier settlement due.
- Settlement overdue warning.
- Dispute follow-up.

Rules:

- Templates should be generated from order data.
- Admin copies and sends manually.
- Templates must avoid exposing private data to the wrong party.
- Templates should be clear, Ghana-friendly, and action-oriented.

Future:

- WhatsApp Business API automation.
- Delivery/status notifications by WhatsApp.

## 32. Support and Dispute Rules

Dispute types:

- Wrong product.
- Damaged product.
- Product not received.
- Delivery issue.
- Payment dispute.
- Supplier says customer did not pay.
- Customer says they paid.
- Reseller missing commission.
- Supplier settlement proof dispute.
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

Rules:

- Disputes should attach to order where possible.
- Evidence uploads should be private.
- Admin actions must be audited.
- Commission may remain pending while dispute is open.
- Settlement may remain disputed until verified.
- Support copy should be calm, direct, and specific.

## 33. Return/Refund Rules

Returns vary by category.

Category examples:

| Category | Return rule |
| --- | --- |
| Beauty/skincare | Return only if sealed/unopened, unless wrong/damaged. |
| Shoes/clothing | Return if wrong size/item or supplier fault. |
| Phone accessories | Return if wrong model/defective. |
| Custom/preorder | Restricted returns. |
| Perishable items | Usually no return. |

Return/refund statuses:

- Return Requested.
- Return Approved.
- Return Rejected.
- Returned to Supplier.
- Refund Pending.
- Refund Completed.
- Refund Rejected.

MVP:

- Refund handling can be manual/admin-controlled.
- Pay on Delivery means many refunds may involve supplier/customer manual handling.
- Still track return/refund status.
- Commission and settlement may be held or adjusted during unresolved return/refund cases.

## 34. Audit Log Rules

Every sensitive action must be logged.

Audit log events:

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

Audit log should store:

- Actor user id.
- Actor role.
- Action.
- Entity type.
- Entity id.
- Old value.
- New value.
- Reason/note.
- Timestamp.
- Metadata, without storing secrets.

Audit logs must not store raw secrets, passwords, private keys, or public URLs for sensitive documents.

## 35. Admin Operations Queue Rules

Admin dashboard must have operational queues:

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

Each queue should have:

- Count.
- Priority.
- Status.
- Quick actions.
- Filters.
- Audit trail.

Queue priority examples:

- Overdue settlement: high.
- Customer confirmation nearing expiry: medium/high.
- Product approval: normal unless supplier is high value.
- Fraud/risk review: high.
- Failed delivery: high if customer paid or supplier settlement is affected.

## 36. Security and Privacy Rules

Backend security principles:

- Never trust frontend-sent price, margin, role, supplier_id, reseller_id, or commission.
- Server/database must calculate price and commission.
- Use RLS for all tables later.
- Sensitive files must be private.
- Ghana Card/verification documents must not be public.
- Admin access must be role-protected.
- Supplier staff must only access their supplier workspace.
- Resellers must only access their own shop/orders/commissions.
- Customers must only access their own orders/account.
- Suppliers must only access their own products/orders/settlements.
- Admin actions must be audited.
- Service role must never be exposed to client.
- Existing order prices cannot be changed by user actions.
- Stock reservation must be atomic.

Privacy rules:

- Explain why verification documents are collected.
- Require consent before ID upload.
- Restrict who can view ID documents.
- Add privacy/terms requirement.
- Do not expose supplier private contact to customer/reseller in normal flow.
- Do not expose reseller margin strategy to supplier/customer.

## 37. MVP Boundary

MVP includes:

- Clerk Google/email auth.
- Customer account creation.
- Reseller onboarding.
- Supplier onboarding.
- Admin approval of suppliers/products.
- Product catalog.
- Reseller shop/link.
- Reseller margin limits.
- Customer checkout.
- Pay on Delivery.
- Stock reservation.
- Supplier inventory/restock.
- Inventory manager role.
- Customer confirmation.
- Delivery estimate/quote approval.
- Supplier fulfillment.
- Supplier settlement due/proof/verification.
- Reseller commission pending/available.
- Reseller withdrawals, manual/admin.
- Resend email notifications.
- Manual WhatsApp templates.
- Admin operations queues.
- Audit logs.
- Basic disputes/support.
- Supplier promotions/boost request, manual payment/approval.
- Trending/featured products basic.

MVP does not include:

- Native mobile apps.
- Rider app.
- Full automated MoMo/Paystack settlement.
- WhatsApp Business API automation.
- AI recommendations.
- Advanced brand campaigns.
- Complex subscriptions.
- Fully automated refunds.
- Real-time map tracking.
- Advanced fraud ML.
- Multi-country support.

## 38. Future Features

Future features:

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
- Native app later only if business need is proven and approved.

## 39. Open Questions / Decisions to Confirm Later

- Should reseller onboarding require admin approval at MVP, or should low-risk resellers be auto-approved?
- What exact minimum withdrawal amount should MVP use: GH₵20, GH₵50, or another threshold?
- What exact supplier outstanding settlement limit should trigger new-order blocking?
- Should New Supplier order volume be capped per day/week?
- Which payment provider will power Pay Online later: Paystack, Hubtel, or another provider?
- Should Pay Online be hidden, disabled, or shown as "coming soon" in MVP?
- Who arranges delivery by default in MVP: supplier, customer, or admin coordination by category/area?
- What delivery quote SLA should admin/supplier follow?
- What supplier availability response timer should trigger alerts?
- Which product categories are approved for launch?
- What proof is required before marking customer payment received?
- Which users can view Ghana Card documents in admin?
- Should finance staff be included in MVP or remain future role?
- How long should audit logs be retained?

## 40. Final Implementation Principles

- Follow the approved PWA/web platform direction.
- Read the brand/UI guide before any UI work.
- Do not build native mobile at MVP.
- Do not build UI, schema, or PRD from assumptions that conflict with this document.
- Server/database must enforce pricing, stock, role, settlement, and commission rules.
- Keep customer, reseller, supplier, and admin data boundaries strict.
- Make Pay on Delivery trustworthy without weakening marketplace controls.
- Keep supplier settlement and reseller commission logic transparent and auditable.
- Use admin queues to prevent operational work from hiding.
- Treat stock reservation as a database-safe business-critical operation.
- Keep Ghana-specific context visible in examples, copy, and future flows.
- If a rule is undecided, document it as an open question instead of inventing a silent behavior.
