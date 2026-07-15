import { PriceChangeRequestScreen } from "@/components/supplier/inventory-screens";

export default async function SupplierInventoryPriceChangePage({ params }: { params: Promise<{ productId: string }> }) {
  const { productId } = await params;

  return <PriceChangeRequestScreen productId={productId} />;
}
