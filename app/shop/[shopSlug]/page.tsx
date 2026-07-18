import { PublicShopRpcScreen } from "@/components/customer/public-shop-rpc-screens";
import { listPublicResellerShopWithClient } from "@/lib/public-shop/catalog";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function PublicShopPage({ params }: { params: Promise<{ shopSlug: string }> }) {
  const { shopSlug } = await params;
  const supabase = await createSupabaseServerClient();
  const { error, products, shop } = await listPublicResellerShopWithClient(supabase, shopSlug);

  return <PublicShopRpcScreen error={error} products={products} shop={shop} />;
}
