import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import {
  ResellerAddedProductScreen,
  ResellerOnboardingScreen,
  ResellerOrdersScreen,
  ResellerPriceScreen,
  ResellerProductCatalogScreen,
  ResellerProductDetailScreen,
  ResellerSettingsScreen,
  ResellerShareProductScreen,
  ResellerShopScreen,
  ResellerWalletScreen
} from "@/components/reseller/screens";
import { resellerCoreProducts, resellerProfile } from "@/lib/mock/reseller-core";

describe("Phase 4 reseller PWA core", () => {
  it("renders onboarding with Ghana reseller context and placeholder auth copy", () => {
    render(<ResellerOnboardingScreen step="type" />);

    expect(screen.getByRole("heading", { name: /Welcome to Risellar/i })).toBeInTheDocument();
    expect(screen.getByText("General Reseller")).toBeInTheDocument();
    expect(screen.getByText("Beauty Plug")).toBeInTheDocument();
    expect(screen.getByText(/Clerk or email sign-in will connect later/i)).toBeInTheDocument();
  });

  it("renders catalog search, filters, product images, and reseller prices", async () => {
    const user = userEvent.setup();

    render(<ResellerProductCatalogScreen />);

    expect(screen.getByRole("heading", { name: /Browse trusted products/i })).toBeInTheDocument();
    expect(screen.getByRole("searchbox", { name: /Search products/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Beauty" })).toBeInTheDocument();
    expect(screen.getByText("Nike Air Force 1 '07 Green & White")).toBeInTheDocument();
    expect(screen.getByText("Reseller cost GH₵310")).toBeInTheDocument();
    expect(screen.getByText("Profit GH₵30")).toBeInTheDocument();
    expect(screen.getAllByLabelText(/product image/i).length).toBeGreaterThan(3);

    await user.type(screen.getByRole("searchbox", { name: /Search products/i }), "hair");
    expect(screen.getByText("Hair Oil")).toBeInTheDocument();
    expect(screen.queryByText("Oraimo Power Bank 30000mAh")).not.toBeInTheDocument();
  });

  it("renders product detail and selling price controls without supplier internals", () => {
    const product = resellerCoreProducts[0];

    render(<ResellerProductDetailScreen id={product.id} />);

    expect(screen.getByRole("heading", { name: product.name })).toBeInTheDocument();
    expect(screen.getByText("Reseller cost")).toBeInTheDocument();
    expect(screen.getByText("Suggested selling price")).toBeInTheDocument();
    expect(screen.getByText("Max allowed selling price")).toBeInTheDocument();
    expect(screen.getByText(/commission becomes available after supplier settlement/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Add to My Shop" })).toBeInTheDocument();
    expect(screen.queryByText(/supplier base price/i)).not.toBeInTheDocument();
    expect(screen.queryByText("GH₵300")).not.toBeInTheDocument();
  });

  it("shows max-price warning on the selling price screen", async () => {
    const user = userEvent.setup();

    render(<ResellerPriceScreen id="nike-air-force-1-07-green-white" />);

    const priceInput = screen.getByRole("spinbutton", { name: /Your selling price/i });
    expect(screen.getByText("Maximum allowed: GH₵360")).toBeInTheDocument();
    expect(screen.getByText("Expected profit")).toBeInTheDocument();

    await user.clear(priceInput);
    await user.type(priceInput, "390");

    expect(screen.getByText(/Price is above the allowed maximum/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Save Selling Price" })).toBeDisabled();
  });

  it("renders shop, share, orders, wallet, and settings with clear commission rules", async () => {
    const user = userEvent.setup();

    const { rerender } = render(<ResellerShopScreen />);
    expect(screen.getByRole("heading", { name: resellerProfile.shopName })).toBeInTheDocument();
    expect(screen.getByText(resellerProfile.location)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Share Shop" })).toBeInTheDocument();

    rerender(<ResellerAddedProductScreen id="nike-air-force-1-07-green-white" />);
    expect(screen.getByRole("heading", { name: /Added to My Shop/i })).toBeInTheDocument();

    rerender(<ResellerShareProductScreen productId="nike-air-force-1-07-green-white" />);
    expect(screen.getByText(/ready for delivery anywhere in Accra/i)).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Copy Caption" }));
    expect(screen.getByText("Caption copied")).toBeInTheDocument();

    rerender(<ResellerOrdersScreen />);
    expect(screen.getByText("Delivery Quote Pending")).toBeInTheDocument();
    expect(screen.getByText(/Commission becomes available after supplier settlement is verified/i)).toBeInTheDocument();

    rerender(<ResellerWalletScreen />);
    expect(screen.getByText("Available balance")).toBeInTheDocument();
    expect(screen.getByText("Pending commission")).toBeInTheDocument();
    expect(screen.getByText(/Pending commission cannot be withdrawn/i)).toBeInTheDocument();
    expect(screen.getByText(/Minimum withdrawal is GH₵50/i)).toBeInTheDocument();

    rerender(<ResellerSettingsScreen />);
    expect(screen.getByText("MTN MoMo")).toBeInTheDocument();
    expect(screen.getByText("Ama's Beauty Plug")).toBeInTheDocument();
    expect(screen.getByText(/mock settings/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sign out" })).toBeInTheDocument();
  });
});
