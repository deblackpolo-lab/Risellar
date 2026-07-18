import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  archiveSupplierProductWithClient,
  buildCreateSupplierProductPayload,
  createSupplierProductWithClient,
  supplierProductForbiddenSubmitFields,
  updateSupplierProductWithClient,
  type SupplierProductRpcClient
} from "@/lib/supplier/product-management";

function createRpcSpyClient(response: { data?: unknown; error?: { code?: string; message?: string } | null } = {}) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: SupplierProductRpcClient = {
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

describe("supplier product management RPC integration", () => {
  it("validates create product fields before calling the backend RPC", () => {
    expect(() =>
      buildCreateSupplierProductPayload({
        productName: " ",
        basePrice: "20",
        stockQuantity: "1"
      })
    ).toThrow("Product name is required");
    expect(() =>
      buildCreateSupplierProductPayload({
        productName: "Dev Product",
        basePrice: "0",
        stockQuantity: "1"
      })
    ).toThrow("Base price must be greater than 0");
    expect(() =>
      buildCreateSupplierProductPayload({
        productName: "Dev Product",
        basePrice: "20",
        stockQuantity: "-1"
      })
    ).toThrow("Stock quantity must be 0 or greater");
  });

  it("calls create_supplier_product with supplier-safe fields only", async () => {
    const { calls, client } = createRpcSpyClient();

    const result = await createSupplierProductWithClient(client, {
      productName: "  Dev QA Product  ",
      description: "  Fake product for QA  ",
      category: "  Electronics  ",
      basePrice: "125.50",
      stockQuantity: "3"
    });

    expect(result).toMatchObject({ code: "OK" });
    expect(calls).toEqual([
      {
        name: "create_supplier_product",
        args: {
          p_product_name: "Dev QA Product",
          p_description: "Fake product for QA",
          p_category: "Electronics",
          p_base_price: 125.5,
          p_stock_quantity: 3,
          p_variants: null,
          p_image_metadata: null
        }
      }
    ]);
  });

  it("calls update_supplier_product without approval, status, or pricing-control fields", async () => {
    const { calls, client } = createRpcSpyClient();

    const result = await updateSupplierProductWithClient(client, {
      productId: "22222222-2222-4222-8222-222222222222",
      productName: "Updated Dev Product",
      description: "Updated safely",
      category: "Beauty",
      basePrice: "150",
      brand: "Dev Brand"
    });

    expect(result).toMatchObject({ code: "OK" });
    expect(calls[0].name).toBe("update_supplier_product");
    expect(calls[0].args).toEqual({
      p_product_id: "22222222-2222-4222-8222-222222222222",
      p_product_name: "Updated Dev Product",
      p_description: "Updated safely",
      p_category: "Beauty",
      p_base_price: 150,
      p_brand: "Dev Brand"
    });

    for (const field of supplierProductForbiddenSubmitFields) {
      expect(calls[0].args).not.toHaveProperty(field);
      expect(calls[0].args).not.toHaveProperty(`p_${field}`);
    }
  });

  it("calls archive_supplier_product for soft archive requests", async () => {
    const { calls, client } = createRpcSpyClient();

    const result = await archiveSupplierProductWithClient(client, {
      productId: "33333333-3333-4333-8333-333333333333",
      reason: "Dev QA archive"
    });

    expect(result).toMatchObject({ code: "OK" });
    expect(calls).toEqual([
      {
        name: "archive_supplier_product",
        args: {
          p_product_id: "33333333-3333-4333-8333-333333333333",
          p_reason: "Dev QA archive"
        }
      }
    ]);
  });

  it("keeps service role and approval self-mutation out of supplier product UI", () => {
    const root = process.cwd();
    const files = [
      "app/supplier/products/actions.ts",
      "app/supplier/products/page.tsx",
      "app/supplier/products/new/page.tsx",
      "app/supplier/products/[id]/page.tsx",
      "app/supplier/products/[id]/edit/page.tsx",
      "components/supplier/product-management-rpc-screens.tsx"
    ];

    for (const file of files) {
      const source = readFileSync(join(root, file), "utf8");
      expect(source).not.toContain("createSupabaseAdminClient");
      expect(source).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
      expect(source).not.toContain('name="approval_status"');
      expect(source).not.toContain('name="product_status"');
      expect(source).not.toContain('name="platform_margin_amount"');
      expect(source).not.toContain('name="reseller_cost_amount"');
      expect(source).not.toContain('name="requested_role"');
    }
  });

  it("keeps product UI scoped away from unrelated live business flows", () => {
    const productActions = readFileSync(join(process.cwd(), "app/supplier/products/actions.ts"), "utf8");
    const productHelper = readFileSync(join(process.cwd(), "lib/supplier/product-management.ts"), "utf8");

    expect(productHelper).toContain('rpc<string>("create_supplier_product"');
    expect(productHelper).toContain('rpc<string>("update_supplier_product"');
    expect(productHelper).toContain('rpc<string>("archive_supplier_product"');
    expect(productHelper).toContain('rpc<unknown[]>("get_supplier_products"');
    expect(productActions).not.toContain("checkout");
    expect(productActions).not.toContain("settlement");
    expect(productActions).not.toContain("commission");
    expect(productActions).not.toContain("payment");
    expect(productActions).not.toContain("reserve");
  });

  it("renders explicit empty, success, and error states in the connected product screen source", () => {
    const source = readFileSync(join(process.cwd(), "components/supplier/product-management-rpc-screens.tsx"), "utf8");
    const productHelper = readFileSync(join(process.cwd(), "lib/supplier/product-management.ts"), "utf8");

    expect(source).toContain("No supplier products yet");
    expect(productHelper).toContain("Product saved for admin review.");
    expect(productHelper).toContain("Product archived.");
    expect(source).toContain("state.code !== \"OK\"");
  });
});
