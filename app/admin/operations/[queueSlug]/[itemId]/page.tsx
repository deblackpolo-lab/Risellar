import { AdminOperationsQueueDetailScreen } from "@/components/admin/admin-operations-screens";

export default async function AdminOperationsQueueDetailPage({ params }: { params: Promise<{ queueSlug: string; itemId: string }> }) {
  const { queueSlug, itemId } = await params;

  return <AdminOperationsQueueDetailScreen itemId={itemId} queueSlug={queueSlug} />;
}
