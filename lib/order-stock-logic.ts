export type CurrencyCode = "GHS";

export type PaymentMethod = "Pay on Delivery" | "Pay Online";

export type CheckoutPaymentAvailability = {
  method: PaymentMethod;
  status: "active" | "placeholder";
  primary: boolean;
  reason?: string;
};

export type ProductPriceBreakdownInput = {
  supplierBasePrice: number;
  platformMargin: number;
  resellerMargin: number;
  quantity?: number;
  deliveryFee?: number;
  currencyCode?: CurrencyCode;
};

export type ProductPriceBreakdown = {
  supplierBasePrice: number;
  platformMargin: number;
  resellerMargin: number;
  resellerCost: number;
  customerProductPrice: number;
  quantity: number;
  productSubtotal: number;
  deliveryFee: number;
  totalPayOnDelivery: number;
  currencyCode: CurrencyCode;
};

export type ResellerMarginValidationInput = {
  resellerMargin: number;
  maxResellerMargin?: number;
};

export type ResellerMarginValidationResult =
  | { valid: true }
  | { valid: false; reason: string };

export type OrderPriceSnapshotInput = {
  orderId: string;
  productId: string;
  variantId: string;
  supplierId: string;
  resellerId: string;
  resellerListingId: string;
  capturedAt: string;
  breakdown: ProductPriceBreakdown;
};

export type OrderPriceSnapshot = {
  orderId: string;
  productId: string;
  variantId: string;
  supplierId: string;
  resellerId: string;
  resellerListingId: string;
  capturedAt: string;
  quantity: number;
  supplierBasePriceSnapshot: number;
  platformMarginSnapshot: number;
  resellerMarginSnapshot: number;
  resellerCostSnapshot: number;
  customerProductPriceSnapshot: number;
  productSubtotalSnapshot: number;
  deliveryFeeSnapshot: number;
  totalPayOnDeliverySnapshot: number;
  currencyCode: CurrencyCode;
};

export type OrderPriceRole = "customer" | "reseller" | "admin";

export type CustomerOrderPriceView = {
  customerProductPrice: number;
  deliveryFee: number;
  totalPayOnDelivery: number;
  currencyCode: CurrencyCode;
};

export type ResellerOrderPriceView = CustomerOrderPriceView & {
  resellerCost: number;
  resellerMargin: number;
};

export type AdminOrderPriceView = ResellerOrderPriceView & {
  supplierBasePrice: number;
  platformMargin: number;
};

export type StockReservationInput = {
  totalStock: number;
  reservedStock: number;
  soldStock?: number;
  requestedQuantity: number;
};

export type StockReservationResult =
  | { canReserve: true; availableStock: number }
  | { canReserve: false; availableStock: number; reason: string };

export type OrderConfirmationInput = {
  currentStatus: "Awaiting Customer Confirmation" | "Customer Confirmed" | "Confirmation Expired";
  confirmedAt: Date | string;
  reservationExpiresAt: Date | string;
  stockCanReserve: boolean;
};

export type OrderConfirmationResult = {
  orderStatus: "Customer Confirmed" | "Confirmation Expired" | "Stock Reservation Failed";
  reservationStatus: "reserved" | "expired" | "failed";
  nextAction: string;
};

const DEFAULT_CONFIRMATION_HOLD_MINUTES = 60;

export function calculateProductPriceBreakdown({
  supplierBasePrice,
  platformMargin,
  resellerMargin,
  quantity = 1,
  deliveryFee = 0,
  currencyCode = "GHS"
}: ProductPriceBreakdownInput): ProductPriceBreakdown {
  assertNonNegativeMoney("supplierBasePrice", supplierBasePrice);
  assertNonNegativeMoney("platformMargin", platformMargin);
  assertNonNegativeMoney("resellerMargin", resellerMargin);
  assertNonNegativeMoney("deliveryFee", deliveryFee);
  assertPositiveInteger("quantity", quantity);

  const resellerCost = supplierBasePrice + platformMargin;
  const customerProductPrice = resellerCost + resellerMargin;
  const productSubtotal = customerProductPrice * quantity;

  return {
    supplierBasePrice,
    platformMargin,
    resellerMargin,
    resellerCost,
    customerProductPrice,
    quantity,
    productSubtotal,
    deliveryFee,
    totalPayOnDelivery: productSubtotal + deliveryFee,
    currencyCode
  };
}

export function validateResellerMargin({
  resellerMargin,
  maxResellerMargin
}: ResellerMarginValidationInput): ResellerMarginValidationResult {
  if (!Number.isFinite(resellerMargin)) {
    return { valid: false, reason: "Reseller margin must be a valid amount." };
  }

  if (resellerMargin < 0) {
    return { valid: false, reason: "Reseller margin cannot be negative." };
  }

  if (maxResellerMargin !== undefined && resellerMargin > maxResellerMargin) {
    return { valid: false, reason: "Reseller margin cannot exceed the approved maximum." };
  }

  return { valid: true };
}

