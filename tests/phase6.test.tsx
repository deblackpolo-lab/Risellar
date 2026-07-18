import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import {
  SupplierAddProductScreen,
  SupplierDashboardScreen,
  SupplierEditProductScreen,
  SupplierNotificationsScreen,
  SupplierOnboardingScreen,
  SupplierOrderDetailScreen,
  SupplierOrdersScreen,
  SupplierPrepareOrderScreen,
  SupplierProductDetailScreen,
  SupplierProductsScreen,
  SupplierSettingsScreen,
  SupplierSupportScreen
} from "@/components/supplier/screens";
import { supplierCoreMock } from "@/lib/mock/supplier-core";

describe("Phase 6 supplier PWA core", () => {
  it("renders supplier onboarding steps with verification, payout, agreement, pending, and rejected states", async () => {
    const user = userEvent.setup();
    const { rerender } = render(<SupplierOnboardingScreen step="welcome" />);

    expect(screen.getByRole("heading", { name: /Welcome to Risellar Supplier/i })).toBeInTheDocument();
    expect(screen.getByText("List products. Reach resellers. Grow sales.")).toBeInTheDocument();
    expect(screen.getByText(/You keep your base price/i)).toBeInTheDocument();

    rerender(<SupplierOnboardingScreen step="business" />);
    expect(screen.getByLabelText("Business name")).toHaveValue("KNUST Gadgets");
    expect(screen.getByLabelText("Location")).toHaveValue("Kumasi, Ashanti Region");

    rerender(<SupplierOnboardingScreen step="category" />);
    expect(screen.getByText("Phones & Accessories")).toBeInTheDocument();
    expect(screen.getByText("Skincare / Perfume")).toBeInTheDocument();

    rerender(<SupplierOnboardingScreen step="verification" />);
    expect(screen.getByText(/Ghana Card/i)).toBeInTheDocument();
    expect(screen.getByText(/verification protects customers and resellers/i)).toBeInTheDocument();

    rerender(<SupplierOnboardingScreen step="payout" />);
    expect(screen.getByLabelText("MoMo number")).toHaveValue("+233 24 555 0120");
    expect(screen.getByText(/bank option placeholder/i)).toBeInTheDocument();

    rerender(<SupplierOnboardingScreen step="agreement" />);
    expect(screen.getByText(/resellers may sell products above supplier base price/i)).toBeInTheDocument();
    expect(screen.getByText(/settle Risellar share immediately/i)).toBeInTheDocument();
    await user.click(screen.getByLabelText(/I agree to the supplier rules/i));
    expect(screen.getByRole("button", { name: "Continue" })).toBeEnabled();

    rerender(<SupplierOnboardingScreen step="pending" />);
    expect(screen.getByText("Your supplier account is under review.")).toBeInTheDocument();

    rerender(<SupplierOnboardingScreen step="rejected" />);
    expect(screen.getByText(/More information required/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Update Information" })).toBeInTheDocument();
  });

  it("renders the supplier dashboard with operational summaries and no deep Phase 7 or Phase 8 flows", () => {
    render(<SupplierDashboardScreen />);

    expect(screen.getByRole("heading", { name: /KNUST Gadgets/i })).toBeInTheDocument();
    expect(screen.getByText("Verified Supplier")).toBeInTheDocument();
    expect(screen.getByText("Active products")).toBeInTheDocument();
    expect(screen.getByText("Pending orders")).toBeInTheDocument();
    expect(screen.getByText("Settlement due")).toBeInTheDocument();
    expect(screen.getByText("Low stock")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Add Product" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "View Orders" })).toBeInTheDocument();
    expect(screen.getByText(/settlements must be paid immediately after customer payment/i)).toBeInTheDocument();
    expect(screen.getByText(/Inventory tools arrive in Phase 7/i)).toBeInTheDocument();
    expect(screen.getByText(/Settlement details arrive in Phase 8/i)).toBeInTheDocument();
  });

  it("renders product list, add product, product detail, and edit product supplier views", async () => {
    const user = userEvent.setup();
    const product = supplierCoreMock.products[0];
    const { rerender } = render(<SupplierProductsScreen />);

    expect(screen.getByRole("heading", { name: /Products/i })).toBeInTheDocument();
    expect(screen.getByRole("searchbox", { name: /Search supplier products/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Pending Approval" })).toBeInTheDocument();
    expect(screen.getByText(product.name)).toBeInTheDocument();
    expect(screen.getByLabelText(product.imageAlt)).toHaveClass("h-20", "w-20");
    expect(screen.getByLabelText(product.imageAlt)).not.toHaveClass("w-full");
    expect(screen.getAllByText("Supplier base price").length).toBeGreaterThan(0);
    expect(screen.getByText("Stock 18")).toBeInTheDocument();

    await user.type(screen.getByRole("searchbox", { name: /Search supplier products/i }), "case");
    expect(screen.getByText("iPhone 14 Pro Max Case")).toBeInTheDocument();
    expect(screen.queryByText("Samsung Galaxy A14")).not.toBeInTheDocument();

    rerender(<SupplierAddProductScreen />);
    expect(screen.getByRole("heading", { name: /Add product/i })).toBeInTheDocument();
    expect(screen.getByText(/Your base price is what you expect to receive/i)).toBeInTheDocument();
    expect(screen.getByText(/Admin must approve products before resellers can sell them/i)).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Save Product" }));
    expect(screen.getByText("Product saved for approval.")).toBeInTheDocument();

    rerender(<SupplierProductDetailScreen id="samsung-galaxy-a14" />);
    expect(screen.getByRole("heading", { name: "Samsung Galaxy A14" })).toBeInTheDocument();
    expect(screen.getByText("Active resellers")).toBeInTheDocument();
    expect(screen.getByText("Orders this month")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Manage Inventory" })).toBeDisabled();
    expect(screen.getByText(/Coming in Phase 7/i)).toBeInTheDocument();

    rerender(<SupplierEditProductScreen id="samsung-galaxy-a14" />);
    expect(screen.getByRole("heading", { name: /Edit product/i })).toBeInTheDocument();
    expect(screen.getByText(/price changes may require admin approval/i)).toBeInTheDocument();
    expect(screen.getByText("Existing orders keep their original price.")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Save Changes" }));
    expect(screen.getByText("Product changes saved for review.")).toBeInTheDocument();
  });

  it("renders supplier order list, order detail, and prepare order mock action", async () => {
    const user = userEvent.setup();
    const orderId = supplierCoreMock.orders[0].id;
    const { rerender } = render(<SupplierOrdersScreen />);

    expect(screen.getByRole("heading", { name: /Orders/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Customer Confirmed" })).toBeInTheDocument();
    expect(screen.getByText(orderId)).toBeInTheDocument();
    expect(screen.getByText("Pay on Delivery")).toBeInTheDocument();
    expect(screen.getByText("Supplier base amount")).toBeInTheDocument();
    expect(screen.queryByText(/reseller margin strategy/i)).not.toBeInTheDocument();

    rerender(<SupplierOrderDetailScreen id={orderId} />);
    expect(screen.getByRole("heading", { name: orderId })).toBeInTheDocument();
    expect(screen.getByText("Customer delivery snapshot")).toBeInTheDocument();
    expect(screen.getByText(/After customer pays, settle Risellar share immediately/i)).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Mark Preparing" }));
    expect(screen.getByText("Preparing")).toBeInTheDocument();

    rerender(<SupplierPrepareOrderScreen id={orderId} />);
    expect(screen.getByRole("heading", { name: /Prepare order/i })).toBeInTheDocument();
    expect(screen.getByLabelText("Check product")).toBeInTheDocument();
    expect(screen.getByLabelText("Confirm variant and quantity")).toBeInTheDocument();
    expect(screen.getByText(/packing proof placeholder/i)).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Mark as Ready" }));
    expect(within(screen.getByRole("status")).getByText("Order ready for delivery arrangement.")).toBeInTheDocument();
  });

  it("renders supplier notifications, settings, and support with mock-only actions", async () => {
    const user = userEvent.setup();
    const { rerender } = render(<SupplierNotificationsScreen />);

    expect(screen.getByRole("heading", { name: /Notifications/i })).toBeInTheDocument();
    expect(screen.getByText(/new confirmed order/i)).toBeInTheDocument();
    expect(screen.getByText(/settlement due reminder/i)).toBeInTheDocument();

    rerender(<SupplierSettingsScreen />);
    expect(screen.getByRole("heading", { name: /Settings/i })).toBeInTheDocument();
    expect(screen.getByText("Business profile")).toBeInTheDocument();
    expect(screen.getByText("Payout details summary")).toBeInTheDocument();
    expect(screen.getByText("Agreement and rules")).toBeInTheDocument();
    expect(screen.queryByText("Logout placeholder")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sign out" })).toBeInTheDocument();

    rerender(<SupplierSupportScreen />);
    expect(screen.getByRole("heading", { name: /Supplier support/i })).toBeInTheDocument();
    expect(screen.getByText("Product approval")).toBeInTheDocument();
    expect(screen.getByText("Settlement")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Send Support Request" }));
    expect(screen.getByText("Support request saved.")).toBeInTheDocument();
  });
});
