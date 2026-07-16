import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import {
  AccessDeniedStateScreen,
  InventoryManagerDashboardScreen,
  InventoryManagerOrdersScreen,
  InventoryManagerProductsScreen,
  InventoryManagerSettingsScreen,
  InviteTeamMemberScreen,
  SupplierTeamActivityScreen,
  SupplierTeamMemberDetailScreen,
  SupplierTeamOverviewScreen,
  SupplierTeamRolesScreen,
  TeamMemberPermissionsScreen
} from "@/components/supplier/team-permissions-screens";

describe("Phase 12 supplier team, inventory manager, and permissions", () => {
  it("renders supplier team overview with owner, members, role badges, and safety guidance", () => {
    render(<SupplierTeamOverviewScreen />);

    expect(screen.getByRole("heading", { name: "Team Members" })).toBeInTheDocument();
    for (const text of [
      "KNUST Gadgets",
      "Kofi Mensah",
      "Supplier Owner",
      "Akua Boateng",
      "Inventory Manager",
      "Efua Darko",
      "Pending Invite",
      "Kwame Osei",
      "Viewer",
      "Finance Staff",
      "Only invite people you trust to manage products and stock.",
      "Recent activity"
    ]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
    expect(screen.getByRole("link", { name: "Invite Team Member" })).toHaveAttribute("href", "/supplier/team/invite");
  });

  it("renders invite flow and Akua member detail with mock-only controls", () => {
    const { rerender } = render(<InviteTeamMemberScreen />);

    expect(screen.getByRole("heading", { name: "Invite Inventory Manager" })).toBeInTheDocument();
    for (const text of [
      "Invite by email",
      "Staff name",
      "Email",
      "Role",
      "Permission preview",
      "Inventory managers can add products, update stock, restock products, and prepare orders.",
      "They cannot change payout details, verify settlements, or remove the supplier owner.",
      "Temporary password option disabled",
      "Send Invite Mock",
      "Invite success state"
    ]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<SupplierTeamMemberDetailScreen memberId="akua-boateng" />);
    expect(screen.getByRole("heading", { name: "Akua Boateng" })).toBeInTheDocument();
    for (const text of [
      "Inventory Manager",
      "Active",
      "akua@knustgadgets.com",
      "Last active",
      "Permissions summary",
      "Products updated",
      "Orders prepared",
      "Stock changes",
      "Edit Permissions",
      "Suspend Access",
      "Resend Invite",
      "Remove Member"
    ]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
    expect(screen.getByRole("link", { name: "Edit Permissions" })).toHaveAttribute("href", "/supplier/team/akua-boateng/permissions");
  });

  it("renders permission matrix, role rules, access denied state, and activity log", () => {
    const { rerender } = render(<TeamMemberPermissionsScreen memberId="akua-boateng" />);

    expect(screen.getByRole("heading", { name: "Edit Permissions" })).toBeInTheDocument();
    for (const text of [
      "Product permissions",
      "View products",
      "Upload product images placeholder",
      "Inventory permissions",
      "Set low stock threshold",
      "Order permissions",
      "Add packing note/proof placeholder",
      "Finance permissions",
      "Edit payout details",
      "Verify settlement",
      "Team permissions",
      "Remove members",
      "Locked for Inventory Manager"
    ]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<SupplierTeamRolesScreen />);
    for (const text of [
      "Role Permissions Matrix",
      "Supplier Owner",
      "all supplier workspace permissions",
      "Inventory Manager default",
      "cannot edit payout details",
      "cannot verify settlements",
      "cannot invite/remove staff"
    ]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<AccessDeniedStateScreen />);
    for (const text of [
      "You do not have access to this page",
      "Inventory Manager",
      "Missing permission: Edit payout details",
      "Inventory Manager cannot edit payout details.",
      "Request Access",
      "Go Back",
      "Contact Supplier Owner"
    ]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<SupplierTeamActivityScreen />);
    expect(screen.getByRole("heading", { name: "Team Activity Log" })).toBeInTheDocument();
    for (const text of [
      "Product",
      "Stock",
      "Order",
      "Team",
      "Price",
      "Akua Boateng restocked Nike Air Force 1 size 42 by +12",
      "Akua Boateng marked order RSR-20260713-00021 ready",
      "Kofi Mensah changed Akua's role to Inventory Manager",
      "System recorded stock reservation for order RSR-20260713-00021",
      "Old value",
      "New value"
    ]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
  });

  it("renders inventory manager limited dashboard, products, orders, and settings without finance controls", () => {
    const { rerender } = render(<InventoryManagerDashboardScreen />);

    expect(screen.getByRole("heading", { name: "Inventory Manager Dashboard" })).toBeInTheDocument();
    for (const text of [
      "Hello, Akua",
      "Assigned supplier",
      "KNUST Gadgets",
      "Products needing stock updates",
      "Orders to prepare",
      "Low stock alerts",
      "Recent activity",
      "Add Product",
      "Restock Product",
      "Prepare Orders",
      "No finance or payout controls are available for this role."
    ]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
    expect(screen.queryByText("Settlement verification")).not.toBeInTheDocument();

    rerender(<InventoryManagerProductsScreen />);
    expect(screen.getByRole("heading", { name: "Inventory Manager Products" })).toBeInTheDocument();
    for (const text of ["Samsung Galaxy A14", "Nike Air Force 1 '07 Green & White", "Stock status", "Edit Product Mock", "Restock Mock", "No payout or settlement info is shown."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<InventoryManagerOrdersScreen />);
    expect(screen.getByRole("heading", { name: "Inventory Manager Orders" })).toBeInTheDocument();
    for (const text of ["Order prep list", "RSR-20260713-00021", "Mark Ready Mock", "Customer delivery area", "No settlement verification controls are available."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<InventoryManagerSettingsScreen />);
    expect(screen.getByRole("heading", { name: "Inventory Manager Settings" })).toBeInTheDocument();
    for (const text of ["Profile info", "Assigned supplier", "Role summary", "Permissions summary", "Request Access", "Sign Out Placeholder", "No supplier owner settings are available."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
  });
});
