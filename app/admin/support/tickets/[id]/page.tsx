import { AdminSupportTicketDetailScreen } from "@/components/support/support-disputes-screens";

export default async function AdminSupportTicketDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <AdminSupportTicketDetailScreen ticketId={id} />;
}
