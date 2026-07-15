import { InventoryProductDetailScreen } from "@/components/supplier/inventory-screens";

export default async function SupplierInventoryProductPage({ params }: { params: Promise<{ productId: string }> }) {
  const { productId } = await params;

  return <InventoryProductDetailScreen productId={productId} />;
}
