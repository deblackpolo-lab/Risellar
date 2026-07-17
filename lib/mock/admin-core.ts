import { getMockProductImages, getPrimaryProductImageAlt, type MockProductImage } from "@/lib/mock/product-images";

export type MoneyBreakdown = {
  supplierBase: number;
  platformMargin: number;
  resellerMargin: number;
  customerProductPrice: number;
  deliveryFee: number;
  totalPayOnDelivery: number;
};

export type AdminMetric = {
  label: string;
  value: string;
  trend: string;
};

export type AdminOrder = {
  id: string;
  displayId: string;
  date: string;
  customer: string;
  customerId: string;
  reseller: string;
  resellerId: string;
  supplier: string;
  supplierId: string;
  product: string;
  productId: string;
  location: string;
  payment: string;
  status: string;
  settlement: string;
  confirmation: string;
  delivery: string;
  financials: MoneyBreakdown;
  timeline: Array<{ label: string; value: string; status: string }>;
};

export type AdminProduct = {
  id: string;
  name: string;
  imageAlt: string;
  images: MockProductImage[];
  supplier: string;
  supplierId: string;
  category: string;
  status: string;
  approval: string;
  stock: number;
  activeResellers: number;
  risk: string;
  price: MoneyBreakdown;
};

export type AdminSupplier = {
  id: string;
  name: string;
  owner: string;
  location: string;
  category: string;
  status: string;
  products: number;
  settlementDue: number;
  overdue: number;
  trustScore: string;
};

export type AdminReseller = {
  id: string;
  name: string;
  owner: string;
  location: string;
  status: string;
  orders: number;
  commissionPending: number;
  commissionAvailable: number;
  trustScore: string;
};

export type AdminCustomer = {
  id: string;
  name: string;
  phone: string;
  location: string;
  status: string;
  orders: number;
  totalPaid: number;
  lastOrder: string;
};

export type AdminFinanceRow = {
  id: string;
  party: string;
  orderId: string;
  amount: number;
  status: string;
  note: string;
};

export type AdminSupportTicket = {
  id: string;
  title: string;
  customer: string;
  priority: string;
  status: string;
  owner: string;
};

export const adminMetrics: AdminMetric[] = [
  { label: "Total orders", value: "248", trend: "+18.6% this month" },
  { label: "Pending confirmations", value: "18", trend: "Needs follow-up" },
  { label: "Settlement due", value: "GH₵4,850", trend: "48 settlements" },
  { label: "Overdue settlements", value: "GH₵1,350", trend: "12 overdue" },
  { label: "Pending reseller commissions", value: "GH₵3,420", trend: "Awaiting settlement" },
  { label: "Active suppliers", value: "42", trend: "+5 active" },
  { label: "Active resellers", value: "318", trend: "+24 active" },
  { label: "Products pending approval", value: "14", trend: "Review queue" }
];

export const adminOrders: AdminOrder[] = [
  {
    id: "rsr-20260713-00021",
    displayId: "RSR-20260713-00021",
    date: "13 Jul 2026, 10:24 AM",
    customer: "Nana Yaw",
    customerId: "nana-yaw",
    reseller: "Ama's Beauty Plug",
    resellerId: "amas-beauty-plug",
    supplier: "KNUST Gadgets",
    supplierId: "knust-gadgets",
    product: "Nike Air Force 1 '07 Green & White",
    productId: "nike-air-force-1-07-green-white",
    location: "Legon, Accra",
    payment: "Pay on Delivery",
    status: "Pending Confirmation",
    settlement: "Settlement Due",
    confirmation: "Customer confirmation pending",
    delivery: "Standard delivery estimate pending supplier approval",
    financials: { supplierBase: 300, platformMargin: 10, resellerMargin: 30, customerProductPrice: 340, deliveryFee: 45, totalPayOnDelivery: 385 },
    timeline: [
      { label: "Order placed", value: "13 Jul 2026, 10:24 AM", status: "Completed" },
      { label: "Customer confirmation", value: "Waiting on customer", status: "Pending" },
      { label: "Supplier preparation", value: "Starts after confirmation", status: "Pending" },
      { label: "Delivery quote", value: "Before dispatch", status: "Pending" },
      { label: "Settlement", value: "Due after supplier receives payment", status: "Settlement Due" }
    ]
  },
  {
    id: "rsr-20260713-00034",
    displayId: "RSR-20260713-00034",
    date: "13 Jul 2026, 11:12 AM",
    customer: "Ama Serwaa",
    customerId: "ama-serwaa",
    reseller: "Campus Finds GH",
    resellerId: "campus-finds-gh",
    supplier: "Palace Beauty Supplies",
    supplierId: "palace-beauty-supplies",
    product: "Anua Niacinamide Serum 30ml",
    productId: "anua-niacinamide-serum-30ml",
    location: "Madina, Accra",
    payment: "Pay on Delivery",
    status: "Preparing",
    settlement: "Pending",
    confirmation: "Confirmed by customer",
    delivery: "Next day delivery selected",
    financials: { supplierBase: 120, platformMargin: 5, resellerMargin: 20, customerProductPrice: 145, deliveryFee: 35, totalPayOnDelivery: 180 },
    timeline: [
      { label: "Order placed", value: "13 Jul 2026, 11:12 AM", status: "Completed" },
      { label: "Customer confirmation", value: "13 Jul 2026, 11:30 AM", status: "Completed" },
      { label: "Supplier preparation", value: "In progress", status: "Preparing" }
    ]
  },
  {
    id: "rsr-20260712-00018",
    displayId: "RSR-20260712-00018",
    date: "12 Jul 2026, 4:45 PM",
    customer: "Esi Owusu",
    customerId: "esi-owusu",
    reseller: "Akwasi Deals",
    resellerId: "akwasi-deals",
    supplier: "Beautiful Living Store",
    supplierId: "beautiful-living-store",
    product: "Hostel Essentials Pack",
    productId: "hostel-essentials-pack",
    location: "Kumasi, Ashanti Region",
    payment: "Pay on Delivery",
    status: "Completed",
    settlement: "Paid",
    confirmation: "Confirmed",
    delivery: "Delivered",
    financials: { supplierBase: 150, platformMargin: 10, resellerMargin: 25, customerProductPrice: 185, deliveryFee: 30, totalPayOnDelivery: 215 },
    timeline: [{ label: "Delivered", value: "13 Jul 2026, 6:20 PM", status: "Completed" }]
  }
];

