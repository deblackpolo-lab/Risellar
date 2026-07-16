import Link from "next/link";
import { ChevronRight, Star } from "lucide-react";
import { StatusBadge } from "@/components/ui";
import { cn } from "@/lib/utils/cn";
import { ProductImageFrame, type ProductImageLike } from "./ProductImageFrame";

function CardContent({
  badges = [],
  category,
  expectedProfit,
  imageAlt,
  images,
  name,
  price,
  priceLabel = "Price",
  rating,
  resellerCost,
  stockStatus
}: ProductGridCardProps) {
  return (
    <>
      <ProductImageFrame imageAlt={imageAlt} images={images} productName={name} />
      <div className="mt-3 min-w-0 space-y-2">
        <div className="flex min-w-0 items-start justify-between gap-2">
          <h3 className="line-clamp-2 min-h-[2.5rem] text-sm font-extrabold leading-5 text-[var(--color-charcoal)]">
            {name}
          </h3>
          <ChevronRight className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-muted)]" aria-hidden />
        </div>
        <p className="truncate text-xs font-semibold text-[var(--color-muted)]">{category}</p>
        {badges.length > 0 ? (
          <div className="flex flex-wrap gap-1.5">
            {badges.slice(0, 2).map((badge) => (
              <StatusBadge key={badge} status={badge}>{badge}</StatusBadge>
            ))}
          </div>
        ) : null}
        <dl className="space-y-1 text-xs">
          <div>
            <dt className="text-[var(--color-muted)]">{priceLabel}</dt>
            <dd className="text-base font-extrabold text-[var(--color-primary)]">{price}</dd>
          </div>
          {resellerCost ? (
            <div className="flex justify-between gap-2">
              <dt className="text-[var(--color-muted)]">Reseller cost</dt>
              <dd className="font-bold">{resellerCost}</dd>
              <span className="sr-only">Reseller cost {resellerCost}</span>
            </div>
          ) : null}
          {expectedProfit ? (
            <div className="flex justify-between gap-2">
              <dt className="text-[var(--color-muted)]">Expected profit</dt>
              <dd className="font-bold text-[var(--color-primary)]">{expectedProfit}</dd>
              <span className="sr-only">Profit {expectedProfit}</span>
            </div>
          ) : null}
        </dl>
        <div className="flex min-h-6 items-center justify-between gap-2">
          {rating ? (
            <span className="inline-flex min-w-0 items-center gap-1 truncate text-xs font-semibold text-[var(--color-muted)]">
              <Star className="h-3.5 w-3.5 shrink-0 fill-[var(--color-accent)] text-[var(--color-accent)]" aria-hidden />
              {rating}
            </span>
          ) : <span />}
          {stockStatus ? <span className="truncate text-xs font-bold text-[var(--color-primary)]">{stockStatus}</span> : null}
        </div>
      </div>
    </>
  );
}

export type ProductGridCardProps = {
  href?: string;
  name: string;
  category: string;
  price: string;
  priceLabel?: string;
  images?: ProductImageLike[];
  imageAlt?: string;
  badges?: string[];
  stockStatus?: string;
  rating?: string;
  resellerCost?: string;
  expectedProfit?: string;
  className?: string;
};

export function ProductGridCard(props: ProductGridCardProps) {
  const className = cn(
    "group block h-full overflow-hidden rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white p-3 shadow-[var(--shadow-sm)] transition hover:border-[var(--color-primary)]/35 hover:shadow-[var(--shadow-md)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--color-primary)]",
    props.className
  );

  if (props.href) {
    return (
      <Link aria-label={props.name} className={className} href={props.href}>
        <CardContent {...props} />
      </Link>
    );
  }

  return (
    <article className={className} role="listitem">
      <CardContent {...props} />
    </article>
  );
}
