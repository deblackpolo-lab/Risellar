import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import {
  FinanceOverviewScreen,
  OverdueSettlementsScreen,
  PartialSettlementsScreen,
  PayoutDetailsScreen,
  SettlementDetailScreen,
  SettlementHistoryScreen,
  SettlementOverviewScreen,
  SettlementRulesScreen,
  SettlementSettleScreen,
  TrustScoreScreen
} from "@/components/supplier/settlement-screens";
import { getSupplierSettlement } from "@/lib/mock/supplier-settlements";

describe("Phase 8 supplier settlements and financial control", () => {
  it("renders the settlement overview with summary metrics, filters, status guide, and overdue warning", async () => {
    const user = userEvent.setup();
    render(<SettlementOverviewScreen />);

    expect(screen.getByRole("heading", { name: /Settlements/i })).toBeInTheDocument();
    expect(screen.getByText("KNUST Gadgets")).toBeInTheDocument();
    expect(screen.getByText("Trust score")).toBeInTheDocument();
    expect(screen.getByText("88/100")).toBeInTheDocument();
    expect(screen.getByText("Total settlements due")).toBeInTheDocument();
    expect(screen.getByText("GH₵4,850")).toBeInTheDocument();
    expect(screen.getByText("Overdue amount")).toBeInTheDocument();
    expect(screen.getByText("GH₵1,350")).toBeInTheDocument();
    expect(screen.getByText("Paid this month")).toBeInTheDocument();
    expect(screen.getByText("GH₵3,200")).toBeInTheDocument();
    expect(screen.getByText("Total settled all time")).toBeInTheDocument();
    expect(screen.getByText("GH₵27,650")).toBeInTheDocument();
    for (const filter of ["All", "Due", "Overdue", "Paid", "Partially Paid"]) {
      expect(screen.getByRole("button", { name: filter })).toBeInTheDocument();
    }
    expect(screen.getByText("Settlement obligations")).toBeInTheDocument();
    expect(screen.getByText("RSR-20260713-00021")).toBeInTheDocument();
    expect(screen.getAllByText("Due to Risellar").length).toBeGreaterThan(0);
    expect(screen.getByText("Settlement is not optional after customer payment.")).toBeInTheDocument();
    expect(screen.getByText("You have GH₵1,350 in overdue settlements.")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "View Overdue" })).toHaveAttribute("href", "/supplier/settlements/overdue");
    expect(screen.getByRole("link", { name: "Settlement Rules" })).toHaveAttribute("href", "/supplier/settlements/rules");
    await user.click(screen.getByRole("button", { name: "Download Statement" }));
    expect(screen.getByRole("status")).toHaveTextContent("Statement download prepared for this mock session.");
  });

  it("renders settlement detail with financial breakdown, timeline, restrictions, and actions", () => {
    const settlement = getSupplierSettlement("stl-rsr-20260713-00021");
    render(<SettlementDetailScreen settlementId={settlement.id} />);

    expect(screen.getByRole("heading", { name: settlement.settlementNumber })).toBeInTheDocument();
    expect(screen.getAllByText(new RegExp(settlement.orderId)).length).toBeGreaterThan(0);
    expect(screen.getByText("Customer paid amount")).toBeInTheDocument();
    expect(screen.getByText("Supplier base amount")).toBeInTheDocument();
    expect(screen.getByText("Risellar margin")).toBeInTheDocument();
    expect(screen.getByText("Reseller commission")).toBeInTheDocument();
    expect(screen.getByText("Total amount to settle")).toBeInTheDocument();
    expect(screen.getByText("Outstanding amount")).toBeInTheDocument();
    expect(screen.getByText("Payment history")).toBeInTheDocument();
    expect(screen.getByText("Linked order summary")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Settle Now" })).toHaveAttribute("href", `/supplier/settlements/${settlement.id}/settle`);
    expect(screen.getByRole("link", { name: "Upload Proof" })).toHaveAttribute("href", `/supplier/settlements/${settlement.id}/settle`);
    expect(screen.getByRole("button", { name: "View Order" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Contact Support" })).toBeInTheDocument();
  });

  it("renders settle proof form with payment methods, upload placeholder, and submitted state", async () => {
    const user = userEvent.setup();
    render(<SettlementSettleScreen settlementId="stl-rsr-20260713-00021" />);

    expect(screen.getByRole("heading", { name: /Settle now/i })).toBeInTheDocument();
    expect(screen.getByText("Upload proof after sending the settlement amount.")).toBeInTheDocument();
    expect(screen.getByText("Admin will verify your payment before reseller commission is released.")).toBeInTheDocument();
    expect(screen.getByText("Submitting proof does not mean settlement is verified yet.")).toBeInTheDocument();
    for (const method of ["MTN Mobile Money", "Telecel Cash", "AirtelTigo Money", "Bank Transfer"]) {
      expect(screen.getByLabelText(method)).toBeInTheDocument();
    }
    expect(screen.getByLabelText("Amount sent")).toBeInTheDocument();
    expect(screen.getByLabelText("Transaction or reference number")).toBeInTheDocument();
    expect(screen.getAllByText("Upload proof placeholder").length).toBeGreaterThan(0);
    expect(screen.getByLabelText("Settlement notes")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Submit Proof" }));
    expect(screen.getByRole("status")).toHaveTextContent("Settlement proof submitted for admin verification.");
  });

  it("renders partial, overdue, history, and rules settlement states", () => {
    const { rerender } = render(<PartialSettlementsScreen />);

    expect(screen.getByRole("heading", { name: /Partial settlements/i })).toBeInTheDocument();
    expect(screen.getByText("Partially Paid")).toBeInTheDocument();
    expect(screen.getByText("Reseller commission may remain pending until settlement is complete.")).toBeInTheDocument();
    expect(screen.getAllByRole("link", { name: "Settle Balance" }).length).toBeGreaterThan(0);

    rerender(<OverdueSettlementsScreen />);
    expect(screen.getByRole("heading", { name: /Overdue settlements/i })).toBeInTheDocument();
    expect(screen.getByText("Settle overdue amounts to avoid restrictions.")).toBeInTheDocument();
    expect(screen.getByText("Suppliers with overdue settlements cannot boost products.")).toBeInTheDocument();
    expect(screen.getByText("Repeated overdue settlements may hide your products from resellers.")).toBeInTheDocument();
    for (const level of ["Warning", "Limited", "Restricted", "Suspended"]) {
      expect(screen.getAllByText(level).length).toBeGreaterThan(0);
    }

    rerender(<SettlementHistoryScreen />);
    expect(screen.getByRole("heading", { name: /Settlement history/i })).toBeInTheDocument();
    expect(screen.getByText("Proof verified")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Export Statement" })).toBeInTheDocument();

    rerender(<SettlementRulesScreen />);
    expect(screen.getByRole("heading", { name: /Settlement rules/i })).toBeInTheDocument();
    expect(screen.getByText(/Supplier receives customer payment at MVP/i)).toBeInTheDocument();
    expect(screen.getByText(/Reseller commission depends on verified settlement/i)).toBeInTheDocument();
    expect(screen.getByText(/Future trusted suppliers may qualify/i)).toBeInTheDocument();
  });

  it("renders finance, payout details, and trust score screens with financial controls", async () => {
    const user = userEvent.setup();
    const { rerender } = render(<FinanceOverviewScreen />);

    expect(screen.getByRole("heading", { name: "Finance" })).toBeInTheDocument();
    expect(screen.getByText("Financial summary")).toBeInTheDocument();
    expect(screen.getByText("Settlement due")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Settlement History" })).toHaveAttribute("href", "/supplier/settlements/history");
    expect(screen.getByText("Payout and MoMo details")).toBeInTheDocument();
    expect(screen.getByText("Restriction status")).toBeInTheDocument();

    rerender(<PayoutDetailsScreen />);
    expect(screen.getByRole("heading", { name: /Payout details/i })).toBeInTheDocument();
    expect(screen.getByText("MTN Mobile Money")).toBeInTheDocument();
    expect(screen.getByText("+233 24 987 6543")).toBeInTheDocument();
    expect(screen.getByText("Bank option placeholder")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Edit Payout Details" }));
    expect(screen.getByRole("status")).toHaveTextContent("Payout details update saved for this mock session.");

    rerender(<TrustScoreScreen />);
    expect(screen.getByRole("heading", { name: /Trust score/i })).toBeInTheDocument();
    expect(screen.getByText("88/100")).toBeInTheDocument();
    for (const factor of ["Settle on time", "Keep disputes low", "Upload valid proof", "Complete orders successfully"]) {
      expect(screen.getByText(factor)).toBeInTheDocument();
    }
    expect(screen.getAllByText("Good Standing").length).toBeGreaterThan(0);
    expect(screen.getByText(/Settle overdue balances before they affect product visibility/i)).toBeInTheDocument();
  });
});
