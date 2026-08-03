export type CustomerDisputeActionCode =
  | "OK"
  | "AUTH_REQUIRED"
  | "SUPABASE_AUTH_TOKEN_MISSING"
  | "VALIDATION_ERROR"
  | "DISPUTE_NOT_FOUND"
  | "ORDER_NOT_FOUND"
  | "DUPLICATE_ACTIVE_DISPUTE"
  | "IDEMPOTENCY_CONFLICT"
  | "ITEM_SELECTOR_REQUIRED"
  | "DISPUTE_RESPONSE_NOT_ALLOWED"
  | "RPC_PERMISSION_DENIED"
  | "UNKNOWN";

export type CustomerDisputeActionState = {
  code: CustomerDisputeActionCode;
  message: string;
  disputeHref?: string;
};

export type CustomerDisputeStatus =
  | "open"
  | "awaiting_customer"
  | "awaiting_supplier"
  | "under_review"
  | "return_review"
  | "refund_review"
  | "resolved_customer"
  | "resolved_supplier"
  | "partially_resolved"
  | "rejected"
  | "cancelled"
  | "closed";

export type CustomerDisputeListItem = {
  disputeId: string;
  safeOrderReference: string;
  scopeType: string;
  affectedItemSummary: string;
  category: string;
  categoryLabel: string;
  reasonCode: string;
  reasonLabel: string;
  requestedOutcome: string;
  requestedOutcomeLabel: string;
  status: CustomerDisputeStatus;
  statusLabel: string;
  customerActionRequired: boolean;
  supplierActionRequired: boolean;
  openedAt: string;
  updatedAt: string;
  safeLatestMessage: string | null;
  safeNextAction: string | null;
  detailHref: string;
};

export type CustomerDisputeMessage = {
  authorRole: string;
  messageType: string;
  body: string;
  createdAt: string;
};

export type CustomerDisputeStatusHistoryItem = {
  previousStatus: string | null;
  newStatus: string;
  changedByRole: string | null;
  publicNote: string | null;
  createdAt: string;
};

export type CustomerDispute = CustomerDisputeListItem & {
  priority: string;
  publicResolutionMessage: string | null;
  messages: CustomerDisputeMessage[];
  statusHistory: CustomerDisputeStatusHistoryItem[];
};

export type CustomerDisputeOrderItemSafe = {
  orderItemId: string;
  safeItemName: string;
  safeVariantSummary: string | null;
  quantity: number;
  finalCustomerPriceAmount: number | null;
  lineTotalAmount: number | null;
  currencyCode: string;
};

export const customerDisputeStatuses: CustomerDisputeStatus[] = [
  "open",
  "awaiting_customer",
  "awaiting_supplier",
  "under_review",
  "return_review",
  "refund_review",
  "resolved_customer",
  "resolved_supplier",
  "partially_resolved",
  "rejected",
  "cancelled",
  "closed"
];

export const customerDisputeCategoryLabels: Record<string, string> = {
  pre_delivery: "Before delivery",
  delivery: "Delivery",
  payment: "Payment",
  post_completion: "After delivery",
  other: "Other"
};

export const customerDisputeReasonLabels: Record<string, string> = {
  supplier_not_responding: "Supplier not responding",
  supplier_rejected_status_incorrect: "Supplier rejection seems incorrect",
  order_stuck_in_preparation: "Order stuck in preparation",
  delivery_not_arranged: "Delivery not arranged",
  delivery_delay: "Delivery delay",
  customer_requests_cancellation: "I want to cancel",
  order_not_received: "Order not received",
  wrong_item_received: "Wrong item received",
  damaged_item_received: "Damaged item received",
  incomplete_order: "Incomplete order",
  unsafe_delivery_issue: "Unsafe delivery issue",
  delivery_fee_disagreement: "Delivery fee disagreement",
  customer_paid_not_reported: "Payment not reported",
  supplier_reported_customer_disagrees: "I disagree with payment report",
  duplicate_payment_claim: "Duplicate payment claim",
  wrong_amount_collected: "Wrong amount collected",
  unauthorised_extra_charge: "Unauthorised extra charge",
  item_not_as_described: "Item not as described",
  product_quality_issue: "Product quality issue",
  return_requested: "Return requested",
  refund_requested: "Refund requested",
  other: "Other"
};

