import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  listPublicResellerShopWithClient,
  publicShopForbiddenFields,
  readPublicResellerShopProductWithClient,
  type PublicShopRpcClient
} from "@/lib/public-shop/catalog";

function createRpcSpyClient(response: { data?: unknown; error?: { code?: string; message?: string } | null } = {}) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: PublicShopRpcClient = {
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

describe("public reseller shop read-only foundation", () => {
  it("loads public shop listings through the public-safe RPC without auth", async () => {
    const { calls, client } = createRpcSpyClient({
      data: [
        {
          shop_slug: "shop-dev-reseller",
          shop_display_name: "Dev Reseller Shop",
          shop_bio: "Development-only shop",
          listing_id: "11111111-1111-4111-8111-111111111111",
          product_slug: "qa-product",
          share_slug: "qa-product-share",
          name: "QA Public Product",
          description: "Safe customer description",
          category: "QA Test",
          brand: "QA Brand",
          listing_status: "active",
          product_status: "active",
          approval_status: "approved",
          customer_product_price_amount: 84.43,
          currency_code: "GHS",
          stock_availability_label: "3 available",
          image_count: 1,
          primary_image_alt: "QA product image"
        }
      ]
    });

    const result = await listPublicResellerShopWithClient(client, "shop-dev-reseller");

    expect(result.error).toBeNull();
    expect(result.shop).toMatchObject({
      slug: "shop-dev-reseller",
      displayName: "Dev Reseller Shop"
    });
    expect(result.products).toHaveLength(1);
    expect(result.products[0]).toMatchObject({
      listingId: "11111111-1111-4111-8111-111111111111",
      productSlug: "qa-product",
      shareSlug: "qa-product-share",
      finalCustomerPriceAmount: 84.43
    });
    expect(calls).toEqual([
      {
        name: "get_public_reseller_shop",
        args: { p_shop_slug: "shop-dev-reseller" }
      }
    ]);
  });

  it("keeps only active approved public products in defensive mapping", async () => {
    const { client } = createRpcSpyClient({
      data: [
        {
          shop_slug: "shop-dev-reseller",
          shop_display_name: "Dev Reseller Shop",
          listing_id: "11111111-1111-4111-8111-111111111111",
          product_slug: "approved-product",
          share_slug: "approved-product-share",
          name: "Approved Product",
          listing_status: "active",
          product_status: "active",
          approval_status: "approved",
          customer_product_price_amount: 84.43
        },
        {
          shop_slug: "shop-dev-reseller",
          shop_display_name: "Dev Reseller Shop",
          listing_id: "22222222-2222-4222-8222-222222222222",
          product_slug: "archived-product",
          share_slug: "archived-product-share",
          name: "Archived Product",
          listing_status: "archived",
          product_status: "active",
          approval_status: "approved",
          customer_product_price_amount: 99
        },
        {
          shop_slug: "shop-dev-reseller",
          shop_display_name: "Dev Reseller Shop",
          listing_id: "33333333-3333-4333-8333-333333333333",
          product_slug: "pending-product",
          share_slug: "pending-product-share",
          name: "Pending Product",
          listing_status: "active",
          product_status: "active",
          approval_status: "pending_review",
          customer_product_price_amount: 99
        }
      ]
    });

    const result = await listPublicResellerShopWithClient(client, "shop-dev-reseller");

    expect(result.products.map((product) => product.name)).toEqual(["Approved Product"]);
  });

  it("does not expose supplier, reseller, admin, or money-internal fields", async () => {
    const { client } = createRpcSpyClient({
      data: [
        {
          shop_slug: "shop-dev-reseller",
          shop_display_name: "Dev Reseller Shop",
          listing_id: "11111111-1111-4111-8111-111111111111",
          product_slug: "qa-product",
          share_slug: "qa-product-share",
          name: "QA Public Product",
          listing_status: "active",
          product_status: "active",
          approval_status: "approved",
          customer_product_price_amount: 84.43,
          base_price_amount: 40,
          platform_margin_amount: 10,
          reseller_margin_amount: 6.66,
          supplier_contact_phone: "hidden",
          payout_details_masked: "hidden",
          risk_level: "hidden",
          internal_notes: "hidden"
        }
      ]
    });

    const result = await listPublicResellerShopWithClient(client, "shop-dev-reseller");
    const product = result.products[0];

    for (const field of publicShopForbiddenFields) {
      expect(product).not.toHaveProperty(field);
    }
  });

  it("loads a public product detail through the public-safe product RPC", async () => {
    const { calls, client } = createRpcSpyClient({
      data: [
        {
          shop_slug: "shop-dev-reseller",
          shop_display_name: "Dev Reseller Shop",
          listing_id: "11111111-1111-4111-8111-111111111111",
          product_slug: "qa-product",
          share_slug: "qa-product-share",
          name: "QA Public Product",
          listing_status: "active",
          product_status: "active",
          approval_status: "approved",
          customer_product_price_amount: 84.43
        }
      ]
    });

    const result = await readPublicResellerShopProductWithClient(client, "shop-dev-reseller", "qa-product-share");

    expect(result.error).toBeNull();
    expect(result.product?.name).toBe("QA Public Product");
    expect(calls).toEqual([
      {
        name: "get_public_reseller_shop_product",
        args: {
          p_shop_slug: "shop-dev-reseller",
          p_product_slug: "qa-product-share"
        }
      }
    ]);
  });

  it("keeps public shop browsing unauthenticated and read-only", () => {
    const publicShopSources = ["app/shop", "components/customer", "lib/public-shop"].map(readSourceTree).join("\n");

    expect(publicShopSources).not.toContain("@clerk/nextjs");
    expect(publicShopSources).not.toContain("auth()");
    expect(publicShopSources).not.toContain("createSupabaseUserServerClient");
    expect(publicShopSources).not.toContain("createSupabaseAdminClient");
    expect(publicShopSources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(publicShopSources).not.toContain("create_order");
    expect(publicShopSources).not.toContain("reserve_stock");
    expect(publicShopSources).not.toContain("create_payment");
  });
});
