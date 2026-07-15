export type SupplierProductStatus = "Active" | "Pending Approval" | "Needs Changes" | "Out of Stock" | "Needs Reseller Review";
export type SupplierOrderStatus = "Customer Confirmed" | "Preparing" | "Ready" | "Delivered" | "Payment Collected" | "Settlement Due";

export type SupplierProfile = {
  businessName: string;
  ownerName: string;
  phone: string;
  email: string;
  location: string;
  category: string;
  verificationStatus: string;
  payoutMethod: string;
};

export type SupplierProduct = {
  id: string;
  name: string;
  category: string;
  imageLabel: string;
  basePrice: number;
  stock: number;
  lowStockThreshold: number;
  status: SupplierProductStatus;
  activeResellers: number;
  ordersThisMonth: number;
  notes: string;
};

export type SupplierOrder = {
  id: string;
  customerName: string;
  customerPhone: string;
  deliveryArea: string;
  productId: string;
  quantity: number;
  customerPrice: number;
  supplierBaseAmount: number;
  settlementDue: number;
  paymentMethod: string;
  status: SupplierOrderStatus;
  placedAt: string;
  deliveryWindow: string;
};

export function formatGhc(amount: number) {
  return `GH₵${amount.toLocaleString("en-GH", { maximumFractionDigits: 0 })}`;
}

export const supplierCoreMock = {
  supplier: {
    businessName: "KNUST Gadgets",
    ownerName: "Kofi Mensah",
    phone: "+233 24 555 0120",
    email: "kofi@knustgadgets.com",
    location: "Kumasi, Ashanti Region",
    category: "Mobile Phones & Accessories",
    verificationStatus: "Verified Supplier",
    payoutMethod: "MTN MoMo"
  } satisfies SupplierProfile,
  suppliers: ["KNUST Gadgets", "Accra Beauty Hub", "Palace Beauty Supplies", "Beautiful Living Store"],
  products: [
    {
      id: "samsung-galaxy-a14",
      name: "Samsung Galaxy A14",
      category: "Mobile Phones",
      imageLabel: "A14",
      basePrice: 300,
      stock: 18,
      lowStockThreshold: 5,
      status: "Active",
      activeResellers: 12,
      ordersThisMonth: 14,
      notes: "Reliable phone for students and campus resellers."
    },
    {
      id: "nike-air-force-1-07-green-white",
      name: "Nike Air Force 1 '07 Green & White",
      category: "Sneakers",
      imageLabel: "AF1",
      basePrice: 300,
      stock: 7,
      lowStockThreshold: 3,
      status: "Pending Approval",
      activeResellers: 8,
      ordersThisMonth: 9,
      notes: "Imported sneakers pending final admin review."
    },
    {
      id: "jean-paul-gaultier-le-male-edt",
      name: "Jean Paul Gaultier Le Male EDT",
      category: "Perfumes",
      imageLabel: "JPG",
      basePrice: 210,
      stock: 3,
      lowStockThreshold: 5,
      status: "Needs Reseller Review",
      activeResellers: 6,
      ordersThisMonth: 5,
      notes: "Low stock. Resellers should review availability."
    },
    {
      id: "iphone-14-pro-max-case",
      name: "iPhone 14 Pro Max Case",
      category: "Phone Accessories",
      imageLabel: "14",
      basePrice: 60,
      stock: 0,
      lowStockThreshold: 6,
      status: "Out of Stock",
      activeResellers: 4,
      ordersThisMonth: 6,
      notes: "Temporarily unavailable until new stock arrives."
    },
    {
      id: "hostel-essentials-pack",
      name: "Hostel Essentials Pack",
      category: "Home & Living",
      imageLabel: "HE",
      basePrice: 150,
      stock: 15,
      lowStockThreshold: 5,
      status: "Needs Changes",
      activeResellers: 3,
      ordersThisMonth: 2,
      notes: "Admin requested clearer package photos."
    }
  ] satisfies SupplierProduct[],
  orders: [
    {
      id: "rsr-20260713-00021",
      customerName: "Nana Yaw",
      customerPhone: "+233 24 123 4567",
      deliveryArea: "Legon, Accra",
      productId: "samsung-galaxy-a14",
      quantity: 1,
      customerPrice: 340,
      supplierBaseAmount: 300,
      settlementDue: 40,
      paymentMethod: "Pay on Delivery",
      status: "Customer Confirmed",
      placedAt: "13 Jul 2026, 10:24 AM",
      deliveryWindow: "Today, 2:00 PM - 4:00 PM"
    },
    {
      id: "rsr-20260713-00022",
      customerName: "Ama Serwaa",
      customerPhone: "+233 20 887 4412",
      deliveryArea: "Madina, Accra",
      productId: "nike-air-force-1-07-green-white",
      quantity: 1,
      customerPrice: 340,
      supplierBaseAmount: 300,
      settlementDue: 40,
      paymentMethod: "Pay on Delivery",
      status: "Preparing",
      placedAt: "13 Jul 2026, 11:05 AM",
      deliveryWindow: "Today, 4:00 PM - 6:00 PM"
    },
    {
      id: "rsr-20260712-00018",
      customerName: "Kojo Appiah",
      customerPhone: "+233 55 204 7788",
      deliveryArea: "KNUST Campus, Kumasi",
      productId: "jean-paul-gaultier-le-male-edt",
      quantity: 1,
      customerPrice: 250,
      supplierBaseAmount: 210,
      settlementDue: 40,
      paymentMethod: "Pay on Delivery",
      status: "Ready",
      placedAt: "12 Jul 2026, 3:42 PM",
      deliveryWindow: "Tomorrow, 10:00 AM - 12:00 PM"
    },
    {
      id: "rsr-20260710-00009",
      customerName: "Esi Owusu",
      customerPhone: "+233 26 420 9061",
      deliveryArea: "Spintex, Accra",
      productId: "hostel-essentials-pack",
      quantity: 2,
      customerPrice: 380,
      supplierBaseAmount: 300,
      settlementDue: 80,
      paymentMethod: "Pay on Delivery",
      status: "Settlement Due",
      placedAt: "10 Jul 2026, 9:15 AM",
      deliveryWindow: "Delivered"
    }
  ] satisfies SupplierOrder[],
  notifications: [
    "New confirmed order RSR-20260713-00021 is ready for preparation.",
    "Samsung Galaxy A14 was approved and is active for resellers.",
    "Settlement due reminder: settle Risellar share after customer payment.",
    "Low stock alert: Jean Paul Gaultier Le Male EDT has 3 units left.",
    "Verification update: business profile is verified."
  ],
  supportTopics: ["Orders & Preparation", "Products & Approval", "Settlements", "Verification", "Payout Details"]
} as const;

export function getSupplierProduct(id: string) {
  return supplierCoreMock.products.find((product) => product.id === id) ?? supplierCoreMock.products[0];
}

export function getSupplierOrder(id: string) {
  return supplierCoreMock.orders.find((order) => order.id === id) ?? supplierCoreMock.orders[0];
}
