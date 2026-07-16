import { AdminRefundDetailScreen } from "@/components/support/support-disputes-screens";

export default async function AdminRefundDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <AdminRefundDetailScreen refundId={id} />;
}
