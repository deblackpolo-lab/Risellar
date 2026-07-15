export const sampleOrders = [
  {
    id: "RSR-250518-8842",
    customer: "Ama Serwaa",
    reseller: "Kofi Mensah",
    supplier: "KNUST Gadgets",
    status: "Awaiting Customer Confirmation",
    deliveryStatus: "Delivery Quote Pending",
    total: "GH₵385",
    product: "Nike Air Force 1 '07 Green & White"
  },
  {
    id: "RSR-250518-8799",
    customer: "Kofi Appiah",
    reseller: "Esi Owusu",
    supplier: "Beauty Central GH",
    status: "Delivery Approved",
    deliveryStatus: "Preparing",
    total: "GH₵360",
    product: "The Ordinary Skincare Set"
  }
];

export const sampleTimelineEvents = [
  { label: "Order placed", time: "13 May 2025, 10:24 AM", status: "Completed" },
  { label: "Awaiting Confirmation", time: "13 May 2025, 10:25 AM", status: "Awaiting Confirmation" },
  { label: "Customer Confirmed", time: "13 May 2025, 10:36 AM", status: "Customer Confirmed" },
  { label: "Delivery Quote Pending", time: "13 May 2025, 10:42 AM", status: "Delivery Quote Pending" },
  { label: "Preparing", time: "13 May 2025, 12:15 PM", status: "Preparing" },
  { label: "Out for Delivery", time: "Pending", status: "Out for Delivery" }
];

export const sampleDeliveryOptions = [
  { name: "Express Delivery", price: "GH₵50 - 100", timing: "1-3 hours", status: "Delivery Quote Pending" },
  { name: "Standard Delivery", price: "GH₵20 - 40", timing: "2-3 days", status: "Delivery Approved" }
];

export const samplePaymentMethods = [
  { name: "Pay on Delivery", detail: "Customer pays when the item arrives.", status: "Active" },
  { name: "MTN MoMo", detail: "Used for supplier settlements and reseller withdrawals.", status: "Pending Approval" }
];
