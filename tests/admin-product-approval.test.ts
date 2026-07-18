import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildAdminProductReviewPayload,
  canReviewSupplierProducts,
  reviewSupplierProductWithClient,
  type AdminProductReviewRpcClient
} from "@/lib/admin/product-approval";

function createRpcSpyClient(response: { data?: unknown; error?: { code?: string; message?: string } | null } = {}) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: AdminProductReviewRpcClient = {
    async rpc<T = unknown>(name: string, args?: Record<string, unknown>) {
      calls.push({ name, args });
      return {
        data: (response.data ?? "11111111-1111-4111-8111-111111111111") as T,
        error: response.error ?? null
      };
    }
  };

  return { calls, client };
}

function readSourceTree(relativePath: string): string {
  const fullPath = join(process.cwd(), relativePath);
  const stat = statSync(fullPath);

  if (stat.isFile()) {
    return readFileSync(fullPath, "utf8");
  }

  return readdirSync(fullPath)
    .map((entry): string => readSourceTree(join(relativePath, entry)))
    .join("\n");
}

describe("admin product approval RPC integration", () => {
  it("builds review payloads only for approved or rejected decisions", () => {
    expect(
      buildAdminProductReviewPayload({
        productId: "11111111-1111-4111-8111-111111111111",
        decision: "approved",
        reviewNotes: "  Looks good for QA  "
      })
    ).toEqual({
      productId: "11111111-1111-4111-8111-111111111111",
      decision: "approved",
      reviewNotes: "Looks good for QA"
    });

    expect(() => buildAdminProductReviewPayload({ productId: "", decision: "approved" })).toThrow("Product id is required");
    expect(() =>
      buildAdminProductReviewPayload({
        productId: "11111111-1111-4111-8111-111111111111",
        decision: "pending_review"
      })
    ).toThrow("Product review decision must be approved or rejected");
  });

  it("calls the audited product review RPC without direct table mutation", async () => {
    const { calls, client } = createRpcSpyClient();

    const result = await reviewSupplierProductWithClient(client, {
      productId: "22222222-2222-4222-8222-222222222222",
      decision: "rejected",
      reviewNotes: "Dev-only reject path"
    });

    expect(result).toMatchObject({ code: "OK" });
    expect(calls).toEqual([
      {
        name: "review_supplier_product",
        args: {
          p_product_id: "22222222-2222-4222-8222-222222222222",
          p_decision: "rejected",
          p_review_notes: "Dev-only reject path"
        }
      }
    ]);
  });

  it("requires active admin staff access for product reviews", () => {
    expect(canReviewSupplierProducts({ hasActiveAdminStaff: true })).toBe(true);
    expect(canReviewSupplierProducts({ hasActiveAdminStaff: false })).toBe(false);
    expect(canReviewSupplierProducts(null)).toBe(false);
  });

  it("keeps service role and direct product approval mutation out of app components", () => {
    const root = process.cwd();
    const files = [
      "app/admin/products/actions.ts",
      "app/admin/products/page.tsx",
      "app/admin/products/[id]/page.tsx",
      "components/admin/product-approval-rpc-screens.tsx"
    ];

    for (const file of files) {
      const source = readFileSync(join(root, file), "utf8");
      expect(source).not.toContain("createSupabaseAdminClient");
      expect(source).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
      expect(source).not.toContain(".from(\"products\").update");
      expect(source).not.toContain(".from('products').update");
      expect(source).not.toContain('name="approval_status"');
      expect(source).not.toContain('name="product_status"');
    }
  });

  it("does not connect unrelated customer, reseller, checkout, order, payment, or delivery flows", () => {
    const unrelatedPaths = ["app/checkout", "app/customer", "app/reseller", "app/shop"];
    const forbidden = ["review_supplier_product", "approve_supplier_product", "reject_supplier_product"];

    for (const relativePath of unrelatedPaths) {
      const source = readSourceTree(relativePath);
      for (const token of forbidden) {
        expect(source).not.toContain(token);
      }
    }
  });
});
