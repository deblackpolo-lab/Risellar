import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import {
  AdminCommissionsScreen,
  AdminCustomerDetailScreen,
  AdminCustomersScreen,
  AdminDashboardScreen,
  AdminOrderDetailScreen,
  AdminOrdersScreen,
  AdminProductDetailScreen,
  AdminProductsScreen,
  AdminResellerDetailScreen,
  AdminResellersScreen,
  AdminSettingsScreen,
  AdminSettlementsScreen,
  AdminSupplierDetailScreen,
  AdminSuppliersScreen,
  AdminSupportScreen,
  AdminWithdrawalsScreen
} from "@/components/admin/admin-core-screens";
import { getAdminCustomer, getAdminOrder, getAdminProduct, getAdminReseller, getAdminSupplier } from "@/lib/mock/admin-core";

describe("Phase 9 admin core dashboard", () => {
  it("renders the desktop admin dashboard with Phase 9 metrics, summaries, and navigation", () => {
    render(<AdminDashboardScreen />);

    expect(screen.getByRole("heading", { name: "Admin Dashboard" })).toBeInTheDocument();
    for (const item of ["Dashboard", "Orders", "Products", "Suppliers", "Resellers", "Customers", "Settlements", "Commissions", "Withdrawals", "Support", "Settings"]) {
      expect(screen.getByRole("link", { name: item })).toBeInTheDocument();
    }
    for (const metric of ["Total orders", "Pending confirmations", "Settlement due", "Overdue settlements", "Pending reseller commissions", "Active suppliers", "Active resellers", "Products pending approval"]) {
      expect(screen.getByText(metric)).toBeInTheDocument();
    }
    for (const value of ["248", "18", "GH₵4,850", "GH₵1,350", "GH₵3,420", "42", "318", "14"]) {
      expect(screen.getByText(value)).toBeInTheDocument();
    }
    expect(screen.getByText("Revenue and platform margin")).toBeInTheDocument();
    expect(screen.getByText("Recent orders")).toBeInTheDocument();
    expect(screen.getByText("Supplier settlement summary")).toBeInTheDocument();
    expect(screen.getByText("Product approval summary")).toBeInTheDocument();
    expect(screen.getByText("Support and dispute summary")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Review orders" })).toHaveAttribute("href", "/admin/orders");
    expect(screen.getByRole("link", { name: "View settlements" })).toHaveAttribute("href", "/admin/settlements");
  });

  it("renders orders list and static order detail with full admin financial visibility", () => {
    const order = getAdminOrder("rsr-20260713-00021");
    const { rerender } = render(<AdminOrdersScreen />);

    expect(screen.getByRole("heading", { name: "Orders" })).toBeInTheDocument();
    for (const filter of ["All", "Pending Confirmation", "Preparing", "Delivery Quote Pending", "Completed", "Settlement Due"]) {
      expect(screen.getByRole("button", { name: filter })).toBeInTheDocument();
    }
    for (const column of ["Order ID", "Customer", "Reseller", "Supplier", "Product", "Final Price", "Payment", "Status", "Settlement"]) {
      expect(screen.getByText(column)).toBeInTheDocument();
    }
    expect(screen.getByRole("link", { name: "View rsr-20260713-00021" })).toHaveAttribute("href", "/admin/orders/rsr-20260713-00021");

    rerender(<AdminOrderDetailScreen orderId={order.id} />);
    expect(screen.getByRole("heading", { name: order.displayId })).toBeInTheDocument();
    for (const label of ["Supplier base price", "Risellar platform margin", "Reseller margin", "Customer product price", "Delivery fee", "Total Pay on Delivery"]) {
      expect(screen.getByText(label)).toBeInTheDocument();
    }
    expect(screen.getByText("Pay on Delivery")).toBeInTheDocument();
    expect(screen.getByText("Customer only sees product price, delivery fee, and total to pay.")).toBeInTheDocument();
    expect(screen.getByText("Admin notes placeholder")).toBeInTheDocument();
    for (const action of ["Send Confirmation Message", "Notify Supplier", "Mark Delivered", "Review Settlement"]) {
      expect(screen.getByRole("button", { name: action })).toBeInTheDocument();
    }
  });

  it("renders product, supplier, reseller, customer lists and their approved static detail routes", () => {
    const product = getAdminProduct("nike-air-force-1-07-green-white");
    const supplier = getAdminSupplier("knust-gadgets");
    const reseller = getAdminReseller("amas-beauty-plug");
    const customer = getAdminCustomer("nana-yaw");
    const { rerender } = render(<AdminProductsScreen />);

    expect(screen.getByRole("heading", { name: "Products" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: product.name })).toHaveAttribute("href", "/admin/products/nike-air-force-1-07-green-white");

    rerender(<AdminProductDetailScreen productId={product.id} />);
    expect(screen.getByRole("heading", { name: product.name })).toBeInTheDocument();
    expect(screen.getByText("Admin pricing layers")).toBeInTheDocument();
    expect(screen.getByText("Approval state is mock-only in Phase 9.")).toBeInTheDocument();

    rerender(<AdminSuppliersScreen />);
    expect(screen.getByRole("heading", { name: "Suppliers" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: supplier.name })).toHaveAttribute("href", "/admin/suppliers/knust-gadgets");

    rerender(<AdminSupplierDetailScreen supplierId={supplier.id} />);
    expect(screen.getByRole("heading", { name: supplier.name })).toBeInTheDocument();
    expect(screen.getByText("Supplier profile")).toBeInTheDocument();
    expect(screen.getByText("Settlement visibility")).toBeInTheDocument();

    rerender(<AdminResellersScreen />);
    expect(screen.getByRole("heading", { name: "Resellers" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: reseller.name })).toHaveAttribute("href", "/admin/resellers/amas-beauty-plug");

    rerender(<AdminResellerDetailScreen resellerId={reseller.id} />);
    expect(screen.getByRole("heading", { name: reseller.name })).toBeInTheDocument();
    expect(screen.getByText("Commission status")).toBeInTheDocument();
    expect(screen.getByText("Pending commission is not withdrawable until supplier settlement is verified.")).toBeInTheDocument();

    rerender(<AdminCustomersScreen />);
    expect(screen.getByRole("heading", { name: "Customers" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: customer.name })).toHaveAttribute("href", "/admin/customers/nana-yaw");

    rerender(<AdminCustomerDetailScreen customerId={customer.id} />);
    expect(screen.getByRole("heading", { name: customer.name })).toBeInTheDocument();
    expect(screen.getByText("Customer-facing financial view")).toBeInTheDocument();
    expect(screen.queryByText("Supplier base price")).not.toBeInTheDocument();
  });

  it("renders finance, support, and settings summary pages without workflow integrations", () => {
    const { rerender } = render(<AdminSettlementsScreen />);

    expect(screen.getByRole("heading", { name: "Settlements" })).toBeInTheDocument();
    expect(screen.getByText("Read-only settlement summary for Phase 9.")).toBeInTheDocument();
    expect(screen.getByText("No payment verification workflow is connected.")).toBeInTheDocument();

    rerender(<AdminCommissionsScreen />);
    expect(screen.getByRole("heading", { name: "Commissions" })).toBeInTheDocument();
    expect(screen.getByText("Commission release is displayed only after verified supplier settlement.")).toBeInTheDocument();

    rerender(<AdminWithdrawalsScreen />);
    expect(screen.getByRole("heading", { name: "Withdrawals" })).toBeInTheDocument();
    expect(screen.getByText("Withdrawal approval is not implemented in Phase 9.")).toBeInTheDocument();

    rerender(<AdminSupportScreen />);
    expect(screen.getByRole("heading", { name: "Support" })).toBeInTheDocument();
    expect(screen.getByText("Support and dispute summary only.")).toBeInTheDocument();

    rerender(<AdminSettingsScreen />);
    expect(screen.getByRole("heading", { name: "Settings" })).toBeInTheDocument();
    for (const category of ["Admin profile", "Marketplace rules", "Delivery settings", "Notification templates", "Audit and compliance"]) {
      expect(screen.getByText(category)).toBeInTheDocument();
    }
  });
});
