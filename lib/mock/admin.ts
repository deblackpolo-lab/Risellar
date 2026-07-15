export const sampleAdminQueues = [
  { title: "Customer Confirmation Queue", count: 86, status: "Awaiting Confirmation", priority: "High" },
  { title: "Supplier Approval Queue", count: 22, status: "Pending Approval", priority: "Medium" },
  { title: "Proof Verification", count: 11, status: "Verifying", priority: "High" }
];

export const sampleAuditLogItems = [
  { actor: "Kwame Mensah", action: "Approved product", target: "Nike Air Force 1 '07", time: "10:28 AM" },
  { actor: "Akua Boating", action: "Updated stock", target: "Oraimo Power Bank", time: "09:58 AM" },
  { actor: "Admin", action: "Marked settlement paid", target: "SET-8842", time: "09:42 AM" }
];

export const sampleWhatsAppTemplates = [
  {
    title: "Customer confirmation",
    channel: "WhatsApp",
    body: "Hi Ama, please confirm your Risellar order so the supplier can prepare it."
  },
  {
    title: "Delivery quote ready",
    channel: "WhatsApp",
    body: "Your delivery quote is ready for review before dispatch."
  }
];

export const sampleRiskActions = [
  { label: "Supplier Restricted", value: "6 accounts", status: "Supplier Restricted" },
  { label: "Manual override", value: "2 today", status: "More Info Required" }
];
