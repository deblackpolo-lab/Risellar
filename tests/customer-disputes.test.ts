import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it, vi } from "vitest";
import { canAccessRoute, getVerifiedRouteAccessProfile } from "@/lib/auth/route-guards";
import {
  buildCustomerDisputeListPayload,
  buildCustomerDisputeOpenPayload,
  buildCustomerDisputeResponsePayload,
  getCustomerDisputeSafeWithClient,
  listCustomerOrderItemsForDisputeSafeWithClient,
  listCustomerDisputesSafeWithClient,
  mapCustomerDisputeRpcError,
  type CustomerDisputeRpcClient
} from "@/lib/customer/disputes";

vi.mock("server-only", () => ({}));

function createRpcSpyClient(responses: Record<string, { data?: unknown; error?: { code?: string; message?: string } | null }>) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: CustomerDisputeRpcClient = {
    async rpc<T = unknown>(name: string, args?: Record<string, unknown>) {
      calls.push({ name, args });
      const response = responses[name] ?? {};
      return {
        data: (response.data ?? []) as T,
        error: response.error ?? null
      };
    }
  };

  return { calls, client };
}

function readSourceTree(relativePath: string): string {
  const fullPath = join(process.cwd(), relativePath);
  const stat = statSync(fullPath);

  if (stat.isFile()) {
    return readFileSync(fullPath, "utf8");
  }

  return readdirSync(fullPath)
    .map((entry): string => readSourceTree(join(relativePath, entry)))
    .join("\n");
}

