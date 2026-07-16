import { EdgeCaseRouteScreen } from "@/components/edge-cases/edge-case-screens";
import { edgeCaseDefinitions, requiredEdgeCasePaths } from "@/lib/mock/edge-cases";

export function generateStaticParams() {
  return requiredEdgeCasePaths
    .filter((path) => path !== "/edge-cases")
    .map((path) => ({
      slug: path.replace("/edge-cases/", "").split("/")
    }));
}

export default async function EdgeCasesPage({ params }: { params: Promise<{ slug?: string[] }> }) {
  const resolvedParams = await params;

  return <EdgeCaseRouteScreen slug={resolvedParams.slug} />;
}

export const dynamicParams = true;

export const metadata = {
  title: "Risellar Empty States + Edge Cases",
  description: `${edgeCaseDefinitions.length} mock-only Risellar state patterns for Phase 14.`
};
