# Customer Checkout Security Checklist

## Scope

Use this checklist for every customer account, checkout draft, order, stock reservation, delivery quote, Pay on Delivery, and future payment implementation.

## Global Safety

- [ ] Production Supabase is not connected.
- [ ] Production data is not used.
- [ ] No destructive reset command is run.
- [ ] `.env.local` is not printed or committed.
- [ ] Service role is not imported in `app/` or `components/`.
- [ ] Checkout/customer code uses user-context Supabase access where user auth is required.
- [ ] RLS/RPC/storage policies are not weakened to make tests pass.

## Customer Account

- [ ] Customer account creation requires Clerk auth.
- [ ] Customer row maps to the signed-in profile only.
- [ ] Customer cannot assign or mutate role.
- [ ] Phone/WhatsApp are stored as customer contact, not auth factors.
- [ ] Customer can read/update only own address/contact data.

## Public Listing Input

- [ ] Browser sends only listing slug/share slug, variant id, quantity, and customer-entered contact/delivery fields.
- [ ] Browser does not send trusted final price.
- [ ] Browser does not send supplier base price.
- [ ] Browser does not send platform margin.
- [ ] Browser does not send reseller margin.
- [ ] Browser does not send commission amount.
- [ ] Browser does not send settlement due amount.
- [ ] Browser does not send supplier/reseller/customer ids as trusted inputs.

## Listing Eligibility

- [ ] Reseller shop is active and non-deleted.
- [ ] Reseller listing is active and non-deleted.
- [ ] Product is active and approved.
- [ ] Product is non-deleted.
- [ ] Supplier is active and approved.
- [ ] Supplier is non-deleted.
- [ ] Variant is active/low-stock and non-deleted.
- [ ] Pending/rejected/archived/hidden/restricted/suspended listings are blocked.
- [ ] Pending/rejected/archived/hidden/restricted/suspended products are blocked.

## Pricing Snapshot

- [ ] Supplier base price snapshot comes from `products.base_price_amount`.
- [ ] Platform margin snapshot comes from `products.platform_margin_amount`.
- [ ] Reseller margin snapshot comes from `reseller_products.reseller_margin_amount`.
- [ ] Customer product price snapshot comes from `reseller_products.customer_product_price_amount`.
- [ ] Line total is server-calculated from quantity and customer product price snapshot.
- [ ] Settlement due amount is server-calculated.
- [ ] Commission snapshot is server-calculated.
- [ ] Existing orders are immutable to later supplier/listing price changes.

## Order Creation

- [ ] Order creation happens through audited RPC, not direct browser table writes.
- [ ] Order starts as Pay on Delivery unless future online payment phase is explicitly approved.
- [ ] Order starts with customer confirmation pending.
- [ ] Order stores customer contact snapshot.
- [ ] Order stores delivery address snapshot.
- [ ] Order item stores product/listing/supplier/reseller snapshot fields.
- [ ] Order creation fails clearly for unavailable listing.
- [ ] Order creation fails clearly for invalid quantity.

## Stock Reservation

- [ ] Reservation runs in the database transaction that locks variant stock.
- [ ] Variant row is locked before availability calculation.
- [ ] Available stock subtracts reserved and sold quantities.
- [ ] Insufficient stock fails without overselling.
- [ ] Successful reservation increments reserved stock.
- [ ] Reservation expiry is set, recommended MVP default 1 hour.
- [ ] Inventory movement is written for reservation.
- [ ] Reservation release/expiry decrements reserved stock safely.
- [ ] Race-condition boundary test exists.

## Pay on Delivery

- [ ] Pay Online remains hidden/disabled/deferred.
- [ ] No provider reference or webhook is accepted in MVP Pay on Delivery flow.
- [ ] Customer confirmation is required before supplier preparation.
- [ ] Supplier payment received and settlement proof are separate later actions.
- [ ] Commission is not available at order creation.
- [ ] Settlement is not verified at order creation.

## Delivery Quote

- [ ] Delivery estimate is separate from product price.
- [ ] Customer cannot set final delivery quote.
- [ ] Customer can approve/reject only own order's quote.
- [ ] Quote approval/rejection writes audit log.
- [ ] Quote rejection does not incorrectly mark order paid/completed.

## Privacy

- [ ] Customer sees final product price only.
- [ ] Customer does not see supplier base price.
- [ ] Customer does not see platform margin.
- [ ] Customer does not see reseller margin/commission.
- [ ] Customer does not see supplier private contact/payout/internal/admin/risk/team data.
- [ ] Reseller does not see supplier private contact through checkout/order views.
- [ ] Supplier does not see reseller margin strategy beyond required order operations.

## Audit

- [ ] Customer account creation/update is audited if implemented as sensitive transition.
- [ ] Checkout draft creation/update is audited if used for order intent tracking.
- [ ] Order creation is audited.
- [ ] Stock reservation creation/release/expiry is audited.
- [ ] Customer confirmation/cancellation is audited.
- [ ] Delivery quote approval/rejection is audited.
- [ ] No audit log stores raw secrets, tokens, or private document URLs.

## Test Gates

- [ ] SQL boundary test exists for each new RPC.
- [ ] Tests run only against confirmed development project unless separately approved.
- [ ] Browser QA uses dev-only accounts/data.
- [ ] Secret scan passes.
- [ ] Scope scan confirms no checkout/order/stock/payment/delivery mutation references were added outside approved phase.

