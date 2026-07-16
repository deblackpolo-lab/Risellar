import { ResellerSupportTicketDetailScreen } from "@/components/support/support-disputes-screens";

export default async function ResellerSupportTicketDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ResellerSupportTicketDetailScreen ticketId={id} />;
}
