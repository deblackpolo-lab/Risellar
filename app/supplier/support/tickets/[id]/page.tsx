import { SupplierSupportTicketDetailScreen } from "@/components/support/support-disputes-screens";

export default async function SupplierSupportTicketDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <SupplierSupportTicketDetailScreen ticketId={id} />;
}
