import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it, vi } from "vitest";
import { canAccessRoute, getVerifiedRouteAccessProfile } from "@/lib/auth/route-guards";
import {
  buildCustomerOrderSafeReadPayload,
  getCustomerOrderSafeWithClient,
  mapCustomerOrderReadRpcError,
  type CustomerOrderReadRpcClient,
  type CustomerOrderSafe
} from "@/lib/orders/customer-order-read";

vi.mock("server-only", () => ({}));

function createRpcSpyClient(response: { data?: unknown; error?: { code?: string; message?: string; details?: string } | null } = {}) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: CustomerOrderReadRpcClient = {
    async rpc<T = unknown>(name: string, args?: Record<string, unknown>) {
      calls.push({ name, args });
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

describe("Checkout Phase C C5 customer order read boundary", () => {
  it("builds a safe order-read payload with order id only", () => {
    expect(buildCustomerOrderSafeReadPayload("11111111-1111-4111-8111-111111111111")).toEqual({
      p_order_id: "11111111-1111-4111-8111-111111111111"
    });
    expect(() => buildCustomerOrderSafeReadPayload("not-an-id")).toThrow("Order id is required");
  });

  it("calls only the customer-safe order read RPC", async () => {
    const { calls, client } = createRpcSpyClient({
      data: [
        {
          order_id: "11111111-1111-4111-8111-111111111111",
          order_number: "RSR-TEST",
          created_at: "2026-07-30T00:00:00.000Z",
          updated_at: "2026-07-30T00:00:00.000Z",
          order_status_label: "Placed - waiting for supplier confirmation",
          customer_confirmation_label: "Customer confirmation pending",
          payment_method_label: "Pay on Delivery",
          payment_collection_label: "Payment not collected",
          delivery_status_label: "Delivery not arranged yet",
          delivery_quote_label: "Delivery fee not confirmed",
          product_name: "QA Product",
          product_slug: "qa-product",
          product_image_snapshot: { image_count: 1 },
          quantity: 1,
          final_customer_price_amount: 125,
          line_total_amount: 125,
          total_payable_amount: 125,
          currency_code: "GHS",
          customer_contact_snapshot: { phone: "masked" },
          delivery_address_snapshot: { city: "Accra", area: "QA Area" },
          reseller_shop_name: "QA Shop",
          reseller_shop_slug: "qa-shop",
          reservation_status_label: "Stock reserved for this order"
        }
      ]
    });

    const result = await getCustomerOrderSafeWithClient(client, "11111111-1111-4111-8111-111111111111");

    expect(result.state).toMatchObject({ code: "OK" });
    expect(result.order).toMatchObject({
      orderNumber: "RSR-TEST",
      productName: "QA Product",
      paymentMethodLabel: "Pay on Delivery",
      paymentCollectionLabel: "Payment not collected",
      reservationStatusLabel: "Stock reserved for this order"
    });
    expect(calls).toEqual([
      {
        name: "get_customer_order_safe",
        args: {
          p_order_id: "11111111-1111-4111-8111-111111111111"
        }
      }
    ]);
    expect(calls[0].args).not.toHaveProperty("customer_id");
    expect(calls[0].args).not.toHaveProperty("product_id");
    expect(calls[0].args).not.toHaveProperty("price");
  });

  it("normalizes missing or unauthorized orders without enumeration", async () => {
    const { client } = createRpcSpyClient({ data: [] });
    const result = await getCustomerOrderSafeWithClient(client, "11111111-1111-4111-8111-111111111111");

    expect(result.order).toBeNull();
    expect(result.state).toMatchObject({ code: "ORDER_NOT_FOUND" });
  });

  it("maps auth, validation, and permission errors safely", () => {
    expect(mapCustomerOrderReadRpcError({ message: "AUTH_REQUIRED" })).toMatchObject({ code: "AUTH_REQUIRED" });
    expect(mapCustomerOrderReadRpcError(new Error("Order id is required"))).toMatchObject({ code: "VALIDATION_ERROR" });
    expect(mapCustomerOrderReadRpcError({ code: "42501", message: "permission denied" })).toMatchObject({ code: "RPC_PERMISSION_DENIED" });
  });

  it("excludes internal commercial and operational fields from the typed customer return shape", () => {
    const allowedKeys = new Set<keyof CustomerOrderSafe>([
      "orderId",
      "orderNumber",
      "createdAt",
      "updatedAt",
      "orderStatusLabel",
      "customerConfirmationLabel",
      "paymentMethodLabel",
      "paymentCollectionLabel",
      "deliveryStatusLabel",
      "deliveryQuoteLabel",
      "productName",
      "productSlug",
      "productImageSnapshot",
      "quantity",
      "finalCustomerPriceAmount",
      "lineTotalAmount",
      "totalPayableAmount",
      "currencyCode",
      "customerContactSnapshot",
      "deliveryAddressSnapshot",
      "resellerShopName",
      "resellerShopSlug",
      "reservationStatusLabel",
      "reservationExpiresAt"
    ]);

    for (const forbiddenField of [
      "customerId",
      "resellerId",
      "supplierId",
      "supplierBasePriceSnapshotAmount",
      "platformMarginSnapshotAmount",
      "resellerMarginSnapshotAmount",
      "resellerCostSnapshotAmount",
      "settlementDueAmount",
      "commissionAmount",
      "riskLevel",
      "adminNotes",
      "paymentProviderReference"
    ]) {
      expect(allowedKeys.has(forbiddenField as keyof CustomerOrderSafe)).toBe(false);
    }
  });

  it("keeps customer order routes customer-only in route policy", () => {
    expect(canAccessRoute("/customer/orders/11111111-1111-4111-8111-111111111111", getVerifiedRouteAccessProfile({ primaryRole: "customer" }))).toBe(true);
    expect(canAccessRoute("/customer/orders/11111111-1111-4111-8111-111111111111", getVerifiedRouteAccessProfile({ primaryRole: "reseller" }))).toBe(false);
    expect(canAccessRoute("/customer/orders/11111111-1111-4111-8111-111111111111", getVerifiedRouteAccessProfile({ primaryRole: "supplier_owner" }))).toBe(false);
    expect(canAccessRoute("/customer/orders/11111111-1111-4111-8111-111111111111", getVerifiedRouteAccessProfile({ primaryRole: "customer", hasActiveAdminStaff: true }))).toBe(false);
  });

  it("keeps final confirmation, payment, delivery, preparation, and finance implementation out of customer order read sources", () => {
    const sources = [
      "lib/orders/customer-order-read.ts",
      "app/checkout/draft",
      "components/customer/checkout-draft-rpc-screens.tsx",
      "components/customer/checkout-draft-action-forms.tsx"
    ].map(readSourceTree).join("\n");

    expect(sources).toContain("get_customer_order_safe");
    expect(sources).not.toContain("Place order");
    expect(sources).not.toContain("create_order_from_checkout_draft(");
    expect(sources).not.toContain("insert(");
    expect(sources).not.toContain("update(");
    expect(sources).not.toContain("delivery_quotes");
    expect(sources).not.toContain("create_payment");
    expect(sources).not.toContain("commission");
    expect(sources).not.toContain("settlement");
    expect(sources).not.toContain("withdrawal");
    expect(sources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(sources).not.toContain("createSupabaseAdminClient");
  });
});
