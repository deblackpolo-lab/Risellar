import { AdminReturnDetailScreen } from "@/components/support/support-disputes-screens";

export default async function AdminReturnDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <AdminReturnDetailScreen returnId={id} />;
}
