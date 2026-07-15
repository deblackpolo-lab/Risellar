import { ResellerShareProductScreen } from "@/components/reseller/screens";

export default async function ResellerShareProductPage({ params }: { params: Promise<{ productId: string }> }) {
  const { productId } = await params;

  return <ResellerShareProductScreen productId={productId} />;
}
