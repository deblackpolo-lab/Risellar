import { CustomerReturnRequestScreen } from "@/components/support/support-disputes-screens";

export default async function CustomerReturnRequestPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <CustomerReturnRequestScreen id={id} />;
}
