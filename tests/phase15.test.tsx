import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import PreviewPage from "@/app/preview/page";
import { previewRoutes, previewSections, requiredPhase15RouteChecks } from "@/lib/mock/preview-routes";
import { statusCatalog } from "@/lib/status/status-definitions";

describe("Phase 15 frontend QA polish", () => {
  it("renders the preview launcher with all required sections and key routes", () => {
    render(<PreviewPage />);

    expect(screen.getByRole("heading", { name: "Screen launcher for frontend QA" })).toBeInTheDocument();

    for (const section of previewSections) {
      expect(screen.getAllByRole("heading", { name: section }).length).toBeGreaterThan(0);
    }

    for (const section of [
      "Public/Auth",
      "Customer Account/Orders",
      "Reseller Insights/Promotions",
      "Supplier Inventory",
      "Supplier Settlements/Finance",
      "Supplier Promotions",
      "Supplier Team/Inventory Manager",
      "Admin Promotions",
      "Admin Support/Disputes/Returns/Refunds"
    ]) {
      expect(previewSections).toContain(section);
    }

    for (const route of [
      "/design-system",
      "/reseller/dashboard",
      "/checkout/payment",
      "/supplier/settlements",
      "/admin/operations",
      "/edge-cases/customer/awaiting-confirmation"
    ]) {
      expect(screen.getByText(route)).toBeInTheDocument();
    }

    expect(screen.getByRole("link", { name: "Open Customer Awaiting Confirmation" })).toHaveAttribute(
      "href",
      "/edge-cases/customer/awaiting-confirmation"
    );
  });

  it("links every required Phase 15 route check from the preview inventory", () => {
    const previewPaths = new Set(previewRoutes.map((route) => route.path));

    for (const path of requiredPhase15RouteChecks) {
      expect(previewPaths.has(path)).toBe(true);
    }

    expect(previewRoutes).toHaveLength(new Set(previewRoutes.map((route) => route.path)).size);
  });

  it("keeps required business statuses represented in the frontend status catalog", () => {
    const requiredStatuses = {
      order: [
        "Awaiting Confirmation",
        "Customer Confirmed",
        "Preparing",
        "Delivery Quote Pending",
        "Delivery Approved",
        "Out for Delivery",
        "Delivered",
        "Payment Collected",
        "Settlement Due",
        "Settlement Overdue",
        "Completed",
        "Cancelled",
        "Customer Refused",
        "Dispute Opened"
      ],
      product: ["Pending Approval", "Active", "Rejected", "Needs Changes", "Price Change Pending", "Needs Reseller Review", "Out of Stock", "Hidden", "Suspended"],
      settlement: ["Due", "Proof Submitted", "Verifying", "Partially Settled", "Paid", "Overdue", "Disputed"],
      commission: ["Pending", "Awaiting Settlement", "Available", "Withdrawal Requested", "Paid", "Cancelled", "Disputed"],
      promotion: ["Pending Payment", "Pending Approval", "Active", "Paused", "Completed", "Rejected", "Cancelled"],
      verification: ["Pending", "Approved", "Rejected", "More Info Required"]
    } as const;

    for (const [domain, labels] of Object.entries(requiredStatuses)) {
      const available = new Set(statusCatalog[domain as keyof typeof statusCatalog].map((status) => status.label));
      for (const label of labels) {
        expect(available.has(label)).toBe(true);
      }
    }
  });
});
