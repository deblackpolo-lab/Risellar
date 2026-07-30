import { CheckoutDraftStartForm } from "@/components/customer/checkout-draft-start-form";
import { PublicShopProductRpcScreen } from "@/components/customer/public-shop-rpc-screens";
import { readPublicResellerShopProductWithClient } from "@/lib/public-shop/catalog";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function PublicProductPage({
  params,
  searchParams
}: {
  params: Promise<{ productId: string; shopSlug: string }>;
  searchParams?: Promise<{ checkout_error?: string }>;
}) {
  const { productId, shopSlug } = await params;
  const query = await searchParams;
  const supabase = await createSupabaseServerClient();
  const { error, product, shop } = await readPublicResellerShopProductWithClient(supabase, shopSlug, productId);

  return (
    <PublicShopProductRpcScreen
      error={error}
      product={product}
      shop={shop}
      startCheckoutControl={product && shop ? (
        <CheckoutDraftStartForm
          listingId={product.listingId}
          returnTo={`/shop/${shop.slug}/product/${product.shareSlug || product.productSlug}`}
        />
      ) : null}
      startCheckoutErrorCode={query?.checkout_error ?? null}
    />
  );
}
