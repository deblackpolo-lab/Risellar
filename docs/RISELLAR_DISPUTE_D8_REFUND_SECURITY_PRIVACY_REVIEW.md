# Risellar D8 Refund Security and Privacy Review

## Authorization

Refund approval, platform sent reporting, finance verification, finance report rejection, and completion require active `admin_staff` finance authority: `finance_staff` or `super_admin`. Support-only staff cannot approve or verify monetary refunds. Admin authority is not based only on `profiles.primary_role`.

Supplier sent reporting requires the active approved supplier owner for the affected supplier. Customers can confirm or dispute only their own refund. Resellers receive only minimal impact visibility.

## Direct Access

`order_refunds` and `refund_actions` are RLS-forced and direct table privileges are revoked from browser roles. Mutation access is only through narrow RPCs.

## Privacy

Safe reads hide:

- internal finance notes from customers, suppliers, resellers, and support views where not appropriate,
- supplier private sent notes from customer views,
- raw or unsafe references,
- customer profile identifiers from supplier views,
- refund amounts from reseller impact views,
- settlement, commission, wallet, withdrawal, payout, and risk data.

Audit metadata and refund audit `reason` values exclude note bodies, raw external references, account details, phone numbers, payout data, evidence, settlement data, commission data, wallet data, and withdrawal data.

## Input Safety

D8 validates controlled refund types, statuses, responsibility codes, responsible party roles, refund methods, idempotency keys, safe public text, safe internal text, and masked references. Raw long numeric account/reference strings are rejected.

## Secret and Scope Review

No service-role client is exposed in `app/`, `components/`, or browser code. No UI integration was added. No provider credentials, bearer tokens, Clerk secrets, Supabase service-role values, passwords, or production data were added to docs/source/scripts.
