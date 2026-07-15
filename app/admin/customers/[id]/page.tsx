import { AdminCustomerDetailScreen } from "@/components/admin/admin-core-screens";

export default async function AdminCustomerDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <AdminCustomerDetailScreen customerId={id} />;
}
