import { SupplierFinanceRpcPage } from "./finance-page";

export default function SupplierFinancePage({
  searchParams
}: {
  searchParams?: Promise<{ status?: string; from?: string; to?: string }>;
}) {
  return <SupplierFinanceRpcPage searchParams={searchParams} title="Supplier finance" />;
}
