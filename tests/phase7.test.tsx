import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import {
  InventoryActivityScreen,
  InventoryDashboardScreen,
  InventoryProductDetailScreen,
  LowStockScreen,
  OutOfStockScreen,
  PriceChangeRequestScreen,
  RestockProductScreen,
  StockMovementHistoryScreen,
  VariantStockScreen
} from "@/components/supplier/inventory-screens";
import { getInventoryProduct } from "@/lib/mock/supplier-inventory";

describe("Phase 7 supplier inventory and stock management", () => {
  it("renders the inventory dashboard with stock metrics, quick actions, and trust guidance", () => {
    render(<InventoryDashboardScreen />);

    expect(screen.getByRole("heading", { name: /Inventory/i })).toBeInTheDocument();
    expect(screen.getByText("KNUST Gadgets")).toBeInTheDocument();
    expect(screen.getByText("Inventory value")).toBeInTheDocument();
    expect(screen.getByText("Total products")).toBeInTheDocument();
    expect(screen.getByText("Available stock")).toBeInTheDocument();
    expect(screen.getByText("Reserved stock")).toBeInTheDocument();
    expect(screen.getByText("Low stock alerts")).toBeInTheDocument();
    expect(screen.getByText("Out-of-stock items")).toBeInTheDocument();
    expect(screen.getByText("Price change requests")).toBeInTheDocument();
    expect(screen.getByText(/Stock accuracy protects customers, resellers, and supplier trust/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Add Product" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Restock" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "View Low Stock" })).toHaveAttribute("href", "/supplier/inventory/low-stock");
    expect(screen.getByRole("link", { name: "View Out of Stock" })).toHaveAttribute("href", "/supplier/inventory/out-of-stock");
    expect(screen.getByRole("link", { name: "Activity Log" })).toHaveAttribute("href", "/supplier/inventory/activity");
    expect(screen.getByText("Recent stock activity")).toBeInTheDocument();
    expect(screen.getAllByText("Nike Air Force 1 '07 Green & White").length).toBeGreaterThan(0);
  });

  it("renders product inventory detail with reserved/available explanations and stock actions", () => {
    const product = getInventoryProduct("nike-air-force-1-07-green-white");
    render(<InventoryProductDetailScreen productId={product.id} />);

    expect(screen.getByRole("heading", { name: product.name })).toBeInTheDocument();
    expect(screen.getByText("Supplier base price")).toBeInTheDocument();
    expect(screen.getByText("Total stock")).toBeInTheDocument();
    expect(screen.getByText("Reserved stock")).toBeInTheDocument();
    expect(screen.getByText("Available stock")).toBeInTheDocument();
    expect(screen.getByText("Sold stock")).toBeInTheDocument();
    expect(screen.getByText("Low stock threshold")).toBeInTheDocument();
    expect(screen.getByText("Active resellers")).toBeInTheDocument();
    expect(screen.getByText("Recent orders")).toBeInTheDocument();
    expect(screen.getByText(/Reserved stock means stock held for pending\/confirmed orders/i)).toBeInTheDocument();
    expect(screen.getByText(/Available stock is what resellers and customers can still sell or order/i)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Restock" })).toHaveAttribute("href", `/supplier/inventory/${product.id}/restock`);
    expect(screen.getByRole("link", { name: "View Variants" })).toHaveAttribute("href", `/supplier/inventory/${product.id}/variants`);
    expect(screen.getByRole("link", { name: "Stock Movement History" })).toHaveAttribute("href", `/supplier/inventory/${product.id}/movements`);
    expect(screen.getByRole("link", { name: "Request Price Change" })).toHaveAttribute("href", `/supplier/inventory/${product.id}/price-change`);
    expect(screen.getByRole("button", { name: "Mark Out of Stock" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Edit Product" })).toBeInTheDocument();
  });

  it("renders variant stock and restock mock action", async () => {
    const user = userEvent.setup();
    const product = getInventoryProduct("nike-air-force-1-07-green-white");
    const { rerender } = render(<VariantStockScreen productId={product.id} />);

    expect(screen.getByRole("heading", { name: /Stock variants/i })).toBeInTheDocument();
    expect(screen.getByText("Size 40")).toBeInTheDocument();
    expect(screen.getByText("Size 41")).toBeInTheDocument();
    expect(screen.getByText("Size 42")).toBeInTheDocument();
    expect(screen.getByText("Size 43")).toBeInTheDocument();
    expect(screen.getByText("Only 1 left")).toBeInTheDocument();
    expect(screen.getByText(/Resellers sell from shared supplier stock/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Add Variant" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Save Variants" })).toBeInTheDocument();

    rerender(<RestockProductScreen productId={product.id} />);
    expect(screen.getByRole("heading", { name: /Restock product/i })).toBeInTheDocument();
    expect(screen.getByText("Current stock")).toBeInTheDocument();
    expect(screen.getByLabelText("Quantity to add")).toHaveValue(12);
    expect(screen.getByText(/New stock total preview/i)).toBeInTheDocument();
    expect(screen.getByLabelText("Restock note")).toBeInTheDocument();
    expect(screen.getByLabelText("Batch or source note")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Confirm Restock" }));
    expect(screen.getByRole("status")).toHaveTextContent("Restock recorded for this mock session.");
  });

  it("renders movement history and price change request with required warnings", async () => {
    const user = userEvent.setup();
    const product = getInventoryProduct("nike-air-force-1-07-green-white");
    const { rerender } = render(<StockMovementHistoryScreen productId={product.id} />);

    expect(screen.getByRole("heading", { name: /Stock movement history/i })).toBeInTheDocument();
    for (const movementType of ["initial stock", "restock", "reservation", "sale", "cancellation release", "manual adjustment", "return", "damage/loss"]) {
      expect(screen.getByText(movementType)).toBeInTheDocument();
    }
    expect(screen.getAllByText("Kofi Mensah").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Akua Boateng").length).toBeGreaterThan(0);
    expect(screen.getAllByText("System Reservation").length).toBeGreaterThan(0);
    expect(screen.getByText("RSR-20260713-00021")).toBeInTheDocument();

    rerender(<PriceChangeRequestScreen productId={product.id} />);
    expect(screen.getByRole("heading", { name: /Request price change/i })).toBeInTheDocument();
    expect(screen.getByText("Current supplier base price")).toBeInTheDocument();
    expect(screen.getByLabelText("New requested base price")).toHaveValue("GH₵330");
    expect(screen.getByLabelText("Effective date")).toHaveValue("2026-07-25");
    expect(screen.getByLabelText("Reason for change")).toBeInTheDocument();
    expect(screen.getByText("Existing orders keep their original price.")).toBeInTheDocument();
    expect(screen.getByText("Price changes may require admin approval.")).toBeInTheDocument();
    expect(screen.getByText("Reseller listings may require review after price changes.")).toBeInTheDocument();
    expect(screen.getByText("Needs Review")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Submit Price Change Request" }));
    expect(screen.getByRole("status")).toHaveTextContent("Price change request submitted for review.");
  });

  it("renders low stock, out-of-stock, and inventory activity states", () => {
    const { rerender } = render(<LowStockScreen />);

    expect(screen.getByRole("heading", { name: /Low stock alerts/i })).toBeInTheDocument();
    expect(screen.getByText("Low stock can reduce reseller sales.")).toBeInTheDocument();
    expect(screen.getAllByText("Affected reseller listings").length).toBeGreaterThan(0);
    expect(screen.getAllByRole("link", { name: "Restock" }).length).toBeGreaterThan(0);

    rerender(<OutOfStockScreen />);
    expect(screen.getByRole("heading", { name: /Out-of-stock products/i })).toBeInTheDocument();
    expect(screen.getByText("Out-of-stock products are hidden or blocked from new orders until restocked.")).toBeInTheDocument();
    expect(screen.getByText(/cannot receive new customer orders/i)).toBeInTheDocument();

    rerender(<InventoryActivityScreen />);
    expect(screen.getByRole("heading", { name: /Inventory manager activity/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "All" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Restocks" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Reservations" })).toBeInTheDocument();
    expect(screen.getByText(/restocked Nike Air Force 1 size 42/i)).toBeInTheDocument();
    expect(screen.getByText(/changed low-stock threshold from 3 to 5/i)).toBeInTheDocument();
    expect(screen.getByText(/reserved 1 item for order RSR-20260713-00021/i)).toBeInTheDocument();
  });
});
