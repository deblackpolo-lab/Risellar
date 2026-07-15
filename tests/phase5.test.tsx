import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import {
  CheckoutAccountScreen,
  CheckoutCartScreen,
  CheckoutDeliveryScreen,
  CheckoutPaymentScreen,
  CheckoutReviewScreen,
  CheckoutSuccessScreen,
  CustomerDeliveryQuoteScreen,
  CustomerOrderConfirmScreen,
  CustomerOrderTrackingScreen,
  CustomerOrdersScreen,
  CustomerReportIssueScreen,
  CustomerSupportScreen,
  PublicProductDetailScreen,
  PublicShopScreen
} from "@/components/customer/screens";
import { customerCheckoutMock } from "@/lib/mock/customer-checkout";

describe("Phase 5 customer mobile web checkout core", () => {
  it("renders the public reseller shop with trusted Ghana checkout signals and no internal prices", async () => {
    const user = userEvent.setup();

    render(<PublicShopScreen shopSlug="amas-beauty-plug" />);

    expect(screen.getByRole("heading", { name: customerCheckoutMock.shop.name })).toBeInTheDocument();
    expect(screen.getByText("Verified trusted reseller")).toBeInTheDocument();
    expect(screen.getByText("Legon, Accra")).toBeInTheDocument();
    expect(screen.getAllByText("Pay on Delivery").length).toBeGreaterThan(0);
    expect(screen.getByRole("searchbox", { name: /Search Ama's Beauty Plug/i })).toBeInTheDocument();
    expect(screen.getByText("Nike Air Force 1 '07 Green & White")).toBeInTheDocument();
    expect(screen.getAllByText(/Final customer price/i).length).toBeGreaterThan(0);

    await user.type(screen.getByRole("searchbox", { name: /Search Ama's Beauty Plug/i }), "anua");
    expect(screen.getByText("Anua Niacinamide Serum 30ml")).toBeInTheDocument();
    expect(screen.queryByText("Oraimo Power Bank 30000mAh")).not.toBeInTheDocument();
    expect(screen.queryByText(/supplier base/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Risellar margin/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/reseller margin/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/supplier contact/i)).not.toBeInTheDocument();
  });

  it("renders product detail with final customer pricing, stock, delivery trust copy, and cart actions", () => {
    render(<PublicProductDetailScreen shopSlug="amas-beauty-plug" productId="nike-air-force-1-07-green-white" />);

    expect(screen.getByRole("heading", { name: "Nike Air Force 1 '07 Green & White" })).toBeInTheDocument();
    expect(screen.getByText("Sold by Ama's Beauty Plug")).toBeInTheDocument();
    expect(screen.getByText("In stock")).toBeInTheDocument();
    expect(screen.getByLabelText(/Size/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Quantity/i)).toBeInTheDocument();
    expect(screen.getByText(/Delivery cost is estimated and will be confirmed before dispatch/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Add to Cart" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Buy Now" })).toBeInTheDocument();
    expect(screen.queryByText(/supplier base/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/platform margin/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/reseller margin/i)).not.toBeInTheDocument();
  });

  it("renders cart, account, delivery, payment, and review steps with required customer rules", async () => {
    const user = userEvent.setup();
    const { rerender } = render(<CheckoutCartScreen />);

    expect(screen.getByRole("heading", { name: /Your cart/i })).toBeInTheDocument();
    expect(screen.getByText("Delivery estimate pending")).toBeInTheDocument();
    expect(screen.getByText(/Delivery cost is estimated and will be confirmed before dispatch/i)).toBeInTheDocument();

    rerender(<CheckoutAccountScreen />);
    expect(screen.getByRole("heading", { name: /Create your account/i })).toBeInTheDocument();
    expect(screen.getByText("Continue with Google")).toBeInTheDocument();
    expect(screen.getByText("Continue with Email")).toBeInTheDocument();
    expect(screen.getByText("We use your account to track your order.")).toBeInTheDocument();
    expect(screen.getByText("Your phone number helps us contact you for delivery.")).toBeInTheDocument();
    expect(screen.getByText("No phone OTP is required at this stage.")).toBeInTheDocument();

    rerender(<CheckoutDeliveryScreen />);
    expect(screen.getByRole("heading", { name: /Delivery details/i })).toBeInTheDocument();
    expect(screen.getByLabelText(/Area or city/i)).toHaveValue("Legon, Accra");
    expect(screen.getByText("Campus Delivery")).toBeInTheDocument();
    expect(screen.getByText(/You can approve or cancel after the final delivery quote is ready/i)).toBeInTheDocument();

    rerender(<CheckoutPaymentScreen />);
    expect(screen.getByRole("heading", { name: /Choose payment method/i })).toBeInTheDocument();
    expect(screen.getAllByText("Pay on Delivery").length).toBeGreaterThan(0);
    expect(screen.getByText("Pay Online")).toBeInTheDocument();
    expect(screen.getByText("Coming soon")).toBeInTheDocument();
    expect(screen.getByText("No upfront payment")).toBeInTheDocument();
    expect(screen.getByText("Inspect your item before paying")).toBeInTheDocument();
    expect(screen.getByText("Order confirmation required")).toBeInTheDocument();
    expect(screen.queryByText(/supplier base/i)).not.toBeInTheDocument();

    rerender(<CheckoutReviewScreen />);
    expect(screen.getByRole("heading", { name: /Review your order/i })).toBeInTheDocument();
    expect(screen.getByLabelText("I understand delivery cost will be confirmed before dispatch.")).toBeInTheDocument();
    expect(screen.getByLabelText("I understand my order must be confirmed before processing.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Place Order" })).toBeDisabled();

    await user.click(screen.getByLabelText("I understand delivery cost will be confirmed before dispatch."));
    await user.click(screen.getByLabelText("I understand my order must be confirmed before processing."));
    expect(screen.getByRole("button", { name: "Place Order" })).toBeEnabled();
  });

  it("renders success, order tracking, confirmation, quote approval, and support issue states", async () => {
    const user = userEvent.setup();
    const orderId = customerCheckoutMock.order.id;
    const { rerender } = render(<CheckoutSuccessScreen />);

    expect(screen.getByRole("heading", { name: /Order received/i })).toBeInTheDocument();
    expect(screen.getByText(orderId)).toBeInTheDocument();
    expect(screen.getByText("Confirm Order")).toBeInTheDocument();
    expect(screen.getByText(/Pay when item arrives/i)).toBeInTheDocument();

    rerender(<CustomerOrdersScreen />);
    expect(screen.getByRole("heading", { name: /My orders/i })).toBeInTheDocument();
    expect(screen.getByText("Awaiting Customer Confirmation")).toBeInTheDocument();

    rerender(<CustomerOrderTrackingScreen id={orderId} />);
    expect(screen.getByRole("heading", { name: /Track your order/i })).toBeInTheDocument();
    expect(screen.getByText("Delivery Quote Pending")).toBeInTheDocument();
    expect(screen.getByText("Out for Delivery")).toBeInTheDocument();

    rerender(<CustomerOrderConfirmScreen id={orderId} />);
    expect(screen.getByRole("heading", { name: /Confirm your order/i })).toBeInTheDocument();
    expect(screen.getByText(/item is reserved only after confirmation/i)).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Confirm Order" }));
    expect(screen.getByText("Customer Confirmed")).toBeInTheDocument();

    rerender(<CustomerDeliveryQuoteScreen id={orderId} />);
    expect(screen.getByRole("heading", { name: /Delivery quote/i })).toBeInTheDocument();
    expect(screen.getByText("Final delivery quote")).toBeInTheDocument();
    expect(screen.getByText("Total to pay on delivery")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Approve Delivery Quote" }));
    expect(screen.getByText("Delivery Approved")).toBeInTheDocument();

    rerender(<CustomerSupportScreen />);
    expect(screen.getByRole("heading", { name: /Help and support/i })).toBeInTheDocument();
    expect(screen.getByText("Report an issue")).toBeInTheDocument();

    rerender(<CustomerReportIssueScreen id={orderId} />);
    expect(screen.getByRole("heading", { name: /Report an issue/i })).toBeInTheDocument();
    expect(screen.getByText("Wrong product")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Submit Issue" }));
    expect(within(screen.getByRole("status")).getByText("Issue Submitted")).toBeInTheDocument();
  });
});
