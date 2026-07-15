import { formatGhc, supplierCoreMock } from "@/lib/mock/supplier-core";

export type StockStatus = "Available" | "Low Stock" | "Out of Stock" | "Reserved" | "Active" | "Needs Review" | "Price Change Pending" | "Only 1 left";
export type StockMovementType =
  | "initial stock"
  | "restock"
  | "reservation"
  | "sale"
  | "cancellation release"
  | "manual adjustment"
  | "return"
  | "damage/loss";

export type InventoryProduct = {
  id: string;
  name: string;
  category: string;
  imageLabel: string;
  supplierBasePrice: number;
  status: string;
  stockStatus: StockStatus;
  totalStock: number;
  reservedStock: number;
  availableStock: number;
  soldStock: number;
  lowStockThreshold: number;
  activeResellers: number;
  recentOrders: number;
  affectedListings: number;
  priceChangeStatus?: "Needs Review" | "Pending Approval";
};

export type InventoryVariant = {
  id: string;
  label: string;
  color: string;
  model: string;
  totalStock: number;
  reservedStock: number;
  availableStock: number;
  lowStockThreshold: number;
  status: StockStatus;
};

export type StockMovement = {
  id: string;
  productId: string;
  type: StockMovementType;
  actor: string;
  role: string;
  timestamp: string;
  quantityChange: string;
  relatedOrderId?: string;
  note: string;
};

export type InventoryActivity = {
  id: string;
  actor: string;
  role: string;
  type: "Restock" | "Reservation" | "Threshold" | "Price" | "Adjustment";
  action: string;
  product: string;
  timestamp: string;
  beforeAfter: string;
};

