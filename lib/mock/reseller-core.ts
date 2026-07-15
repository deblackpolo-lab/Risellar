export type ResellerProduct = {
  id: string;
  name: string;
  categoryId: string;
  category: string;
  resellerCost: number;
  suggestedSellingPrice: number;
  maxAllowedPrice: number;
  stockStatus: string;
  stockCount: number;
  expectedProfit: number;
  rating: string;
  tags: string[];
  variant: string;
  deliveryNote: string;
  settlementNote: string;
  inShop: boolean;
};

export const formatGhc = (amount: number) => `GH₵${amount.toLocaleString("en-GH")}`;

export const resellerProfile = {
  name: "Ama Serwaa",
  firstName: "Ama",
  shopName: "Ama's Beauty Plug",
  handle: "@amasbeautyplug",
  type: "General Reseller / Beauty Plug",
  location: "Legon, Accra",
  campus: "University of Ghana, Legon",
  momoProvider: "MTN MoMo",
  momoNumber: "+233 24 123 4567",
  availableBalance: 930,
  pendingCommission: 320,
  totalEarned: 4620,
  ordersThisMonth: 56,
  productsShared: 48,
  activeProducts: 12,
  followers: 286
};

export const resellerCategories = [
  { id: "beauty", name: "Beauty" },
  { id: "phones", name: "Phones" },
  { id: "fashion", name: "Fashion" },
  { id: "hostel-essentials", name: "Hostel Essentials" },
  { id: "bags", name: "Bags" },
  { id: "skincare", name: "Skincare" },
  { id: "perfumes", name: "Perfumes" }
];

export const resellerCoreProducts: ResellerProduct[] = [
  {
    id: "nike-air-force-1-07-green-white",
    name: "Nike Air Force 1 '07 Green & White",
    categoryId: "fashion",
    category: "Fashion",
    resellerCost: 310,
    suggestedSellingPrice: 340,
    maxAllowedPrice: 360,
    stockStatus: "Only 1 left",
    stockCount: 1,
    expectedProfit: 30,
    rating: "4.7 (128)",
    tags: ["Sponsored", "Trending"],
    variant: "Size 42",
    deliveryNote: "Delivery is separate and confirmed before dispatch.",
    settlementNote: "Your commission becomes available after supplier settlement is verified by Risellar.",
    inShop: true
  },
  {
    id: "jean-paul-gaultier-le-male-edt-125ml",
    name: "Jean Paul Gaultier Le Male EDT 125ml",
    categoryId: "perfumes",
    category: "Perfumes",
    resellerCost: 125,
    suggestedSellingPrice: 145,
    maxAllowedPrice: 160,
    stockStatus: "In Stock",
    stockCount: 18,
    expectedProfit: 20,
    rating: "4.8 (64)",
    tags: ["Hot Seller"],
    variant: "125ml",
    deliveryNote: "Same-day dispatch is available in Accra after customer confirmation.",
    settlementNote: "Commission is pending until supplier settlement is verified by Risellar.",
    inShop: true
  },
  {
    id: "anua-niacinamide-serum",
    name: "Anua Niacinamide Serum",
    categoryId: "skincare",
    category: "Skincare",
    resellerCost: 120,
    suggestedSellingPrice: 145,
    maxAllowedPrice: 165,
    stockStatus: "In Stock",
    stockCount: 22,
    expectedProfit: 25,
    rating: "4.6 (86)",
    tags: ["Trending"],
    variant: "30ml",
    deliveryNote: "Delivery cost is confirmed with the customer before dispatch.",
    settlementNote: "Pending commission cannot be withdrawn before settlement verification.",
    inShop: true
  },
  {
    id: "oraimo-power-bank-30000mah",
    name: "Oraimo Power Bank 30000mAh",
    categoryId: "phones",
    category: "Phones",
    resellerCost: 145,
    suggestedSellingPrice: 165,
    maxAllowedPrice: 185,
    stockStatus: "Low Stock",
    stockCount: 3,
    expectedProfit: 20,
    rating: "4.5 (74)",
    tags: ["Low Stock"],
    variant: "30000mAh",
    deliveryNote: "Available for Accra and Kumasi delivery after customer confirmation.",
    settlementNote: "Commission is released after supplier settlement is marked verified.",
    inShop: false
  },
  {
    id: "iphone-14-pro-max-case",
    name: "iPhone 14 Pro Max Case",
    categoryId: "phones",
    category: "Phones",
    resellerCost: 45,
    suggestedSellingPrice: 60,
    maxAllowedPrice: 70,
    stockStatus: "Out of Stock",
    stockCount: 0,
    expectedProfit: 15,
    rating: "4.3 (39)",
    tags: ["Out of Stock"],
    variant: "Clear MagSafe",
    deliveryNote: "This product is hidden from new customer orders until restocked.",
    settlementNote: "No commission can be earned while the product is out of stock.",
    inShop: false
  },
  {
    id: "hostel-essentials-pack",
    name: "Hostel Essentials Pack",
    categoryId: "hostel-essentials",
    category: "Hostel Essentials",
    resellerCost: 150,
    suggestedSellingPrice: 185,
    maxAllowedPrice: 210,
    stockStatus: "In Stock",
    stockCount: 15,
    expectedProfit: 35,
    rating: "4.7 (58)",
    tags: ["Sponsored"],
    variant: "Student starter kit",
    deliveryNote: "Best for Legon, Madina, UPSA, and nearby hostel deliveries.",
    settlementNote: "Commission stays pending until supplier settlement clears.",
    inShop: true
  },
  {
    id: "laptop-backpack",
    name: "Laptop Backpack",
    categoryId: "bags",
    category: "Bags",
    resellerCost: 200,
    suggestedSellingPrice: 235,
    maxAllowedPrice: 260,
    stockStatus: "In Stock",
    stockCount: 9,
    expectedProfit: 35,
    rating: "4.4 (51)",
    tags: ["Trending"],
    variant: "15.6 inch",
    deliveryNote: "Delivery quote is confirmed before dispatch.",
    settlementNote: "Commission is protected until supplier settlement is verified.",
    inShop: false
  },
  {
    id: "skincare-set",
    name: "Skincare Set",
    categoryId: "beauty",
    category: "Beauty",
    resellerCost: 260,
    suggestedSellingPrice: 310,
    maxAllowedPrice: 340,
    stockStatus: "In Stock",
    stockCount: 10,
    expectedProfit: 50,
    rating: "4.8 (92)",
    tags: ["Sponsored"],
    variant: "6-in-1",
    deliveryNote: "Customer pays on delivery after final delivery cost confirmation.",
    settlementNote: "Available balance updates after settlement verification.",
    inShop: false
  },
  {
    id: "press-on-nails",
    name: "Press-on Nails",
    categoryId: "beauty",
    category: "Beauty",
    resellerCost: 55,
    suggestedSellingPrice: 80,
    maxAllowedPrice: 95,
    stockStatus: "In Stock",
    stockCount: 34,
    expectedProfit: 25,
    rating: "4.6 (44)",
    tags: ["Hot Seller"],
    variant: "24-piece set",
    deliveryNote: "Small parcel delivery available around Accra campuses.",
    settlementNote: "Commission becomes available after verified settlement.",
    inShop: false
  },
  {
    id: "hair-oil",
    name: "Hair Oil",
    categoryId: "beauty",
    category: "Beauty",
    resellerCost: 70,
    suggestedSellingPrice: 95,
    maxAllowedPrice: 115,
    stockStatus: "In Stock",
    stockCount: 28,
    expectedProfit: 25,
    rating: "4.5 (37)",
    tags: ["Trending"],
    variant: "Growth blend",
    deliveryNote: "Ready for delivery anywhere in Accra after confirmation.",
    settlementNote: "Pending commission cannot be withdrawn before supplier settlement.",
    inShop: false
  }
];

