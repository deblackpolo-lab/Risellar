import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { CheckoutOrderConfirmationForm } from "@/components/customer/checkout-order-confirmation-form";
import {
  buildCheckoutOrderConfirmationPayload,
  confirmCheckoutDraftOrderWithClient,
  mapCheckoutOrderConfirmationRpcError,
  type CheckoutOrderConfirmationRpcClient
} from "@/lib/orders/confirm-checkout-order";

vi.mock("server-only", () => ({}));

function createRpcSpyClient(response: { data?: unknown; error?: { code?: string; message?: string; details?: string } | null } = {}) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: CheckoutOrderConfirmationRpcClient = {
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

describe("Checkout Phase C C6 order confirmation UI integration", () => {
  it("builds a confirmation payload with draft id and idempotency key only", () => {
    expect(
      buildCheckoutOrderConfirmationPayload({
        checkoutDraftId: "11111111-1111-4111-8111-111111111111",
        idempotencyKey: "checkout-confirm:11111111-1111-4111-8111-111111111111"
      })
    ).toEqual({
      p_checkout_draft_id: "11111111-1111-4111-8111-111111111111",
      p_idempotency_key: "checkout-confirm:11111111-1111-4111-8111-111111111111"
    });

    expect(() => buildCheckoutOrderConfirmationPayload({ checkoutDraftId: "not-a-uuid" })).toThrow("Checkout draft id is required");
  });

  it("calls only create_order_from_checkout_draft for order confirmation", async () => {
    const { calls, client } = createRpcSpyClient({
      data: [
        {
          order_id: "22222222-2222-4222-8222-222222222222",
          order_number: "RSR-20260730-000001",
          checkout_draft_id: "11111111-1111-4111-8111-111111111111",
          order_status: "placed_pending_confirmation",
          payment_method: "pay_on_delivery",
          payment_collection_status: "not_collected",
          delivery_status: "not_arranged",
          customer_confirmation_status: "pending",
          delivery_quote_status: "not_requested",
          product_name: "QA Product",
          quantity: 1,
          final_customer_price_amount: 125,
          line_total_amount: 125,
          total_payable_amount: 125,
          currency_code: "GHS",
          reservation_status: "active"
        }
      ]
    });

    const result = await confirmCheckoutDraftOrderWithClient(client, {
      checkoutDraftId: "11111111-1111-4111-8111-111111111111",
      idempotencyKey: "checkout-confirm:11111111-1111-4111-8111-111111111111"
    });

    expect(result.state).toMatchObject({ code: "OK" });
    expect(result.order).toMatchObject({
      orderId: "22222222-2222-4222-8222-222222222222",
      orderNumber: "RSR-20260730-000001",
      paymentMethodLabel: "Pay on Delivery"
    });
    expect(calls).toEqual([
      {
        name: "create_order_from_checkout_draft",
        args: {
          p_checkout_draft_id: "11111111-1111-4111-8111-111111111111",
          p_idempotency_key: "checkout-confirm:11111111-1111-4111-8111-111111111111"
        }
      }
    ]);
    expect(calls[0].args).not.toHaveProperty("customer_id");
    expect(calls[0].args).not.toHaveProperty("listing_id");
    expect(calls[0].args).not.toHaveProperty("product_id");
    expect(calls[0].args).not.toHaveProperty("price");
    expect(calls[0].args).not.toHaveProperty("quantity");
    expect(calls[0].args).not.toHaveProperty("payment_status");
  });

  it("maps order confirmation errors safely", () => {
    expect(mapCheckoutOrderConfirmationRpcError({ message: "AUTH_REQUIRED" })).toMatchObject({ code: "AUTH_REQUIRED" });
    expect(mapCheckoutOrderConfirmationRpcError({ message: "CHECKOUT_DRAFT_NOT_FOUND" })).toMatchObject({ code: "CHECKOUT_DRAFT_NOT_FOUND" });
    expect(mapCheckoutOrderConfirmationRpcError({ message: "CHECKOUT_DRAFT_NOT_REVIEW_PENDING" })).toMatchObject({ code: "CHECKOUT_DRAFT_NOT_READY" });
    expect(mapCheckoutOrderConfirmationRpcError({ message: "INSUFFICIENT_STOCK" })).toMatchObject({
      code: "INSUFFICIENT_STOCK",
      message: "This product just sold out or has less stock than requested. No order was placed."
    });
    expect(mapCheckoutOrderConfirmationRpcError({ code: "42501", message: "permission denied" })).toMatchObject({ code: "RPC_PERMISSION_DENIED" });
  });

  it("renders the Pay on Delivery acknowledgement form without commercial browser inputs", () => {
    render(
      <CheckoutOrderConfirmationForm
        canConfirm
        checkoutDraftId="11111111-1111-4111-8111-111111111111"
        state={{ code: "OK", message: "" }}
      />
    );

    expect(screen.getByRole("button", { name: /place pay on delivery order/i })).toBeDisabled();
    expect(screen.getByLabelText(/pay on delivery order/i)).toBeInTheDocument();

    const html = document.body.innerHTML;
    expect(html).toContain('name="draft_id"');
    expect(html).toContain('name="idempotency_key"');
    expect(html).toContain('name="acknowledged_order_terms"');
    expect(html).not.toContain('name="quantity"');
    expect(html).not.toContain('name="price"');
    expect(html).not.toContain('name="product_id"');
    expect(html).not.toContain('name="payment_method"');
  });

  it("keeps C6 scoped to confirmation RPC, safe order read, and no payment/delivery/finance implementation", () => {
    const sources = [
      "app/checkout/draft",
      "app/customer/orders",
      "components/customer/checkout-draft-rpc-screens.tsx",
      "components/customer/checkout-draft-action-forms.tsx",
      "components/customer/checkout-order-confirmation-form.tsx",
      "lib/orders/customer-order-read.ts",
      "lib/orders/confirm-checkout-order.ts"
    ].map(readSourceTree).join("\n");

    expect(sources).toContain("create_order_from_checkout_draft");
    expect(sources).toContain("get_customer_order_safe");
    expect(sources).toContain("Place Pay on Delivery Order");
    expect(sources).not.toContain("create_payment");
    expect(sources).not.toContain("delivery_quotes");
    expect(sources).not.toContain("prepare_supplier_for_order");
    expect(sources).not.toContain("commission");
    expect(sources).not.toContain("settlement");
    expect(sources).not.toContain("withdrawal");
    expect(sources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(sources).not.toContain("createSupabaseAdminClient");
  });
});
