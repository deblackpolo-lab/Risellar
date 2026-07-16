import { Card } from "@/components/ui/Card";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { ProductImageFrame, type ProductImageLike } from "./ProductImageFrame";

export function ProductCard({
  images,
  imageAlt,
  name,
  price,
  status
}: {
  images?: ProductImageLike[];
  imageAlt?: string;
  name: string;
  price: string;
  status: string;
}) {
  return (
    <Card>
      <ProductImageFrame className="aspect-[4/3] rounded-[var(--radius-md)]" imageAlt={imageAlt} images={images} productName={name} />
      <div className="mt-3 flex items-start justify-between gap-3">
        <div>
          <h3 className="line-clamp-2 text-sm font-bold leading-5">{name}</h3>
          <p className="mt-1 text-lg font-bold text-[var(--color-primary)]">{price}</p>
        </div>
        <StatusBadge status={status} />
      </div>
    </Card>
  );
}
