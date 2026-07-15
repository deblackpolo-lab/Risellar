import { RestockProductScreen } from "@/components/supplier/inventory-screens";

export default async function SupplierInventoryRestockPage({ params }: { params: Promise<{ productId: string }> }) {
  const { productId } = await params;

  return <RestockProductScreen productId={productId} />;
}
