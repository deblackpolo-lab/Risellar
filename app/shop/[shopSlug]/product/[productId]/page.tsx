import { PublicShopProductRpcScreen } from "@/components/customer/public-shop-rpc-screens";
import { readPublicResellerShopProductWithClient } from "@/lib/public-shop/catalog";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function PublicProductPage({ params }: { params: Promise<{ productId: string; shopSlug: string }> }) {
  const { productId, shopSlug } = await params;
  const supabase = await createSupabaseServerClient();
  const { error, product, shop } = await readPublicResellerShopProductWithClient(supabase, shopSlug, productId);

  return <PublicShopProductRpcScreen error={error} product={product} shop={shop} />;
}
