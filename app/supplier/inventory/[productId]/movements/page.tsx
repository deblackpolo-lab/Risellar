import { StockMovementHistoryScreen } from "@/components/supplier/inventory-screens";

export default async function SupplierInventoryMovementsPage({ params }: { params: Promise<{ productId: string }> }) {
  const { productId } = await params;

  return <StockMovementHistoryScreen productId={productId} />;
}
