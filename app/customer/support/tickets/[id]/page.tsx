import { CustomerSupportTicketDetailScreen } from "@/components/support/support-disputes-screens";

export default async function CustomerSupportTicketDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <CustomerSupportTicketDetailScreen ticketId={id} />;
}
