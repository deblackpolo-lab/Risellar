import { adminOrders, adminProducts, formatGhc } from "@/lib/mock/admin-core";

export type Priority = "Low" | "Medium" | "High" | "Critical";
export type QueueStatus = "Open" | "In Review" | "Waiting" | "Resolved";
export type RiskEntityType = "suppliers" | "resellers" | "customers" | "products";

export type AdminQueueItem = {
  id: string;
  priority: Priority;
  status: QueueStatus;
  relatedEntity: string;
  age: string;
  assignedAdmin: string;
  dueTime: string;
  recommendedAction: string;
  href?: string;
  customer?: string;
  contact?: string;
  product?: string;
  reseller?: string;
  supplier?: string;
  orderId?: string;
  amount?: number;
  metadata: Array<[string, string]>;
};

export type AdminOperationQueue = {
  slug: string;
  title: string;
  description: string;
  count: number;
  priority: Priority;
  summary: string;
  actions: string[];
  items: AdminQueueItem[];
};

export type RiskEntity = {
  id: string;
  name: string;
  type: RiskEntityType;
  score: number;
  level: "Low" | "Medium" | "High" | "Critical";
  triggerCount: number;
  restrictionStatus: string;
  recommendedAction: string;
  details: Array<[string, string]>;
};

export const operationsMetrics = [
  { label: "Customer confirmations", value: "18", priority: "High" },
  { label: "Delivery quotes pending", value: "9", priority: "Medium" },
  { label: "Settlement due", value: "24", priority: "High" },
  { label: "Overdue settlements", value: "6", priority: "Critical" },
  { label: "Commission release", value: "14", priority: "Medium" },
  { label: "Product approvals", value: "12", priority: "Medium" },
  { label: "Supplier approvals", value: "5", priority: "High" },
  { label: "Disputes", value: "7", priority: "High" },
  { label: "Failed deliveries", value: "4", priority: "High" },
  { label: "Stock issues", value: "11", priority: "Medium" },
  { label: "Promotion approvals", value: "8", priority: "Medium" },
  { label: "Risk reviews", value: "10", priority: "High" }
];

const baseOrder = adminOrders[0];
const baseProduct = adminProducts[0];

export const whatsappTemplates = [
  {
    type: "customer confirmation",
    title: "Customer Confirmation",
    body: `Hi Nana Yaw, please confirm your Risellar order ${baseOrder.displayId} for ${baseOrder.product}. Your item is reserved for 1 hour.`
  },
  {
    type: "delivery quote",
    title: "Delivery Quote",
    body: `Your delivery quote to ${baseOrder.location} is ${formatGhc(baseOrder.financials.deliveryFee)}. Reply YES to approve before dispatch.`
  },
  {
    type: "supplier preparation",
    title: "Supplier Preparation",
    body: `KNUST Gadgets, please prepare ${baseOrder.product} after customer confirmation. Do not dispatch before delivery quote approval.`
  },
  {
    type: "supplier settlement due",
    title: "Settlement Due",
    body: `KNUST Gadgets, settlement of ${formatGhc(40)} is due for ${baseOrder.displayId}. Please send Risellar share and upload proof.`
  },
  {
    type: "overdue settlement warning",
    title: "Overdue Settlement Warning",
    body: `KNUST Gadgets, your settlement is overdue. Continued delay may restrict product visibility and new orders.`
  },
  {
    type: "dispute follow-up",
    title: "Dispute Follow-up",
    body: `We are reviewing dispute DSP-RSR-20260713-00021. Please provide the requested evidence so the support team can resolve it.`
  }
];

