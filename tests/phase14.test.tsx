import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import {
  EdgeCaseIndexScreen,
  EdgeCaseRouteScreen,
  edgeCaseDefinitions,
  getEdgeCaseDefinition,
  requiredEdgeCasePaths
} from "@/components/edge-cases/edge-case-screens";

describe("Phase 14 empty states and edge cases", () => {
  it("renders the edge-case index with role sections and reusable state previews", () => {
    render(<EdgeCaseIndexScreen />);

    for (const text of [
      "Empty States + Edge Cases",
      "Shared / General",
      "Customer",
      "Reseller",
      "Supplier",
      "Admin",
      "Supplier settlement overdue",
      "Reseller commission pending",
      "Support issue submitted",
      "Admin manual override warning"
    ]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
  });

  it("defines every required Phase 14 route path", () => {
    expect(requiredEdgeCasePaths).toHaveLength(50);

    for (const path of requiredEdgeCasePaths) {
      expect(getEdgeCaseDefinition(path)).toBeTruthy();
    }

    expect(edgeCaseDefinitions.some((state) => state.path === "/edge-cases/customer/product-reserved")).toBe(true);
    expect(edgeCaseDefinitions.some((state) => state.path === "/edge-cases/supplier/inventory-manager-access-denied")).toBe(true);
    expect(edgeCaseDefinitions.some((state) => state.path === "/edge-cases/admin/commission-release-blocked")).toBe(true);
  });

  it("renders customer, reseller, supplier, and admin edge copy without exposing private money to customers", () => {
    const { rerender } = render(<EdgeCaseRouteScreen slug={["customer", "product-reserved"]} />);

    expect(screen.getByRole("heading", { name: "Someone just reserved this item" })).toBeInTheDocument();
    expect(screen.getByText("If they do not confirm, it may become available again.")).toBeInTheDocument();
    expect(screen.getByText("GH₵340")).toBeInTheDocument();
    expect(screen.queryByText("Supplier base price")).not.toBeInTheDocument();
    expect(screen.queryByText("Reseller commission")).not.toBeInTheDocument();

    rerender(<EdgeCaseRouteScreen slug={["reseller", "commission-pending"]} />);
    expect(screen.getByRole("heading", { name: "Commission is still pending" })).toBeInTheDocument();
    expect(screen.getByText("This commission is pending until the supplier settlement is verified.")).toBeInTheDocument();
    expect(screen.getByText("GH₵30")).toBeInTheDocument();

    rerender(<EdgeCaseRouteScreen slug={["supplier", "settlement-overdue"]} />);
    expect(screen.getByRole("heading", { name: "Settlement is overdue" })).toBeInTheDocument();
    expect(screen.getByText("You have overdue settlements. Settle them to keep your products visible to resellers.")).toBeInTheDocument();
    expect(screen.getByText("GH₵40")).toBeInTheDocument();

    rerender(<EdgeCaseRouteScreen slug={["admin", "manual-override-warning"]} />);
    expect(screen.getByRole("heading", { name: "Manual override is restricted" })).toBeInTheDocument();
    expect(screen.getByText("A reason and audit log are required.")).toBeInTheDocument();
  });

  it("renders not-found and permission-denied states with clear mock actions", () => {
    const { rerender } = render(<EdgeCaseRouteScreen slug={["not-found"]} />);

    expect(screen.getByRole("heading", { name: "Record not found" })).toBeInTheDocument();
    expect(screen.getByText("Return to dashboard")).toBeInTheDocument();

    rerender(<EdgeCaseRouteScreen slug={["permission-denied"]} />);
    expect(screen.getByRole("heading", { name: "You do not have access" })).toBeInTheDocument();
    expect(screen.getByText("Request access")).toBeInTheDocument();
  });
});
