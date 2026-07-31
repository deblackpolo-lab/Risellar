export type SupplierOrderCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "SUPPLIER_REQUIRED"
  | "ORDER_NOT_FOUND"
  | "ORDER_NOT_ACTIONABLE"
  | "ORDER_NOT_CONFIRMED"
  | "RESERVATION_NOT_FOUND"
  | "RESERVATION_EXPIRED"
  | "RESERVATION_NOT_ACTIVE"
  | "ALREADY_CONFIRMED"
  | "ALREADY_REJECTED"
  | "ALREADY_PREPARING"
  | "INVALID_REJECTION_REASON"
  | "REJECTION_NOTE_TOO_LONG"
  | "STOCK_RELEASE_FAILED"
  | "VALIDATION_ERROR"
  | "RPC_PERMISSION_DENIED"
  | "UNKNOWN";

export type SupplierOrderState = {
  code: SupplierOrderCode;
  message: string;
};

export type SupplierOrderSafe = {
  orderId: string;
  orderNumber: string;
  createdAt: string;
  updatedAt: string;
  orderStatus: string;
  orderStatusLabel: string;
  isSupplierActionable: boolean;
  productName: string;
  productSlug: string | null;
  productImageSnapshot: Record<string, unknown>;
  variantSku: string | null;
  variantName: string | null;
  quantity: number;
  supplierAmountExpected: number | null;
  customerTotalAmount: number | null;
  currencyCode: string;
  paymentMethodLabel: string;
  paymentStatusLabel: string;
  deliveryStatusLabel: string;
  reservationStatusLabel: string;
  reservationExpiresAt: string | null;
  reservationQuantity: number | null;
  recipientName: string | null;
  recipientPhone: string | null;
  recipientWhatsapp: string | null;
  deliveryAddressSnapshot: Record<string, unknown>;
  locationSummary?: string | null;
  resellerShopName: string | null;
  resellerShopSlug: string | null;
};

export const initialSupplierOrderState: SupplierOrderState = {
  code: "OK",
  message: ""
};

export const supplierOrderRejectReasonCodes = [
  "out_of_stock",
  "product_unavailable",
  "unable_to_fulfil",
  "incorrect_listing",
  "supplier_temporarily_closed",
  "other"
] as const;
