import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { canAccessRoute, getVerifiedRouteAccessProfile } from "@/lib/auth/route-guards";
import {
  acceptSupplierOrderWithClient,
  buildAcceptSupplierOrderPayload,
  buildArrangeSupplierOrderDeliveryPayload,
  buildListSupplierOrdersSafePayload,
  buildMarkSupplierOrderOutForDeliveryPayload,
  buildReportSupplierOrderPaymentReceivedPayload,
  buildMarkReadyForDeliverySupplierOrderPayload,
  buildRejectSupplierOrderPayload,
  buildStartPreparingSupplierOrderPayload,
  buildSupplierOrderDetailPayload,
  arrangeSupplierOrderDeliveryWithClient,
  listSupplierOrdersSafeWithClient,
  markSupplierOrderOutForDeliveryWithClient,
  reportSupplierOrderPaymentReceivedWithClient,
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
  resellerShopSlug: "qa-reseller-shop",
  deliveryArrangementMethod: null,
  deliveryArrangementMethodLabel: null,
  deliveryArrangementFeeAmount: null,
  deliveryArrangementCurrencyCode: null,
  deliveryArrangementExpectedDate: null,
  deliveryArrangementTimeWindow: null,
  deliveryArrangementCourierName: null,
  deliveryArrangementCourierPhone: null,
  deliveryArrangementCustomerInstruction: null,
  deliveryArrangementSupplierPrivateNote: null,
  deliveryArrangedAt: null,
  outForDeliveryAt: null,
  dispatchReference: null,
  customerDispatchInstruction: null,
  deliveredAt: null,
  deliveryConfirmationNote: null,
  paymentReportedAt: null,
  paymentReference: null,
  supplierPaymentPrivateNote: null,
  platformAmountDue: null,
  resellerCommissionDue: null,
  settlementStatusLabel: null,
  commissionStatusLabel: null
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
    await reportSupplierOrderPaymentReceivedWithClient(client, {
      orderId: pendingOrder.orderId,
      paymentReference: "QA-PAYMENT-001",
      supplierPrivateNote: "Development-only private payment note",
      idempotencyKey: `supplier-payment-reported:${pendingOrder.orderId}`
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
      },
      {
        name: "supplier_report_order_payment_received",
        args: buildReportSupplierOrderPaymentReceivedPayload({
          orderId: pendingOrder.orderId,
          paymentReference: "QA-PAYMENT-001",
          supplierPrivateNote: "Development-only private payment note",
          idempotencyKey: `supplier-payment-reported:${pendingOrder.orderId}`
        })
      }
    ]);

    for (const call of calls) {
      expect(call.args).not.toHaveProperty("p_supplier_id");
      expect(call.args).not.toHaveProperty("p_status");
      expect(call.args).not.toHaveProperty("p_price");
      expect(call.args).not.toHaveProperty("p_stock");
      expect(call.args).not.toHaveProperty("p_quantity");
      expect(call.args).not.toHaveProperty("p_reported_amount");
      expect(call.args).not.toHaveProperty("p_currency");
      expect(call.args).not.toHaveProperty("p_commission");
      expect(call.args).not.toHaveProperty("p_settlement_status");
    }
  });

  it("calls delivery arrangement RPC with server-resolved supplier, currency, status, stock, and payment fields", async () => {
    const { calls, client } = createRpcSpyClient({ data: [{ order_id: pendingOrder.orderId, order_number: pendingOrder.orderNumber }] });

    await arrangeSupplierOrderDeliveryWithClient(client, {
      orderId: pendingOrder.orderId,
      deliveryMethod: "third_party_courier",
      agreedDeliveryFeeAmount: "25.50",
      expectedDeliveryDate: "2026-08-01",
      expectedTimeWindow: "Morning",
      courierDisplayName: "QA Courier",
      courierPhone: "+233200000000",
      customerInstruction: "Call before arrival",
      supplierPrivateNote: "Private supplier-only QA note",
      idempotencyKey: `supplier-arrange-delivery:${pendingOrder.orderId}`
    });

    expect(calls).toEqual([
      {
        name: "supplier_arrange_order_delivery",
        args: buildArrangeSupplierOrderDeliveryPayload({
          orderId: pendingOrder.orderId,
          deliveryMethod: "third_party_courier",
          agreedDeliveryFeeAmount: "25.50",
          expectedDeliveryDate: "2026-08-01",
          expectedTimeWindow: "Morning",
          courierDisplayName: "QA Courier",
          courierPhone: "+233200000000",
          customerInstruction: "Call before arrival",
          supplierPrivateNote: "Private supplier-only QA note",
          idempotencyKey: `supplier-arrange-delivery:${pendingOrder.orderId}`
        })
      }
    ]);
    expect(calls[0].args).toMatchObject({
      p_order_id: pendingOrder.orderId,
      p_delivery_method: "third_party_courier",
      p_agreed_delivery_fee_amount: 25.5,
      p_expected_delivery_date: "2026-08-01",
      p_expected_time_window: "Morning",
      p_courier_display_name: "QA Courier",
      p_courier_phone: "+233200000000",
      p_customer_instruction: "Call before arrival",
      p_supplier_private_note: "Private supplier-only QA note",
      p_idempotency_key: `supplier-arrange-delivery:${pendingOrder.orderId}`
    });

    for (const forbiddenField of [
      "p_supplier_id",
      "p_customer_id",
      "p_reseller_id",
      "p_product_id",
      "p_variant_id",
      "p_order_status",
      "p_currency",
      "p_stock",
      "p_payment_status",
      "p_total"
    ]) {
      expect(calls[0].args).not.toHaveProperty(forbiddenField);
    }
  });

  it("calls out-for-delivery RPC with server-resolved supplier, status, reservation, stock, and payment fields", async () => {
    const { calls, client } = createRpcSpyClient({ data: [{ order_id: pendingOrder.orderId, order_number: pendingOrder.orderNumber }] });

    await markSupplierOrderOutForDeliveryWithClient(client, {
      orderId: pendingOrder.orderId,
      dispatchReference: "QA-DISPATCH-001",
      customerDispatchInstruction: "Meet the courier at the main gate",
      idempotencyKey: `supplier-out-for-delivery:${pendingOrder.orderId}`
    });

    expect(calls).toEqual([
      {
        name: "supplier_mark_order_out_for_delivery",
        args: buildMarkSupplierOrderOutForDeliveryPayload({
          orderId: pendingOrder.orderId,
          dispatchReference: "QA-DISPATCH-001",
          customerDispatchInstruction: "Meet the courier at the main gate",
          idempotencyKey: `supplier-out-for-delivery:${pendingOrder.orderId}`
        })
      }
    ]);
    expect(calls[0].args).toMatchObject({
      p_order_id: pendingOrder.orderId,
      p_dispatch_reference: "QA-DISPATCH-001",
      p_customer_dispatch_instruction: "Meet the courier at the main gate",
      p_idempotency_key: `supplier-out-for-delivery:${pendingOrder.orderId}`
    });

    for (const forbiddenField of [
      "p_supplier_id",
      "p_customer_id",
      "p_reseller_id",
      "p_product_id",
      "p_variant_id",
      "p_order_status",
      "p_currency",
      "p_stock",
      "p_payment_status",
      "p_total",
      "p_delivered_at",
      "p_payment_collected",
      "p_tracking_url"
    ]) {
      expect(calls[0].args).not.toHaveProperty(forbiddenField);
    }
  });

  it("validates delivery arrangement inputs before calling the RPC", () => {
    expect(() => buildArrangeSupplierOrderDeliveryPayload({ orderId: pendingOrder.orderId, deliveryMethod: "book_uber" })).toThrow("Choose a valid delivery method");
    expect(() => buildArrangeSupplierOrderDeliveryPayload({ orderId: pendingOrder.orderId, deliveryMethod: "supplier_rider", agreedDeliveryFeeAmount: "-1" })).toThrow("Delivery fee must be zero or greater");
    expect(() => buildArrangeSupplierOrderDeliveryPayload({ orderId: pendingOrder.orderId, deliveryMethod: "supplier_rider", agreedDeliveryFeeAmount: "not money" })).toThrow("Delivery fee must be a valid amount");
    expect(() => buildArrangeSupplierOrderDeliveryPayload({ orderId: pendingOrder.orderId, deliveryMethod: "supplier_rider", expectedTimeWindow: "x".repeat(101) })).toThrow("Delivery arrangement text is too long");
  });

  it("validates out-for-delivery inputs before calling the RPC", () => {
    expect(() => buildMarkSupplierOrderOutForDeliveryPayload({ orderId: pendingOrder.orderId, dispatchReference: "x".repeat(101) })).toThrow("Dispatch reference is too long");
    expect(() => buildMarkSupplierOrderOutForDeliveryPayload({ orderId: pendingOrder.orderId, customerDispatchInstruction: "x".repeat(501) })).toThrow("Customer dispatch instruction is too long");
    expect(() => buildMarkSupplierOrderOutForDeliveryPayload({ orderId: pendingOrder.orderId, customerDispatchInstruction: "Live tracking: https://example.test" })).toThrow("Dispatch details cannot include live tracking or verified delivery claims");
  });

  it("validates supplier payment-report inputs before calling the RPC", () => {
    expect(buildReportSupplierOrderPaymentReceivedPayload({ orderId: pendingOrder.orderId })).toEqual({
      p_order_id: pendingOrder.orderId,
      p_payment_reference: null,
      p_supplier_private_note: null,
      p_idempotency_key: `supplier-payment-reported:${pendingOrder.orderId}`
    });
    expect(() => buildReportSupplierOrderPaymentReceivedPayload({ orderId: pendingOrder.orderId, paymentReference: "x".repeat(101) })).toThrow("Payment reference is too long");
    expect(() => buildReportSupplierOrderPaymentReceivedPayload({ orderId: pendingOrder.orderId, supplierPrivateNote: "x".repeat(301) })).toThrow("Payment note is too long");
    expect(() => buildReportSupplierOrderPaymentReceivedPayload({ orderId: pendingOrder.orderId, paymentReference: "OTP 123456" })).toThrow("Payment details cannot include secrets");
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
    expect(mapSupplierOrderRpcError({ message: "ALREADY_ARRANGED" })).toMatchObject({ code: "ALREADY_ARRANGED" });
    expect(mapSupplierOrderRpcError({ message: "ALREADY_OUT_FOR_DELIVERY" })).toMatchObject({ code: "ALREADY_OUT_FOR_DELIVERY" });
    expect(mapSupplierOrderRpcError({ message: "ALREADY_REPORTED" })).toMatchObject({ code: "ALREADY_REPORTED" });
    expect(mapSupplierOrderRpcError({ message: "ORDER_NOT_ARRANGED" })).toMatchObject({ code: "ORDER_NOT_ARRANGED" });
    expect(mapSupplierOrderRpcError({ message: "ORDER_NOT_DELIVERED" })).toMatchObject({ code: "ORDER_NOT_DELIVERED" });
    expect(mapSupplierOrderRpcError({ message: "PAYMENT_METHOD_NOT_SUPPORTED" })).toMatchObject({ code: "PAYMENT_METHOD_NOT_SUPPORTED" });
    expect(mapSupplierOrderRpcError({ message: "PAYMENT_ALREADY_COLLECTED" })).toMatchObject({ code: "PAYMENT_ALREADY_COLLECTED" });
    expect(mapSupplierOrderRpcError({ message: "STOCK_STATE_INCONSISTENT" })).toMatchObject({ code: "STOCK_STATE_INCONSISTENT" });
    expect(mapSupplierOrderRpcError({ message: "FINANCIAL_SNAPSHOT_INVALID" })).toMatchObject({ code: "FINANCIAL_SNAPSHOT_INVALID" });
    expect(mapSupplierOrderRpcError({ message: "INVALID_PAYMENT_FIELD" })).toMatchObject({ code: "INVALID_PAYMENT_FIELD" });
    expect(mapSupplierOrderRpcError({ message: "DELIVERY_ARRANGEMENT_NOT_FOUND" })).toMatchObject({ code: "DELIVERY_ARRANGEMENT_NOT_FOUND" });
    expect(mapSupplierOrderRpcError({ message: "INVALID_DISPATCH_FIELD" })).toMatchObject({ code: "INVALID_DISPATCH_FIELD" });
    expect(mapSupplierOrderRpcError({ message: "INVALID_DELIVERY_METHOD" })).toMatchObject({ code: "INVALID_DELIVERY_METHOD" });
    expect(mapSupplierOrderRpcError({ message: "CONFLICTING_RETRY" })).toMatchObject({ code: "CONFLICTING_RETRY" });
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
        arrangeDeliveryAction={vi.fn()}
        markReadyForDeliveryAction={vi.fn()}
      />
    );
    expect(screen.getByText("Order is ready for delivery")).toBeInTheDocument();
    expect(screen.getByText("Record the manual delivery arrangement once you and the customer have agreed the handoff outside Risellar. This does not book a courier, assign a rider, collect payment, or mark the order delivered.")).toBeInTheDocument();
    expect(screen.getByRole("combobox", { name: "Delivery method" })).toBeInTheDocument();
    expect(screen.getByLabelText("Agreed delivery fee")).toBeInTheDocument();
    expect(screen.getByLabelText("Expected date")).toBeInTheDocument();
    expect(screen.getByLabelText("Courier or rider display name")).toBeInTheDocument();
    expect(screen.getByLabelText("Private supplier note")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Save delivery arrangement" })).toBeDisabled();
    fireEvent.click(screen.getByRole("checkbox", { name: /Confirm this is a manual arrangement/i }));
    expect(screen.getByRole("button", { name: "Save delivery arrangement" })).toBeEnabled();
    expect(screen.queryByRole("button", { name: "Mark ready for delivery" })).not.toBeInTheDocument();

    rerender(
      <SupplierOrderDetailRpcScreen
        actionState={{ code: "OK", message: "Delivery arrangement saved" }}
        order={{
          ...pendingOrder,
          orderStatus: "delivery_arranged",
          orderStatusLabel: "Delivery arranged",
          deliveryArrangementMethodLabel: "Third-party courier",
          deliveryArrangementFeeAmount: 25.5,
          deliveryArrangementCurrencyCode: "GHS",
          deliveryArrangementExpectedDate: "2026-08-01",
          deliveryArrangementTimeWindow: "Morning",
          deliveryArrangementCourierName: "QA Courier",
          deliveryArrangementCourierPhone: "+233200000000",
          deliveryArrangementCustomerInstruction: "Call before arrival",
          deliveryArrangementSupplierPrivateNote: "Private supplier-only QA note",
          deliveryArrangedAt: "2026-07-30T12:20:00.000Z"
        }}
        arrangeDeliveryAction={vi.fn()}
        markOutForDeliveryAction={vi.fn()}
      />
    );
    expect(screen.getByText("Delivery arrangement saved")).toBeInTheDocument();
    expect(screen.getByText("Use this only after the order has been handed to the rider, courier, or customer pickup contact. Risellar does not provide live tracking or collect payment.")).toBeInTheDocument();
    expect(screen.getByText("Third-party courier")).toBeInTheDocument();
    expect(screen.getByText("Private supplier-only QA note")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Save delivery arrangement" })).not.toBeInTheDocument();
    expect(screen.getByLabelText("Dispatch reference")).toBeInTheDocument();
    expect(screen.getByLabelText("Customer dispatch instruction")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Mark as out for delivery" })).toBeDisabled();
    fireEvent.click(screen.getByRole("checkbox", { name: /Confirm the order has been handed off/i }));
    expect(screen.getByRole("button", { name: "Mark as out for delivery" })).toBeEnabled();

    rerender(
      <SupplierOrderDetailRpcScreen
        actionState={{ code: "OK", message: "Order marked as out for delivery" }}
        order={{
          ...pendingOrder,
          orderStatus: "out_for_delivery",
          orderStatusLabel: "Out for delivery",
          deliveryArrangementMethodLabel: "Third-party courier",
          deliveryArrangementFeeAmount: 25.5,
          deliveryArrangementCurrencyCode: "GHS",
          deliveryArrangementCustomerInstruction: "Call before arrival",
          deliveryArrangementSupplierPrivateNote: "Private supplier-only QA note",
          deliveryArrangedAt: "2026-07-30T12:20:00.000Z",
          outForDeliveryAt: "2026-07-30T13:00:00.000Z",
          dispatchReference: "QA-DISPATCH-001",
          customerDispatchInstruction: "Meet the courier at the main gate"
        }}
        markOutForDeliveryAction={vi.fn()}
      />
    );
    expect(screen.getByText("Order marked as out for delivery")).toBeInTheDocument();
    expect(screen.getByText("The order has been dispatched. Payment has not been collected and the order has not been marked delivered.")).toBeInTheDocument();
    expect(screen.getByText("QA-DISPATCH-001")).toBeInTheDocument();
    expect(screen.getByText("Meet the courier at the main gate")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Mark as out for delivery" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /delivered/i })).not.toBeInTheDocument();

    expect(document.body.innerHTML).not.toMatch(/customer email|reseller margin|platform margin|commission|settlement|risk|raw stock/i);
  });

  it("renders supplier payment report control only for delivered Pay on Delivery orders", () => {
    const deliveredOrder: SupplierOrderSafe = {
      ...pendingOrder,
      orderStatus: "delivered",
      orderStatusLabel: "Delivered",
      isSupplierActionable: false,
      deliveryStatusLabel: "Delivered - payment not confirmed",
      outForDeliveryAt: "2026-07-30T13:00:00.000Z",
      deliveredAt: "2026-07-30T14:00:00.000Z",
      deliveryConfirmationNote: "Development-only delivered note"
    };

    const { rerender } = render(
      <SupplierOrderDetailRpcScreen
        actionState={{ code: "OK", message: "" }}
        order={deliveredOrder}
        reportPaymentReceivedAction={vi.fn()}
      />
    );

    expect(screen.getByText("Use this only after you have received the full Pay on Delivery amount from the customer.")).toBeInTheDocument();
    expect(screen.getByText(/platform amount and reseller commission will remain pending/i)).toBeInTheDocument();
    expect(screen.getByPlaceholderText("Optional cash, Mobile Money, or internal receipt reference")).toBeInTheDocument();
    expect(screen.getByLabelText("Private payment note")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Report payment received" })).toBeDisabled();
    fireEvent.click(screen.getByRole("checkbox", { name: /received the full Pay on Delivery amount/i }));
    expect(screen.getByRole("button", { name: "Report payment received" })).toBeEnabled();

    rerender(
      <SupplierOrderDetailRpcScreen
        actionState={{ code: "OK", message: "Payment reported - settlement pending" }}
        order={{
          ...deliveredOrder,
          orderStatus: "payment_reported",
          orderStatusLabel: "Payment reported - settlement pending",
          paymentStatusLabel: "Payment reported by supplier",
          reservationStatusLabel: "Stock committed",
          paymentReportedAt: "2026-07-30T15:00:00.000Z",
          paymentReference: "QA-PAYMENT-001",
          supplierPaymentPrivateNote: "Development-only private payment note",
          platformAmountDue: 20,
          resellerCommissionDue: 20,
          settlementStatusLabel: "Pending settlement to Risellar",
          commissionStatusLabel: "Locked until settlement is verified"
        }}
        reportPaymentReceivedAction={vi.fn()}
      />
    );

    expect(screen.getAllByText("Payment reported - settlement pending").length).toBeGreaterThan(0);
    expect(screen.getByText("Your payment report has been recorded. The platform amount and reseller commission are still pending settlement verification.")).toBeInTheDocument();
    expect(screen.getByText("Pending settlement to Risellar")).toBeInTheDocument();
    expect(screen.getByText("Locked until settlement is verified")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Report payment received" })).not.toBeInTheDocument();
    expect(document.body.innerHTML).not.toMatch(/commission available|settlement complete|withdraw|payment verified by risellar|order completed/i);
  });

  it("keeps supplier routes supplier-only and excludes payment providers, withdrawals, service-role, and direct table mutation code", () => {
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
    expect(sources).toContain("supplier_arrange_order_delivery");
    expect(sources).toContain("supplier-arrange-delivery:");
    expect(sources).toContain("supplier_mark_order_out_for_delivery");
    expect(sources).toContain("supplier-out-for-delivery:");
    expect(sources).toContain("supplier_mark_order_delivered");
    expect(sources).toContain("supplier-delivered:");
    expect(sources).toContain("supplier_report_order_payment_received");
    expect(sources).toContain("supplier-payment-reported:");
    expect(sources).not.toContain("create_payment");
    expect(sources).not.toContain("delivery_quotes");
    expect(sources).not.toContain("prepare_supplier_for_order");
    expect(sources).not.toContain("collect_payment_provider");
    expect(sources).not.toContain("payment_verified");
    expect(sources).not.toContain("tracking_url");
    expect(sources).not.toContain("commission available");
    expect(sources).not.toContain("settlement complete");
    expect(sources).not.toContain("withdrawal");
    expect(sources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(sources).not.toContain("createSupabaseAdminClient");
    expect(sources).not.toContain(".from(\"orders\").update");
    expect(sources).not.toContain(".from(\"stock_reservations\").update");
  });
});
