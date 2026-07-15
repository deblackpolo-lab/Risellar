import { AdminResellerDetailScreen } from "@/components/admin/admin-core-screens";

export default async function AdminResellerDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <AdminResellerDetailScreen resellerId={id} />;
}
