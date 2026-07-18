import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  archiveResellerListingWithClient,
  createResellerListingWithClient,
  listResellerShopProductsWithClient,
  mapResellerListingRpcError,
  updateResellerListingWithClient,
  type ResellerListingRpcClient
} from "@/lib/reseller/listings";

function createRpcSpyClient(response: { data?: unknown; error?: { code?: string; message?: string; details?: string } | null } = {}) {
  const calls: Array<{ name: string; args?: Record<string, unknown> }> = [];
  const client: ResellerListingRpcClient = {
    async rpc<T = unknown>(name: string, args?: Record<string, unknown>) {
      calls.push({ name, args });
      return {
        data: (response.data ?? null) as T,
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

describe("reseller add-to-shop listing integration", () => {
  it("creates a reseller listing through the RPC with margin only", async () => {
    const { calls, client } = createRpcSpyClient({ data: "listing-123" });

    const result = await createResellerListingWithClient(client, {
      productId: "11111111-1111-4111-8111-111111111111",
      resellerMargin: 25
    });

    expect(result).toEqual({ ok: true, listingId: "listing-123" });
    expect(calls).toEqual([
      {
        name: "create_reseller_product_listing",
        args: {
          p_product_id: "11111111-1111-4111-8111-111111111111",
          p_reseller_margin: 25
        }
      }
    ]);
    expect(calls[0].args).not.toHaveProperty("base_price_amount");
    expect(calls[0].args).not.toHaveProperty("platform_margin_amount");
    expect(calls[0].args).not.toHaveProperty("supplier_base_price");
  });

  it("maps invalid margin and duplicate listing errors to safe messages", () => {
    expect(mapResellerListingRpcError({ message: "Reseller margin must be greater than zero" })).toMatchObject({
      code: "INVALID_MARGIN"
    });
    expect(mapResellerListingRpcError({ message: "Duplicate active reseller listing already exists for this product" })).toMatchObject({
      code: "DUPLICATE_LISTING"
    });
  });

  it("loads own shop listings through the owned listing RPC", async () => {
    const { calls, client } = createRpcSpyClient({
      data: [
        {
          listing_id: "22222222-2222-4222-8222-222222222222",
          product_id: "11111111-1111-4111-8111-111111111111",
          name: "Approved Listed Product",
          listing_status: "active",
          product_status: "active",
          approval_status: "approved",
          reseller_margin_amount: 25,
          customer_product_price_amount: 175
        }
      ]
    });

    const result = await listResellerShopProductsWithClient(client);

    expect(result.error).toBeNull();
    expect(result.listings).toHaveLength(1);
    expect(result.listings[0]).toMatchObject({
      listingId: "22222222-2222-4222-8222-222222222222",
      productId: "11111111-1111-4111-8111-111111111111",
      name: "Approved Listed Product"
    });
    expect(calls).toEqual([{ name: "get_reseller_shop_products", args: undefined }]);
  });

  it("updates listing margin through the update RPC without unsafe fields", async () => {
    const { calls, client } = createRpcSpyClient({ data: "listing-123" });

    const result = await updateResellerListingWithClient(client, {
      listingId: "22222222-2222-4222-8222-222222222222",
      resellerMargin: 35
    });

    expect(result).toEqual({ ok: true, listingId: "listing-123" });
    expect(calls).toEqual([
      {
        name: "update_reseller_product_listing",
        args: {
          p_listing_id: "22222222-2222-4222-8222-222222222222",
          p_reseller_margin: 35,
          p_listing_status: null
        }
      }
    ]);
    expect(calls[0].args).not.toHaveProperty("customer_product_price_amount");
    expect(calls[0].args).not.toHaveProperty("base_price_amount");
    expect(calls[0].args).not.toHaveProperty("platform_margin_amount");
  });

  it("archives own listing through the archive RPC", async () => {
    const { calls, client } = createRpcSpyClient({ data: "listing-123" });

    const result = await archiveResellerListingWithClient(client, {
      listingId: "22222222-2222-4222-8222-222222222222"
    });

    expect(result).toEqual({ ok: true, listingId: "listing-123" });
    expect(calls).toEqual([
      {
        name: "archive_reseller_product_listing",
        args: {
          p_listing_id: "22222222-2222-4222-8222-222222222222"
        }
      }
    ]);
  });

  it("keeps service role and unrelated live flows out of the reseller listing UI", () => {
    const resellerSources = [
      "app/reseller/products",
      "app/reseller/my-products",
      "components/reseller",
      "lib/reseller"
    ].map(readSourceTree).join("\n");

    expect(resellerSources).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(resellerSources).not.toContain("createSupabaseAdminClient");
    expect(resellerSources).not.toContain(".from(\"reseller_products\").insert");
    expect(resellerSources).not.toContain(".from('reseller_products').insert");

    const unrelatedSources = ["app/checkout", "app/customer", "app/shop"].map(readSourceTree).join("\n");
    for (const rpcName of [
      "create_reseller_product_listing",
      "update_reseller_product_listing",
      "archive_reseller_product_listing",
      "get_reseller_shop_products"
    ]) {
      expect(unrelatedSources).not.toContain(rpcName);
    }
  });
});
