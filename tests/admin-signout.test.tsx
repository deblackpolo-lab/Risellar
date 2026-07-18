import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { AdminShell, AdminSidebar } from "@/components/admin/AdminSidebar";

vi.mock("next/navigation", () => ({
  usePathname: () => "/admin/dashboard"
}));

describe("Admin account switching support", () => {
  it("uses the real Clerk sign-out control in the admin shell footer", () => {
    render(
      <AdminShell>
        <div>Admin content</div>
      </AdminShell>
    );

    expect(screen.getAllByRole("button", { name: "Logout" }).length).toBeGreaterThanOrEqual(1);
    expect(screen.queryByRole("button", { name: "Logout mock action" })).not.toBeInTheDocument();
  });

  it("uses the real Clerk sign-out control in the design-system admin sidebar preview", () => {
    render(<AdminSidebar />);

    expect(screen.getByRole("button", { name: "Logout" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Logout mock action" })).not.toBeInTheDocument();
  });
});
