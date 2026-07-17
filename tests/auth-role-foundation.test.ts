import { describe, expect, it } from "vitest";
import {
  getDefaultRedirect,
  profileOnboardingFields,
  protectedRoutePolicies,
  publicRoutePolicies,
  risellarRoles,
  roleRedirectRules
} from "@/lib/auth/role-policy";

describe("Risellar auth role foundation", () => {
  it("models the approved Clerk-facing roles", () => {
    expect(risellarRoles).toEqual(["customer", "reseller", "supplier_owner", "supplier_inventory_manager", "admin"]);
  });

  it("keeps phone as profile data for every non-admin role", () => {
    for (const role of ["customer", "reseller", "supplier_owner", "supplier_inventory_manager"] as const) {
      expect(profileOnboardingFields[role]).toContain("phone");
    }

    expect(profileOnboardingFields.admin).not.toContain("phone");
  });

  it("separates public storefront routes from protected app workspaces", () => {
    expect(publicRoutePolicies.map((route) => route.pattern)).toContain("/shop/:shopSlug");
    expect(publicRoutePolicies.map((route) => route.pattern)).toContain("/shop/:shopSlug/product/:productId");

    expect(protectedRoutePolicies).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ pattern: "/reseller/:slug*", roles: ["reseller"] }),
        expect.objectContaining({ pattern: "/supplier/:slug*", roles: ["supplier_owner"] }),
        expect.objectContaining({ pattern: "/supplier/inventory-manager/:slug*", roles: ["supplier_inventory_manager"] }),
        expect.objectContaining({ pattern: "/admin/:slug*", roles: ["admin"] })
      ])
    );
  });

  it("has redirect rules for each role and onboarding state", () => {
    expect(roleRedirectRules).toHaveLength(risellarRoles.length * 4);
    expect(getDefaultRedirect("customer", "not_started")).toBe("/checkout/account");
    expect(getDefaultRedirect("reseller", "complete")).toBe("/reseller/dashboard");
    expect(getDefaultRedirect("supplier_owner", "pending_review")).toBe("/supplier/onboarding/pending");
    expect(getDefaultRedirect("supplier_inventory_manager", "complete")).toBe("/supplier/inventory-manager/dashboard");
    expect(getDefaultRedirect("admin", "complete")).toBe("/admin/dashboard");
  });
});
