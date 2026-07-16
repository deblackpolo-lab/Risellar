import { TeamMemberPermissionsScreen } from "@/components/supplier/team-permissions-screens";

export default async function SupplierTeamMemberPermissionsPage({ params }: { params: Promise<{ memberId: string }> }) {
  const { memberId } = await params;
  return <TeamMemberPermissionsScreen memberId={memberId} />;
}