describe("Customer dispute workflow UI contract", () => {
  it("builds bounded customer dispute list payloads without caller-owned ids", () => {
    expect(buildCustomerDisputeListPayload({ status: " open ", limit: "200" })).toEqual({
      p_status: "open",
      p_limit: 50,
      p_cursor_opened_at: null,
      p_cursor_dispute_id: null
    });

    expect(buildCustomerDisputeListPayload({})).toEqual({
      p_status: null,
      p_limit: 20,
      p_cursor_opened_at: null,
      p_cursor_dispute_id: null
    });
    expect(() => buildCustomerDisputeListPayload({ status: "supplier_private" })).toThrow("Dispute status filter is invalid");
    expect(JSON.stringify(buildCustomerDisputeListPayload({ status: "open" }))).not.toMatch(/customer_id|profile_id|supplier_id/i);
  });

  it("calls only customer-safe dispute list and detail RPCs", async () => {
    const { calls, client } = createRpcSpyClient({
      list_customer_disputes_safe: {
        data: [
          {
            dispute_id: "11111111-1111-4111-8111-111111111111",
            safe_order_reference: "RSR-TEST",
            scope_type: "order",
            affected_item_summary: "Order-wide review",
            category: "delivery",
            reason_code: "delivery_delay",
            requested_outcome: "information_only",
            status: "open",
            customer_action_required: false,
            supplier_action_required: true,
            opened_at: "2026-08-01T00:00:00.000Z",
            updated_at: "2026-08-01T01:00:00.000Z",
            safe_latest_message: "Customer-safe update",
            safe_next_action: "Waiting for supplier response"
          }
        ]
      },
      get_customer_dispute_safe: {
        data: [
          {
            dispute_id: "11111111-1111-4111-8111-111111111111",
            safe_order_reference: "RSR-TEST",
            scope_type: "order",
            affected_item_summary: "Order-wide review",
            category: "delivery",
            reason_code: "delivery_delay",
            requested_outcome: "information_only",
            status: "open",
            priority: "normal",
            customer_action_required: false,
            supplier_action_required: true,
            opened_at: "2026-08-01T00:00:00.000Z",
            updated_at: "2026-08-01T01:00:00.000Z",
            public_resolution_message: null,
            safe_next_action: "Waiting for supplier response",
            messages: [
              {
                messageId: "22222222-2222-4222-8222-222222222222",
                authorRole: "customer",
                messageType: "participant_response",
                body: "Customer-safe update",
                createdAt: "2026-08-01T00:00:00.000Z"
              }
            ],
            status_history: [
              {
                previousStatus: null,
                newStatus: "open",
                changedByRole: "customer",
                publicNote: "Dispute opened by customer.",
                internalNote: "must never map",
                createdAt: "2026-08-01T00:00:00.000Z"
              }
            ]
          }
        ]
      }
    });

    const listResult = await listCustomerDisputesSafeWithClient(client, { status: "open" });
    const detailResult = await getCustomerDisputeSafeWithClient(client, "11111111-1111-4111-8111-111111111111");

    expect(listResult.disputes[0]).toMatchObject({
      safeOrderReference: "RSR-TEST",
      affectedItemSummary: "Order-wide review",
      reasonLabel: "Delivery delay",
      statusLabel: "Open"
    });
    expect(detailResult.dispute?.messages[0]).toMatchObject({
      authorRole: "customer",
      body: "Customer-safe update"
    });
    expect(JSON.stringify(detailResult.dispute)).not.toMatch(/internalNote|supplier_private|settlement|commission|payout|margin/i);
    expect(calls).toEqual([
      {
        name: "list_customer_disputes_safe",
        args: {
          p_status: "open",
          p_limit: 20,
          p_cursor_opened_at: null,
          p_cursor_dispute_id: null
        }
      },
      {
        name: "get_customer_dispute_safe",
        args: {
          p_dispute_id: "11111111-1111-4111-8111-111111111111"
        }
      }
    ]);
  });

  it("builds open and response payloads for audited customer RPCs only", () => {
    expect(
      buildCustomerDisputeOpenPayload({
        orderId: "11111111-1111-4111-8111-111111111111",
        disputeCategory: "delivery",
        reasonCode: "delivery_delay",
        requestedOutcome: "information_only",
        description: "Delivery is delayed and I need an update.",
        idempotencyKey: "qa-key-123"
      })
    ).toEqual({
      p_order_id: "11111111-1111-4111-8111-111111111111",
      p_order_item_id: null,
      p_dispute_category: "delivery",
      p_reason_code: "delivery_delay",
      p_requested_outcome: "information_only",
      p_description: "Delivery is delayed and I need an update.",
      p_idempotency_key: "qa-key-123"
    });

    expect(
      buildCustomerDisputeResponsePayload({
        disputeId: "33333333-3333-4333-8333-333333333333",
        body: "I can provide more details for review.",
        idempotencyKey: "response-key-123"
      })
    ).toEqual({
      p_dispute_id: "33333333-3333-4333-8333-333333333333",
      p_body: "I can provide more details for review.",
      p_idempotency_key: "response-key-123"
    });

    expect(() =>
      buildCustomerDisputeOpenPayload({
        orderId: "11111111-1111-4111-8111-111111111111",
        disputeCategory: "delivery",
        reasonCode: "damaged_item_received",
        requestedOutcome: "replacement",
        description: "Damaged item",
        idempotencyKey: "qa-key-123"
      })
    ).toThrow("This reason needs a safe item selector");

    expect(
      buildCustomerDisputeOpenPayload({
        orderId: "11111111-1111-4111-8111-111111111111",
        orderItemId: "44444444-4444-4444-8444-444444444444",
        disputeCategory: "post_completion",
        reasonCode: "damaged_item_received",
        requestedOutcome: "replacement",
        description: "The selected item arrived damaged.",
        idempotencyKey: "qa-key-456"
      })
    ).toEqual({
      p_order_id: "11111111-1111-4111-8111-111111111111",
      p_order_item_id: "44444444-4444-4444-8444-444444444444",
      p_dispute_category: "post_completion",
      p_reason_code: "damaged_item_received",
      p_requested_outcome: "replacement",
      p_description: "The selected item arrived damaged.",
      p_idempotency_key: "qa-key-456"
    });
  });

  it("loads customer-safe order item selector rows through the read-only RPC", async () => {
    const { calls, client } = createRpcSpyClient({
      list_customer_order_items_for_dispute_safe: {
        data: [
          {
            order_item_id: "44444444-4444-4444-8444-444444444444",
            safe_item_name: "QA Safe Product",
            safe_variant_summary: "Red / Small",
            quantity: 2,
            final_customer_price_amount: 150,
            line_total_amount: 300,
            currency_code: "GHS",
            supplier_id: "must not map",
            supplier_base_price_snapshot_amount: 80,
            reseller_margin_snapshot_amount: 20,
            commission_amount: 5,
            settlement_due_amount: 70,
            internal_note: "must not map"
          }
        ]
      }
    });

    const result = await listCustomerOrderItemsForDisputeSafeWithClient(client, "11111111-1111-4111-8111-111111111111");

    expect(calls).toEqual([
      {
        name: "list_customer_order_items_for_dispute_safe",
        args: {
          p_order_id: "11111111-1111-4111-8111-111111111111"
        }
      }
    ]);
    expect(result.state.code).toBe("OK");
    expect(result.orderItems).toEqual([
      {
        orderItemId: "44444444-4444-4444-8444-444444444444",
        safeItemName: "QA Safe Product",
        safeVariantSummary: "Red / Small",
        quantity: 2,
        finalCustomerPriceAmount: 150,
        lineTotalAmount: 300,
        currencyCode: "GHS"
      }
    ]);
    expect(JSON.stringify(result.orderItems)).not.toMatch(/supplier|margin|commission|settlement|internal|base_price/i);
  });

  it("maps customer dispute RPC errors to safe UI messages", () => {
    expect(mapCustomerDisputeRpcError({ message: "CUSTOMER_REQUIRED" })).toMatchObject({ code: "AUTH_REQUIRED" });
    expect(mapCustomerDisputeRpcError({ message: "DUPLICATE_ACTIVE_DISPUTE" })).toMatchObject({ code: "DUPLICATE_ACTIVE_DISPUTE" });
    expect(mapCustomerDisputeRpcError({ message: "ORDER_ITEM_REQUIRED_FOR_REASON" })).toMatchObject({ code: "ITEM_SELECTOR_REQUIRED" });
    expect(mapCustomerDisputeRpcError(new Error("Description is required"))).toMatchObject({ code: "VALIDATION_ERROR" });
  });

  it("keeps customer dispute routes customer-only in route policy", () => {
    expect(canAccessRoute("/customer/disputes", getVerifiedRouteAccessProfile({ primaryRole: "customer" }))).toBe(true);
    expect(canAccessRoute("/customer/disputes/11111111-1111-4111-8111-111111111111", getVerifiedRouteAccessProfile({ primaryRole: "customer" }))).toBe(true);
    expect(canAccessRoute("/customer/orders/11111111-1111-4111-8111-111111111111/report-problem", getVerifiedRouteAccessProfile({ primaryRole: "customer" }))).toBe(true);
    expect(canAccessRoute("/customer/disputes", getVerifiedRouteAccessProfile({ primaryRole: "reseller" }))).toBe(false);
    expect(canAccessRoute("/customer/disputes", getVerifiedRouteAccessProfile({ primaryRole: "supplier_owner" }))).toBe(false);
    expect(canAccessRoute("/customer/disputes", getVerifiedRouteAccessProfile({ primaryRole: "customer", hasActiveAdminStaff: true }))).toBe(false);
  });

  it("does not connect dispute UI to private or unrelated business flows", () => {
    const sources = [
      "app/customer/disputes",
      "app/customer/orders/[id]/report-problem",
      "components/customer/customer-dispute-rpc-screens.tsx",
      "lib/customer/disputes.ts",
      "lib/customer/dispute-shared.ts"
    ].map(readSourceTree).join("\n");

    expect(sources).toContain("list_customer_disputes_safe");
    expect(sources).toContain("get_customer_dispute_safe");
    expect(sources).toContain("customer_open_order_dispute");
    expect(sources).toContain("customer_add_dispute_response");
    expect(sources).toContain("list_customer_order_items_for_dispute_safe");
    expect(sources).not.toContain("lib/mock/support-disputes");
    expect(sources).not.toContain("createSupabaseAdminClient");
    expect(sources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(sources).not.toMatch(/create_payment|payment_provider|create_delivery|delivery_quote_action|create_settlement|create_commission|create_withdrawal|create_return|create_refund/i);
    expect(sources).not.toMatch(/\b(from|insert\s+into|update|delete\s+from)\s+public\.(orders|stock_reservations|delivery_quotes|settlements|commissions|withdrawals|refund_requests|return_requests)\b/i);
  });

  it("keeps dispute submission navigation and terminal response states safe", () => {
    const actionsSource = readSourceTree("app/customer/disputes/actions.ts");
    const screenSource = readSourceTree("components/customer/customer-dispute-rpc-screens.tsx");

    expect(actionsSource).toContain('return result');
    expect(screenSource).toContain('window.location.assign(state.disputeHref)');
    expect(screenSource).toContain('name="order_item_id"');
    expect(screenSource).not.toContain('name="dispute_category"');
    expect(screenSource).toContain('itemSelectionMissing');
    expect(screenSource).toContain('Supplier assignment is derived by the audited RPC');
    expect(screenSource).toContain('const terminalDisputeStatuses = new Set');
    expect(screenSource).toContain('Responses closed');
    expect(screenSource).toContain('This dispute is in a terminal state');
    expect(screenSource).not.toContain('disabled={option.itemSelectorRequired}');
  });
});
