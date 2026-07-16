import {
  getMockProductImages,
  getPrimaryProductImageAlt,
  type MockProductImage
} from "@/lib/mock/product-images";

export type PromotionStatus = "Pending Payment" | "Pending Approval" | "Active" | "Paused" | "Completed" | "Rejected" | "Cancelled";

export type PromotionPackage = {
  id: string;
  name: string;
  price: number;
  duration: string;
  placement: string;
  eligibility: string;
  note: string;
};

export type Promotion = {
  id: string;
  name: string;
  product: string;
  supplier: string;
  packageName: string;
  target: string;
  status: PromotionStatus;
  startDate: string;
  endDate: string;
  amount: number;
  paymentStatus: string;
  eligibilityStatus: string;
  pauseReason?: string;
};

export type InsightProduct = {
  id: string;
  name: string;
  supplier: string;
  category: string;
  location: string;
  resellerCost: number;
  suggestedPrice: number;
  maxAllowedPrice: number;
  expectedProfit: number;
  stockState: string;
  trust: string;
  labels: string[];
  insight: string;
  imageLabel: string;
  images: MockProductImage[];
  imageAlt: string;
};

export const formatGhc = (amount: number) => `GH₵${amount.toLocaleString("en-GH")}`;

export const promotionPackages: PromotionPackage[] = [
  { id: "daily-boost", name: "Daily Boost", price: 10, duration: "24 hours", placement: "Featured Products", eligibility: "Approved, active, in-stock products", note: "Good for testing a product." },
  { id: "three-day-boost", name: "3-Day Boost", price: 20, duration: "3 days", placement: "Featured in category", eligibility: "Recommended for trusted suppliers", note: "Recommended for steady visibility." },
  { id: "campus-push", name: "Campus/Area Push", price: 20, duration: "3 days", placement: "Legon, KNUST, UPSA, or Madina", eligibility: "Area stock and supplier trust required", note: "Good for campus sellers." },
  { id: "category-top-spot", name: "Category Top Spot", price: 30, duration: "3 days", placement: "Top placement in category", eligibility: "Subject to admin approval", note: "Best for high-stock products." }
];

export const supplierPromotionSummary = {
  businessName: "KNUST Gadgets",
  active: 2,
  pending: 1,
  paused: 1,
  completed: 5,
  totalSpentThisMonth: 70,
  resellersReached: 428,
  productViews: 1240,
  ordersInfluenced: 34,
  warning: "Overdue settlement can pause or block promotions."
};

export const promotionEligibilityChecks = [
  { label: "Product approved", passed: true },
  { label: "Product in stock", passed: true },
  { label: "Supplier verified", passed: true },
  { label: "No overdue settlement", passed: false },
  { label: "Product complaint rate acceptable", passed: true }
];

export const promotions: Promotion[] = [
  {
    id: "boost-jpg-le-male-legon",
    name: "Le Male Legon Campus Push",
    product: "Jean Paul Gaultier Le Male EDT 125ml",
    supplier: "Palace Beauty Supplies",
    packageName: "Campus/Area Push",
    target: "Legon",
    status: "Pending Approval",
    startDate: "After admin approval",
    endDate: "3 days after activation",
    amount: 20,
    paymentStatus: "Proof submitted",
    eligibilityStatus: "Needs overdue settlement check"
  },
  {
    id: "boost-nike-af1-accra",
    name: "Nike AF1 Accra Featured Boost",
    product: "Nike Air Force 1 '07 Green & White",
    supplier: "Sneaker Plug GH",
    packageName: "3-Day Boost",
    target: "Accra",
    status: "Active",
    startDate: "14 Jul 2026",
    endDate: "17 Jul 2026",
    amount: 20,
    paymentStatus: "Approved",
    eligibilityStatus: "Eligible"
  },
  {
    id: "boost-oraimo-knust",
    name: "Oraimo KNUST Power Push",
    product: "Oraimo Power Bank",
    supplier: "KNUST Gadgets",
    packageName: "Daily Boost",
    target: "KNUST",
    status: "Paused",
    startDate: "13 Jul 2026",
    endDate: "Paused",
    amount: 10,
    paymentStatus: "Approved",
    eligibilityStatus: "Paused by settlement risk",
    pauseReason: "Supplier has an overdue settlement."
  },
  {
    id: "boost-anua-legon",
    name: "Anua Beauty Weekend Push",
    product: "Anua Niacinamide Serum",
    supplier: "Accra Beauty Hub",
    packageName: "Category Top Spot",
    target: "Beauty category",
    status: "Completed",
    startDate: "8 Jul 2026",
    endDate: "11 Jul 2026",
    amount: 30,
    paymentStatus: "Approved",
    eligibilityStatus: "Completed"
  }
];

