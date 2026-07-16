import { SupplierTeamMemberDetailScreen } from "@/components/supplier/team-permissions-screens";

export default async function SupplierTeamMemberPage({ params }: { params: Promise<{ memberId: string }> }) {
  const { memberId } = await params;
  return <SupplierTeamMemberDetailScreen memberId={memberId} />;
}
