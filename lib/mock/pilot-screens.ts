export const pilotReseller = {
  name: "Ama",
  shopName: "Ama's Beauty Plug",
  location: "Legon, Accra",
  availableBalance: "Available Balance GH₵240",
  pendingCommission: "GH₵180",
  ordersToday: "4",
  productsShared: "18",
  hotProduct: "Jean Paul Gaultier Le Male EDT 125ml"
};

export const pilotProduct = {
  id: "nike-air-force-1-07-green-white",
  name: "Nike Air Force 1 '07 Green & White",
  category: "Sneakers",
  imageLabel: "Green and white sneaker",
  stock: "Only 1 left",
  variant: "Size 42",
  resellerCost: "GH₵310",
  suggestedSellingPrice: "GH₵340",
  maxAllowedPrice: "GH₵360",
  resellerMargin: "GH₵30",
  expectedProfit: "GH₵30",
  customerPrice: "GH₵340",
  deliveryNote: "Delivery is separate and confirmed before dispatch.",
  settlementNote: "Your commission becomes available after customer payment and verified supplier settlement."
};

export const pilotOrders = [
  { id: "RSR-250518-8842", customer: "Nana Yaw", status: "Delivery Quote Pending", total: "GH₵360-380" },
  { id: "RSR-250518-8799", customer: "Kofi Appiah", status: "Completed", total: "GH₵340" },
  { id: "RSR-250518-8711", customer: "Akosua Boateng", status: "Awaiting Settlement", total: "GH₵310" }
];

export const pilotCheckout = {
  customer: {
    name: "Nana Yaw",
    phone: "+233 24 123 4567"
  },
  resellerShop: "Ama's Beauty Plug",
  product: pilotProduct.name,
  productPrice: "GH₵340",
  deliveryOption: "Standard Delivery",
  deliveryEstimate: "GH₵20-40",
  estimatedTotal: "GH₵360-380",
  paymentMethod: "Pay on Delivery",
  statusAfterPlaceOrder: "Awaiting Customer Confirmation"
};
