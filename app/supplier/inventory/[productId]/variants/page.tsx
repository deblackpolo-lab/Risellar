import { VariantStockScreen } from "@/components/supplier/inventory-screens";

export default async function SupplierInventoryVariantsPage({ params }: { params: Promise<{ productId: string }> }) {
  const { productId } = await params;

  return <VariantStockScreen productId={productId} />;
}
