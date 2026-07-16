import Image from "next/image";
import type { MockProductImage, ProductImageTone } from "@/lib/mock/product-images";
import { cn } from "@/lib/utils/cn";

export type ProductImageLike = MockProductImage & { src?: string };

type NormalizedProductImage = ProductImageLike & {
  src: string;
};

const toneStyles: Record<ProductImageTone, { from: string; to: string; ink: string }> = {
  shoe: { from: "#E7F5EE", to: "#FFF4D8", ink: "#086B4F" },
  beauty: { from: "#FFF0F4", to: "#FFF7E6", ink: "#8A5A00" },
  tech: { from: "#EEF4FF", to: "#E7F5EE", ink: "#086B4F" },
  hostel: { from: "#FFF7E6", to: "#E7F5EE", ink: "#8A5A00" },
  fashion: { from: "#F6F7F8", to: "#E7F5EE", ink: "#086B4F" },
  home: { from: "#FFF7E6", to: "#F6F7F8", ink: "#086B4F" }
};

function escapeSvgText(value: string) {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

export function createProductPlaceholderSrc(image: ProductImageLike, productName: string) {
  const tone = toneStyles[image.tone];
  const label = escapeSvgText(image.label);
  const detail = escapeSvgText(image.detail);
  const title = escapeSvgText(productName);
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="640" height="640" viewBox="0 0 640 640" role="img" aria-label="${title}">
      <defs>
        <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="${tone.from}" />
          <stop offset="100%" stop-color="${tone.to}" />
        </linearGradient>
        <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="18" stdDeviation="20" flood-color="#086B4F" flood-opacity="0.16" />
        </filter>
      </defs>
      <rect width="640" height="640" rx="56" fill="url(#bg)" />
      <rect x="104" y="132" width="432" height="288" rx="44" fill="#FFFFFF" fill-opacity="0.84" filter="url(#shadow)" />
      <path d="M188 380 C238 304 294 260 366 250 C414 244 452 258 486 292" fill="none" stroke="${tone.ink}" stroke-width="28" stroke-linecap="round" opacity="0.9" />
      <path d="M176 398 H478" stroke="${tone.ink}" stroke-width="22" stroke-linecap="round" opacity="0.68" />
      <circle cx="224" cy="222" r="34" fill="${tone.ink}" opacity="0.12" />
      <circle cx="450" cy="208" r="24" fill="#FFB300" opacity="0.35" />
      <text x="320" y="474" text-anchor="middle" font-family="Arial, sans-serif" font-size="64" font-weight="800" fill="${tone.ink}">${label}</text>
      <text x="320" y="524" text-anchor="middle" font-family="Arial, sans-serif" font-size="24" font-weight="700" fill="#5F6B7A">${detail}</text>
    </svg>
  `;

  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
}

export function normalizeProductImages(images: ProductImageLike[] | undefined, productName: string) {
  const fallback: ProductImageLike[] = [
    {
      id: "placeholder",
      alt: `${productName} product image placeholder`,
      label: productName.slice(0, 3).toUpperCase(),
      tone: "home",
      detail: "Product preview"
    }
  ];

  return (images && images.length > 0 ? images : fallback).slice(0, 5).map<NormalizedProductImage>((image) => ({
    ...image,
    src: image.src ?? createProductPlaceholderSrc(image, productName)
  }));
}

export function ProductImageFrame({
  images,
  productName,
  imageAlt,
  className,
  imageClassName,
  priority = false
}: {
  images?: ProductImageLike[];
  productName: string;
  imageAlt?: string;
  className?: string;
  imageClassName?: string;
  priority?: boolean;
}) {
  const [image] = normalizeProductImages(images, productName);

  return (
    <figure
      aria-label={imageAlt ?? image.alt}
      className={cn(
        "relative aspect-square overflow-hidden rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-[var(--color-muted-soft)]",
        className
      )}
    >
      <Image
        alt={image.alt}
        className={cn("object-cover", imageClassName)}
        fill
        priority={priority}
        sizes="(max-width: 640px) 45vw, 220px"
        src={image.src}
        unoptimized
      />
    </figure>
  );
}
