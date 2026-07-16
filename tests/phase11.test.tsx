import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import {
  AdminPromotionDetailScreen,
  AdminPromotionPackagesScreen,
  AdminPromotionsScreen,
  ResellerCaptionsScreen,
  ResellerInsightListScreen,
  ResellerInsightsOverviewScreen,
  ResellerProInsightsScreen,
  ResellerSponsoredProductsScreen,
  ResellerTrendingScreen,
  SupplierPromotionDetailScreen,
  SupplierPromotionEligibilityScreen,
  SupplierPromotionHistoryScreen,
  SupplierPromotionPackagesScreen,
  SupplierPromotionPaymentProofScreen,
  SupplierPromotionPerformanceScreen,
  SupplierPromotionsNewScreen,
  SupplierPromotionsOverviewScreen
} from "@/components/promotions/promotions-insights-screens";

describe("Phase 11 promotions and insights", () => {
  it("renders supplier promotions overview, creation flow, packages, and eligibility rules", () => {
    const { rerender } = render(<SupplierPromotionsOverviewScreen />);

    expect(screen.getByRole("heading", { name: "Supplier Promotions" })).toBeInTheDocument();
    for (const text of ["KNUST Gadgets", "Active promotions", "2", "Pending approval", "1", "Paused", "1", "GH₵70", "1,240", "428", "34"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
    expect(screen.getByRole("link", { name: "Promote Product" })).toHaveAttribute("href", "/supplier/promotions/new");
    expect(screen.getByText("Overdue settlement can pause or block promotions.")).toBeInTheDocument();

    rerender(<SupplierPromotionsNewScreen />);
    for (const text of ["Promote Product", "Select product", "Jean Paul Gaultier Le Male EDT 125ml", "All resellers", "Legon", "KNUST", "Beauty category", "Preview placement", "Estimated reach"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
    for (const check of ["Product approved", "Product in stock", "Supplier verified", "No overdue settlement", "Product complaint rate acceptable"]) {
      expect(screen.getByText(check)).toBeInTheDocument();
    }

    rerender(<SupplierPromotionPackagesScreen />);
    for (const pack of ["Daily Boost", "3-Day Boost", "Campus/Area Push", "Category Top Spot", "GH₵10", "GH₵20", "GH₵30"]) {
      expect(screen.getAllByText(pack).length).toBeGreaterThan(0);
    }

    rerender(<SupplierPromotionEligibilityScreen />);
    expect(screen.getByRole("heading", { name: "Promotion Eligibility" })).toBeInTheDocument();
    expect(screen.getByText("Paid promotion must not override trust and safety.")).toBeInTheDocument();
  });

  it("renders supplier promotion detail, performance, history, and payment proof placeholder", () => {
    const { rerender } = render(<SupplierPromotionDetailScreen promotionId="boost-jpg-le-male-legon" />);

    expect(screen.getByRole("heading", { name: "Le Male Legon Campus Push" })).toBeInTheDocument();
    for (const text of ["Jean Paul Gaultier Le Male EDT 125ml", "Campus/Area Push", "Legon", "Pending Approval", "GH₵20", "View Performance", "Copy Product Link", "Contact Support", "Cancel Promotion"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
    expect(screen.getByRole("button", { name: "Cancel Promotion" })).toBeDisabled();

    rerender(<SupplierPromotionPerformanceScreen promotionId="boost-jpg-le-male-legon" />);
    for (const text of ["Promotion Performance", "620", "38", "92", "12", "GH₵3,600", "GH₵20", "Cost per order influenced", "Top areas", "Top reseller categories", "No real analytics are connected."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<SupplierPromotionHistoryScreen />);
    expect(screen.getByRole("heading", { name: "Promotion History" })).toBeInTheDocument();
    expect(screen.getByText("Completed promotions")).toBeInTheDocument();

    rerender(<SupplierPromotionPaymentProofScreen />);
    for (const text of ["Promotion Payment Proof", "Admin must approve promotion payment before boost becomes active.", "No real payment is processed in this prototype.", "Upload proof placeholder", "Reference number"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
  });

  it("renders reseller trending, insights, Pro lock, captions, and sponsored products", () => {
    const { rerender } = render(<ResellerTrendingScreen />);

    expect(screen.getByRole("heading", { name: "Trending Products" })).toBeInTheDocument();
    for (const filter of ["All", "Beauty", "Phones", "Fashion", "Hostel Essentials", "Sponsored", "High Profit"]) {
      expect(screen.getByRole("button", { name: filter })).toBeInTheDocument();
    }
    for (const text of ["What should I sell today?", "Hot Seller", "Trending in Accra", "Only 3 left", "Recently Restocked", "Add to Shop", "Share"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<ResellerInsightsOverviewScreen />);
    for (const text of ["Reseller Insights", "Top opportunities", "Beauty products are trending in Legon this week.", "Phone accessories have high repeat demand.", "Sponsored products are marked clearly.", "Pro insights"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<ResellerInsightListScreen type="top-selling" />);
    expect(screen.getByRole("heading", { name: "Top-Selling Products" })).toBeInTheDocument();
    for (const text of ["High demand", "Fast moving", "Popular in Accra", "Good for students"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<ResellerInsightListScreen type="high-profit" />);
    expect(screen.getByRole("heading", { name: "High-Profit Products" })).toBeInTheDocument();
    expect(screen.getByText("Max allowed price")).toBeInTheDocument();

    rerender(<ResellerInsightListScreen type="low-competition" />);
    expect(screen.getByRole("heading", { name: "Low-Competition Products" })).toBeInTheDocument();
    expect(screen.getByText("Opportunity badge")).toBeInTheDocument();

    rerender(<ResellerProInsightsScreen />);
    for (const text of ["Pro Insights", "top-selling by area", "best product captions", "early access to hot products", "complete 3 successful orders to unlock trial"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<ResellerCaptionsScreen />);
    for (const text of ["WhatsApp Captions", "Copy Caption", "Share Mock"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
    expect(screen.getByText(/Fresh sneakers available now/)).toBeInTheDocument();
    expect(screen.getByText(/Pay on delivery available/)).toBeInTheDocument();

    rerender(<ResellerSponsoredProductsScreen />);
    for (const text of ["Sponsored Products", "Sponsored means supplier paid for visibility.", "Product still passed Risellar trust checks.", "Supplier trust indicator"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
  });

  it("renders admin promotion approvals, detail, and package controls as mock-only", () => {
    const { rerender } = render(<AdminPromotionsScreen />);

    expect(screen.getByRole("heading", { name: "Admin Promotions" })).toBeInTheDocument();
    for (const text of ["Promotion requests", "Active promotions", "Paused promotions", "Completed promotions", "Payment proof pending", "Supplier status", "Product stock status"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
    for (const button of screen.getAllByRole("button", { name: "Approve Boost" })) {
      expect(button).toBeDisabled();
    }

    rerender(<AdminPromotionDetailScreen promotionId="boost-jpg-le-male-legon" />);
    for (const text of ["Le Male Legon Campus Push", "Payment proof placeholder", "Eligibility checklist", "Risk flags", "Performance summary", "Audit preview"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<AdminPromotionPackagesScreen />);
    expect(screen.getByRole("heading", { name: "Promotion Packages" })).toBeInTheDocument();
    for (const text of ["Daily Boost", "3-Day Boost", "Campus Push", "Category Top Spot", "Edit placeholder only"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
  });
});
