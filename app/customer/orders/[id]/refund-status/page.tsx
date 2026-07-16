import { CustomerRefundStatusScreen } from "@/components/support/support-disputes-screens";

export default async function CustomerRefundStatusPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <CustomerRefundStatusScreen id={id} />;
}