export const adminOperationQueues: AdminOperationQueue[] = [
  {
    slug: "customer-confirmations",
    title: "Customer Confirmation Queue",
    description: "Orders awaiting customer confirmation before supplier preparation.",
    count: 18,
    priority: "High",
    summary: "Pending confirmation summary",
    actions: ["Copy WhatsApp confirmation", "Mark Confirmed", "Cancel/Expire Order", "View Order"],
    items: [
      {
        id: "RSR-20260713-00021",
        priority: "High",
        status: "Open",
        relatedEntity: "Nana Yaw order",
        age: "46 min open",
        assignedAdmin: "Kwame Admin",
        dueTime: "14 min left",
        recommendedAction: "Send confirmation reminder before reservation expires.",
        href: "/admin/operations/customer-confirmations/rsr-20260713-00021",
        customer: "Nana Yaw",
        contact: "+233 24 123 4567",
        product: baseOrder.product,
        reseller: baseOrder.reseller,
        orderId: baseOrder.displayId,
        metadata: [
          ["Customer name/contact summary", "Nana Yaw • +233 24 123 4567"],
          ["Product", baseOrder.product],
          ["Reseller", baseOrder.reseller],
          ["Stock reservation expiry", "14 min left"],
          ["Confirmation deadline", "Today, 11:24 AM"]
        ]
      }
    ]
  },
  {
    slug: "supplier-availability",
    title: "Supplier Availability Queue",
    description: "Suppliers who need to confirm stock and ability to fulfill.",
    count: 8,
    priority: "Medium",
    summary: "Supplier availability checks",
    actions: ["Ask Supplier to Confirm", "Mark Available", "Mark Unavailable", "View Supplier"],
    items: [{ id: "SUP-AVL-004", priority: "Medium", status: "Waiting", relatedEntity: "Palace Beauty Supplies", age: "1h open", assignedAdmin: "Esi Ops", dueTime: "Today", recommendedAction: "Confirm stock before order preparation.", supplier: "Palace Beauty Supplies", metadata: [["Supplier", "Palace Beauty Supplies"], ["Product", "Anua Niacinamide Serum 30ml"], ["Area", "Accra"]] }]
  },
  {
    slug: "supplier-preparation",
    title: "Supplier Preparation Queue",
    description: "Confirmed orders waiting for suppliers to prepare items.",
    count: 10,
    priority: "Medium",
    summary: "Supplier preparation follow-up",
    actions: ["Send Preparation Template", "Mark Ready", "Escalate Delay", "View Order"],
    items: [{ id: "PREP-20260713-003", priority: "Medium", status: "In Review", relatedEntity: "KNUST Gadgets", age: "2h open", assignedAdmin: "Kwame Admin", dueTime: "Today", recommendedAction: "Ask supplier for preparation status.", supplier: "KNUST Gadgets", orderId: "RSR-20260713-00021", metadata: [["Supplier", "KNUST Gadgets"], ["Product", baseOrder.product], ["Preparation SLA", "Same day"]] }]
  },
  {
    slug: "delivery-quotes",
    title: "Delivery Quote Queue",
    description: "Orders needing final delivery quote approval before dispatch.",
    count: 9,
    priority: "Medium",
    summary: "Delivery quote pending summary",
    actions: ["Send Quote Template", "Mark Quote Approved", "Mark Quote Rejected", "View Order"],
    items: [{ id: "DLQ-RSR-20260713-00021", priority: "Medium", status: "Open", relatedEntity: "Legon delivery quote", age: "32 min open", assignedAdmin: "Esi Ops", dueTime: "Today", recommendedAction: "Confirm final delivery cost with customer.", orderId: baseOrder.displayId, amount: 45, metadata: [["Customer area", "Legon, Accra"], ["Supplier area", "Kumasi, Ashanti Region"], ["Selected delivery estimate", "Standard delivery GH₵20 - GH₵40"], ["Proposed final quote", formatGhc(45)]] }]
  },
  {
    slug: "settlement-due",
    title: "Settlement Due Queue",
    description: "Supplier settlements due after Pay on Delivery collection.",
    count: 24,
    priority: "High",
    summary: "Settlement due today",
    actions: ["Send Reminder Template", "View Settlement", "Mark Proof Received", "Contact Supplier"],
    items: [{ id: "STL-RSR-20260713-00034", priority: "High", status: "Open", relatedEntity: "Palace Beauty Supplies", age: "4h open", assignedAdmin: "Finance Team", dueTime: "Today", recommendedAction: "Send settlement reminder and request proof.", supplier: "Palace Beauty Supplies", orderId: "RSR-20260713-00034", amount: 40, metadata: [["Customer paid amount", formatGhc(180)], ["Supplier base amount", formatGhc(120)], ["Amount due to Risellar", formatGhc(25)], ["Days due/overdue", "Due today"], ["Settlement status", "Due"], ["Supplier trust score", "94/100"], ["Restriction recommendation", "Reminder only"]] }]
  },
  {
    slug: "overdue-settlements",
    title: "Overdue Settlements Queue",
    description: "Overdue supplier balances that may affect restrictions.",
    count: 6,
    priority: "Critical",
    summary: "Overdue settlement warning",
    actions: ["Send Reminder Template", "View Settlement", "Mark Proof Received", "Restrict Supplier", "Contact Supplier"],
    items: [{ id: "STL-RSR-20260713-00021", priority: "Critical", status: "Open", relatedEntity: "KNUST Gadgets", age: "2 days open", assignedAdmin: "Finance Team", dueTime: "Overdue", recommendedAction: "Warn supplier and prepare restriction review.", href: "/admin/operations/overdue-settlements/stl-rsr-20260713-00021", supplier: "KNUST Gadgets", orderId: baseOrder.displayId, amount: 40, metadata: [["Customer paid amount", formatGhc(385)], ["Supplier base amount", formatGhc(300)], ["Amount due to Risellar", formatGhc(40)], ["Days due/overdue", "2 days overdue"], ["Settlement status", "Overdue"], ["Supplier trust score", "88/100"], ["Restriction recommendation", "Limited visibility if unpaid today"]] }]
  },
  {
    slug: "commission-release",
    title: "Commission Release Queue",
    description: "Commissions waiting on verified supplier settlement.",
    count: 14,
    priority: "Medium",
    summary: "Commission release summary",
    actions: ["Release Commission", "View Settlement", "View Reseller"],
    items: [{ id: "COM-RSR-20260713-00021", priority: "Medium", status: "Waiting", relatedEntity: "Ama's Beauty Plug", age: "1 day open", assignedAdmin: "Finance Team", dueTime: "After verification", recommendedAction: "Hold commission until settlement is verified.", reseller: "Ama's Beauty Plug", orderId: baseOrder.displayId, amount: 30, metadata: [["Reseller", "Ama's Beauty Plug"], ["Order", baseOrder.displayId], ["Settlement status", "Overdue"], ["Commission amount", formatGhc(30)], ["Release readiness", "Not ready"]] }]
  },
  {
    slug: "product-approvals",
    title: "Product Approval Queue",
    description: "Supplier products awaiting marketplace review.",
    count: 12,
    priority: "Medium",
    summary: "Product approval summary",
    actions: ["Approve", "Reject", "Request Changes"],
    items: [{ id: "PRD-NIKE-AF1", priority: "Medium", status: "In Review", relatedEntity: baseProduct.name, age: "5h open", assignedAdmin: "Catalog Team", dueTime: "Today", recommendedAction: "Review product details and risk flags.", product: baseProduct.name, supplier: "KNUST Gadgets", amount: 300, metadata: [["Product name", baseProduct.name], ["Supplier", "KNUST Gadgets"], ["Category", "Sneakers"], ["Base price", formatGhc(300)], ["Platform margin", formatGhc(10)], ["Stock", "18"], ["Images placeholder", "3 images ready for review"], ["Risk flags", "Brand authenticity check"]] }]
  },
  {
    slug: "supplier-approvals",
    title: "Supplier Approval Queue",
    description: "Supplier onboarding profiles awaiting review.",
    count: 5,
    priority: "High",
    summary: "Supplier approval summary",
    actions: ["Approve Supplier", "Request More Info", "Reject"],
    items: [{ id: "SUP-APP-KNUST", priority: "High", status: "In Review", relatedEntity: "KNUST Gadgets", age: "1 day open", assignedAdmin: "Kwame Admin", dueTime: "Today", recommendedAction: "Review documents and category risk.", supplier: "KNUST Gadgets", metadata: [["Supplier name", "KNUST Gadgets"], ["Owner", "Kofi Mensah"], ["Location", "Kumasi"], ["Category", "Electronics & Sneakers"], ["Document status placeholder", "Ghana Card uploaded"], ["Agreement accepted", "Yes"], ["Risk flags", "Electronics category review"]] }]
  },
  {
    slug: "withdrawal-requests",
    title: "Withdrawal Request Queue",
    description: "Reseller withdrawal requests for available commissions.",
    count: 6,
    priority: "Medium",
    summary: "Withdrawal requests",
    actions: ["Approve", "Reject", "Mark Paid"],
    items: [{ id: "WDL-AMA-204", priority: "Medium", status: "Open", relatedEntity: "Ama's Beauty Plug", age: "3h open", assignedAdmin: "Finance Team", dueTime: "Today", recommendedAction: "Check available balance and MoMo details.", reseller: "Ama's Beauty Plug", amount: 900, metadata: [["Reseller", "Ama's Beauty Plug"], ["Requested amount", formatGhc(900)], ["Available balance", formatGhc(930)], ["MoMo number/name", "MTN MoMo • Ama Serwaa"], ["Status", "Open"], ["Risk flags", "None"]] }]
  },
  {
    slug: "disputes",
    title: "Disputes Queue",
    description: "Open disputes and support cases requiring admin follow-up.",
    count: 7,
    priority: "High",
    summary: "Disputes and failed delivery summary",
    actions: ["Assign", "Request Evidence", "Resolve"],
    items: [{ id: "DSP-RSR-20260713-00021", priority: "High", status: "Open", relatedEntity: baseOrder.displayId, age: "2h open", assignedAdmin: "Support Team", dueTime: "Today", recommendedAction: "Request evidence from customer and supplier.", href: "/admin/operations/disputes/dsp-rsr-20260713-00021", customer: "Nana Yaw", orderId: baseOrder.displayId, metadata: [["Dispute id", "DSP-RSR-20260713-00021"], ["Order id", baseOrder.displayId], ["Dispute type", "Delivery quote dispute"], ["Opened by", "Customer"], ["Involved parties", "Nana Yaw, Ama's Beauty Plug, KNUST Gadgets"], ["Status", "Open"], ["Priority", "High"]] }]
  },
  {
    slug: "failed-deliveries",
    title: "Failed Deliveries Queue",
    description: "Failed delivery attempts needing customer/supplier coordination.",
    count: 4,
    priority: "High",
    summary: "Failed deliveries",
    actions: ["Follow Up", "Reschedule", "Open Dispute", "View Order"],
    items: [{ id: "FD-RSR-20260712-00018", priority: "High", status: "Open", relatedEntity: "Esi Owusu delivery", age: "6h open", assignedAdmin: "Support Team", dueTime: "Today", recommendedAction: "Call customer and reschedule delivery.", customer: "Esi Owusu", reseller: "Akwasi Deals", supplier: "Beautiful Living Store", orderId: "RSR-20260712-00018", amount: 30, metadata: [["Order id", "RSR-20260712-00018"], ["Reason", "Customer unavailable"], ["Customer", "Esi Owusu"], ["Reseller", "Akwasi Deals"], ["Supplier", "Beautiful Living Store"], ["Delivery quote", formatGhc(30)], ["Next action", "Reschedule"], ["Customer risk impact", "Low unless repeated"]] }]
  },
  {
    slug: "stock-issues",
    title: "Stock Issues Queue",
    description: "Stock mismatches, reservations, and supplier availability issues.",
    count: 11,
    priority: "Medium",
    summary: "Stock issues",
    actions: ["Hide Product", "Ask Supplier to Restock", "View Inventory"],
    items: [{ id: "STK-NIKE-AF1", priority: "High", status: "Open", relatedEntity: baseProduct.name, age: "1h open", assignedAdmin: "Inventory Team", dueTime: "Today", recommendedAction: "Confirm stock and hide listing if mismatch persists.", product: baseProduct.name, supplier: "KNUST Gadgets", metadata: [["Product", baseProduct.name], ["Supplier", "KNUST Gadgets"], ["Stock issue type", "Stock mismatch"], ["Affected reseller listings", "36"], ["Affected orders", "2"], ["Recommended action", "Ask Supplier to Restock"]] }]
  },
  {
    slug: "promotion-approvals",
    title: "Promotion Approval Queue",
    description: "Supplier boost requests awaiting eligibility checks.",
    count: 8,
    priority: "Medium",
    summary: "Promotion approvals",
    actions: ["Approve Boost", "Reject", "Pause"],
    items: [{ id: "PROMO-NIKE-AF1", priority: "Medium", status: "In Review", relatedEntity: baseProduct.name, age: "4h open", assignedAdmin: "Growth Team", dueTime: "Today", recommendedAction: "Check eligibility before approving sponsored placement.", product: baseProduct.name, supplier: "KNUST Gadgets", amount: 20, metadata: [["Supplier", "KNUST Gadgets"], ["Product", baseProduct.name], ["Promotion package", "Featured product boost"], ["Amount", formatGhc(20)], ["Payment/proof placeholder", "MoMo receipt pending"], ["Product approved", "Yes"], ["In stock", "Yes"], ["No overdue settlement", "No"], ["Supplier verified", "Yes"], ["Complaint rate acceptable", "Yes"]] }]
  }
];

