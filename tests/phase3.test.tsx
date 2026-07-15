import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import CheckoutPaymentPage from "@/app/checkout/payment/page";
import { ProductDetailPilot } from "@/components/pilot/ProductDetailPilot";
import ResellerDashboardPage from "@/app/reseller/dashboard/page";
import { pilotCheckout, pilotProduct } from "@/lib/mock/pilot-screens";

describe("Phase 3 pilot screens", () => {
  it("renders the reseller dashboard with mobile PWA operations and commission states", () => {
    render(<ResellerDashboardPage />);

    expect(screen.getByRole("heading", { name: /Ama's Beauty Plug/i })).toBeInTheDocument();
    expect(screen.getByText("Legon, Accra")).toBeInTheDocument();
    expect(screen.getByText("GH₵930")).toBeInTheDocument();
    expect(screen.getByText("GH₵320")).toBeInTheDocument();
    expect(screen.getAllByText("Commission Pending").length).toBeGreaterThan(0);
    expect(screen.getByText(/supplier settlement is verified/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Browse Products" })).toBeInTheDocument();
    expect(screen.getByText("Home")).toBeInTheDocument();
    expect(screen.getByText("Nike Air Force 1 '07 Green & White")).toBeInTheDocument();
    expect(screen.getByText("Home").closest("a")).toHaveAttribute("aria-current", "page");
  });

  it("renders the reseller product detail without exposing supplier private/base details", () => {
    render(<ProductDetailPilot id={pilotProduct.id} />);

    expect(screen.getByRole("heading", { name: pilotProduct.name })).toBeInTheDocument();
    expect(screen.getAllByText("Only 1 left").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Reseller cost").length).toBeGreaterThan(0);
    expect(screen.getAllByText("GH₵310").length).toBeGreaterThan(0);
    expect(screen.getByText("Expected profit")).toBeInTheDocument();
    expect(screen.getAllByText("GH₵30").length).toBeGreaterThan(0);
    expect(screen.getByRole("button", { name: "Add to My Shop" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Share Product" })).toBeInTheDocument();
    expect(screen.queryByText("Supplier base price")).not.toBeInTheDocument();
    expect(screen.queryByText("GH₵300")).not.toBeInTheDocument();
    expect(screen.queryByText(/supplier phone/i)).not.toBeInTheDocument();
  });

  it("renders the checkout payment pilot with Pay on Delivery trust copy and hidden internals", () => {
    render(<CheckoutPaymentPage />);

    expect(screen.getByRole("heading", { name: /Choose payment method/i })).toBeInTheDocument();
    expect(screen.getByText(pilotCheckout.customer.name)).toBeInTheDocument();
    expect(screen.getByText("Pay when your item arrives.")).toBeInTheDocument();
    expect(screen.getByText("Delivery cost will be confirmed before dispatch.")).toBeInTheDocument();
    expect(screen.getByText("We may ask you to confirm the order before processing.")).toBeInTheDocument();
    expect(screen.getByText("GH₵360-380")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Place Order" })).toBeInTheDocument();
    expect(screen.getByText("Awaiting Customer Confirmation")).toBeInTheDocument();
    expect(screen.queryByText("Reseller margin")).not.toBeInTheDocument();
    expect(screen.queryByText("Risellar margin")).not.toBeInTheDocument();
    expect(screen.queryByText("Supplier base price")).not.toBeInTheDocument();
  });
});
