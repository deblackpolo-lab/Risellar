import { readFileSync } from "node:fs";
import { join } from "node:path";
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { BottomNav } from "@/components/layout";
import { ResellerDashboardMetricsScreen } from "@/components/dashboard/real-dashboard-metrics-screens";
import { canAccessRoute, getVerifiedRouteAccessProfile } from "@/lib/auth/route-guards";
import type { ResellerEarning, ResellerWithdrawalHistory } from "@/lib/reseller/finance/reseller-finance";
import type { ResellerDashboardSummary } from "@/lib/dashboard/real-dashboard-metrics";

const dashboardScreenPath = join(process.cwd(), "components/dashboard/real-dashboard-metrics-screens.tsx");
const bottomNavPath = join(process.cwd(), "components/layout/BottomNav.tsx");
const resellerDashboardPath = join(process.cwd(), "app/reseller/dashboard/page.tsx");

function read(path: string) {
  return readFileSync(path, "utf8");
}

const summary: ResellerDashboardSummary = {
  current: {
    currencyCode: "GHS",
    lockedCommissionAmount: 120,
    availableBalanceAmount: 480,
    pendingWithdrawalAmount: 75,
    withdrawnAmount: 900
  },
  period: {
    dateFrom: "2026-08-01",
    dateTo: "2026-08-03",
    attributedOrdersCount: 8,
    completedSalesCount: 5,
    rejectedOrdersCount: 1,
    commissionEarnedAmount: 220
  }
};

const earnings: ResellerEarning[] = [
  {
    availableAt: "2026-08-03T00:00:00Z",
    commissionAmount: 45,
    commissionId: "commission-1",
    commissionStatus: "available",
    currencyCode: "GHS",
    earnedAt: "2026-08-02T00:00:00Z",
    orderNumber: "RSR-ORDER-1",
    productName: "QA Reseller Product",
    quantity: 1,
    resellerShopName: "QA Shop",
    withdrawalReference: null,
    withdrawalStatus: null
  }
];

const withdrawals: ResellerWithdrawalHistory[] = [
  {
    currencyCode: "GHS",
    paidAt: null,
    payoutAccountMasked: null,
    payoutAccountName: null,
    payoutMethod: null,
    payoutReferencePresent: false,
    requestedAmount: 75,
    requestedAt: "2026-08-03T00:00:00Z",
    requestReference: "WD-QA-1",
    withdrawalId: "11111111-1111-4111-8111-111111111111",
    withdrawalStatus: "pending_review"
  }
];

describe("reseller PWA dashboard restoration", () => {
  it("renders the live reseller dashboard inside the mobile PWA shell with fixed bottom navigation", () => {
    render(
      <ResellerDashboardMetricsScreen
        earnings={earnings}
        period="last_30_days"
        state={{ code: "OK", message: "Dashboard loaded." }}
        summaries={[summary]}
        withdrawals={withdrawals}
      />
    );

    expect(screen.getByRole("heading", { name: "Your reseller home" })).toBeInTheDocument();
    expect(screen.queryByText("Sales and wallet dashboard")).not.toBeInTheDocument();
    expect(screen.getByText("Available balance")).toBeInTheDocument();
    expect(screen.getByText("GH₵480.00")).toBeInTheDocument();
    expect(screen.getByText("Locked")).toBeInTheDocument();
    expect(screen.getByText("Pending withdrawal")).toBeInTheDocument();
    expect(screen.getByText("Withdrawn")).toBeInTheDocument();
    expect(screen.getByText("Commission earned")).toBeInTheDocument();
    expect(screen.getByText("Orders attributed")).toBeInTheDocument();
    expect(screen.getByText("QA Reseller Product")).toBeInTheDocument();
    expect(screen.getByText("WD-QA-1")).toBeInTheDocument();

    expect(screen.getByRole("link", { name: "Home" })).toHaveAttribute("href", "/reseller/dashboard");
    expect(screen.getByRole("link", { name: "Products" })).toHaveAttribute("href", "/reseller/products");
    expect(screen.getByRole("link", { name: "Orders" })).toHaveAttribute("href", "/reseller/orders");
    expect(screen.getByRole("link", { name: "Wallet" })).toHaveAttribute("href", "/reseller/wallet");
    expect(screen.getAllByRole("link", { name: "Profile" }).some((link) => link.getAttribute("href") === "/reseller/settings")).toBe(true);
    expect(screen.getByRole("link", { name: "Home" })).toHaveAttribute("aria-current", "page");
  });

  it("keeps legacy active aliases while rendering approved reseller tab labels", () => {
    render(<BottomNav active="Shop" />);

    expect(screen.getByRole("link", { name: "Products" })).toHaveAttribute("aria-current", "page");
    expect(screen.queryByRole("link", { name: "Shop" })).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Support" })).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Account" })).not.toBeInTheDocument();
  });

  it("derives active reseller tabs from the current route when older screens pass stale active labels", () => {
    window.history.pushState({}, "", "/reseller/orders");
    render(<BottomNav active="Support" />);

    expect(screen.getByRole("link", { name: "Orders" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByRole("link", { name: "Profile" })).not.toHaveAttribute("aria-current");
  });

  it("preserves live metric helpers and avoids mock dashboard or service-role regressions", () => {
    const source = [read(dashboardScreenPath), read(bottomNavPath), read(resellerDashboardPath)].join("\n");

    expect(source).toContain("getResellerDashboardMetricsSafeWithClient");
    expect(source).toContain("listResellerEarningsHistorySafeWithClient");
    expect(source).toContain("listResellerWithdrawalHistorySafeWithClient");
    expect(source).not.toContain("ResellerDashboardCoreScreen");
    expect(source).not.toContain("@/lib/mock");
    expect(source).not.toContain("createSupabaseAdminClient");
    expect(source).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(source).toContain("pb-36");
    expect(source).toContain("<BottomNav active=\"Home\" />");
  });

  it("keeps reseller dashboard route role-enforced", () => {
    expect(canAccessRoute("/reseller/dashboard", getVerifiedRouteAccessProfile({ primaryRole: "reseller" }))).toBe(true);
    expect(canAccessRoute("/reseller/dashboard", getVerifiedRouteAccessProfile({ primaryRole: "customer" }))).toBe(false);
    expect(canAccessRoute("/reseller/dashboard", getVerifiedRouteAccessProfile({ primaryRole: "supplier_owner" }))).toBe(false);
    expect(canAccessRoute("/reseller/dashboard", getVerifiedRouteAccessProfile({ primaryRole: "customer", hasActiveAdminStaff: true }))).toBe(false);
  });
});
