import { AdminOrderDetailScreen } from "@/components/admin/admin-core-screens";

export default async function AdminOrderDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <AdminOrderDetailScreen orderId={id} />;
}