export const riskEntities: RiskEntity[] = [
  { id: "knust-gadgets", name: "KNUST Gadgets", type: "suppliers", score: 72, level: "High", triggerCount: 6, restrictionStatus: "Limited monitoring", recommendedAction: "Send settlement warning and review product visibility.", details: [["Risk score", "72/100"], ["Overdue settlements", "GH₵320"], ["Dispute count", "2"], ["Stock issues", "3"], ["Complaint rate", "4.2%"], ["Restriction recommendation", "Limit boosts until settlement clears"]] },
  { id: "palace-beauty-supplies", name: "Palace Beauty Supplies", type: "suppliers", score: 24, level: "Low", triggerCount: 1, restrictionStatus: "None", recommendedAction: "Monitor normally.", details: [["Risk score", "24/100"], ["Overdue settlements", "GH₵0"], ["Dispute count", "0"], ["Stock issues", "1"], ["Complaint rate", "1.1%"], ["Restriction recommendation", "None"]] },
  { id: "amas-beauty-plug", name: "Ama's Beauty Plug", type: "resellers", score: 38, level: "Medium", triggerCount: 3, restrictionStatus: "None", recommendedAction: "Monitor commission disputes.", details: [["Risk score", "38/100"], ["Cancelled orders", "1"], ["Dispute count", "1"], ["Complaint rate", "2.4%"]] },
  { id: "nana-yaw", name: "Nana Yaw", type: "customers", score: 19, level: "Low", triggerCount: 1, restrictionStatus: "None", recommendedAction: "No action needed.", details: [["Risk score", "19/100"], ["Refused deliveries", "0"], ["Cancelled orders", "1"]] },
  { id: "nike-air-force-1-07-green-white", name: baseProduct.name, type: "products", score: 61, level: "High", triggerCount: 4, restrictionStatus: "Review required", recommendedAction: "Review authenticity and stock.", details: [["Risk score", "61/100"], ["Risk flags", "Brand authenticity, stock mismatch"], ["Affected listings", "36"]] }
];

