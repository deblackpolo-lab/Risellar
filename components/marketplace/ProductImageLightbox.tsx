"use client";

import type { ReactNode } from "react";
import { PhotoProvider } from "react-photo-view";
import type { ProductImageLike } from "./ProductImageFrame";

export function ProductImageLightbox({
  children,
  images,
  productName
}: {
  children: ReactNode;
  images: ProductImageLike[];
  productName: string;
}) {
  return (
    <PhotoProvider
      loop
      maskOpacity={0.88}
      toolbarRender={({ index }) => (
        <span className="rounded-full bg-white/90 px-3 py-1 text-xs font-bold text-[var(--color-charcoal)]">
          {index + 1} / {images.length} {productName}
        </span>
      )}
    >
      {children}
    </PhotoProvider>
  );
}
