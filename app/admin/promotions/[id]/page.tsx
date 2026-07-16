import { AdminPromotionDetailScreen } from "@/components/promotions/promotions-insights-screens";

export default async function AdminPromotionDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <AdminPromotionDetailScreen promotionId={id} />;
}
