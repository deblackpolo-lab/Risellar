import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { canAccessRoute } from "@/lib/auth/route-guards";
import { getRootAuthRedirectPath } from "@/lib/auth/root-redirect";

const rootPagePath = join(process.cwd(), "app/page.tsx");
const rootRedirectPath = join(process.cwd(), "lib/auth/root-redirect.ts");
const routeBoundaryPath = join(process.cwd(), "lib/auth/route-access-boundary.tsx");
const customerDisputesPath = join(process.cwd(), "app/customer/disputes/page.tsx");

function read(path: string) {
  return readFileSync(path, "utf8");
}

describe("secure root auth and role redirect", () => {
  it("redirects signed-out users to sign-in without rendering the old root shell", () => {
    expect(getRootAuthRedirectPath({ isAuthenticated: false })).toBe("/sign-in");

    const rootPage = read(rootPagePath);
    expect(rootPage).not.toContain("Risellar Phase 1");
    expect(rootPage).not.toContain("Design foundation shell");
    expect(rootPage).not.toContain("Open design system");
    expect(rootPage).toContain("redirect(");
    expect(rootPage).toContain("getRootAuthRedirectPath");
  });

  it("redirects active completed workspace roles to their dashboards", () => {
    expect(
      getRootAuthRedirectPath({
        isAuthenticated: true,
        profile: { primaryRole: "customer", accountStatus: "active", onboardingStatus: "complete" }
      })
    ).toBe("/customer/dashboard");

    expect(
      getRootAuthRedirectPath({
        isAuthenticated: true,
        profile: { primaryRole: "supplier_owner", accountStatus: "active", onboardingStatus: "complete" }
      })
    ).toBe("/supplier/dashboard");

    expect(
      getRootAuthRedirectPath({
        isAuthenticated: true,
        profile: { primaryRole: "reseller", accountStatus: "active", onboardingStatus: "complete" }
      })
    ).toBe("/reseller/dashboard");
  });

  it("redirects active support, finance, admin, and super-admin staff to the admin dashboard", () => {
    const base = { isAuthenticated: true, profile: { primaryRole: "customer", accountStatus: "active" } } as const;

    expect(getRootAuthRedirectPath({ ...base, adminAccess: { hasSupportStaff: true } })).toBe("/admin/dashboard");
    expect(getRootAuthRedirectPath({ ...base, adminAccess: { hasFinanceStaff: true } })).toBe("/admin/dashboard");
    expect(getRootAuthRedirectPath({ ...base, adminAccess: { hasAdmin: true } })).toBe("/admin/dashboard");
  });

  it("uses admin_staff precedence for mixed customer/admin accounts", () => {
    expect(
      getRootAuthRedirectPath({
        isAuthenticated: true,
        profile: { primaryRole: "customer", accountStatus: "active", onboardingStatus: "complete" },
        adminAccess: { hasFinanceStaff: true }
      })
    ).toBe("/admin/dashboard");
  });

  it("routes inactive and suspended accounts to safe status surfaces", () => {
    expect(
      getRootAuthRedirectPath({
        isAuthenticated: true,
        profile: { primaryRole: "customer", accountStatus: "inactive", onboardingStatus: "complete" }
      })
    ).toBe("/edge-cases/account-restricted");

    expect(
      getRootAuthRedirectPath({
        isAuthenticated: true,
        profile: { primaryRole: "customer", accountStatus: "suspended", onboardingStatus: "complete" }
      })
    ).toBe("/edge-cases/account-suspended");
  });

  it("routes incomplete onboarding to role-appropriate onboarding paths", () => {
    expect(
      getRootAuthRedirectPath({
        isAuthenticated: true,
        profile: { primaryRole: "customer", accountStatus: "active", onboardingStatus: "not_started" }
      })
    ).toBe("/checkout/account");

    expect(
      getRootAuthRedirectPath({
        isAuthenticated: true,
        profile: { primaryRole: "supplier_owner", accountStatus: "active", onboardingStatus: "in_progress" }
      })
    ).toBe("/supplier/onboarding/business");

    expect(
      getRootAuthRedirectPath({
        isAuthenticated: true,
        profile: { primaryRole: "reseller", accountStatus: "active", onboardingStatus: "in_progress" }
      })
    ).toBe("/reseller/onboarding/profile");
  });

  it("handles missing profiles and unknown roles without exposing dashboards", () => {
    expect(getRootAuthRedirectPath({ isAuthenticated: true, profile: null })).toBe("/auth/qa-profile-sync");
    expect(
      getRootAuthRedirectPath({
        isAuthenticated: true,
        profile: { primaryRole: "admin", accountStatus: "active", onboardingStatus: "complete" },
        adminAccess: { hasAdmin: false, hasFinanceStaff: false, hasSupportStaff: false }
      })
    ).toBe("/sign-in");
  });

  it("keeps redirect targets out of the root/sign-in loop and preserves wrong-role guards", () => {
    const rootRedirect = read(rootRedirectPath);

    expect(rootRedirect).not.toMatch(/localStorage|window\.location|document\.cookie|query.*role/i);
    expect(rootRedirect).not.toContain('"/"');
    expect(canAccessRoute("/supplier/dashboard", { role: "reseller", onboardingStatus: "complete" })).toBe(false);
    expect(canAccessRoute("/admin/dashboard", { role: "customer", onboardingStatus: "complete" })).toBe(false);
    expect(read(routeBoundaryPath)).toContain("getRootAdminDashboardAccess");
  });

  it("keeps customer dispute routes unaffected", () => {
    expect(canAccessRoute("/customer/disputes", { role: "customer", onboardingStatus: "complete" })).toBe(true);
    expect(canAccessRoute("/customer/disputes", { role: "admin", onboardingStatus: "complete" })).toBe(false);
    expect(read(customerDisputesPath)).toContain("getCustomerDisputesForCurrentUser");
  });
});
