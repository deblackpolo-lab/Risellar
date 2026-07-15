import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import DesignSystemPage from "@/app/design-system/page";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { allStatuses, getStatusDefinition, getStatusTone, statusCatalog } from "@/lib/status/status-definitions";
import { sampleAdminQueues, sampleAuditLogItems, sampleWhatsAppTemplates } from "@/lib/mock/admin";
import { sampleCommissions, sampleSettlements } from "@/lib/mock/finance";
import { sampleOrders, sampleTimelineEvents } from "@/lib/mock/orders";
import { sampleProducts, sampleStockStates } from "@/lib/mock/products";

const gallerySections = [
  "Brand Colors",
  "Typography",
  "Spacing / Radius / Shadows",
  "Buttons",
  "Forms and Inputs",
  "Badges and Statuses",
  "Cards",
  "Product and Marketplace Components",
  "Price / Profit / Commission Components",
  "Stock and Inventory Components",
  "Orders and Timeline Components",
  "Delivery and Payment Components",
  "Settlement and Wallet Components",
  "Promotions and Insights Components",
  "Admin Components",
  "Risk / Audit / Manual Override Components",
  "Empty / Error / Loading States",
  "Responsive Examples"
];

describe("Phase 2 component library contract", () => {
  it("centralizes every required status with a badge tone", () => {
    expect(statusCatalog.order.map((status) => status.label)).toContain("Awaiting Confirmation");
    expect(statusCatalog.order.map((status) => status.label)).toContain("Settlement Overdue");
    expect(statusCatalog.product.map((status) => status.label)).toContain("Needs Reseller Review");
    expect(statusCatalog.settlement.map((status) => status.label)).toContain("Proof Submitted");
    expect(statusCatalog.commission.map((status) => status.label)).toContain("Withdrawal Requested");
    expect(statusCatalog.verification.map((status) => status.label)).toContain("More Info Required");
    expect(statusCatalog.promotion.map((status) => status.label)).toContain("Pending Payment");

    expect(allStatuses.length).toBeGreaterThanOrEqual(51);
    expect(allStatuses.every((status) => status.tone)).toBe(true);
    expect(getStatusTone("Settlement Overdue")).toBe("danger");
    expect(getStatusDefinition("Inventory Manager")).toBeUndefined();
  });

  it("maps status badges from status labels consistently", () => {
    render(
      <div>
        <StatusBadge status="Delivery Quote Pending" />
        <StatusBadge status="Paid" />
        <StatusBadge status="Supplier Restricted" />
      </div>
    );

    expect(screen.getByText("Delivery Quote Pending")).toHaveClass("bg-[var(--color-warning-soft)]");
    expect(screen.getByText("Paid")).toHaveClass("bg-[var(--color-success-soft)]");
    expect(screen.getByText("Supplier Restricted")).toHaveClass("bg-[var(--color-danger-soft)]");
  });

  it("supports refined button variants, sizes, disabled and loading states", () => {
    render(
      <div>
        <Button variant="soft-warning" size="large">
          Settle now
        </Button>
        <Button variant="outline" size="table-action">
          View
        </Button>
        <Button loading>Saving</Button>
        <Button disabled>Disabled</Button>
      </div>
    );

    expect(screen.getByRole("button", { name: "Settle now" })).toHaveClass("bg-[var(--color-warning-soft)]");
    expect(screen.getByRole("button", { name: "View" })).toHaveClass("h-8");
    expect(screen.getByRole("button", { name: /Saving/ })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Disabled" })).toBeDisabled();
  });

  it("supports input states for future forms", () => {
    render(
      <div>
        <Input aria-label="Default phone" defaultValue="+233 24 123 4567" />
        <Input aria-label="Error amount" state="error" defaultValue="GH₵0" />
        <Input aria-label="Success account" state="success" defaultValue="Ama Serwaa" />
      </div>
    );

    expect(screen.getByLabelText("Error amount")).toHaveClass("border-[var(--color-danger)]");
    expect(screen.getByLabelText("Success account")).toHaveClass("border-[var(--color-success)]");
  });

  it("organizes realistic design-system mock data by domain", () => {
    expect(sampleProducts[0].customerPrice).toBe("GH₵340");
    expect(sampleProducts[0].supplierBasePrice).toBe("GH₵300");
    expect(sampleStockStates).toContain("Only 1 left");
    expect(sampleOrders[0].status).toBe("Awaiting Customer Confirmation");
    expect(sampleTimelineEvents.length).toBeGreaterThan(4);
    expect(sampleSettlements[0].status).toBe("Settlement Due");
    expect(sampleCommissions[0].status).toBe("Commission Pending");
    expect(sampleAdminQueues[0].title).toBe("Customer Confirmation Queue");
    expect(sampleAuditLogItems.length).toBeGreaterThan(2);
    expect(sampleWhatsAppTemplates[0].channel).toBe("WhatsApp");
  });

  it("renders the full approved design-system gallery section list", () => {
    render(<DesignSystemPage />);

    for (const section of gallerySections) {
      expect(screen.getByRole("heading", { name: new RegExp(section, "i") })).toBeInTheDocument();
    }

    expect(screen.getByText("Available Balance GH₵240")).toBeInTheDocument();
    expect(screen.getAllByText("Inventory Manager").length).toBeGreaterThan(0);
  });
});
