import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  listResellerCatalogProductsWithClient,
  mapResellerCatalogRows,
  resellerCatalogForbiddenFields,
  type ResellerCatalogRpcClient
} from "@/lib/reseller/catalog";

function createRpcSpyClient(response: { data?: unknown; error?: { code?: string; message?: string } | null } = {}) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: ResellerCatalogRpcClient = {
    async rpc<T = unknown>(name: string, args?: Record<string, unknown>) {
      calls.push({ name, args });
      return {
        data: (response.data ?? []) as T,
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

describe("reseller approved product catalog foundation", () => {
  it("calls the approved reseller catalog RPC without table writes", async () => {
    const { calls, client } = createRpcSpyClient({
      data: [
        {
          product_id: "11111111-1111-4111-8111-111111111111",
          name: "Approved Dev Product",
          category: "QA Test",
          approval_status: "approved",
          product_status: "active",
          reseller_cost_amount: 125,
          max_customer_price_amount: 150,
          available_stock_quantity: 4
        }
      ]
    });

    const result = await listResellerCatalogProductsWithClient(client);

    expect(result.error).toBeNull();
    expect(result.products).toHaveLength(1);
    expect(calls).toEqual([{ name: "get_reseller_approved_products", args: undefined }]);
  });

  it("keeps only approved active products in the mapped catalog", () => {
    const products = mapResellerCatalogRows([
      {
        product_id: "11111111-1111-4111-8111-111111111111",
        name: "Approved Dev Product",
        category: "QA Test",
        approval_status: "approved",
        product_status: "active",
        reseller_cost_amount: 125,
        max_customer_price_amount: 150,
        available_stock_quantity: 4
      },
      {
        product_id: "22222222-2222-4222-8222-222222222222",
        name: "Pending Dev Product",
        approval_status: "pending_review",
        product_status: "active"
      },
      {
        product_id: "33333333-3333-4333-8333-333333333333",
        name: "Archived Dev Product",
        approval_status: "approved",
        product_status: "archived"
      }
    ]);

    expect(products.map((product) => product.productId)).toEqual(["11111111-1111-4111-8111-111111111111"]);
  });

  it("does not map supplier-private or admin-only fields into reseller catalog items", () => {
    const [product] = mapResellerCatalogRows([
      {
        product_id: "11111111-1111-4111-8111-111111111111",
        name: "Approved Dev Product",
        approval_status: "approved",
        product_status: "active",
        supplier_private_phone: "000",
        payout_account: "hidden",
        approved_by_profile_id: "99999999-9999-4999-8999-999999999999",
        platform_margin_amount: 20,
        base_price_amount: 100,
        internal_notes: "hidden"
      }
    ]);

    for (const field of resellerCatalogForbiddenFields) {
      expect(product).not.toHaveProperty(field);
    }
  });

  it("keeps add-to-shop disabled and service role out of reseller product UI", () => {
    const files = [
      "app/reseller/products/page.tsx",
      "app/reseller/products/[id]/page.tsx",
      "components/reseller/reseller-catalog-rpc-screens.tsx"
    ];

    for (const file of files) {
      const source = readFileSync(join(process.cwd(), file), "utf8");
      expect(source).not.toContain("createSupabaseAdminClient");
      expect(source).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
      expect(source).not.toContain(".from(\"reseller_products\").insert");
      expect(source).not.toContain(".from('reseller_products').insert");
      expect(source).not.toContain("add_reseller_product");
    }

    const screenSource = readFileSync(join(process.cwd(), "components/reseller/reseller-catalog-rpc-screens.tsx"), "utf8");
    expect(screenSource).toContain("disabled");
    expect(screenSource).toContain("Add to shop planned");
  });

  it("does not connect customer, shop, checkout, order, payment, or delivery flows", () => {
    const unrelatedPaths = ["app/checkout", "app/customer", "app/shop"];
    const forbidden = ["get_reseller_approved_products", "reseller catalog", "add_reseller_product"];

    for (const relativePath of unrelatedPaths) {
      const source = readSourceTree(relativePath);
      for (const token of forbidden) {
        expect(source).not.toContain(token);
      }
    }
  });
});
