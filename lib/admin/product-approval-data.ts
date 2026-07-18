import "server-only";

import type { AdminProductApprovalListItem } from "@/components/admin/product-approval-rpc-screens";

export type AdminProductApprovalQueryClient = {
  from(table: string): AdminProductApprovalQueryBuilder;
};

type AdminProductApprovalQueryBuilder = PromiseLike<{
  data: unknown[] | null;
  error: { message?: string } | null;
}> & {
  select(columns: string): AdminProductApprovalQueryBuilder;
  in(column: string, values: string[]): AdminProductApprovalQueryBuilder;
  eq(column: string, value: string): AdminProductApprovalQueryBuilder;
  order(column: string, options?: Record<string, unknown>): AdminProductApprovalQueryBuilder;
};

type QueryResult<T> = {
  data: T[] | null;
  error: { message?: string } | null;
};

type ProductRow = {
  id: string;
  supplier_id: string;
  category: string | null;
  name: string;
  description: string | null;
  product_status: string;
  approval_status: string;
  base_price_amount: number;
  currency_code: string;
  rejection_reason: string | null;
  approved_at: string | null;
  created_at: string;
  updated_at: string;
};

type SupplierRow = {
  id: string;
  business_name: string | null;
  public_display_name: string | null;
};

type VariantRow = {
  product_id: string;
  total_stock_quantity: number;
};

type ImageRow = {
  product_id: string;
  storage_path: string;
  is_primary: boolean;
};

async function runQuery<T>(query: unknown): Promise<{ data: T[] | null; error: { message?: string } | null }> {
  return (await query) as QueryResult<T>;
}

export async function loadAdminProductApprovalItems(client: AdminProductApprovalQueryClient) {
  const { data, error } = await runQuery<ProductRow>(
    client
      .from("products")
      .select(
        "id, supplier_id, category, name, description, product_status, approval_status, base_price_amount, currency_code, rejection_reason, approved_at, created_at, updated_at"
      )
      .in("approval_status", ["pending_review", "approved", "rejected"])
      .order("updated_at", { ascending: false })
  );

  if (error) {
    return { products: [] as AdminProductApprovalListItem[], error: error.message ?? "Product approval queue unavailable" };
  }

  return mapAdminProductRows(client, data ?? []);
}

export async function loadAdminProductApprovalItem(client: AdminProductApprovalQueryClient, productId: string) {
  const { data, error } = await runQuery<ProductRow>(
    client
      .from("products")
      .select(
        "id, supplier_id, category, name, description, product_status, approval_status, base_price_amount, currency_code, rejection_reason, approved_at, created_at, updated_at"
      )
      .eq("id", productId)
  );

  if (error) {
    return { product: null, error: error.message ?? "Product unavailable" };
  }

  const mapped = await mapAdminProductRows(client, data ?? []);

  return { product: mapped.products[0] ?? null, error: mapped.error };
}

async function mapAdminProductRows(client: AdminProductApprovalQueryClient, rows: ProductRow[]) {
  const productIds = rows.map((row) => row.id);
  const supplierIds = [...new Set(rows.map((row) => row.supplier_id))];
  const suppliers = new Map<string, SupplierRow>();
  const stockByProduct = new Map<string, number>();
  const imageStats = new Map<string, { count: number; primaryPath: string | null }>();
  let loadWarning: string | null = null;

  if (supplierIds.length > 0) {
    const { data, error } = await runQuery<SupplierRow>(
      client.from("suppliers").select("id, business_name, public_display_name").in("id", supplierIds)
    );

    if (error) {
      loadWarning = error.message ?? "Supplier details unavailable";
    } else {
      for (const supplier of data ?? []) {
        suppliers.set(supplier.id, supplier);
      }
    }
  }

  if (productIds.length > 0) {
    const { data, error } = await runQuery<VariantRow>(
      client.from("product_variants").select("product_id, total_stock_quantity").in("product_id", productIds)
    );

    if (error) {
      loadWarning = loadWarning ?? error.message ?? "Stock details unavailable";
    } else {
      for (const variant of data ?? []) {
        stockByProduct.set(variant.product_id, (stockByProduct.get(variant.product_id) ?? 0) + Number(variant.total_stock_quantity ?? 0));
      }
    }
  }

  if (productIds.length > 0) {
    const { data, error } = await runQuery<ImageRow>(
      client.from("product_images").select("product_id, storage_path, is_primary").in("product_id", productIds)
    );

    if (error) {
      loadWarning = loadWarning ?? error.message ?? "Image metadata unavailable";
    } else {
      for (const image of data ?? []) {
        const current = imageStats.get(image.product_id) ?? { count: 0, primaryPath: null };
        imageStats.set(image.product_id, {
          count: current.count + 1,
          primaryPath: image.is_primary || !current.primaryPath ? image.storage_path : current.primaryPath
        });
      }
    }
  }

  return {
    error: loadWarning,
    products: rows.map((row) => {
      const supplier = suppliers.get(row.supplier_id);
      const images = imageStats.get(row.id);

      return {
        productId: row.id,
        supplierId: row.supplier_id,
        supplierName: supplier?.public_display_name ?? null,
        supplierBusinessName: supplier?.business_name ?? null,
        category: row.category,
        name: row.name,
        description: row.description,
        productStatus: row.product_status,
        approvalStatus: row.approval_status,
        basePriceAmount: Number(row.base_price_amount ?? 0),
        currencyCode: row.currency_code ?? "GHS",
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        approvedAt: row.approved_at,
        rejectionReason: row.rejection_reason,
        stockQuantity: stockByProduct.get(row.id) ?? 0,
        imageCount: images?.count ?? 0,
        primaryImagePath: images?.primaryPath ?? null
      };
    })
  };
}
