export function formatGhc(amount: number) {
  return `GH₵${amount.toLocaleString("en-GH")}`;
}

export type Party = "Customer" | "Reseller" | "Supplier" | "Admin";
export type SupportPriority = "Low" | "Medium" | "High" | "Critical";

export type SupportTicket = {
  id: string;
  title: string;
  party: Party;
  relatedOrderId: string;
  relatedDisputeId?: string;
  priority: SupportPriority;
  status: string;
  owner: string;
  openedAt: string;
  summary: string;
};

export type Dispute = {
  id: string;
  type: string;
  status: string;
  priority: SupportPriority;
  orderId: string;
  customer: string;
  reseller: string;
  supplier: string;
  product: string;
  amount: number;
  commissionImpact: number;
  settlementImpact: number;
  openedAt: string;
  nextAction: string;
};

export type ReturnRequest = {
  id: string;
  orderId: string;
  status: string;
  product: string;
  reason: string;
  requestedAt: string;
  nextAction: string;
};

export type Refund = {
  id: string;
  orderId: string;
  status: string;
  method: string;
  amount: number;
  note: string;
  requestedAt: string;
};

export const supportOrder = {
  id: "RSR-20260713-00021",
  customer: "Nana Yaw",
  reseller: "Ama's Beauty Plug",
  supplier: "KNUST Gadgets",
  product: "Nike Air Force 1 '07 Green & White",
  deliveryArea: "Legon, Accra",
  paymentMethod: "Pay on Delivery",
  total: 385,
  productPrice: 340,
  deliveryFee: 45,
  commission: 30,
  settlementDue: 40,
  placedAt: "13 July 2026, 10:24 AM"
};

export const disputeTypes = [
  "Wrong product",
  "Damaged product",
  "Product not received",
  "Delivery issue",
  "Payment dispute",
  "Customer says payment made",
  "Supplier says customer did not pay",
  "Missing reseller commission",
  "Supplier settlement proof dispute",
  "Stock issue",
  "Price mismatch",
  "Return/refund request",
  "Customer refused delivery",
  "Product unavailable after confirmation"
];

export const disputeStatuses = [
  "Open",
  "Under Review",
  "Waiting for Customer",
  "Waiting for Supplier",
  "Waiting for Reseller",
  "Waiting for Admin",
  "Evidence Requested",
  "Resolved",
  "Rejected",
  "Escalated",
  "Closed"
];

export const returnStatuses = [
  "Return Requested",
  "Return Under Review",
  "Return Approved",
  "Return Rejected",
  "Returned to Supplier",
  "Refund Pending",
  "Refund Completed",
  "Refund Rejected"
];

export const supportTickets: SupportTicket[] = [
  {
    id: "TKT-RSR-20260713-00021",
    title: "Wrong product received",
    party: "Customer",
    relatedOrderId: supportOrder.id,
    relatedDisputeId: "DSP-RSR-20260713-00021",
    priority: "High",
    status: "Evidence Requested",
    owner: "Support Team",
    openedAt: "13 July 2026, 12:15 PM",
    summary: "Customer says the received sneaker color does not match the order."
  },
  {
    id: "TKT-COMMISSION-RSR-20260713-00021",
    title: "Missing commission after delivery",
    party: "Reseller",
    relatedOrderId: supportOrder.id,
    relatedDisputeId: "CMD-RSR-20260713-00021",
    priority: "Medium",
    status: "Waiting for Supplier",
    owner: "Finance Support",
    openedAt: "13 July 2026, 01:05 PM",
    summary: "Reseller expects commission, but supplier settlement has not been verified."
  },
  {
    id: "TKT-SETTLEMENT-RSR-20260713-00021",
    title: "Payment proof waiting for review",
    party: "Supplier",
    relatedOrderId: supportOrder.id,
    relatedDisputeId: "SDP-RSR-20260713-00021",
    priority: "High",
    status: "Waiting for Admin",
    owner: "Finance Admin",
    openedAt: "13 July 2026, 01:30 PM",
    summary: "Supplier uploaded mock settlement proof. Admin finance must verify before clearing the dispute."
  }
];

