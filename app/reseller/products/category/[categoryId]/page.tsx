import { ResellerProductCatalogScreen } from "@/components/reseller/screens";

export default async function ResellerCategoryProductsPage({ params }: { params: Promise<{ categoryId: string }> }) {
  const { categoryId } = await params;

  return <ResellerProductCatalogScreen categoryId={categoryId} />;
}
