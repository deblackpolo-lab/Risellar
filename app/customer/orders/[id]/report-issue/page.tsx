import { CustomerReportIssueScreen } from "@/components/support/support-disputes-screens";

export default async function CustomerReportIssuePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <CustomerReportIssueScreen id={id} />;
}
