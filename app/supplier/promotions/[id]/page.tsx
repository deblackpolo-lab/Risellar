import { SupplierPromotionDetailScreen } from "@/components/promotions/promotions-insights-screens";

export default async function SupplierPromotionDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <SupplierPromotionDetailScreen promotionId={id} />;
}
