import { PublicShopScreen } from "@/components/customer/screens";

export default async function PublicShopPage({ params }: { params: Promise<{ shopSlug: string }> }) {
  const { shopSlug } = await params;

  return <PublicShopScreen shopSlug={shopSlug} />;
}
