# Risellar Dispute Role and Privacy Matrix

## Matrix

| Actor | May open | May view | May act | Must not see | Must not do |
| --- | --- | --- | --- | --- | --- |
| Anonymous | Nothing | Nothing | Nothing | Any dispute/order/evidence data | Open or mutate cases |
| Customer | Own eligible order cases | Own dispute timeline, customer-safe order data, public resolution, return/refund progress | Add customer response, confirm requested info, view resolution | Supplier private notes, admin private notes, payout data, settlement proof, reseller commission, risk internals | Dispute another customer's order, set status, set refund amount, upload unsafe files |
| Supplier owner | Own supplier order cases | Own supplier disputes, claim detail needed to respond, return/refund instructions | Add response, confirm return receipt, classify returned item when authorised, report manual refund sent | Customer account metadata beyond order needs, reseller private strategy, admin private notes, finance-only calculations | Resolve own dispute, approve own refund, verify own settlement, access another supplier's case |
| Supplier inventory staff | No, unless later approved | Own supplier returns needing inspection | Classify returned item if permission exists | Payout/settlement proof, admin finance notes, other supplier data | Change refund/commission/settlement decisions |
| Reseller | Commission/accounting cases | Own commission-impact summary and safe order reference | Add commission issue response if allowed | Customer private claim, supplier evidence, supplier payout, admin notes, settlement proof, other reseller data | Resolve dispute, change commission, approve refunds |
| Support staff | Platform/support cases | Assigned dispute context and safe order timeline | Request info, triage, recommend non-finance resolution | Raw payout data, Ghana Card/KYC, settlement proof unless explicitly allowed, private finance internals | Apply money adjustment, verify settlement, pay withdrawal |
| Finance staff | Finance discrepancies | Finance dispute context, settlements, commissions, withdrawals, masked payout fields | Approve finance holds, verify manual refund completion, apply finance adjustment within RPC limits | Unneeded evidence or customer private data outside case | Broad support resolution if not assigned, arbitrary money edits |
| Admin | Operational cases | Authorised dispute/admin context | Triage, request info, approve/reject return, set non-finance resolution | Unmasked payout/KYC unless role allows | Bypass finance_staff for finance actions, arbitrary status/money update |
| Super admin | Exceptional cases | Full authorised context | Sensitive overrides with reason and audit | Secrets/tokens/raw provider credentials | Unlogged changes or direct table mutation from UI |

## Field Visibility

Customer-safe:

- safe order reference
- product name
- public shop name
- fulfilment status label
- payment-safe status label
- dispute status
- next action
- refund/return status
- approved customer-facing messages

Supplier-safe:

- order reference
- ordered item details needed for fulfilment
- customer claim and approved evidence needed to respond
- return instructions
- refund obligation assigned to supplier, if approved
- no reseller commission amounts unless already supplier-safe order snapshot requires it

Reseller-safe:

- order reference
- dispute opened/closed
- commission hold status
- final commission effect
- no private evidence

Admin-safe:

- order timeline
- actor responses
- evidence metadata
- finance impact
- stock/reservation history
- audit history
- masked payout/contact details according to role

## Private Fields

Never expose outside authorised roles:

- supplier private contact
- supplier payout data
- settlement proof details
- reseller payout data
- customer private account metadata unrelated to case
- admin private notes
- risk scores
- raw evidence storage paths
- raw provider payloads
- secrets, cookies, JWTs, API keys, database IDs in public reports

## Email Privacy

Transactional emails must not include private evidence, internal notes, raw enums, settlement internals, commission internals, payout data, or risk scores. Emails should link to authenticated safe pages.

## D2 Safe-Read Alignment

D2 maps this matrix into narrow read RPCs:

- Customer: `list_customer_disputes_safe`, `get_customer_dispute_safe`
- Supplier: `list_supplier_disputes_safe`, `get_supplier_dispute_safe`
- Reseller: `get_reseller_dispute_impact_safe`
- Admin/support/finance: `list_admin_disputes_safe`, `get_admin_dispute_safe`

Direct table access remains revoked for browser roles.

## D5-A Scope Addendum

Supplier "own case" access now means explicit target ownership through `affected_supplier_id`, or a single-supplier order-wide case. Owning an unrelated item on a multi-supplier order is not sufficient. Reseller visibility remains safe impact-only and does not expose complaint text or supplier private details.