export const resellerOrders = [
  {
    id: "RSR-250518-8842",
    customer: "Nana Yaw",
    productId: "nike-air-force-1-07-green-white",
    product: "Nike Air Force 1 '07 Green & White",
    status: "Delivery Quote Pending",
    commissionStatus: "Commission Pending",
    expectedCommission: 30,
    total: 380,
    timeline: ["Order placed", "Customer confirmed", "Delivery quote pending"]
  },
  {
    id: "RSR-250518-8799",
    customer: "Kofi Appiah",
    productId: "hostel-essentials-pack",
    product: "Hostel Essentials Pack",
    status: "Awaiting Settlement",
    commissionStatus: "Awaiting Settlement",
    expectedCommission: 35,
    total: 205,
    timeline: ["Order delivered", "Customer paid", "Supplier settlement pending"]
  },
  {
    id: "RSR-250518-8711",
    customer: "Akosua Boateng",
    productId: "anua-niacinamide-serum",
    product: "Anua Niacinamide Serum",
    status: "Completed",
    commissionStatus: "Completed",
    expectedCommission: 25,
    total: 165,
    timeline: ["Order delivered", "Settlement verified", "Commission released"]
  },
  {
    id: "RSR-250518-8608",
    customer: "Abena Mensah",
    productId: "jean-paul-gaultier-le-male-edt-125ml",
    product: "Jean Paul Gaultier Le Male EDT 125ml",
    status: "Cancelled",
    commissionStatus: "Cancelled",
    expectedCommission: 0,
    total: 0,
    timeline: ["Order placed", "Customer refused", "Commission cancelled"]
  }
];

export const resellerTransactions = [
  { id: "TRX-001", label: "Commission pending", amount: 30, status: "Commission Pending", date: "18 May 2025" },
  { id: "TRX-002", label: "Commission available", amount: 25, status: "Completed", date: "17 May 2025" },
  { id: "TRX-003", label: "Withdrawal requested", amount: -120, status: "Processing", date: "16 May 2025" },
  { id: "TRX-004", label: "Withdrawal paid", amount: -80, status: "Paid", date: "15 May 2025" },
  { id: "TRX-005", label: "Withdrawal failed", amount: 0, status: "Failed", date: "14 May 2025" }
];

export const resellerNotifications = [
  "New order from Nana Yaw is awaiting delivery quote.",
  "Commission GH₵25 is now available after supplier settlement.",
  "Hair Oil is trending around Legon this week.",
  "Withdrawal failed: MoMo provider could not process the request."
];

export function getResellerProduct(id: string) {
  return resellerCoreProducts.find((product) => product.id === id) ?? resellerCoreProducts[0];
}

export function getResellerCategory(categoryId: string) {
  return resellerCategories.find((category) => category.id === categoryId);
}
