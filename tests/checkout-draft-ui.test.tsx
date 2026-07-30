import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { CheckoutDraftReviewScreen } from "@/components/customer/checkout-draft-rpc-screens";
import {
  abandonCheckoutDraftWithClient,
  buildCheckoutDraftContactAddressPayload,
  buildCheckoutDraftCreatePayload,
  createCheckoutDraftFromListingWithClient,
  getCheckoutDraftWithClient,
  mapCheckoutDraftRpcError,
  updateCheckoutDraftContactAddressWithClient,
  type CheckoutDraftRpcClient
} from "@/lib/checkout/draft";
import { canAccessRoute, getVerifiedRouteAccessProfile } from "@/lib/auth/route-guards";

vi.mock("server-only", () => ({}));

function createRpcSpyClient(response: { data?: unknown; error?: { code?: string; message?: string; details?: string } | null } = {}) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: CheckoutDraftRpcClient = {
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

describe("Checkout Phase B draft UI integration", () => {
  it("validates trusted listing id and quantity before creating a draft", () => {
    expect(() => buildCheckoutDraftCreatePayload({ listingId: "", quantity: 1 })).toThrow("Listing id is required");
    expect(() => buildCheckoutDraftCreatePayload({ listingId: "not-a-uuid", quantity: 1 })).toThrow("Listing id is required");
    expect(() =>
      buildCheckoutDraftCreatePayload({
        listingId: "11111111-1111-4111-8111-111111111111",
        quantity: 0
      })
    ).toThrow("Quantity must be between 1 and 20");
  });

  it("calls create_checkout_draft_from_listing with listing id and server-safe quantity only", async () => {
    const { calls, client } = createRpcSpyClient({
      data: [
        {
          draft_id: "22222222-2222-4222-8222-222222222222",
          draft_status: "draft",
          customer_id: "33333333-3333-4333-8333-333333333333",
          reseller_product_id: "11111111-1111-4111-8111-111111111111",
          product_id: "44444444-4444-4444-8444-444444444444",
          product_name: "QA Product",
          quantity: 1,
          final_customer_price_amount: 90,
          line_total_amount: 90,
          currency_code: "GHS"
        }
      ]
    });

    const result = await createCheckoutDraftFromListingWithClient(client, {
      listingId: "11111111-1111-4111-8111-111111111111",
      quantity: "1"
    });

    expect(result.state).toMatchObject({ code: "OK" });
    expect(result.draft).toMatchObject({
      draftId: "22222222-2222-4222-8222-222222222222",
      resellerProductId: "11111111-1111-4111-8111-111111111111",
      finalCustomerPriceAmount: 90
    });
    expect(calls).toEqual([
      {
        name: "create_checkout_draft_from_listing",
        args: {
          p_listing_id: "11111111-1111-4111-8111-111111111111",
          p_quantity: 1
        }
      }
    ]);
    expect(calls[0].args).not.toHaveProperty("final_customer_price_amount");
    expect(calls[0].args).not.toHaveProperty("base_price_amount");
    expect(calls[0].args).not.toHaveProperty("reseller_margin_amount");
  });

  it("calls draft review, contact/address update, and abandon RPCs only", async () => {
    const { calls, client } = createRpcSpyClient({
      data: [{ draft_id: "22222222-2222-4222-8222-222222222222", draft_status: "review_pending" }]
    });

    await getCheckoutDraftWithClient(client, "22222222-2222-4222-8222-222222222222");
    await updateCheckoutDraftContactAddressWithClient(client, {
      draftId: "22222222-2222-4222-8222-222222222222",
      addressId: "55555555-5555-4555-8555-555555555555",
      contactPhone: "0200000000"
    });
    await abandonCheckoutDraftWithClient(client, "22222222-2222-4222-8222-222222222222");

    expect(calls.map((call) => call.name)).toEqual([
      "get_checkout_draft",
      "update_checkout_draft_contact_address",
      "abandon_checkout_draft"
    ]);
  });

  it("requires own saved address data for draft review payload", () => {
    expect(() =>
      buildCheckoutDraftContactAddressPayload({
        draftId: "22222222-2222-4222-8222-222222222222",
        addressId: ""
      })
    ).toThrow("Address id is required");
  });

  it("shows the existing order link instead of confirmation form for converted drafts", () => {
    render(
      <CheckoutDraftReviewScreen
        addresses={[]}
        draft={{
          draftId: "22222222-2222-4222-8222-222222222222",
          draftStatus: "converted",
          customerId: "33333333-3333-4333-8333-333333333333",
          resellerProductId: "11111111-1111-4111-8111-111111111111",
          productId: "44444444-4444-4444-8444-444444444444",
          productName: "QA Product",
          productSlug: "qa-product",
          productImageSnapshot: {},
          quantity: 1,
          finalCustomerPriceAmount: 90,
          lineTotalAmount: 90,
          currencyCode: "GHS",
          deliveryAddressId: "55555555-5555-4555-8555-555555555555",
          customerContactSnapshot: {},
          deliveryAddressSnapshot: {},
          publicListingSnapshot: {},
          convertedOrderId: "66666666-6666-4666-8666-666666666666",
          abandonedAt: null,
          createdAt: "2026-07-30T00:00:00.000Z",
          updatedAt: "2026-07-30T00:00:00.000Z"
        }}
        error={null}
      />
    );

    expect(screen.getByRole("link", { name: "View order" })).toHaveAttribute("href", "/customer/orders/66666666-6666-4666-8666-666666666666");
    expect(screen.queryByRole("button", { name: /place pay on delivery order/i })).not.toBeInTheDocument();
  });

  it("maps auth, listing, ownership, and abandoned draft errors safely", () => {
    expect(mapCheckoutDraftRpcError({ message: "AUTH_REQUIRED" })).toMatchObject({ code: "AUTH_REQUIRED" });
    expect(mapCheckoutDraftRpcError({ message: "CHECKOUT_LISTING_NOT_AVAILABLE" })).toMatchObject({ code: "CHECKOUT_LISTING_NOT_AVAILABLE" });
    expect(mapCheckoutDraftRpcError({ message: "CHECKOUT_DRAFT_NOT_FOUND" })).toMatchObject({ code: "CHECKOUT_DRAFT_NOT_FOUND" });
    expect(mapCheckoutDraftRpcError({ message: "CUSTOMER_ADDRESS_NOT_FOUND" })).toMatchObject({ code: "CUSTOMER_ADDRESS_NOT_FOUND" });
    expect(mapCheckoutDraftRpcError({ message: "CHECKOUT_DRAFT_NOT_ACTIVE" })).toMatchObject({ code: "CHECKOUT_DRAFT_NOT_ACTIVE" });
  });

  it("protects checkout draft route for customers only", () => {
    expect(canAccessRoute("/checkout/draft/22222222-2222-4222-8222-222222222222", getVerifiedRouteAccessProfile({ primaryRole: "customer" }))).toBe(true);
    expect(canAccessRoute("/checkout/draft/22222222-2222-4222-8222-222222222222", getVerifiedRouteAccessProfile({ primaryRole: "reseller" }))).toBe(false);
    expect(canAccessRoute("/checkout/draft/22222222-2222-4222-8222-222222222222", getVerifiedRouteAccessProfile({ primaryRole: "supplier_owner" }))).toBe(false);
    expect(canAccessRoute("/checkout/draft/22222222-2222-4222-8222-222222222222", getVerifiedRouteAccessProfile({ primaryRole: "customer", hasActiveAdminStaff: true }))).toBe(false);
  });

  it("keeps final checkout, orders, stock, payment, delivery, and service role out of draft UI", () => {
    const checkoutDraftSources = [
      "app/checkout/draft",
      "components/customer/checkout-draft-action-forms.tsx",
      "components/customer/checkout-draft-rpc-screens.tsx",
      "components/customer/checkout-order-confirmation-form.tsx",
      "lib/checkout/draft.ts",
      "lib/orders/confirm-checkout-order.ts",
      "app/shop/[shopSlug]/product/[productId]/page.tsx"
    ].map(readSourceTree).join("\n");

    expect(checkoutDraftSources).toContain("create_checkout_draft_from_listing");
    expect(checkoutDraftSources).toContain("get_checkout_draft");
    expect(checkoutDraftSources).toContain("update_checkout_draft_contact_address");
    expect(checkoutDraftSources).toContain("abandon_checkout_draft");
    expect(checkoutDraftSources).toContain("create_order_from_checkout_draft");
    expect(checkoutDraftSources).toContain("attachCheckoutDraftAddressFormAction");
    expect(checkoutDraftSources).toContain("abandonCheckoutDraftFormAction");
    expect(checkoutDraftSources).toContain("Place Pay on Delivery Order");
    expect(checkoutDraftSources).not.toContain("Place order");
    expect(checkoutDraftSources).not.toContain("order_items");
    expect(checkoutDraftSources).not.toContain("reserve_stock");
    expect(checkoutDraftSources).not.toContain("delivery_quotes");
    expect(checkoutDraftSources).not.toContain("prepare_supplier_for_order");
    expect(checkoutDraftSources).not.toContain("create_payment");
    expect(checkoutDraftSources).not.toContain("commission");
    expect(checkoutDraftSources).not.toContain("settlement");
    expect(checkoutDraftSources).not.toContain("withdrawal");
    expect(checkoutDraftSources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(checkoutDraftSources).not.toContain("createSupabaseAdminClient");
  });
});