export const disputes: Dispute[] = [
  {
    id: "DSP-RSR-20260713-00021",
    type: "Wrong product",
    status: "Under Review",
    priority: "High",
    orderId: supportOrder.id,
    customer: supportOrder.customer,
    reseller: supportOrder.reseller,
    supplier: supportOrder.supplier,
    product: supportOrder.product,
    amount: supportOrder.total,
    commissionImpact: supportOrder.commission,
    settlementImpact: supportOrder.settlementDue,
    openedAt: "13 July 2026, 12:15 PM",
    nextAction: "Request clear customer photo and supplier packing note."
  },
  {
    id: "CMD-RSR-20260713-00021",
    type: "Missing reseller commission",
    status: "Waiting for Supplier",
    priority: "Medium",
    orderId: supportOrder.id,
    customer: supportOrder.customer,
    reseller: supportOrder.reseller,
    supplier: supportOrder.supplier,
    product: supportOrder.product,
    amount: supportOrder.commission,
    commissionImpact: supportOrder.commission,
    settlementImpact: supportOrder.settlementDue,
    openedAt: "13 July 2026, 01:05 PM",
    nextAction: "Verify supplier settlement before commission release."
  },
  {
    id: "SDP-RSR-20260713-00021",
    type: "Settlement proof dispute",
    status: "Waiting for Admin",
    priority: "High",
    orderId: supportOrder.id,
    customer: supportOrder.customer,
    reseller: supportOrder.reseller,
    supplier: supportOrder.supplier,
    product: supportOrder.product,
    amount: supportOrder.settlementDue,
    commissionImpact: supportOrder.commission,
    settlementImpact: supportOrder.settlementDue,
    openedAt: "13 July 2026, 01:30 PM",
    nextAction: "Admin finance verification required."
  },
  {
    id: "DSP-ESCALATED-20260713-00022",
    type: "Product unavailable after confirmation",
    status: "Escalated",
    priority: "Critical",
    orderId: "RSR-20260713-00022",
    customer: "Esi Owusu",
    reseller: "Campus Deals",
    supplier: "Tech World Ghana",
    product: "Samsung Galaxy A14",
    amount: 1050,
    commissionImpact: 95,
    settlementImpact: 120,
    openedAt: "13 July 2026, 02:20 PM",
    nextAction: "Ops manager to contact supplier and customer."
  }
];

export const returns: ReturnRequest[] = [
  {
    id: "RTN-RSR-20260713-00021",
    orderId: supportOrder.id,
    status: "Return Requested",
    product: supportOrder.product,
    reason: "Wrong product received",
    requestedAt: "13 July 2026, 12:40 PM",
    nextAction: "Review customer evidence and supplier packing note."
  },
  {
    id: "RTN-RSR-20260712-00018",
    orderId: "RSR-20260712-00018",
    status: "Return Under Review",
    product: "Oraimo Power Bank 30000mAh",
    reason: "Defective item reported",
    requestedAt: "12 July 2026, 04:15 PM",
    nextAction: "Ask supplier to inspect returned item."
  },
  {
    id: "RTN-RSR-20260711-00014",
    orderId: "RSR-20260711-00014",
    status: "Returned to Supplier",
    product: "Anua Niacinamide Serum 30ml",
    reason: "Wrong item, sealed package",
    requestedAt: "11 July 2026, 09:40 AM",
    nextAction: "Restock only after review."
  }
];

export const refunds: Refund[] = [
  {
    id: "RFD-RSR-20260713-00021",
    orderId: supportOrder.id,
    status: "Refund Pending",
    method: "Manual Pay on Delivery refund",
    amount: supportOrder.total,
    note: "Pay on Delivery refunds may be manual or off-platform.",
    requestedAt: "13 July 2026, 01:00 PM"
  },
  {
    id: "RFD-RSR-20260712-00018",
    orderId: "RSR-20260712-00018",
    status: "Refund Completed",
    method: "Manual MoMo refund record",
    amount: 210,
    note: "Admin marked this mock refund completed.",
    requestedAt: "12 July 2026, 05:20 PM"
  }
];

export const supportTimeline = [
  ["Order placed", "13 July 2026, 10:24 AM"],
  ["Customer reported issue", "13 July 2026, 12:15 PM"],
  ["Evidence requested", "13 July 2026, 12:20 PM"],
  ["Supplier notified", "13 July 2026, 12:35 PM"],
  ["Admin review pending", "Current step"]
] as const;

export const returnRules = [
  ["Shoes and clothing", "Return if wrong size/item or supplier fault."],
  ["Beauty/skincare", "Return only if sealed/unopened unless wrong or damaged."],
  ["Phone accessories", "Return if wrong model or defective."],
  ["Pay on Delivery", "Refund handling may be manual/admin-controlled."]
] as const;

export function getTicket(id: string) {
  const normalized = id.toUpperCase();
  return supportTickets.find((ticket) => ticket.id === normalized) ?? supportTickets[0];
}

export function getDispute(id: string) {
  const normalized = id.toUpperCase();
  return disputes.find((dispute) => dispute.id === normalized) ?? disputes[0];
}

export function getReturnRequest(id: string) {
  const normalized = id.toUpperCase();
  return returns.find((item) => item.id === normalized) ?? returns[0];
}

export function getRefund(id: string) {
  const normalized = id.toUpperCase();
  return refunds.find((item) => item.id === normalized) ?? refunds[0];
}
