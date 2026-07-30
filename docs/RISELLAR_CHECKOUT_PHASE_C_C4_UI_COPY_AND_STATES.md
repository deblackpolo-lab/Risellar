# Risellar Checkout Phase C C4 UI Copy And States

## Summary

This document defines the planned customer-facing copy and states for the future order-confirmation UI. It does not enable the final button or implement source changes.

## Draft Review Page

Page title:

`Review your order draft`

Intro copy:

`Review your saved contact, delivery address, and product price snapshot before placing the order.`

Safety copy:

`This step does not collect online payment. Pay on Delivery remains the only payment method in this phase.`

## Disabled CTA State

Current safe label:

`Order confirmation coming next`

Disabled-state helper copy:

`Order placement is still disabled while the live confirmation action is prepared and tested.`

This state must remain until the approved implementation group wires the server action.

## Future Enabled CTA State

Future label:

`Place order and reserve stock`

Future helper copy:

`This creates your order and temporarily reserves available stock. Delivery quote, supplier preparation, payment collection, and tracking come later.`

## Required Acknowledgement

Checkbox label:

`I understand this places my order, reserves available stock, and I will pay on delivery after the seller confirms the order process.`

Validation copy:

`Confirm the order terms before placing this order.`

## Loading State

Button label:

`Placing order...`

Page behavior:

- disable submit
- keep draft details visible
- prevent duplicate clicks
- do not navigate until the server action returns or redirects

## Success State

Heading:

`Order placed`

Body:

`Your order was created and stock was reserved. You will pay on delivery. Delivery quote and tracking are not active yet.`

Primary action:

`View order`

Secondary action:

`Continue shopping`

## Error States

Insufficient stock:

`This product just sold out or has less stock than requested. No order was placed.`

Unavailable listing:

`This product is no longer available from this shop. No order was placed.`

Draft no longer active:

`This checkout draft cannot be placed anymore. Start a new draft if the product is still available.`

Address missing:

`Choose one of your saved delivery addresses before placing the order.`

Auth/session issue:

`Your session could not be verified. Please sign in again.`

Generic fallback:

`We could not place the order. Please try again.`

## Order Detail States

Initial live order status:

`Placed, pending confirmation`

Customer confirmation:

`Pending`

Payment:

`Pay on Delivery`

Delivery:

`Delivery quote not started`

Reservation:

`Stock reserved`

Deferred actions:

- `Confirm receipt coming later`
- `Delivery quote approval coming later`
- `Report issue coming later`
- `Return request coming later`

## Copy Guardrails

Do not say:

- payment was collected
- delivery was booked
- supplier has started preparation
- commission was released
- settlement was created
- stock was sold or fulfilled

Do say:

- order was placed
- stock was reserved
- payment is Pay on Delivery
- delivery quote is deferred
- supplier workflow is deferred
