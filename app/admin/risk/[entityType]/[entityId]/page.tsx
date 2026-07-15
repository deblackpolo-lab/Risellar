import { AdminRiskDetailScreen } from "@/components/admin/admin-operations-screens";
import type { RiskEntityType } from "@/lib/mock/admin-operations";

export default async function AdminRiskDetailPage({ params }: { params: Promise<{ entityType: string; entityId: string }> }) {
  const { entityType, entityId } = await params;

  return <AdminRiskDetailScreen entityId={entityId} entityType={entityType as RiskEntityType} />;
}
