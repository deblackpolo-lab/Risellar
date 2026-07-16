import { AdminDisputeDetailScreen } from "@/components/support/support-disputes-screens";

export default async function AdminDisputeDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <AdminDisputeDetailScreen disputeId={id} />;
}
