import { describe, expect, it } from "vitest";
import {
  calculateProductPriceBreakdown,
  calculateReservationExpiry,
  canReserveStock,
  createOrderPriceSnapshot,
  getCheckoutPaymentAvailability,
  getOrderPriceViewForRole,
  getOrderStatusAfterCustomerConfirmation,
  validateResellerMargin
} from "@/lib/order-stock-logic";

describe("Risellar order and stock pure logic", () => {
  it("calculates customer product price from supplier base, platform margin, and reseller margin", () => {
    const breakdown = calculateProductPriceBreakdown({
      supplierBasePrice: 300,
      platformMargin: 10,
      resellerMargin: 30,
      quantity: 2,
      deliveryFee: 45
    });

    expect(breakdown).toEqual({
      supplierBasePrice: 300,
      platformMargin: 10,
      resellerMargin: 30,
      resellerCost: 310,
      customerProductPrice: 340,
      quantity: 2,
      productSubtotal: 680,
      deliveryFee: 45,
      totalPayOnDelivery: 725,
      currencyCode: "GHS"
    });
  });

  it("validates reseller margin against non-negative and maximum margin rules", () => {
    expect(validateResellerMargin({ resellerMargin: 30, maxResellerMargin: 80 })).toEqual({ valid: true });
    expect(validateResellerMargin({ resellerMargin: -1, maxResellerMargin: 80 })).toEqual({
      valid: false,
      reason: "Reseller margin cannot be negative."
    });
    expect(validateResellerMargin({ resellerMargin: 81, maxResellerMargin: 80 })).toEqual({
      valid: false,
      reason: "Reseller margin cannot exceed the approved maximum."
    });
  });

  it("snapshots order item prices so later product price changes do not mutate the order", () => {
    const liveBreakdown = calculateProductPriceBreakdown({
      supplierBasePrice: 300,
      platformMargin: 10,
      resellerMargin: 30,
      quantity: 1,
      deliveryFee: 45
    });

    const snapshot = createOrderPriceSnapshot({
      orderId: "RSR-20260713-00021",
      productId: "nike-air-force-1-07-green-white",
      variantId: "af1-42",
      supplierId: "knust-gadgets",
      resellerId: "amas-beauty-plug",
      resellerListingId: "listing-af1-ama",
      capturedAt: "2026-07-13T10:24:00.000Z",
      breakdown: liveBreakdown
    });

    const changedProductBreakdown = calculateProductPriceBreakdown({
      supplierBasePrice: 350,
      platformMargin: 15,
      resellerMargin: 40,
      quantity: 1,
      deliveryFee: 45
    });

    expect(changedProductBreakdown.customerProductPrice).toBe(405);
    expect(snapshot.customerProductPriceSnapshot).toBe(340);
    expect(snapshot.totalPayOnDeliverySnapshot).toBe(385);
  });

  it("returns role-safe price views for customer, reseller, and admin", () => {
    const snapshot = createOrderPriceSnapshot({
      orderId: "RSR-20260713-00021",
      productId: "nike-air-force-1-07-green-white",
      variantId: "af1-42",
      supplierId: "knust-gadgets",
      resellerId: "amas-beauty-plug",
      resellerListingId: "listing-af1-ama",
      capturedAt: "2026-07-13T10:24:00.000Z",
      breakdown: calculateProductPriceBreakdown({
        supplierBasePrice: 300,
        platformMargin: 10,
        resellerMargin: 30,
        quantity: 1,
        deliveryFee: 45
      })
    });

    expect(getOrderPriceViewForRole(snapshot, "customer")).toEqual({
      customerProductPrice: 340,
      deliveryFee: 45,
      totalPayOnDelivery: 385,
      currencyCode: "GHS"
    });
    expect(getOrderPriceViewForRole(snapshot, "reseller")).toEqual({
      resellerCost: 310,
      resellerMargin: 30,
      customerProductPrice: 340,
      deliveryFee: 45,
      totalPayOnDelivery: 385,
      currencyCode: "GHS"
    });
    expect(getOrderPriceViewForRole(snapshot, "admin")).toEqual({
      supplierBasePrice: 300,
      platformMargin: 10,
      resellerMargin: 30,
      resellerCost: 310,
      customerProductPrice: 340,
      deliveryFee: 45,
      totalPayOnDelivery: 385,
      currencyCode: "GHS"
    });
  });

  it("prevents overselling by checking requested quantity against available stock", () => {
    expect(canReserveStock({ totalStock: 21, reservedStock: 3, soldStock: 0, requestedQuantity: 18 })).toEqual({
      canReserve: true,
      availableStock: 18
    });
    expect(canReserveStock({ totalStock: 21, reservedStock: 3, soldStock: 0, requestedQuantity: 19 })).toEqual({
      canReserve: false,
      availableStock: 18,
      reason: "Requested quantity exceeds available stock."
    });
    expect(canReserveStock({ totalStock: 1, reservedStock: 1, soldStock: 0, requestedQuantity: 1 })).toEqual({
      canReserve: false,
      availableStock: 0,
      reason: "Requested quantity exceeds available stock."
    });
  });

  it("calculates reservation expiry from confirmation hold minutes", () => {
    expect(calculateReservationExpiry("2026-07-13T10:24:00.000Z").toISOString()).toBe("2026-07-13T11:24:00.000Z");
    expect(calculateReservationExpiry("2026-07-13T10:24:00.000Z", 30).toISOString()).toBe("2026-07-13T10:54:00.000Z");
  });

  it("moves confirmed orders only when the reservation can still be held", () => {
    expect(
      getOrderStatusAfterCustomerConfirmation({
        currentStatus: "Awaiting Customer Confirmation",
        confirmedAt: "2026-07-13T10:36:00.000Z",
        reservationExpiresAt: "2026-07-13T11:24:00.000Z",
        stockCanReserve: true
      })
    ).toEqual({
      orderStatus: "Customer Confirmed",
      reservationStatus: "reserved",
      nextAction: "Reserve stock and move to supplier preparation."
    });

    expect(
      getOrderStatusAfterCustomerConfirmation({
        currentStatus: "Awaiting Customer Confirmation",
        confirmedAt: "2026-07-13T11:25:00.000Z",
        reservationExpiresAt: "2026-07-13T11:24:00.000Z",
        stockCanReserve: true
      })
    ).toEqual({
      orderStatus: "Confirmation Expired",
      reservationStatus: "expired",
      nextAction: "Release any hold and ask the customer to place the order again."
    });
  });

  it("marks Pay on Delivery as active and Pay Online as placeholder only", () => {
    expect(getCheckoutPaymentAvailability()).toEqual([
      { method: "Pay on Delivery", status: "active", primary: true },
      { method: "Pay Online", status: "placeholder", primary: false, reason: "Online payment provider is not connected yet." }
    ]);
  });
});
