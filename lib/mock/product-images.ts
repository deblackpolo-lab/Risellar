export type ProductImageTone = "shoe" | "beauty" | "tech" | "hostel" | "fashion" | "home";

export type MockProductImage = {
  id: string;
  alt: string;
  label: string;
  tone: ProductImageTone;
  detail: string;
};

const productImageSets = {
  "nike-air-force-1-07-green-white": [
    { id: "nike-main", label: "AF1", tone: "shoe", detail: "Main side view", alt: "Nike Air Force 1 '07 Green & White main product image" },
    { id: "nike-angle", label: "Side", tone: "shoe", detail: "Outer profile", alt: "Nike Air Force 1 '07 Green & White side profile image" },
    { id: "nike-top", label: "Top", tone: "shoe", detail: "Top view", alt: "Nike Air Force 1 '07 Green & White top view image" },
    { id: "nike-sole", label: "Sole", tone: "shoe", detail: "Sole detail", alt: "Nike Air Force 1 '07 Green & White sole detail image" },
    { id: "nike-box", label: "Box", tone: "shoe", detail: "Package view", alt: "Nike Air Force 1 '07 Green & White packaging image" }
  ],
  "jean-paul-gaultier-le-male-edt-125ml": [
    { id: "jpg-front", label: "JPG", tone: "beauty", detail: "Bottle front", alt: "Jean Paul Gaultier Le Male EDT 125ml front image" },
    { id: "jpg-box", label: "Box", tone: "beauty", detail: "Retail box", alt: "Jean Paul Gaultier Le Male EDT 125ml retail box image" },
    { id: "jpg-side", label: "Side", tone: "beauty", detail: "Bottle side", alt: "Jean Paul Gaultier Le Male EDT 125ml side image" },
    { id: "jpg-detail", label: "Cap", tone: "beauty", detail: "Cap detail", alt: "Jean Paul Gaultier Le Male EDT 125ml cap detail image" }
  ],
  "anua-niacinamide-serum": [
    { id: "anua-front", label: "Anua", tone: "beauty", detail: "Bottle front", alt: "Anua Niacinamide Serum 30ml front image" },
    { id: "anua-box", label: "Box", tone: "beauty", detail: "Package view", alt: "Anua Niacinamide Serum 30ml packaging image" },
    { id: "anua-dropper", label: "Serum", tone: "beauty", detail: "Texture detail", alt: "Anua Niacinamide Serum 30ml texture detail image" }
  ],
  "oraimo-power-bank-30000mah": [
    { id: "oraimo-main", label: "OPB", tone: "tech", detail: "Front view", alt: "Oraimo Power Bank 30000mAh front image" },
    { id: "oraimo-ports", label: "Ports", tone: "tech", detail: "Port detail", alt: "Oraimo Power Bank 30000mAh charging ports image" },
    { id: "oraimo-box", label: "Box", tone: "tech", detail: "Package view", alt: "Oraimo Power Bank 30000mAh packaging image" }
  ],
  "iphone-14-pro-max-case": [
    { id: "case-main", label: "Case", tone: "tech", detail: "Case front", alt: "iPhone 14 Pro Max Case front image" },
    { id: "case-fit", label: "Fit", tone: "tech", detail: "Camera cutout", alt: "iPhone 14 Pro Max Case camera cutout image" }
  ],
  "hostel-essentials-pack": [
    { id: "hostel-main", label: "Hostel", tone: "hostel", detail: "Bundle view", alt: "Hostel Essentials Pack bundle image" },
    { id: "hostel-bedding", label: "Bedding", tone: "hostel", detail: "Bedding set", alt: "Hostel Essentials Pack bedding image" },
    { id: "hostel-lamp", label: "Lamp", tone: "hostel", detail: "Study lamp", alt: "Hostel Essentials Pack study lamp image" },
    { id: "hostel-basket", label: "Basket", tone: "hostel", detail: "Storage basket", alt: "Hostel Essentials Pack storage basket image" },
    { id: "hostel-box", label: "Set", tone: "hostel", detail: "Packed set", alt: "Hostel Essentials Pack packed set image" }
  ],
  "samsung-galaxy-a14": [
    { id: "a14-front", label: "A14", tone: "tech", detail: "Phone front", alt: "Samsung Galaxy A14 front image" },
    { id: "a14-back", label: "Back", tone: "tech", detail: "Phone back", alt: "Samsung Galaxy A14 back image" },
    { id: "a14-box", label: "Box", tone: "tech", detail: "Package view", alt: "Samsung Galaxy A14 packaging image" }
  ],
  "laptop-backpack": [
    { id: "bag-main", label: "Bag", tone: "fashion", detail: "Front view", alt: "Laptop Backpack front image" },
    { id: "bag-pocket", label: "Pocket", tone: "fashion", detail: "Pocket detail", alt: "Laptop Backpack pocket detail image" },
    { id: "bag-side", label: "Side", tone: "fashion", detail: "Side view", alt: "Laptop Backpack side image" }
  ],
  "skincare-set": [
    { id: "skin-main", label: "Skin", tone: "beauty", detail: "Set view", alt: "Skincare Set front image" },
    { id: "skin-items", label: "Items", tone: "beauty", detail: "Item detail", alt: "Skincare Set item detail image" },
    { id: "skin-box", label: "Box", tone: "beauty", detail: "Package view", alt: "Skincare Set packaging image" }
  ],
  "press-on-nails": [
    { id: "nails-main", label: "Nails", tone: "beauty", detail: "Set view", alt: "Press-On Nails set image" },
    { id: "nails-close", label: "Style", tone: "beauty", detail: "Style detail", alt: "Press-On Nails style detail image" }
  ],
  "hair-oil": [
    { id: "oil-main", label: "Oil", tone: "beauty", detail: "Bottle front", alt: "Hair Growth Oil front image" },
    { id: "oil-dropper", label: "Drop", tone: "beauty", detail: "Dropper detail", alt: "Hair Growth Oil dropper detail image" }
  ],
  "delight-impressions-perfume": [
    { id: "delight-main", label: "EDP", tone: "beauty", detail: "Bottle front", alt: "Delight Impressions Perfume front image" },
    { id: "delight-box", label: "Box", tone: "beauty", detail: "Package view", alt: "Delight Impressions Perfume packaging image" }
  ],
  "ordinary-skincare-set": [
    { id: "ordinary-main", label: "Ord", tone: "beauty", detail: "Set view", alt: "Ordinary Skincare Set front image" },
    { id: "ordinary-detail", label: "Set", tone: "beauty", detail: "Bottle detail", alt: "Ordinary Skincare Set bottle detail image" },
    { id: "ordinary-box", label: "Box", tone: "beauty", detail: "Package view", alt: "Ordinary Skincare Set packaging image" }
  ]
} satisfies Record<string, MockProductImage[]>;

const aliases: Record<string, keyof typeof productImageSets> = {
  "jean-paul-gaultier-le-male": "jean-paul-gaultier-le-male-edt-125ml",
  "jean-paul-gaultier-le-male-edt": "jean-paul-gaultier-le-male-edt-125ml",
  "anua-niacinamide-serum-30ml": "anua-niacinamide-serum",
  "oraimo-power-bank": "oraimo-power-bank-30000mah",
  "iphone-14-pro-max-clear-case": "iphone-14-pro-max-case"
};

export function getMockProductImages(key: string): MockProductImage[] {
  const resolved = aliases[key] ?? key;
  return productImageSets[resolved as keyof typeof productImageSets] ?? productImageSets["nike-air-force-1-07-green-white"];
}

export function getPrimaryProductImageAlt(productName: string): string {
  return `${productName} product image gallery`;
}