export const supplierInventoryMock = {
  supplier: supplierCoreMock.supplier,
  products: [
    {
      id: "nike-air-force-1-07-green-white",
      name: "Nike Air Force 1 '07 Green & White",
      category: "Sneakers",
      imageLabel: "AF1",
      supplierBasePrice: 300,
      status: "Active",
      stockStatus: "Low Stock",
      totalStock: 21,
      reservedStock: 3,
      availableStock: 18,
      soldStock: 128,
      lowStockThreshold: 5,
      activeResellers: 8,
      recentOrders: 9,
      affectedListings: 8,
      priceChangeStatus: "Needs Review"
    },
    {
      id: "samsung-galaxy-a14",
      name: "Samsung Galaxy A14",
      category: "Mobile Phones",
      imageLabel: "A14",
      supplierBasePrice: 300,
      status: "Active",
      stockStatus: "Available",
      totalStock: 28,
      reservedStock: 4,
      availableStock: 24,
      soldStock: 64,
      lowStockThreshold: 5,
      activeResellers: 12,
      recentOrders: 14,
      affectedListings: 12
    },
    {
      id: "jean-paul-gaultier-le-male-edt",
      name: "Jean Paul Gaultier Le Male EDT",
      category: "Perfumes",
      imageLabel: "JPG",
      supplierBasePrice: 210,
      status: "Needs Review",
      stockStatus: "Low Stock",
      totalStock: 4,
      reservedStock: 1,
      availableStock: 3,
      soldStock: 38,
      lowStockThreshold: 5,
      activeResellers: 6,
      recentOrders: 5,
      affectedListings: 6
    },
    {
      id: "iphone-14-pro-max-case",
      name: "iPhone 14 Pro Max Case",
      category: "Phone Accessories",
      imageLabel: "14",
      supplierBasePrice: 60,
      status: "Active",
      stockStatus: "Out of Stock",
      totalStock: 0,
      reservedStock: 0,
      availableStock: 0,
      soldStock: 56,
      lowStockThreshold: 6,
      activeResellers: 4,
      recentOrders: 6,
      affectedListings: 4
    },
    {
      id: "hostel-essentials-pack",
      name: "Hostel Essentials Pack",
      category: "Home & Living",
      imageLabel: "HE",
      supplierBasePrice: 150,
      status: "Active",
      stockStatus: "Available",
      totalStock: 18,
      reservedStock: 3,
      availableStock: 15,
      soldStock: 22,
      lowStockThreshold: 5,
      activeResellers: 3,
      recentOrders: 2,
      affectedListings: 3
    },
    {
      id: "skincare-set",
      name: "Skincare Set",
      category: "Beauty & Skincare",
      imageLabel: "SK",
      supplierBasePrice: 260,
      status: "Price Change Pending",
      stockStatus: "Low Stock",
      totalStock: 5,
      reservedStock: 2,
      availableStock: 3,
      soldStock: 41,
      lowStockThreshold: 5,
      activeResellers: 9,
      recentOrders: 7,
      affectedListings: 9,
      priceChangeStatus: "Pending Approval"
    }
  ] satisfies InventoryProduct[],
  variants: {
    "nike-air-force-1-07-green-white": [
      { id: "af1-40", label: "Size 40", color: "Green & White", model: "Sneakers", totalStock: 8, reservedStock: 1, availableStock: 7, lowStockThreshold: 2, status: "Available" },
      { id: "af1-41", label: "Size 41", color: "Green & White", model: "Sneakers", totalStock: 12, reservedStock: 2, availableStock: 10, lowStockThreshold: 2, status: "Available" },
      { id: "af1-42", label: "Size 42", color: "Green & White", model: "Sneakers", totalStock: 1, reservedStock: 0, availableStock: 1, lowStockThreshold: 2, status: "Only 1 left" },
      { id: "af1-43", label: "Size 43", color: "Green & White", model: "Sneakers", totalStock: 0, reservedStock: 0, availableStock: 0, lowStockThreshold: 2, status: "Out of Stock" }
    ]
  } as Record<string, InventoryVariant[]>,
  movements: [
    { id: "mov-001", productId: "nike-air-force-1-07-green-white", type: "initial stock", actor: "Kofi Mensah", role: "Supplier Owner", timestamp: "10 Jul 2026, 08:30 AM", quantityChange: "+20", note: "Opening stock from supplier store." },
    { id: "mov-002", productId: "nike-air-force-1-07-green-white", type: "restock", actor: "Akua Boateng", role: "Inventory Manager", timestamp: "12 Jul 2026, 09:15 AM", quantityChange: "+12", note: "Restocked Nike Air Force 1 size 42 +12." },
    { id: "mov-003", productId: "nike-air-force-1-07-green-white", type: "reservation", actor: "System Reservation", role: "System", timestamp: "13 Jul 2026, 10:24 AM", quantityChange: "-1", relatedOrderId: "RSR-20260713-00021", note: "Reserved stock for customer-confirmed order." },
    { id: "mov-004", productId: "nike-air-force-1-07-green-white", type: "sale", actor: "System Reservation", role: "System", timestamp: "13 Jul 2026, 02:30 PM", quantityChange: "-1", relatedOrderId: "RSR-20260713-00018", note: "Delivered order converted reserved stock to sold stock." },
    { id: "mov-005", productId: "nike-air-force-1-07-green-white", type: "cancellation release", actor: "System Reservation", role: "System", timestamp: "13 Jul 2026, 04:05 PM", quantityChange: "+1", relatedOrderId: "RSR-20260713-00019", note: "Customer cancellation released reserved stock." },
    { id: "mov-006", productId: "nike-air-force-1-07-green-white", type: "manual adjustment", actor: "Kofi Mensah", role: "Supplier Owner", timestamp: "14 Jul 2026, 09:40 AM", quantityChange: "-1", note: "Manual count correction after shelf check." },
    { id: "mov-007", productId: "nike-air-force-1-07-green-white", type: "return", actor: "Akua Boateng", role: "Inventory Manager", timestamp: "14 Jul 2026, 02:10 PM", quantityChange: "+1", relatedOrderId: "RSR-20260712-00011", note: "Returned item inspected and added back to stock." },
    { id: "mov-008", productId: "nike-air-force-1-07-green-white", type: "damage/loss", actor: "Akua Boateng", role: "Inventory Manager", timestamp: "15 Jul 2026, 08:55 AM", quantityChange: "-1", note: "Box damage recorded during stock audit." }
  ] satisfies StockMovement[],
  activity: [
    { id: "act-001", actor: "Akua Boateng", role: "Inventory Manager", type: "Restock", action: "restocked Nike Air Force 1 size 42 +12", product: "Nike Air Force 1 '07 Green & White", timestamp: "12 Jul 2026, 09:15 AM", beforeAfter: "1 -> 13" },
    { id: "act-002", actor: "Kofi Mensah", role: "Supplier Owner", type: "Threshold", action: "changed low-stock threshold from 3 to 5", product: "Nike Air Force 1 '07 Green & White", timestamp: "13 Jul 2026, 08:10 AM", beforeAfter: "3 -> 5" },
    { id: "act-003", actor: "System Reservation", role: "System", type: "Reservation", action: "reserved 1 item for order RSR-20260713-00021", product: "Samsung Galaxy A14", timestamp: "13 Jul 2026, 10:24 AM", beforeAfter: "25 -> 24 available" },
    { id: "act-004", actor: "Kofi Mensah", role: "Supplier Owner", type: "Price", action: "requested supplier base price review", product: "Skincare Set", timestamp: "14 Jul 2026, 12:20 PM", beforeAfter: `${formatGhc(260)} -> ${formatGhc(310)}` },
    { id: "act-005", actor: "Akua Boateng", role: "Inventory Manager", type: "Adjustment", action: "adjusted damaged item after count", product: "Nike Air Force 1 '07 Green & White", timestamp: "15 Jul 2026, 08:55 AM", beforeAfter: "22 -> 21" }
  ] satisfies InventoryActivity[]
} as const;

export function getInventoryProduct(productId: string): InventoryProduct {
  return supplierInventoryMock.products.find((product) => product.id === productId) ?? supplierInventoryMock.products[0];
}

export function getInventoryVariants(productId: string): InventoryVariant[] {
  return supplierInventoryMock.variants[productId] ?? [
    { id: `${productId}-default`, label: "Default", color: "Default", model: "Standard", totalStock: getInventoryProduct(productId).totalStock, reservedStock: getInventoryProduct(productId).reservedStock, availableStock: getInventoryProduct(productId).availableStock, lowStockThreshold: getInventoryProduct(productId).lowStockThreshold, status: getInventoryProduct(productId).stockStatus }
  ];
}

export function getInventorySummary() {
  return {
    inventoryValue: supplierInventoryMock.products.reduce((sum, product) => sum + product.supplierBasePrice * product.totalStock, 0),
    totalProducts: supplierInventoryMock.products.length,
    availableStock: supplierInventoryMock.products.reduce((sum, product) => sum + product.availableStock, 0),
    reservedStock: supplierInventoryMock.products.reduce((sum, product) => sum + product.reservedStock, 0),
    lowStockAlerts: supplierInventoryMock.products.filter((product) => product.stockStatus === "Low Stock").length,
    outOfStockItems: supplierInventoryMock.products.filter((product) => product.stockStatus === "Out of Stock").length,
    priceChangeRequests: supplierInventoryMock.products.filter((product) => product.priceChangeStatus).length
  };
}
