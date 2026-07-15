import { PublicProductDetailScreen } from "@/components/customer/screens";

export default async function PublicProductPage({ params }: { params: Promise<{ productId: string; shopSlug: string }> }) {
  const { productId, shopSlug } = await params;

  return <PublicProductDetailScreen productId={productId} shopSlug={shopSlug} />;
}
