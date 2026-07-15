import { CustomerReportIssueScreen } from "@/components/customer/screens";

export default async function CustomerReportIssuePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return <CustomerReportIssueScreen id={id} />;
}
