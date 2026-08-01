# Risellar Dispute D2 Safe-Read RPC Contracts

## Shared Rules

All D2 read RPCs are read-only. They must not create disputes, messages, status history, audit logs, notifications, refunds, returns, finance holds, settlement rows, commission rows, withdrawal rows, payment rows, stock reservations, or inventory movements.

Rules:

- no caller-supplied profile, customer, supplier, or reseller IDs
- identity resolved from the authenticated profile
- active role/profile checks
- `SECURITY DEFINER` with `set search_path = public`
- explicit return columns
- no `SELECT *`
- pagination limits
- deterministic ordering
- safe labels/messages only
- no private IDs in public docs or reports

## Customer List

Function:

`public.list_customer_disputes_safe(p_status text, p_limit integer, p_cursor_opened_at timestamptz, p_cursor_dispute_id uuid)`

Returns:

- `dispute_id`
- `safe_order_reference`
- `category`
- `reason_code`
- `requested_outcome`
- `status`
- `customer_action_required`
- `supplier_action_required`
- `opened_at`
- `updated_at`
- `safe_latest_message`
- `safe_next_action`

Boundary:

- caller must be active customer
- order must belong to caller's customer row
- messages limited to `customer_and_admin` and `all_case_participants`
- no internal notes, settlement, commission, wallet, withdrawal, supplier private data, evidence paths, or contact metadata

## Customer Detail

Function:

`public.get_customer_dispute_safe(p_dispute_id uuid)`

Returns the safe customer detail plus customer-visible messages and status history. Internal status-history notes are excluded.

## Supplier List

Function:

`public.list_supplier_disputes_safe(p_status text, p_limit integer, p_cursor_opened_at timestamptz, p_cursor_dispute_id uuid)`

Boundary:

- caller must be active approved supplier owner
- dispute must connect to an order item owned by the supplier
- no other supplier data
- no customer auth metadata
- no admin-only notes

## Supplier Detail

Function:

`public.get_supplier_dispute_safe(p_dispute_id uuid)`

Returns:

- safe order reference
- category/reason/outcome/status/priority
- supplier action flag
- product names for own order items
- customer claim only when safe to share
- public resolution message
- supplier-visible messages
- public status history

Excludes:

- customer account metadata
- unrelated customer addresses
- reseller wallet/commission details
- settlement proof
- admin private notes
- evidence paths

## Reseller Impact

Function:

`public.get_reseller_dispute_impact_safe(p_order_id uuid, p_limit integer)`

Returns:

- `safe_order_reference`
- `dispute_exists`
- `dispute_status`
- `commission_impact_state`
- `opened_at`
- `resolved_at`
- `safe_summary`

`commission_impact_state` values:

- `none`
- `review_pending`
- `future_hold_possible`
- `resolved_no_effect`
- `adjustment_required_later`

Excludes complaint text, supplier responses, evidence, private messages, admin notes, refund amount, settlement details, customer contact, payout data, and wallet details.

## Admin List

Function:

`public.list_admin_disputes_safe(p_status text, p_category text, p_priority text, p_assigned_only boolean, p_finance_review_required boolean, p_limit integer, p_cursor_opened_at timestamptz, p_cursor_dispute_id uuid)`

Boundary:

- caller must be active `support_staff`, `admin`, or `super_admin` in `admin_staff`
- finance values are not returned in list
- filters are controlled and rejected if invalid
- no arbitrary customer search in D2

## Admin Detail

Function:

`public.get_admin_dispute_safe(p_dispute_id uuid)`

General admin/support can see operational case context. Finance context is populated only when the caller is active `finance_staff` or `super_admin`.

Finance context includes only high-level status:

- payment collection status
- order status
- settlement status
- commission status
- withdrawal risk warning

It does not allow mutation and does not expose full payout account information.

## Why No Mutation RPCs In D2

D2 intentionally excludes `customer_open_order_dispute` and all response/status mutation RPCs. The schema is idempotency-ready, but live mutation belongs to a later group so ownership/privacy tests can be reviewed first.
