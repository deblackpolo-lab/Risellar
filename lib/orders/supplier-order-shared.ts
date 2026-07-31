export type SupplierOrderCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "SUPPLIER_REQUIRED"
  | "ORDER_NOT_FOUND"
  | "ORDER_NOT_ACTIONABLE"
  | "ORDER_NOT_CONFIRMED"
  | "ORDER_NOT_PREPARING"
  | "RESERVATION_NOT_FOUND"
  | "RESERVATION_EXPIRED"
  | "RESERVATION_NOT_ACTIVE"
  | "ALREADY_CONFIRMED"
  | "ALREADY_REJECTED"
  | "ALREADY_PREPARING"
  | "ALREADY_READY"
  | "ALREADY_ARRANGED"
  | "ALREADY_OUT_FOR_DELIVERY"
  | "ALREADY_DELIVERED"
  | "ALREADY_REPORTED"
  | "ORDER_NOT_ARRANGED"
  | "ORDER_NOT_OUT_FOR_DELIVERY"
  | "ORDER_NOT_DELIVERED"
  | "DELIVERY_ARRANGEMENT_NOT_FOUND"
  | "DISPATCH_NOT_RECORDED"
  | "INVALID_DISPATCH_FIELD"
  | "INVALID_DELIVERY_NOTE"
  | "INVALID_PAYMENT_FIELD"
  | "PAYMENT_METHOD_NOT_SUPPORTED"
  | "PAYMENT_ALREADY_COLLECTED"
  | "STOCK_STATE_INCONSISTENT"
  | "FINANCIAL_SNAPSHOT_INVALID"
  | "PREPARATION_NOT_STARTED"
  | "INVALID_DELIVERY_METHOD"
  | "INVALID_DELIVERY_FEE"
  | "DELIVERY_FEE_TOO_HIGH"
  | "EXPECTED_DATE_IN_PAST"
  | "INVALID_COURIER_PHONE"
  | "FIELD_TOO_LONG"
  | "CONFLICTING_RETRY"
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
  deliveryArrangementMethod: string | null;
  deliveryArrangementMethodLabel: string | null;
  deliveryArrangementFeeAmount: number | null;
  deliveryArrangementCurrencyCode: string | null;
  deliveryArrangementExpectedDate: string | null;
  deliveryArrangementTimeWindow: string | null;
  deliveryArrangementCourierName: string | null;
  deliveryArrangementCourierPhone: string | null;
  deliveryArrangementCustomerInstruction: string | null;
  deliveryArrangementSupplierPrivateNote: string | null;
  deliveryArrangedAt: string | null;
  outForDeliveryAt: string | null;
  dispatchReference: string | null;
  customerDispatchInstruction: string | null;
  deliveredAt: string | null;
  deliveryConfirmationNote: string | null;
  paymentReportedAt: string | null;
  paymentReference: string | null;
  supplierPaymentPrivateNote: string | null;
  platformAmountDue: number | null;
  resellerCommissionDue: number | null;
  settlementStatusLabel: string | null;
  commissionStatusLabel: string | null;
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

export const supplierOrderDeliveryMethodCodes = [
  "supplier_rider",
  "third_party_courier",
  "ride_hailing",
  "customer_pickup",
  "manually_arranged",
  "other"
] as const;
