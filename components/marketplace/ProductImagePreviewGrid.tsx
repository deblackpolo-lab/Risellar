import { ImagePlus, Scissors, Sparkles } from "lucide-react";
import { cn } from "@/lib/utils/cn";
import { ProductImageFrame, type ProductImageLike } from "./ProductImageFrame";

export function ProductImagePreviewGrid({
  images,
  productName,
  imageAlt,
  maxImages = 5,
  className
}: {
  images?: ProductImageLike[];
  productName: string;
  imageAlt?: string;
  maxImages?: number;
  className?: string;
}) {
  const productImages = (images ?? []).slice(0, maxImages);
  const emptySlots = Array.from({ length: Math.max(maxImages - productImages.length, 0) }, (_, index) => index);

  return (
    <section className={cn("rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-4 shadow-[var(--shadow-sm)]", className)}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <h3 className="text-base font-extrabold">Product images</h3>
          <p className="mt-1 text-sm text-[var(--color-muted)]">Upload up to 5 product images.</p>
        </div>
        <span className="rounded-full bg-[var(--color-primary-subtle)] px-3 py-1 text-xs font-bold text-[var(--color-primary)]">
          {productImages.length} / {maxImages} images added
        </span>
      </div>

      <div className="mt-4 grid grid-cols-5 gap-2">
        {productImages.map((image, index) => (
          <ProductImageFrame
            className="rounded-[var(--radius-md)]"
            imageAlt={index === 0 ? imageAlt ?? image.alt : image.alt}
            imageClassName="object-cover"
            images={[image]}
            key={image.id}
            productName={productName}
          />
        ))}
        {emptySlots.map((slot) => (
          <div
            aria-label={`${productName} empty image slot ${slot + productImages.length + 1}`}
            className="grid aspect-square place-items-center rounded-[var(--radius-md)] border border-dashed border-[var(--color-border)] bg-[var(--color-muted-soft)] text-[var(--color-muted)]"
            key={slot}
          >
            <ImagePlus className="h-5 w-5" aria-hidden />
          </div>
        ))}
      </div>

      <div className="mt-4 grid grid-cols-2 gap-2">
        <button
          aria-label="Crop & preview images"
          className="inline-flex min-h-11 items-center justify-center gap-2 rounded-[var(--radius-md)] border border-[var(--color-primary)] px-3 text-sm font-bold text-[var(--color-primary)]"
          type="button"
        >
          <Scissors className="h-4 w-4" aria-hidden />
          Crop & preview
        </button>
        <button
          className="inline-flex min-h-11 items-center justify-center gap-2 rounded-[var(--radius-md)] bg-[var(--color-primary-subtle)] px-3 text-sm font-bold text-[var(--color-primary)]"
          type="button"
        >
          <Sparkles className="h-4 w-4" aria-hidden />
          Compress mock
        </button>
      </div>
      <p className="mt-3 text-xs leading-5 text-[var(--color-muted)]">
        Images will be cropped and compressed before backend upload is connected.
      </p>
    </section>
  );
}