export const riskEvents = [
  "KNUST Gadgets settlement became overdue",
  "Nike Air Force 1 stock mismatch reported",
  "Dispute opened for RSR-20260713-00021",
  "Manual override reviewed by Kwame Admin"
];

export const auditLogs = [
  { timestamp: "13 Jul 2026, 10:28 AM", actor: "Kwame Admin", role: "Admin", action: "product approved", entity: "Nike Air Force 1 '07", oldValue: "Pending Approval", newValue: "Approved", reason: "Catalog review completed", sensitive: false },
  { timestamp: "13 Jul 2026, 10:45 AM", actor: "Finance Team", role: "Finance", action: "settlement proof submitted", entity: "STL-RSR-20260713-00021", oldValue: "Due", newValue: "Proof Submitted", reason: "Supplier uploaded receipt metadata", sensitive: true },
  { timestamp: "13 Jul 2026, 11:10 AM", actor: "Kwame Admin", role: "Admin", action: "supplier restricted", entity: "KNUST Gadgets", oldValue: "Verified", newValue: "Limited", reason: "Overdue settlement threshold", sensitive: true },
  { timestamp: "13 Jul 2026, 11:20 AM", actor: "Finance Team", role: "Finance", action: "settlement verified", entity: "STL-OLD-104", oldValue: "Verifying", newValue: "Paid", reason: "Reference matched bank statement", sensitive: true },
  { timestamp: "13 Jul 2026, 11:32 AM", actor: "Finance Team", role: "Finance", action: "commission released", entity: "COM-OLD-104", oldValue: "Pending", newValue: "Available", reason: "Settlement verified", sensitive: true },
  { timestamp: "13 Jul 2026, 12:05 PM", actor: "Inventory Team", role: "Operations", action: "stock adjusted", entity: "Nike Air Force 1 '07", oldValue: "20", newValue: "18", reason: "Reservation reconciliation", sensitive: false },
  { timestamp: "13 Jul 2026, 12:21 PM", actor: "Esi Ops", role: "Operations", action: "delivery quote approved", entity: "RSR-20260713-00021", oldValue: "Pending", newValue: "Approved", reason: "Customer accepted final quote", sensitive: false },
  { timestamp: "13 Jul 2026, 12:30 PM", actor: "Super Admin", role: "Super Admin", action: "manual override performed", entity: "RSR-20260713-00021", oldValue: "Waiting", newValue: "In Review", reason: "Mock emergency correction", sensitive: true }
];

export const manualOverrideExamples = [
  "change order status",
  "adjust settlement amount",
  "release commission manually",
  "cancel order",
  "restrict supplier",
  "reopen dispute",
  "adjust stock"
];

export function getAdminOperationQueue(slug: string) {
  return adminOperationQueues.find((queue) => queue.slug === slug) ?? adminOperationQueues[0];
}

export function getAdminOperationItem(queueSlug: string, itemId: string) {
  const queue = getAdminOperationQueue(queueSlug);
  return queue.items.find((item) => item.id.toLowerCase() === itemId.toLowerCase() || item.id.toLowerCase().replace(/^stl-|^dsp-/, "") === itemId.toLowerCase()) ?? queue.items[0];
}

export function getAdminRiskEntities(type: RiskEntityType) {
  return riskEntities.filter((entity) => entity.type === type);
}

export function getAdminRiskEntity(type: RiskEntityType, id: string) {
  return getAdminRiskEntities(type).find((entity) => entity.id === id) ?? getAdminRiskEntities(type)[0] ?? riskEntities[0];
}
