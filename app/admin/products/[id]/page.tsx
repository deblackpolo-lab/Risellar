import { AdminProductDetailScreen } from "@/components/admin/admin-core-screens";

export default async function AdminProductDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <AdminProductDetailScreen productId={id} />;
}
