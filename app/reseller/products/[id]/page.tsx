import { ResellerProductDetailScreen } from "@/components/reseller/screens";

export default async function ProductDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <ResellerProductDetailScreen id={id} />;
}