export function createOrderPriceSnapshot({
  orderId,
  productId,
  variantId,
  supplierId,
  resellerId,
  resellerListingId,
  capturedAt,
  breakdown
}: OrderPriceSnapshotInput): OrderPriceSnapshot {
  return {
    orderId,
    productId,
    variantId,
    supplierId,
    resellerId,
    resellerListingId,
    capturedAt,
    quantity: breakdown.quantity,
    supplierBasePriceSnapshot: breakdown.supplierBasePrice,
    platformMarginSnapshot: breakdown.platformMargin,
    resellerMarginSnapshot: breakdown.resellerMargin,
    resellerCostSnapshot: breakdown.resellerCost,
    customerProductPriceSnapshot: breakdown.customerProductPrice,
    productSubtotalSnapshot: breakdown.productSubtotal,
    deliveryFeeSnapshot: breakdown.deliveryFee,
    totalPayOnDeliverySnapshot: breakdown.totalPayOnDelivery,
    currencyCode: breakdown.currencyCode
  };
}

export function getOrderPriceViewForRole(snapshot: OrderPriceSnapshot, role: "customer"): CustomerOrderPriceView;
export function getOrderPriceViewForRole(snapshot: OrderPriceSnapshot, role: "reseller"): ResellerOrderPriceView;
export function getOrderPriceViewForRole(snapshot: OrderPriceSnapshot, role: "admin"): AdminOrderPriceView;
export function getOrderPriceViewForRole(
  snapshot: OrderPriceSnapshot,
  role: OrderPriceRole
): CustomerOrderPriceView | ResellerOrderPriceView | AdminOrderPriceView {
  const customerView: CustomerOrderPriceView = {
    customerProductPrice: snapshot.customerProductPriceSnapshot,
    deliveryFee: snapshot.deliveryFeeSnapshot,
    totalPayOnDelivery: snapshot.totalPayOnDeliverySnapshot,
    currencyCode: snapshot.currencyCode
  };

  if (role === "customer") {
    return customerView;
  }

  const resellerView: ResellerOrderPriceView = {
    resellerCost: snapshot.resellerCostSnapshot,
    resellerMargin: snapshot.resellerMarginSnapshot,
    ...customerView
  };

  if (role === "reseller") {
    return resellerView;
  }

  return {
    supplierBasePrice: snapshot.supplierBasePriceSnapshot,
    platformMargin: snapshot.platformMarginSnapshot,
    ...resellerView
  };
}

export function canReserveStock({
  totalStock,
  reservedStock,
  soldStock = 0,
  requestedQuantity
}: StockReservationInput): StockReservationResult {
  assertPositiveInteger("requestedQuantity", requestedQuantity);
  assertNonNegativeInteger("totalStock", totalStock);
  assertNonNegativeInteger("reservedStock", reservedStock);
  assertNonNegativeInteger("soldStock", soldStock);

  const availableStock = Math.max(totalStock - reservedStock - soldStock, 0);

  if (requestedQuantity > availableStock) {
    return {
      canReserve: false,
      availableStock,
      reason: "Requested quantity exceeds available stock."
    };
  }

  return { canReserve: true, availableStock };
}

export function calculateReservationExpiry(
  createdAt: Date | string,
  holdMinutes = DEFAULT_CONFIRMATION_HOLD_MINUTES
): Date {
  assertPositiveInteger("holdMinutes", holdMinutes);
  return new Date(toDate(createdAt).getTime() + holdMinutes * 60 * 1000);
}

export function getOrderStatusAfterCustomerConfirmation({
  confirmedAt,
  reservationExpiresAt,
  stockCanReserve
}: OrderConfirmationInput): OrderConfirmationResult {
  if (toDate(confirmedAt).getTime() > toDate(reservationExpiresAt).getTime()) {
    return {
      orderStatus: "Confirmation Expired",
      reservationStatus: "expired",
      nextAction: "Release any hold and ask the customer to place the order again."
    };
  }

  if (!stockCanReserve) {
    return {
      orderStatus: "Stock Reservation Failed",
      reservationStatus: "failed",
      nextAction: "Keep the order unprocessed and ask the customer to choose another item or retry."
    };
  }

  return {
    orderStatus: "Customer Confirmed",
    reservationStatus: "reserved",
    nextAction: "Reserve stock and move to supplier preparation."
  };
}

export function getCheckoutPaymentAvailability(): CheckoutPaymentAvailability[] {
  return [
    { method: "Pay on Delivery", status: "active", primary: true },
    { method: "Pay Online", status: "placeholder", primary: false, reason: "Online payment provider is not connected yet." }
  ];
}

function assertNonNegativeMoney(name: string, value: number) {
  if (!Number.isFinite(value) || value < 0) {
    throw new Error(`${name} must be a non-negative amount.`);
  }
}

function assertPositiveInteger(name: string, value: number) {
  if (!Number.isInteger(value) || value < 1) {
    throw new Error(`${name} must be a positive integer.`);
  }
}

function assertNonNegativeInteger(name: string, value: number) {
  if (!Number.isInteger(value) || value < 0) {
    throw new Error(`${name} must be a non-negative integer.`);
  }
}

function toDate(value: Date | string) {
  const date = value instanceof Date ? value : new Date(value);

  if (Number.isNaN(date.getTime())) {
    throw new Error("Date value must be valid.");
  }

  return date;
}
