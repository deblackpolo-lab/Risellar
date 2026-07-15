import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import {
  AdminAuditLogsScreen,
  AdminManualOverridesScreen,
  AdminOperationsDashboard,
  AdminOperationsQueueDetailScreen,
  AdminOperationsQueueScreen,
  AdminRiskDashboardScreen,
  AdminRiskDetailScreen,
  AdminRiskEntityScreen
} from "@/components/admin/admin-operations-screens";
import { getAdminOperationQueue, getAdminRiskEntity } from "@/lib/mock/admin-operations";

describe("Phase 10 admin operations, risk, and queue management", () => {
  it("renders the operations control center with required queue counts and filters", () => {
    render(<AdminOperationsDashboard />);

    expect(screen.getByRole("heading", { name: "Admin Operations Hub" })).toBeInTheDocument();
    for (const metric of [
      ["Customer confirmations", "18"],
      ["Delivery quotes pending", "9"],
      ["Settlement due", "24"],
      ["Overdue settlements", "6"],
      ["Commission release", "14"],
      ["Product approvals", "12"],
      ["Supplier approvals", "5"],
      ["Disputes", "7"],
      ["Failed deliveries", "4"],
      ["Stock issues", "11"],
      ["Promotion approvals", "8"],
      ["Risk reviews", "10"]
    ]) {
      expect(screen.getAllByText(metric[0]).length).toBeGreaterThan(0);
      expect(screen.getAllByText(metric[1]).length).toBeGreaterThan(0);
    }
    for (const filter of ["Urgent", "Due Today", "Overdue", "High Risk", "Assigned to Me"]) {
      expect(screen.getByRole("button", { name: filter })).toBeInTheDocument();
    }
    expect(screen.getByText("Urgent alerts")).toBeInTheDocument();
    expect(screen.getByText("Today’s workload")).toBeInTheDocument();
    expect(screen.getByText("Mock admin user assignment status")).toBeInTheDocument();
    expect(screen.getAllByText("Overdue settlement warning").length).toBeGreaterThan(0);
    expect(screen.getByText("Queue health indicators")).toBeInTheDocument();
  });

  it("renders reusable queue screens with table fields, mock-only actions, and detail links", () => {
    const customerQueue = getAdminOperationQueue("customer-confirmations");
    const deliveryQueue = getAdminOperationQueue("delivery-quotes");
    const { rerender } = render(<AdminOperationsQueueScreen queueSlug="customer-confirmations" />);

    expect(screen.getByRole("heading", { name: customerQueue.title })).toBeInTheDocument();
    for (const column of ["Queue ID", "Priority", "Status", "Related Entity", "Age", "Assigned Admin", "Due Time", "Recommended Action", "Actions"]) {
      expect(screen.getByText(column)).toBeInTheDocument();
    }
    for (const action of ["Copy WhatsApp confirmation", "Mark Confirmed", "Cancel/Expire Order", "View Order"]) {
      expect(screen.getAllByRole("button", { name: action }).length).toBeGreaterThan(0);
    }
    expect(screen.getByRole("link", { name: "View Detail RSR-20260713-00021" })).toHaveAttribute("href", "/admin/operations/customer-confirmations/rsr-20260713-00021");

    rerender(<AdminOperationsQueueScreen queueSlug="delivery-quotes" />);
    expect(screen.getByRole("heading", { name: deliveryQueue.title })).toBeInTheDocument();
    for (const text of ["Customer area", "Supplier area", "Selected delivery estimate", "Proposed final quote"]) {
      expect(screen.getByText(text)).toBeInTheDocument();
    }
    for (const action of ["Send Quote Template", "Mark Quote Approved", "Mark Quote Rejected", "View Order"]) {
      expect(screen.getAllByRole("button", { name: action }).length).toBeGreaterThan(0);
    }

    rerender(<AdminOperationsQueueScreen queueSlug="commission-release" />);
    expect(screen.getByRole("button", { name: "Release Commission" })).toBeDisabled();
    expect(screen.getByText("No real commission release is connected.")).toBeInTheDocument();
  });

  it("renders required operation detail examples with templates, audit previews, and serious placeholders", () => {
    const { rerender } = render(<AdminOperationsQueueDetailScreen queueSlug="customer-confirmations" itemId="rsr-20260713-00021" />);

    expect(screen.getByRole("heading", { name: /RSR-20260713-00021/i })).toBeInTheDocument();
    expect(screen.getByText("Reservation timer")).toBeInTheDocument();
    expect(screen.getByText("WhatsApp template")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Copy Template" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Preview Variables" })).toBeInTheDocument();
    expect(screen.getByText("Confirmation history")).toBeInTheDocument();
    expect(screen.getByText("Admin notes")).toBeInTheDocument();

    rerender(<AdminOperationsQueueDetailScreen queueSlug="overdue-settlements" itemId="stl-rsr-20260713-00021" />);
    expect(screen.getByText("Settlement breakdown")).toBeInTheDocument();
    expect(screen.getByText("Supplier risk impact")).toBeInTheDocument();
    expect(screen.getByText("Manual restriction warning")).toBeInTheDocument();
    expect(screen.getByText("Audit log preview")).toBeInTheDocument();

    rerender(<AdminOperationsQueueDetailScreen queueSlug="disputes" itemId="dsp-rsr-20260713-00021" />);
    expect(screen.getByText("Dispute summary")).toBeInTheDocument();
    expect(screen.getByText("Evidence placeholders")).toBeInTheDocument();
    expect(screen.getByText("Messages timeline")).toBeInTheDocument();
    expect(screen.getByText("Resolution panel mock")).toBeInTheDocument();
  });

  it("renders risk dashboards, entity lists, supplier risk detail, audit logs, and manual override controls", () => {
    const supplier = getAdminRiskEntity("suppliers", "knust-gadgets");
    const { rerender } = render(<AdminRiskDashboardScreen />);

    expect(screen.getByRole("heading", { name: "Risk Dashboard" })).toBeInTheDocument();
    for (const section of ["Supplier risk cards", "Reseller risk cards", "Customer risk cards", "Product risk cards", "Risk events", "Restriction summary", "Recent risk triggers"]) {
      expect(screen.getByText(section)).toBeInTheDocument();
    }

    rerender(<AdminRiskEntityScreen entityType="suppliers" />);
    expect(screen.getByRole("heading", { name: "Supplier Risk" })).toBeInTheDocument();
    for (const column of ["Risk Score", "Risk Level", "Trigger Count", "Restriction Status", "Recommended Action"]) {
      expect(screen.getByText(column)).toBeInTheDocument();
    }
    expect(screen.getByRole("link", { name: supplier.name })).toHaveAttribute("href", "/admin/risk/suppliers/knust-gadgets");

    rerender(<AdminRiskDetailScreen entityType="suppliers" entityId="knust-gadgets" />);
    expect(screen.getByRole("heading", { name: supplier.name })).toBeInTheDocument();
    for (const label of ["Risk score", "Overdue settlements", "Dispute count", "Stock issues", "Complaint rate", "Restriction recommendation", "Manual override placeholder", "Audit log preview"]) {
      expect(screen.getByText(label)).toBeInTheDocument();
    }

    rerender(<AdminAuditLogsScreen />);
    expect(screen.getByRole("heading", { name: "Audit Logs" })).toBeInTheDocument();
    for (const filter of ["Action type", "Actor", "Entity", "Date", "Risk/sensitive actions"]) {
      expect(screen.getByText(filter)).toBeInTheDocument();
    }
    expect(screen.getByText("manual override performed")).toBeInTheDocument();
    expect(screen.getAllByText("Sensitive").length).toBeGreaterThan(0);

    rerender(<AdminManualOverridesScreen />);
    expect(screen.getByRole("heading", { name: "Manual Overrides" })).toBeInTheDocument();
    expect(screen.getByText("Manual override should only be used in exceptional cases.")).toBeInTheDocument();
    expect(screen.getByLabelText("Required reason")).toBeInTheDocument();
    expect(screen.getByText(/Second confirmation mock/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Apply Override" })).toBeDisabled();
  });
});