export const customerDisputeOutcomeLabels: Record<string, string> = {
  information_only: "Information only",
  cancellation: "Cancellation",
  redelivery: "Redelivery",
  replacement: "Replacement",
  return: "Return",
  full_refund: "Full refund",
  partial_refund: "Partial refund",
  delivery_fee_refund: "Delivery fee refund",
  accounting_correction: "Accounting correction",
  other: "Other"
};

export const customerDisputeStatusLabels: Record<CustomerDisputeStatus, string> = {
  open: "Open",
  awaiting_customer: "Waiting for you",
  awaiting_supplier: "Waiting for supplier",
  under_review: "Under review",
  return_review: "Return review",
  refund_review: "Refund review",
  resolved_customer: "Resolved for customer",
  resolved_supplier: "Resolved for supplier",
  partially_resolved: "Partially resolved",
  rejected: "Rejected",
  cancelled: "Cancelled",
  closed: "Closed"
};

export const customerDisputeItemSpecificReasonCodes = new Set([
  "wrong_item_received",
  "damaged_item_received",
  "incomplete_order",
  "item_not_as_described",
  "product_quality_issue",
  "return_requested",
  "refund_requested"
]);

export const customerDisputeReasonOptions = [
  { category: "delivery", reasonCode: "delivery_delay", label: customerDisputeReasonLabels.delivery_delay, itemSelectorRequired: false },
  { category: "delivery", reasonCode: "delivery_not_arranged", label: customerDisputeReasonLabels.delivery_not_arranged, itemSelectorRequired: false },
  { category: "pre_delivery", reasonCode: "supplier_not_responding", label: customerDisputeReasonLabels.supplier_not_responding, itemSelectorRequired: false },
  { category: "pre_delivery", reasonCode: "customer_requests_cancellation", label: customerDisputeReasonLabels.customer_requests_cancellation, itemSelectorRequired: false },
  { category: "payment", reasonCode: "customer_paid_not_reported", label: customerDisputeReasonLabels.customer_paid_not_reported, itemSelectorRequired: false },
  { category: "other", reasonCode: "other", label: customerDisputeReasonLabels.other, itemSelectorRequired: false },
  { category: "post_completion", reasonCode: "wrong_item_received", label: customerDisputeReasonLabels.wrong_item_received, itemSelectorRequired: true },
  { category: "post_completion", reasonCode: "damaged_item_received", label: customerDisputeReasonLabels.damaged_item_received, itemSelectorRequired: true },
  { category: "post_completion", reasonCode: "return_requested", label: customerDisputeReasonLabels.return_requested, itemSelectorRequired: true },
  { category: "post_completion", reasonCode: "refund_requested", label: customerDisputeReasonLabels.refund_requested, itemSelectorRequired: true }
] as const;

export const customerDisputeOutcomeOptions = [
  { value: "information_only", label: customerDisputeOutcomeLabels.information_only },
  { value: "cancellation", label: customerDisputeOutcomeLabels.cancellation },
  { value: "redelivery", label: customerDisputeOutcomeLabels.redelivery },
  { value: "replacement", label: customerDisputeOutcomeLabels.replacement },
  { value: "return", label: customerDisputeOutcomeLabels.return },
  { value: "full_refund", label: customerDisputeOutcomeLabels.full_refund },
  { value: "partial_refund", label: customerDisputeOutcomeLabels.partial_refund },
  { value: "delivery_fee_refund", label: customerDisputeOutcomeLabels.delivery_fee_refund },
  { value: "accounting_correction", label: customerDisputeOutcomeLabels.accounting_correction },
  { value: "other", label: customerDisputeOutcomeLabels.other }
] as const;

export const initialCustomerDisputeActionState: CustomerDisputeActionState = {
  code: "OK",
  message: ""
};
