import { SupplierPromotionPerformanceScreen } from "@/components/promotions/promotions-insights-screens";

export default async function SupplierPromotionPerformancePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <SupplierPromotionPerformanceScreen promotionId={id} />;
}