export const adminProducts: AdminProduct[] = [
  {
    id: "nike-air-force-1-07-green-white",
    name: "Nike Air Force 1 '07 Green & White",
    imageAlt: getPrimaryProductImageAlt("Nike Air Force 1 '07 Green & White"),
    images: getMockProductImages("nike-air-force-1-07-green-white"),
    supplier: "KNUST Gadgets",
    supplierId: "knust-gadgets",
    category: "Sneakers",
    status: "Active",
    approval: "Needs Review",
    stock: 18,
    activeResellers: 36,
    risk: "Low",
    price: { supplierBase: 300, platformMargin: 10, resellerMargin: 30, customerProductPrice: 340, deliveryFee: 45, totalPayOnDelivery: 385 }
  },
  {
    id: "anua-niacinamide-serum-30ml",
    name: "Anua Niacinamide Serum 30ml",
    imageAlt: getPrimaryProductImageAlt("Anua Niacinamide Serum 30ml"),
    images: getMockProductImages("anua-niacinamide-serum-30ml"),
    supplier: "Palace Beauty Supplies",
    supplierId: "palace-beauty-supplies",
    category: "Beauty",
    status: "Active",
    approval: "Approved",
    stock: 24,
    activeResellers: 52,
    risk: "Low",
    price: { supplierBase: 120, platformMargin: 5, resellerMargin: 20, customerProductPrice: 145, deliveryFee: 35, totalPayOnDelivery: 180 }
  },
  {
    id: "hostel-essentials-pack",
    name: "Hostel Essentials Pack",
    imageAlt: getPrimaryProductImageAlt("Hostel Essentials Pack"),
    images: getMockProductImages("hostel-essentials-pack"),
    supplier: "Beautiful Living Store",
    supplierId: "beautiful-living-store",
    category: "Home & Living",
    status: "Active",
    approval: "Approved",
    stock: 32,
    activeResellers: 18,
    risk: "Low",
    price: { supplierBase: 150, platformMargin: 10, resellerMargin: 25, customerProductPrice: 185, deliveryFee: 30, totalPayOnDelivery: 215 }
  }
];

export const adminSuppliers: AdminSupplier[] = [
  { id: "knust-gadgets", name: "KNUST Gadgets", owner: "Kofi Mensah", location: "Kumasi, Ashanti Region", category: "Electronics & Sneakers", status: "Verified", products: 18, settlementDue: 1350, overdue: 320, trustScore: "88/100" },
  { id: "palace-beauty-supplies", name: "Palace Beauty Supplies", owner: "Akua Boateng", location: "Accra", category: "Beauty", status: "Verified", products: 42, settlementDue: 820, overdue: 0, trustScore: "94/100" },
  { id: "beautiful-living-store", name: "Beautiful Living Store", owner: "Yaw Addo", location: "Madina, Accra", category: "Home & Living", status: "Verified", products: 25, settlementDue: 600, overdue: 0, trustScore: "90/100" }
];

