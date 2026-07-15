export type MockProduct = {
  id: string;
  name: string;
  category: string;
  supplier: string;
  supplierBasePrice: string;
  platformMargin: string;
  resellerMargin: string;
  resellerCost: string;
  customerPrice: string;
  status: string;
  stock: string;
  tag: string;
};

export const sampleProducts: MockProduct[] = [
  {
    id: "PRD-AF1-07",
    name: "Nike Air Force 1 '07 Green & White",
    category: "Sneakers",
    supplier: "KNUST Gadgets",
    supplierBasePrice: "GH₵300",
    platformMargin: "GH₵10",
    resellerMargin: "GH₵30",
    resellerCost: "GH₵310",
    customerPrice: "GH₵340",
    status: "Approved",
    stock: "Only 1 left",
    tag: "Sponsored"
  },
  {
    id: "PRD-SKIN-SET",
    name: "The Ordinary Skincare Set",
    category: "Beauty",
    supplier: "Beauty Central GH",
    supplierBasePrice: "GH₵260",
    platformMargin: "GH₵10",
    resellerMargin: "GH₵40",
    resellerCost: "GH₵270",
    customerPrice: "GH₵310",
    status: "Pending Approval",
    stock: "In stock",
    tag: "Trending"
  },
  {
    id: "PRD-PWR-20K",
    name: "Oraimo Power Bank 20000mAh",
    category: "Phone Accessories",
    supplier: "Tech World Ghana",
    supplierBasePrice: "GH₵130",
    platformMargin: "GH₵5",
    resellerMargin: "GH₵30",
    resellerCost: "GH₵135",
    customerPrice: "GH₵165",
    status: "Out of Stock",
    stock: "Out of Stock",
    tag: "Needs Reseller Review"
  }
];

export const sampleVariants = [
  { name: "Size 40", stock: 8, reserved: 2, status: "Active" },
  { name: "Size 41", stock: 1, reserved: 1, status: "Only 1 left" },
  { name: "Size 42", stock: 0, reserved: 0, status: "Out of Stock" }
];

export const sampleStockStates = ["In stock", "Only 1 left", "Out of Stock", "Reserved", "Needs Reseller Review"];
