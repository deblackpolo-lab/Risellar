import { AdminOperationsQueueScreen } from "@/components/admin/admin-operations-screens";

export default async function AdminOperationsQueuePage({ params }: { params: Promise<{ queueSlug: string }> }) {
  const { queueSlug } = await params;

  return <AdminOperationsQueueScreen queueSlug={queueSlug} />;
}
