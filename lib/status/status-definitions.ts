import type { StatusTone } from "@/lib/status/status-tones";

export type StatusDomain = "order" | "product" | "settlement" | "commission" | "verification" | "promotion";

export type StatusDefinition = {
  label: string;
  tone: StatusTone;
  description: string;
};

export const statusCatalog: Record<StatusDomain, readonly StatusDefinition[]> = {
  order: [
    { label: "Awaiting Confirmation", tone: "warning", description: "Customer still needs to confirm the order." },
    { label: "Awaiting Customer Confirmation", tone: "warning", description: "Customer confirmation is pending." },
    { label: "Customer Confirmed", tone: "success", description: "Customer confirmed they want the item." },
    { label: "Preparing", tone: "info", description: "Supplier is preparing the item." },
    { label: "Delivery Quote Pending", tone: "warning", description: "Delivery cost is not approved yet." },
    { label: "Delivery Approved", tone: "success", description: "Customer approved the delivery cost." },
    { label: "Out for Delivery", tone: "info", description: "Rider is delivering the order." },
    { label: "Delivered", tone: "success", description: "Order has reached the customer." },
    { label: "Payment Collected", tone: "success", description: "Cash or MoMo has been collected." },
    { label: "Settlement Due", tone: "warning", description: "Supplier owes Risellar margin and commission." },
    { label: "Settlement Overdue", tone: "danger", description: "Settlement passed its due date." },
    { label: "Completed", tone: "success", description: "Order lifecycle is complete." },
    { label: "Cancelled", tone: "neutral", description: "Order was cancelled before completion." },
    { label: "Customer Refused", tone: "danger", description: "Customer refused the order." },
    { label: "Dispute Opened", tone: "danger", description: "Support is reviewing an order issue." }
  ],
  product: [
    { label: "Draft", tone: "neutral", description: "Product is not submitted yet." },
    { label: "Pending Approval", tone: "warning", description: "Admin approval is pending." },
    { label: "Approved", tone: "success", description: "Product is approved for marketplace use." },
    { label: "Active", tone: "success", description: "Product is available for selling." },
    { label: "Rejected", tone: "danger", description: "Product did not pass review." },
    { label: "Needs Changes", tone: "warning", description: "Supplier must update product details." },
    { label: "Price Change Pending", tone: "warning", description: "New price needs review." },
    { label: "Needs Reseller Review", tone: "warning", description: "Resellers should review changes." },
    { label: "Out of Stock", tone: "danger", description: "No available stock remains." },
    { label: "Only 1 left", tone: "warning", description: "Stock is almost gone." },
    { label: "Hidden", tone: "neutral", description: "Product is hidden from buyers." },
    { label: "Suspended", tone: "danger", description: "Product has been restricted." },
    { label: "Archived", tone: "neutral", description: "Product is no longer active." },
    { label: "Sponsored", tone: "info", description: "Product is promoted in discovery surfaces." },
    { label: "Supplier Restricted", tone: "danger", description: "Supplier access has been restricted." }
  ],
  settlement: [
    { label: "Due", tone: "warning", description: "Settlement should be paid soon." },
    { label: "Proof Submitted", tone: "info", description: "Payment proof is awaiting review." },
    { label: "Verifying", tone: "info", description: "Admin is verifying settlement proof." },
    { label: "Partially Settled", tone: "warning", description: "Some amount remains unpaid." },
    { label: "Paid", tone: "success", description: "Settlement is fully paid." },
    { label: "Overdue", tone: "danger", description: "Settlement is past due." },
    { label: "Disputed", tone: "danger", description: "Settlement is under dispute." },
    { label: "Settlement Due", tone: "warning", description: "Supplier settlement is due." },
    { label: "Settlement Overdue", tone: "danger", description: "Supplier settlement is overdue." }
  ],
  commission: [
    { label: "Pending", tone: "warning", description: "Commission is not available yet." },
    { label: "Awaiting Settlement", tone: "warning", description: "Supplier settlement unlocks commission." },
    { label: "Available", tone: "success", description: "Commission can be withdrawn." },
    { label: "Withdrawal Requested", tone: "info", description: "Payout request is being processed." },
    { label: "Paid", tone: "success", description: "Commission was paid out." },
    { label: "Cancelled", tone: "neutral", description: "Commission is cancelled." },
    { label: "Disputed", tone: "danger", description: "Commission is under dispute." },
    { label: "Commission Pending", tone: "warning", description: "Commission is still pending." }
  ],
  verification: [
    { label: "Pending", tone: "warning", description: "Verification is awaiting review." },
    { label: "Approved", tone: "success", description: "Verification is approved." },
    { label: "Rejected", tone: "danger", description: "Verification was rejected." },
    { label: "More Info Required", tone: "danger", description: "More documentation is needed." }
  ],
  promotion: [
    { label: "Pending Payment", tone: "warning", description: "Promotion payment is pending." },
    { label: "Pending Approval", tone: "warning", description: "Promotion is awaiting review." },
    { label: "Active", tone: "success", description: "Promotion is live." },
    { label: "Paused", tone: "neutral", description: "Promotion is paused." },
    { label: "Completed", tone: "success", description: "Promotion has ended." },
    { label: "Rejected", tone: "danger", description: "Promotion was rejected." },
    { label: "Cancelled", tone: "neutral", description: "Promotion was cancelled." }
  ]
} as const;

export const allStatuses = Object.values(statusCatalog).flat();

export function getStatusDefinition(label: string) {
  return allStatuses.find((status) => status.label.toLowerCase() === label.toLowerCase());
}

export function getStatusTone(label: string): StatusTone {
  return getStatusDefinition(label)?.tone ?? "neutral";
}
