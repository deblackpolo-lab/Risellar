"use client";

import { useCallback, useEffect, useState } from "react";
import useEmblaCarousel from "embla-carousel-react";
import { PhotoView } from "react-photo-view";
import { cn } from "@/lib/utils/cn";
import { ProductImageFrame, normalizeProductImages, type ProductImageLike } from "./ProductImageFrame";
import { ProductImageLightbox } from "./ProductImageLightbox";

export function ProductImageGallery({
  images,
  productName,
  imageAlt,
  className
}: {
  images?: ProductImageLike[];
  productName: string;
  imageAlt?: string;
  className?: string;
}) {
  const galleryImages = normalizeProductImages(images, productName);
  const [emblaRef, emblaApi] = useEmblaCarousel({ align: "start", containScroll: "trimSnaps" });
  const [selectedIndex, setSelectedIndex] = useState(0);

  const onSelect = useCallback(() => {
    if (!emblaApi) return;
    setSelectedIndex(emblaApi.selectedScrollSnap());
  }, [emblaApi]);

  useEffect(() => {
    if (!emblaApi) return undefined;
    onSelect();
    emblaApi.on("select", onSelect);
    emblaApi.on("reInit", onSelect);

    return () => {
      emblaApi.off("select", onSelect);
      emblaApi.off("reInit", onSelect);
    };
  }, [emblaApi, onSelect]);

  return (
    <section className={cn("space-y-3", className)} aria-label={`${productName} image gallery`}>
      <ProductImageLightbox images={galleryImages} productName={productName}>
        <div className="overflow-hidden rounded-[var(--radius-lg)]" ref={emblaRef}>
          <div className="flex touch-pan-y">
            {galleryImages.map((image, index) => (
              <div className="min-w-0 flex-[0_0_100%]" key={image.id}>
                <PhotoView src={image.src}>
                  <button
                    aria-label={`View ${productName} image ${index + 1} of ${galleryImages.length}`}
                    className="block w-full rounded-[var(--radius-lg)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--color-primary)]"
                    type="button"
                  >
                    <ProductImageFrame
                      className="aspect-[4/3]"
                      imageAlt={index === 0 ? imageAlt ?? image.alt : image.alt}
                      images={[image]}
                      productName={productName}
                      priority={index === 0}
                    />
                  </button>
                </PhotoView>
              </div>
            ))}
          </div>
        </div>
      </ProductImageLightbox>

      <div className="flex items-center justify-between gap-3">
        <p className="text-xs font-bold text-[var(--color-muted)]">
          {selectedIndex + 1} / {galleryImages.length}
        </p>
        <div className="flex items-center gap-2" aria-label={`${productName} gallery pagination`}>
          {galleryImages.map((image, index) => (
            <button
              aria-label={`Show ${productName} image ${index + 1}`}
              className={cn(
                "h-2.5 w-2.5 rounded-full border border-[var(--color-primary)] transition",
                selectedIndex === index ? "bg-[var(--color-primary)]" : "bg-white"
              )}
              key={image.id}
              onClick={() => emblaApi?.scrollTo(index)}
              type="button"
            />
          ))}
        </div>
      </div>
      <p className="text-xs font-semibold text-[var(--color-muted)]">Tap image to view full gallery</p>
    </section>
  );
}
