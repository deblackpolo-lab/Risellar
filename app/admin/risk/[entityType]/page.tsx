import { AdminRiskEntityScreen } from "@/components/admin/admin-operations-screens";
import type { RiskEntityType } from "@/lib/mock/admin-operations";

export default async function AdminRiskEntityPage({ params }: { params: Promise<{ entityType: string }> }) {
  const { entityType } = await params;

  return <AdminRiskEntityScreen entityType={entityType as RiskEntityType} />;
}