export const insightProducts: InsightProduct[] = [
  {
    id: "nike-air-force-1-07-green-white",
    name: "Nike Air Force 1 '07 Green & White",
    supplier: "Sneaker Plug GH",
    category: "Fashion",
    location: "Accra",
    resellerCost: 310,
    suggestedPrice: 340,
    maxAllowedPrice: 370,
    expectedProfit: 30,
    stockState: "Only 3 left",
    trust: "Trusted supplier",
    labels: ["Hot Seller", "Trending in Accra", "High Profit", "Good for WhatsApp", "Only Few Left"],
    insight: "Fast-moving sneaker pick for students and casual buyers.",
    imageLabel: "AF1",
    images: getMockProductImages("nike-air-force-1-07-green-white"),
    imageAlt: getPrimaryProductImageAlt("Nike Air Force 1 '07 Green & White")
  },
  {
    id: "jean-paul-gaultier-le-male-edt-125ml",
    name: "Jean Paul Gaultier Le Male EDT 125ml",
    supplier: "Palace Beauty Supplies",
    category: "Beauty",
    location: "Legon",
    resellerCost: 620,
    suggestedPrice: 750,
    maxAllowedPrice: 790,
    expectedProfit: 130,
    stockState: "In stock",
    trust: "Verified supplier",
    labels: ["Sponsored", "High Profit", "Trending", "Good for WhatsApp"],
    insight: "Premium fragrance with strong gifting demand around campus.",
    imageLabel: "JPG",
    images: getMockProductImages("jean-paul-gaultier-le-male-edt-125ml"),
    imageAlt: getPrimaryProductImageAlt("Jean Paul Gaultier Le Male EDT 125ml")
  },
  {
    id: "anua-niacinamide-serum",
    name: "Anua Niacinamide Serum",
    supplier: "Accra Beauty Hub",
    category: "Beauty",
    location: "Madina",
    resellerCost: 120,
    suggestedPrice: 145,
    maxAllowedPrice: 160,
    expectedProfit: 25,
    stockState: "Recently Restocked",
    trust: "Low complaint rate",
    labels: ["Recently Restocked", "Low Competition", "Hot Seller"],
    insight: "Beauty products are trending in Legon this week.",
    imageLabel: "AN",
    images: getMockProductImages("anua-niacinamide-serum"),
    imageAlt: getPrimaryProductImageAlt("Anua Niacinamide Serum")
  },
  {
    id: "oraimo-power-bank",
    name: "Oraimo Power Bank",
    supplier: "KNUST Gadgets",
    category: "Phones",
    location: "KNUST",
    resellerCost: 130,
    suggestedPrice: 165,
    maxAllowedPrice: 180,
    expectedProfit: 35,
    stockState: "In stock",
    trust: "Supplier review active",
    labels: ["Low Competition", "High Profit", "Good for WhatsApp"],
    insight: "Phone accessories have high repeat demand.",
    imageLabel: "PB",
    images: getMockProductImages("oraimo-power-bank"),
    imageAlt: getPrimaryProductImageAlt("Oraimo Power Bank")
  },
  {
    id: "hostel-essentials-pack",
    name: "Hostel Essentials Pack",
    supplier: "Accra Beauty Hub",
    category: "Hostel Essentials",
    location: "UPSA",
    resellerCost: 150,
    suggestedPrice: 195,
    maxAllowedPrice: 210,
    expectedProfit: 45,
    stockState: "In stock",
    trust: "Verified supplier",
    labels: ["Low Competition", "Good for students", "Trending"],
    insight: "Useful campus bundle with fewer resellers pushing it.",
    imageLabel: "HE",
    images: getMockProductImages("hostel-essentials-pack"),
    imageAlt: getPrimaryProductImageAlt("Hostel Essentials Pack")
  },
  {
    id: "iphone-14-pro-max-case",
    name: "iPhone 14 Pro Max Case",
    supplier: "KNUST Gadgets",
    category: "Phones",
    location: "Accra",
    resellerCost: 45,
    suggestedPrice: 65,
    maxAllowedPrice: 75,
    expectedProfit: 20,
    stockState: "In stock",
    trust: "Verified supplier",
    labels: ["Fast moving", "Popular in Accra", "Recently Restocked"],
    insight: "Small-ticket phone accessory with repeat demand.",
    imageLabel: "14",
    images: getMockProductImages("iphone-14-pro-max-case"),
    imageAlt: getPrimaryProductImageAlt("iPhone 14 Pro Max Case")
  }
];

export const captionTemplates = [
  {
    category: "urgency",
    title: "Fast sneaker alert",
    caption: "Fresh sneakers available now. Price: GH₵340. Pay on delivery available. Order through my Risellar shop link."
  },
  {
    category: "beauty",
    title: "Beauty plug caption",
    caption: "Original beauty pick in stock. Pay when it arrives, and I will confirm your order before dispatch."
  },
  {
    category: "student deals",
    title: "Campus deal",
    caption: "Campus-friendly deal for Legon and UPSA. Limited stock, trusted supplier, Pay on Delivery."
  },
  {
    category: "phone accessories",
    title: "Accessory repeat demand",
    caption: "Phone accessory available today. Affordable, useful, and easy to deliver around Accra."
  },
  {
    category: "pay on delivery trust",
    title: "Trust caption",
    caption: "No upfront payment. Confirm your order, approve delivery cost, and pay when the item arrives."
  }
];

export function getPromotion(id: string) {
  return promotions.find((promotion) => promotion.id === id) ?? promotions[0];
}