export const adminResellers: AdminReseller[] = [
  { id: "amas-beauty-plug", name: "Ama's Beauty Plug", owner: "Ama Serwaa", location: "Legon, Accra", status: "Active", orders: 56, commissionPending: 320, commissionAvailable: 930, trustScore: "92/100" },
  { id: "campus-finds-gh", name: "Campus Finds GH", owner: "Kojo Asante", location: "KNUST, Kumasi", status: "Active", orders: 38, commissionPending: 180, commissionAvailable: 540, trustScore: "89/100" },
  { id: "akwasi-deals", name: "Akwasi Deals", owner: "Akwasi Appiah", location: "Madina, Accra", status: "Restricted", orders: 22, commissionPending: 90, commissionAvailable: 0, trustScore: "71/100" }
];

export const adminCustomers: AdminCustomer[] = [
  { id: "nana-yaw", name: "Nana Yaw", phone: "+233 24 123 4567", location: "Legon, Accra", status: "Active", orders: 4, totalPaid: 1180, lastOrder: "RSR-20260713-00021" },
  { id: "ama-serwaa", name: "Ama Serwaa", phone: "+233 20 987 4412", location: "Madina, Accra", status: "Active", orders: 3, totalPaid: 690, lastOrder: "RSR-20260713-00034" },
  { id: "esi-owusu", name: "Esi Owusu", phone: "+233 55 212 9811", location: "Kumasi", status: "Active", orders: 5, totalPaid: 1450, lastOrder: "RSR-20260712-00018" }
];

export const adminSettlements: AdminFinanceRow[] = [
  { id: "stl-001", party: "KNUST Gadgets", orderId: "RSR-20260713-00021", amount: 320, status: "Overdue", note: "Supplier received customer payment; settlement still outstanding." },
  { id: "stl-002", party: "Palace Beauty Supplies", orderId: "RSR-20260713-00034", amount: 40, status: "Due", note: "Due after delivery collection is confirmed." },
  { id: "stl-003", party: "Beautiful Living Store", orderId: "RSR-20260712-00018", amount: 28, status: "Paid", note: "Proof verified by admin mock record." }
];

export const adminCommissions: AdminFinanceRow[] = [
  { id: "com-001", party: "Ama's Beauty Plug", orderId: "RSR-20260713-00021", amount: 30, status: "Pending", note: "Commission locked until supplier settlement is verified." },
  { id: "com-002", party: "Campus Finds GH", orderId: "RSR-20260713-00034", amount: 20, status: "Pending", note: "Waiting on supplier settlement." },
  { id: "com-003", party: "Akwasi Deals", orderId: "RSR-20260712-00018", amount: 25, status: "Released", note: "Released after verified settlement." }
];

export const adminWithdrawals: AdminFinanceRow[] = [
  { id: "wd-001", party: "Ama's Beauty Plug", orderId: "Batch WDL-204", amount: 900, status: "Ready", note: "Mock available wallet balance." },
  { id: "wd-002", party: "Akwasi Deals", orderId: "Batch WDL-198", amount: 240, status: "Failed", note: "MoMo account mismatch in mock data." }
];

export const adminSupportTickets: AdminSupportTicket[] = [
  { id: "DSP-20260713-0042", title: "Delivery quote question", customer: "Nana Yaw", priority: "Medium", status: "Open", owner: "Support Team" },
  { id: "DSP-20260713-0045", title: "Customer unavailable", customer: "Ama Serwaa", priority: "High", status: "Investigating", owner: "Operations" },
  { id: "DSP-20260712-0031", title: "Settlement clarification", customer: "KNUST Gadgets", priority: "Medium", status: "Open", owner: "Finance" }
];

export const recentAdminActivity = [
  "New order received from Nana Yaw",
  "KNUST Gadgets settlement marked overdue",
  "Ama's Beauty Plug commission moved to pending",
  "Nike Air Force 1 product flagged for approval review"
];

export function formatGhc(amount: number) {
  return `GH₵${amount.toLocaleString("en-GH")}`;
}

export function getAdminOrder(id: string) {
  return adminOrders.find((order) => order.id === id) ?? adminOrders[0];
}

export function getAdminProduct(id: string) {
  return adminProducts.find((product) => product.id === id) ?? adminProducts[0];
}

export function getAdminSupplier(id: string) {
  return adminSuppliers.find((supplier) => supplier.id === id) ?? adminSuppliers[0];
}

export function getAdminReseller(id: string) {
  return adminResellers.find((reseller) => reseller.id === id) ?? adminResellers[0];
}

export function getAdminCustomer(id: string) {
  return adminCustomers.find((customer) => customer.id === id) ?? adminCustomers[0];
}
