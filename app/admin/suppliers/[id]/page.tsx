import { AdminSupplierDetailScreen } from "@/components/admin/admin-core-screens";

export default async function AdminSupplierDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <AdminSupplierDetailScreen supplierId={id} />;
}
