import {
  getMockProductImages,
  getPrimaryProductImageAlt,
  type MockProductImage
} from "@/lib/mock/product-images";

export function formatGhc(amount: number) {
  return `GH₵${amount.toLocaleString("en-GH")}`;
}

export type CustomerProduct = {
  id: string;
  name: string;
  category: string;
  price: number;
  imageTone: "shoe" | "beauty" | "tech" | "hostel";
  images: MockProductImage[];
  imageAlt: string;
  stockLabel: string;
  rating: string;
  description: string;
};

export const customerCheckoutMock = {
  shop: {
    slug: "amas-beauty-plug",
    name: "Ama's Beauty Plug",
    owner: "Ama Serwaa",
    location: "Legon, Accra",
    status: "Verified seller",
    tagline: "Original products, fast delivery across Accra, and Pay on Delivery.",
    trustPoints: ["Pay when your item arrives", "Delivery quote confirmed before dispatch", "Real people, real support"]
  },
  customer: {
    name: "Nana Yaw",
    alternateName: "Ama Serwaa",
    email: "nana.yaw@gmail.com",
    phone: "+233 24 123 4567",
    whatsapp: "+233 24 123 4567",
    address: {
      type: "Hostel",
      area: "Legon, Accra",
      details: "Block S, Room 12, Peace Hostel, near Wisconsin University College",
      landmark: "Opp. The Junction Mall",
      notes: "Call me on arrival. I will be around."
    }
  },
  products: [
    {
      id: "nike-air-force-1-07-green-white",
      name: "Nike Air Force 1 '07 Green & White",
      category: "Sneakers",
      price: 340,
      imageTone: "shoe",
      images: getMockProductImages("nike-air-force-1-07-green-white"),
      imageAlt: getPrimaryProductImageAlt("Nike Air Force 1 '07 Green & White"),
      stockLabel: "In stock",
      rating: "4.8 (128)",
      description: "Clean green and white sneaker for casual wear, campus days, and weekend plans."
    },
    {
      id: "jean-paul-gaultier-le-male",
      name: "Jean Paul Gaultier Le Male",
      category: "Perfumes",
      price: 430,
      imageTone: "beauty",
      images: getMockProductImages("jean-paul-gaultier-le-male"),
      imageAlt: getPrimaryProductImageAlt("Jean Paul Gaultier Le Male"),
      stockLabel: "Only 2 left",
      rating: "4.7 (92)",
      description: "Long-lasting fragrance pick from a verified reseller."
    },
    {
      id: "anua-niacinamide-serum-30ml",
      name: "Anua Niacinamide Serum 30ml",
      category: "Beauty",
      price: 145,
      imageTone: "beauty",
      images: getMockProductImages("anua-niacinamide-serum-30ml"),
      imageAlt: getPrimaryProductImageAlt("Anua Niacinamide Serum 30ml"),
      stockLabel: "In stock",
      rating: "4.6 (64)",
      description: "Lightweight skincare serum for everyday routines."
    },
    {
      id: "oraimo-power-bank-30000mah",
      name: "Oraimo Power Bank 30000mAh",
      category: "Phone Accessories",
      price: 165,
      imageTone: "tech",
      images: getMockProductImages("oraimo-power-bank-30000mah"),
      imageAlt: getPrimaryProductImageAlt("Oraimo Power Bank 30000mAh"),
      stockLabel: "In stock",
      rating: "4.5 (83)",
      description: "Reliable backup power for phones, campus, and travel."
    },
    {
      id: "hostel-essentials-pack",
      name: "Hostel Essentials Pack",
      category: "Hostel Essentials",
      price: 150,
      imageTone: "hostel",
      images: getMockProductImages("hostel-essentials-pack"),
      imageAlt: getPrimaryProductImageAlt("Hostel Essentials Pack"),
      stockLabel: "In stock",
      rating: "4.5 (41)",
      description: "Practical hostel starter kit for students in Accra."
    }
  ] satisfies CustomerProduct[],
  cart: {
    itemId: "nike-air-force-1-07-green-white",
    size: "42",
    quantity: 1
  },
  deliveryOptions: [
    { id: "express", name: "Express Delivery", estimate: "GH₵50-100", timing: "1-3 hours / same day" },
    { id: "next-day", name: "Next Day Delivery", estimate: "GH₵30-50", timing: "By tomorrow" },
    { id: "standard", name: "Standard Delivery", estimate: "GH₵20-40", timing: "2-3 days" },
    { id: "campus", name: "Campus Delivery", estimate: "GH₵10-25", timing: "Specific-day delivery" }
  ],
  order: {
    id: "RSR-20260713-00021",
    productId: "nike-air-force-1-07-green-white",
    productPrice: 340,
    deliveryEstimate: "GH₵20-40",
    finalDeliveryQuote: 45,
    totalToPay: 385,
    paymentMethod: "Pay on Delivery",
    deliveryOption: "Standard Delivery",
    status: "Awaiting Customer Confirmation",
    confirmationDeadline: "Confirm within 1 hour to reserve this item.",
    placedAt: "13 July 2026, 10:24 AM"
  },
  issueCategories: ["Order", "Delivery", "Payment", "Wrong product", "Damaged product", "Customer changed mind"]
} as const;

export function getCustomerProduct(productId: string) {
  return customerCheckoutMock.products.find((product) => product.id === productId) ?? customerCheckoutMock.products[0];
}
