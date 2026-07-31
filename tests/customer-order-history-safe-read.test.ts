import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it, vi } from "vitest";
import { canAccessRoute, getVerifiedRouteAccessProfile } from "@/lib/auth/route-guards";
import {
  buildCustomerOrderHistoryPayload,
  getCustomerOrderSummarySafeWithClient,
  listCustomerOrdersSafeWithClient,
  type CustomerOrderHistoryItem,
  type CustomerOrderHistoryRpcClient
} from "@/lib/orders/customer-order-history";

vi.mock("server-only", () => ({}));

function createRpcSpyClient(responses: Record<string, { data?: unknown; error?: { code?: string; message?: string; details?: string } | null }>) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: CustomerOrderHistoryRpcClient = {
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

describe("Customer order history safe read", () => {
  it("builds a bounded order history payload without caller customer ids", () => {
    expect(buildCustomerOrderHistoryPayload({
      group: "active",
      search: " RSR ",
      dateFrom: "2026-07-01",
      dateTo: "2026-07-31",
      limit: "200"
    })).toEqual({
      p_group: "active",
      p_search: "RSR",
      p_date_from: "2026-07-01",
      p_date_to: "2026-07-31",
      p_limit: 50,
      p_cursor_created_at: null,
      p_cursor_order_id: null
    });

    expect(() => buildCustomerOrderHistoryPayload({ group: "supplier" })).toThrow("Order group is invalid");
    expect(() => buildCustomerOrderHistoryPayload({ dateFrom: "2026/07/01" })).toThrow("Start date is invalid");
    expect(() => buildCustomerOrderHistoryPayload({ dateFrom: "2026-08-01", dateTo: "2026-07-01" })).toThrow("Date range is invalid");
    expect(JSON.stringify(buildCustomerOrderHistoryPayload({}))).not.toMatch(/customer_id|profile_id/i);
  });

  it("calls only the customer-safe list and summary RPCs", async () => {
    const { calls, client } = createRpcSpyClient({
      list_customer_orders_safe: {
        data: [
          {
            order_id: "11111111-1111-4111-8111-111111111111",
            order_number: "RSR-TEST",
            created_at: "2026-07-31T00:00:00.000Z",
            updated_at: "2026-07-31T00:00:00.000Z",
            order_status_label: "Supplier confirmed your order",
            order_status_group: "active",
            completed_at: null,
            rejected_at: null,
            product_name: "QA Product",
            product_slug: "qa-product",
            product_image_snapshot: { image_count: 1, primary_alt: "QA Product image" },
            quantity: 2,
            final_customer_price_amount: 125,
            line_total_amount: 250,
            total_payable_amount: 250,
            currency_code: "GHS",
            payment_method_label: "Pay on Delivery",
            payment_collection_label: "Payment not collected",
            delivery_status_label: "Delivery has not been arranged yet",
            reseller_shop_name: "QA Shop",
            reseller_shop_slug: "qa-shop",
            detail_href: "/customer/orders/11111111-1111-4111-8111-111111111111"
          }
        ]
      },
      get_customer_order_summary_safe: {
        data: [
          {
            total_order_count: 1,
            active_order_count: 1,
            completed_order_count: 0,
            rejected_order_count: 0,
            latest_order_created_at: "2026-07-31T00:00:00.000Z",
            latest_order_number: "RSR-TEST",
            latest_order_status_label: "Supplier confirmed your order",
            latest_total_payable_amount: 250,
            currency_code: "GHS"
          }
        ]
      }
    });

    const historyResult = await listCustomerOrdersSafeWithClient(client, { group: "active", search: "QA" });
    const summaryResult = await getCustomerOrderSummarySafeWithClient(client);

    expect(historyResult.state).toMatchObject({ code: "OK" });
    expect(historyResult.orders[0]).toMatchObject({
      orderNumber: "RSR-TEST",
      orderStatusGroup: "active",
      productName: "QA Product",
      totalPayableAmount: 250,
      paymentMethodLabel: "Pay on Delivery"
    });
    expect(summaryResult.summary).toMatchObject({
      totalOrderCount: 1,
      activeOrderCount: 1,
      latestOrderNumber: "RSR-TEST"
    });
    expect(calls.map((call) => call.name)).toEqual(["list_customer_orders_safe", "get_customer_order_summary_safe"]);
    expect(JSON.stringify(calls)).not.toMatch(/customer_id|supplier_id|reseller_id|service_role/i);
  });

  it("keeps internal commercial fields out of the typed history return shape", () => {
    const allowedKeys = new Set<keyof CustomerOrderHistoryItem>([
      "orderId",
      "orderNumber",
      "createdAt",
      "updatedAt",
      "orderStatusLabel",
      "orderStatusGroup",
      "completedAt",
      "rejectedAt",
      "productName",
      "productSlug",
      "productImageSnapshot",
      "quantity",
      "finalCustomerPriceAmount",
      "lineTotalAmount",
      "totalPayableAmount",
      "currencyCode",
      "paymentMethodLabel",
      "paymentCollectionLabel",
      "deliveryStatusLabel",
      "resellerShopName",
      "resellerShopSlug",
      "detailHref"
    ]);

    for (const forbiddenField of [
      "customerId",
      "supplierId",
      "resellerId",
      "supplierBasePriceSnapshotAmount",
      "platformMarginSnapshotAmount",
      "resellerMarginSnapshotAmount",
      "settlementDueAmount",
      "commissionAmount",
      "riskLevel",
      "adminNotes",
      "paymentProviderReference",
      "reservationCount"
    ]) {
      expect(allowedKeys.has(forbiddenField as keyof CustomerOrderHistoryItem)).toBe(false);
    }
  });

  it("keeps customer order history customer-only in route policy", () => {
    expect(canAccessRoute("/customer/orders", getVerifiedRouteAccessProfile({ primaryRole: "customer" }))).toBe(true);
    expect(canAccessRoute("/customer/orders", getVerifiedRouteAccessProfile({ primaryRole: "reseller" }))).toBe(false);
    expect(canAccessRoute("/customer/orders", getVerifiedRouteAccessProfile({ primaryRole: "supplier_owner" }))).toBe(false);
    expect(canAccessRoute("/customer/orders", getVerifiedRouteAccessProfile({ primaryRole: "customer", hasActiveAdminStaff: true }))).toBe(false);
  });

  it("does not add order mutation, payment, delivery mutation, or service-role integration", () => {
    const sources = [
      "app/customer/orders/page.tsx",
      "components/customer/customer-order-history-rpc-screen.tsx",
      "lib/orders/customer-order-history.ts"
    ].map(readSourceTree).join("\n");

    expect(sources).toContain("list_customer_orders_safe");
    expect(sources).toContain("get_customer_order_summary_safe");
    expect(sources).not.toContain("insert(");
    expect(sources).not.toContain("update(");
    expect(sources).not.toContain("delete(");
    expect(sources).not.toMatch(/create_order_from_checkout_draft|confirm_checkout|stock_reservations|delivery_quotes|payment_provider|create_payment|refund_requests|commissions|settlements|withdrawals/i);
    expect(sources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(sources).not.toContain("createSupabaseAdminClient");
  });
});
