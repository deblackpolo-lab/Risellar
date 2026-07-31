import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { canAccessRoute, getVerifiedRouteAccessProfile } from "@/lib/auth/route-guards";
import {
  acceptSupplierOrderWithClient,
  buildAcceptSupplierOrderPayload,
  buildListSupplierOrdersSafePayload,
  buildMarkReadyForDeliverySupplierOrderPayload,
  buildRejectSupplierOrderPayload,
  buildStartPreparingSupplierOrderPayload,
  buildSupplierOrderDetailPayload,
  listSupplierOrdersSafeWithClient,
  markReadyForDeliverySupplierOrderWithClient,
  mapSupplierOrderRpcError,
  rejectSupplierOrderWithClient,
  startPreparingSupplierOrderWithClient,
  type SupplierOrderRpcClient,
  type SupplierOrderSafe
} from "@/lib/orders/supplier-order-read";
import {
  SupplierOrderDetailRpcScreen,
  SupplierOrdersRpcScreen
} from "@/components/supplier/supplier-order-rpc-screens";

vi.mock("server-only", () => ({}));

function createRpcSpyClient(response: { data?: unknown; error?: { code?: string; message?: string; details?: string } | null } = {}) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: SupplierOrderRpcClient = {
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

const pendingOrder: SupplierOrderSafe = {
  orderId: "11111111-1111-4111-8111-111111111111",
  orderNumber: "RSR-SUP-001",
  createdAt: "2026-07-30T12:00:00.000Z",
  updatedAt: "2026-07-30T12:05:00.000Z",
  orderStatus: "placed_pending_confirmation",
  orderStatusLabel: "New order - confirm or reject",
  isSupplierActionable: true,
  productName: "QA Supplier Product",
  productSlug: "qa-supplier-product",
  productImageSnapshot: { primary_alt: "QA image" },
  variantSku: "QA-SKU",
  variantName: "Default",
  quantity: 2,
  supplierAmountExpected: 80,
  customerTotalAmount: 120,
  currencyCode: "GHS",
  paymentMethodLabel: "Pay on Delivery",
  paymentStatusLabel: "Payment not collected",
  deliveryStatusLabel: "Delivery not arranged yet",
  reservationStatusLabel: "Stock reserved",
  reservationExpiresAt: "2026-07-31T12:00:00.000Z",
  reservationQuantity: 2,
  recipientName: "QA Recipient",
  recipientPhone: "Masked phone",
  recipientWhatsapp: "Masked WhatsApp",
  deliveryAddressSnapshot: { region: "Greater Accra", city: "Accra", area: "QA Area", landmark: "QA Landmark" },
  resellerShopName: "QA Reseller Shop",
  resellerShopSlug: "qa-reseller-shop"
};

describe("Supplier Order Handling S6 UI integration", () => {
  it("builds safe supplier order list/detail payloads without supplier identifiers or commercial browser input", () => {
    expect(buildListSupplierOrdersSafePayload({ status: "placed_pending_confirmation", limit: 20 })).toEqual({
      p_status: "placed_pending_confirmation",
      p_limit: 20,
      p_cursor_created_at: null,
      p_cursor_order_id: null
    });
    expect(buildSupplierOrderDetailPayload("11111111-1111-4111-8111-111111111111")).toEqual({
      p_order_id: "11111111-1111-4111-8111-111111111111"
    });
    expect(() => buildSupplierOrderDetailPayload("bad-id")).toThrow("Order id is required");
  });

  it("calls only supplier-safe read RPCs and maps safe fields", async () => {
    const { calls, client } = createRpcSpyClient({
      data: [
        {
          order_id: pendingOrder.orderId,
          order_number: pendingOrder.orderNumber,
          created_at: pendingOrder.createdAt,
          updated_at: pendingOrder.updatedAt,
          order_status: pendingOrder.orderStatus,
          order_status_label: pendingOrder.orderStatusLabel,
          is_supplier_actionable: true,
          product_name: pendingOrder.productName,
          product_slug: pendingOrder.productSlug,
          product_image_snapshot: pendingOrder.productImageSnapshot,
          quantity: pendingOrder.quantity,
          supplier_amount_expected: pendingOrder.supplierAmountExpected,
          currency_code: pendingOrder.currencyCode,
          payment_method_label: pendingOrder.paymentMethodLabel,
          payment_status_label: pendingOrder.paymentStatusLabel,
          reservation_status_label: pendingOrder.reservationStatusLabel,
          reservation_expires_at: pendingOrder.reservationExpiresAt,
          recipient_name: pendingOrder.recipientName,
          location_summary: "Greater Accra, Accra, QA Area",
          reseller_shop_name: pendingOrder.resellerShopName
        }
      ]
    });

    const result = await listSupplierOrdersSafeWithClient(client, { status: "placed_pending_confirmation" });

    expect(result.state).toMatchObject({ code: "OK" });
    expect(result.orders[0]).toMatchObject({
      orderNumber: "RSR-SUP-001",
      productName: "QA Supplier Product",
      paymentStatusLabel: "Payment not collected",
      supplierAmountExpected: 80
    });
    expect(calls).toEqual([
      {
        name: "list_supplier_orders_safe",
        args: {
          p_status: "placed_pending_confirmation",
          p_limit: 50,
          p_cursor_created_at: null,
          p_cursor_order_id: null
        }
      }
    ]);
    expect(calls[0].args).not.toHaveProperty("supplier_id");
    expect(calls[0].args).not.toHaveProperty("price");
    expect(calls[0].args).not.toHaveProperty("stock");
  });

  it("calls accept/reject/start-preparing RPCs with stable idempotency keys and no untrusted business fields", async () => {
    const { calls, client } = createRpcSpyClient({ data: [{ order_id: pendingOrder.orderId, order_number: pendingOrder.orderNumber }] });

    await acceptSupplierOrderWithClient(client, {
      orderId: pendingOrder.orderId,
      idempotencyKey: `supplier-accept:${pendingOrder.orderId}`
    });
    await rejectSupplierOrderWithClient(client, {
      orderId: pendingOrder.orderId,
      reasonCode: "out_of_stock",
      reasonNote: "Development-only note",
      idempotencyKey: `supplier-reject:${pendingOrder.orderId}`
    });
    await startPreparingSupplierOrderWithClient(client, {
      orderId: pendingOrder.orderId,
      idempotencyKey: `supplier-start-preparing:${pendingOrder.orderId}`
    });
    await markReadyForDeliverySupplierOrderWithClient(client, {
      orderId: pendingOrder.orderId,
      idempotencyKey: `supplier-ready-for-delivery:${pendingOrder.orderId}`
    });

    expect(calls).toEqual([
      {
        name: "supplier_accept_order",
        args: buildAcceptSupplierOrderPayload({
          orderId: pendingOrder.orderId,
          idempotencyKey: `supplier-accept:${pendingOrder.orderId}`
        })
      },
      {
        name: "supplier_reject_order",
        args: buildRejectSupplierOrderPayload({
          orderId: pendingOrder.orderId,
          reasonCode: "out_of_stock",
          reasonNote: "Development-only note",
          idempotencyKey: `supplier-reject:${pendingOrder.orderId}`
        })
      },
      {
        name: "supplier_start_preparing",
        args: buildStartPreparingSupplierOrderPayload({
          orderId: pendingOrder.orderId,
          idempotencyKey: `supplier-start-preparing:${pendingOrder.orderId}`
        })
      },
      {
        name: "supplier_mark_ready_for_delivery",
        args: buildMarkReadyForDeliverySupplierOrderPayload({
          orderId: pendingOrder.orderId,
          idempotencyKey: `supplier-ready-for-delivery:${pendingOrder.orderId}`
        })
      }
    ]);

    for (const call of calls) {
      expect(call.args).not.toHaveProperty("p_supplier_id");
      expect(call.args).not.toHaveProperty("p_status");
      expect(call.args).not.toHaveProperty("p_price");
      expect(call.args).not.toHaveProperty("p_stock");
      expect(call.args).not.toHaveProperty("p_quantity");
    }
  });

  it("requires valid rejection reasons and bounded notes", () => {
    expect(() => buildRejectSupplierOrderPayload({ orderId: pendingOrder.orderId, reasonCode: "" })).toThrow("Rejection reason is required");
    expect(() => buildRejectSupplierOrderPayload({ orderId: pendingOrder.orderId, reasonCode: "admin_override" })).toThrow("Choose a valid rejection reason");
    expect(() => buildRejectSupplierOrderPayload({ orderId: pendingOrder.orderId, reasonCode: "other", reasonNote: "x".repeat(501) })).toThrow("Rejection note is too long");
  });

  it("maps supplier action and read errors safely", () => {
    expect(mapSupplierOrderRpcError({ message: "AUTH_REQUIRED" })).toMatchObject({ code: "AUTH_REQUIRED", message: "Sign in to manage this order." });
    expect(mapSupplierOrderRpcError({ message: "SUPPLIER_REQUIRED" })).toMatchObject({ code: "SUPPLIER_REQUIRED" });
    expect(mapSupplierOrderRpcError({ message: "ORDER_NOT_OWNED" })).toMatchObject({ code: "ORDER_NOT_FOUND", message: "This order is unavailable." });
    expect(mapSupplierOrderRpcError({ message: "ORDER_NOT_ACTIONABLE" })).toMatchObject({ code: "ORDER_NOT_ACTIONABLE" });
    expect(mapSupplierOrderRpcError({ message: "ORDER_NOT_CONFIRMED" })).toMatchObject({ code: "ORDER_NOT_CONFIRMED" });
    expect(mapSupplierOrderRpcError({ message: "ORDER_NOT_PREPARING" })).toMatchObject({ code: "ORDER_NOT_PREPARING" });
    expect(mapSupplierOrderRpcError({ message: "RESERVATION_EXPIRED" })).toMatchObject({ code: "RESERVATION_EXPIRED" });
    expect(mapSupplierOrderRpcError({ message: "ALREADY_CONFIRMED" })).toMatchObject({ code: "ALREADY_CONFIRMED" });
    expect(mapSupplierOrderRpcError({ message: "ALREADY_REJECTED" })).toMatchObject({ code: "ALREADY_REJECTED" });
    expect(mapSupplierOrderRpcError({ message: "ALREADY_PREPARING" })).toMatchObject({ code: "ALREADY_PREPARING" });
    expect(mapSupplierOrderRpcError({ message: "ALREADY_READY" })).toMatchObject({ code: "ALREADY_READY" });
    expect(mapSupplierOrderRpcError({ message: "PREPARATION_NOT_STARTED" })).toMatchObject({ code: "PREPARATION_NOT_STARTED" });
    expect(mapSupplierOrderRpcError({ message: "INVALID_REJECTION_REASON" })).toMatchObject({ code: "INVALID_REJECTION_REASON" });
    expect(mapSupplierOrderRpcError({ message: "REJECTION_NOTE_TOO_LONG" })).toMatchObject({ code: "REJECTION_NOTE_TOO_LONG" });
    expect(mapSupplierOrderRpcError({ message: "network failed" })).toMatchObject({ code: "UNKNOWN", message: /Refresh the order/ });
  });

  it("renders list and detail with safe operational fields and hides internal/private fields", () => {
    render(<SupplierOrdersRpcScreen error={null} orders={[pendingOrder]} />);

    expect(screen.getByRole("heading", { name: "Supplier orders" })).toBeInTheDocument();
    expect(screen.getByText("RSR-SUP-001")).toBeInTheDocument();
    expect(screen.getByText("QA Supplier Product")).toBeInTheDocument();
    expect(screen.getByText("Payment not collected")).toBeInTheDocument();
    expect(screen.getByText(/QA Recipient/)).toBeInTheDocument();

    const { rerender } = render(<SupplierOrderDetailRpcScreen actionState={{ code: "OK", message: "" }} order={pendingOrder} />);
    expect(screen.getByRole("heading", { name: "RSR-SUP-001" })).toBeInTheDocument();
    expect(screen.getByText(/Stock is already reserved. Accept only if you can fulfil this order/i)).toBeInTheDocument();
    expect(screen.getByText("Confirm that you can fulfil this order. Stock is already reserved.")).toBeInTheDocument();
    expect(screen.getByText(/The customer will not be charged/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Accept order" })).toBeDisabled();
    fireEvent.click(screen.getByRole("checkbox", { name: /Confirm that you can fulfil this order/i }));
    expect(screen.getByRole("button", { name: "Accept order" })).toBeEnabled();
    expect(screen.getByRole("button", { name: "Reject order" })).toBeDisabled();

    rerender(
      <SupplierOrderDetailRpcScreen
        actionState={{ code: "OK", message: "" }}
        order={{ ...pendingOrder, orderStatus: "supplier_confirmed", orderStatusLabel: "Supplier confirmed", isSupplierActionable: false }}
        startPreparingAction={vi.fn()}
      />
    );
    expect(screen.queryByRole("button", { name: "Accept order" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Reject order" })).not.toBeInTheDocument();
    expect(screen.getByText("Start preparing this order only when you are ready to begin fulfilment. Delivery and payment are handled later.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Start preparing" })).toBeDisabled();
    fireEvent.click(screen.getByRole("checkbox", { name: /Confirm that you are starting preparation/i }));
    expect(screen.getByRole("button", { name: "Start preparing" })).toBeEnabled();

    rerender(
      <SupplierOrderDetailRpcScreen
        actionState={{ code: "OK", message: "Order preparation started" }}
        order={{ ...pendingOrder, orderStatus: "supplier_preparing", orderStatusLabel: "Preparing order", isSupplierActionable: false }}
        markReadyForDeliveryAction={vi.fn()}
        startPreparingAction={vi.fn()}
      />
    );
    expect(screen.getByText("Order preparation started")).toBeInTheDocument();
    expect(screen.getByText("Mark this order ready only when preparation is complete. Delivery arrangements will be handled separately.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Mark ready for delivery" })).toBeDisabled();
    fireEvent.click(screen.getByRole("checkbox", { name: /ready for delivery arrangement/i }));
    expect(screen.getByRole("button", { name: "Mark ready for delivery" })).toBeEnabled();
    expect(screen.queryByRole("button", { name: "Start preparing" })).not.toBeInTheDocument();

    rerender(
      <SupplierOrderDetailRpcScreen
        actionState={{ code: "OK", message: "Order is ready for delivery" }}
        order={{ ...pendingOrder, orderStatus: "ready_for_delivery", orderStatusLabel: "Ready for delivery", isSupplierActionable: false }}
        markReadyForDeliveryAction={vi.fn()}
      />
    );
    expect(screen.getByText("Order is ready for delivery")).toBeInTheDocument();
    expect(screen.getByText("This order is prepared and waiting for delivery arrangement. No rider or delivery fee has been confirmed yet.")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Mark ready for delivery" })).not.toBeInTheDocument();

    expect(document.body.innerHTML).not.toMatch(/customer email|reseller margin|platform margin|commission|settlement|risk|raw stock/i);
  });

  it("keeps supplier routes supplier-only and excludes payment, delivery, preparation, finance, service-role, and direct table mutation code", () => {
    expect(canAccessRoute("/supplier/orders", getVerifiedRouteAccessProfile({ primaryRole: "supplier_owner" }))).toBe(true);
    expect(canAccessRoute("/supplier/orders/11111111-1111-4111-8111-111111111111", getVerifiedRouteAccessProfile({ primaryRole: "supplier_owner" }))).toBe(true);
    expect(canAccessRoute("/supplier/orders", getVerifiedRouteAccessProfile({ primaryRole: "customer" }))).toBe(false);
    expect(canAccessRoute("/supplier/orders", getVerifiedRouteAccessProfile({ primaryRole: "reseller" }))).toBe(false);
    expect(canAccessRoute("/supplier/orders", getVerifiedRouteAccessProfile({ primaryRole: "customer", hasActiveAdminStaff: true }))).toBe(false);

    const sources = [
      "app/supplier/orders",
      "components/supplier/supplier-order-rpc-screens.tsx",
      "lib/orders/supplier-order-read.ts"
    ].map(readSourceTree).join("\n");

    expect(sources).toContain("list_supplier_orders_safe");
    expect(sources).toContain("get_supplier_order_safe");
    expect(sources).toContain("supplier_accept_order");
    expect(sources).toContain("supplier_reject_order");
    expect(sources).toContain("supplier_start_preparing");
    expect(sources).toContain("supplier_mark_ready_for_delivery");
    expect(sources).not.toContain("create_payment");
    expect(sources).not.toContain("delivery_quotes");
    expect(sources).not.toContain("prepare_supplier_for_order");
    expect(sources).not.toContain("commission");
    expect(sources).not.toContain("settlement");
    expect(sources).not.toContain("withdrawal");
    expect(sources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(sources).not.toContain("createSupabaseAdminClient");
    expect(sources).not.toContain(".from(\"orders\").update");
    expect(sources).not.toContain(".from(\"stock_reservations\").update");
  });
});
