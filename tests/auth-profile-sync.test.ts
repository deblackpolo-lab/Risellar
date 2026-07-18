import { describe, expect, it, vi } from "vitest";
import {
  buildProfileInsert,
  findOrCreateProfileForClerkIdentity,
  isSelfAssignableProfileRole,
  normalizeClerkIdentity
} from "@/lib/auth/profile-sync-core";
import {
  canAccessRoute,
  getRoutePolicyForPath,
  getVerifiedRouteAccessProfile,
  isPublicPath
} from "@/lib/auth/route-guards";
import { getRoleHomePath } from "@/lib/auth/role-redirect";

describe("Clerk profile sync foundation", () => {
  it("normalizes Clerk identity into safe profile fields", () => {
    const identity = normalizeClerkIdentity({
      id: "user_123",
      firstName: "Ama",
      lastName: "Mensah",
      fullName: null,
      primaryEmailAddress: { emailAddress: "Ama@example.com" }
    });

    expect(identity).toEqual({
      clerkUserId: "user_123",
      email: "ama@example.com",
      fullName: "Ama Mensah"
    });
  });

  it("builds a customer profile insert and blocks privileged self-assigned roles", () => {
    expect(
      buildProfileInsert({
        clerkUserId: "user_customer",
        email: "customer@example.invalid",
        fullName: "Dev Customer"
      })
    ).toMatchObject({
      clerk_user_id: "user_customer",
      email: "customer@example.invalid",
      full_name: "Dev Customer",
      primary_role: "customer"
    });

    expect(isSelfAssignableProfileRole("customer")).toBe(true);
    expect(isSelfAssignableProfileRole("reseller")).toBe(false);
    expect(isSelfAssignableProfileRole("supplier_owner")).toBe(false);
    expect(isSelfAssignableProfileRole("admin")).toBe(false);
    expect(() =>
      buildProfileInsert({
        clerkUserId: "user_admin",
        email: "admin@example.invalid",
        requestedRole: "admin"
      })
    ).toThrow("Cannot self-assign privileged role");
  });

  it("finds an existing profile before attempting insert", async () => {
    const existingProfile = {
      id: "profile_existing",
      clerk_user_id: "user_existing",
      email: "existing@example.invalid",
      full_name: "Existing User",
      primary_role: "customer",
      account_status: "active"
    };
    const repository = {
      findByClerkUserId: vi.fn().mockResolvedValue(existingProfile),
      createProfile: vi.fn()
    };

    const profile = await findOrCreateProfileForClerkIdentity(
      {
        clerkUserId: "user_existing",
        email: "existing@example.invalid"
      },
      repository
    );

    expect(profile).toBe(existingProfile);
    expect(repository.createProfile).not.toHaveBeenCalled();
  });

  it("creates a safe customer profile for a new Clerk identity", async () => {
    const createdProfile = {
      id: "profile_new",
      clerk_user_id: "user_new",
      email: "new@example.invalid",
      full_name: "New User",
      primary_role: "customer",
      account_status: "active"
    };
    const repository = {
      findByClerkUserId: vi.fn().mockResolvedValue(null),
      createProfile: vi.fn().mockResolvedValue(createdProfile)
    };

    const profile = await findOrCreateProfileForClerkIdentity(
      {
        clerkUserId: "user_new",
        email: "NEW@example.invalid",
        fullName: "New User"
      },
      repository
    );

    expect(repository.createProfile).toHaveBeenCalledWith({
      clerk_user_id: "user_new",
      email: "new@example.invalid",
      full_name: "New User",
      primary_role: "customer"
    });
    expect(profile).toBe(createdProfile);
  });
});

describe("auth route guard foundation", () => {
  it("keeps preview and storefront routes public", () => {
    expect(isPublicPath("/preview")).toBe(true);
    expect(isPublicPath("/design-system")).toBe(true);
    expect(isPublicPath("/shop/ama-store")).toBe(true);
    expect(isPublicPath("/shop/ama-store/product/product-1")).toBe(true);
  });

  it("matches specific supplier inventory manager policy before supplier owner policy", () => {
    expect(getRoutePolicyForPath("/supplier/inventory-manager/dashboard")).toMatchObject({
      pattern: "/supplier/inventory-manager/:slug*",
      roles: ["supplier_inventory_manager"]
    });

    expect(getRoutePolicyForPath("/supplier/dashboard")).toMatchObject({
      pattern: "/supplier/:slug*",
      roles: ["supplier_owner"]
    });
  });

  it("uses server-verified role and onboarding state for protected route access", () => {
    expect(canAccessRoute("/admin/dashboard", { role: "customer", onboardingStatus: "complete" })).toBe(false);
    expect(canAccessRoute("/admin/dashboard", { role: "admin", onboardingStatus: "complete" })).toBe(true);
    expect(canAccessRoute("/reseller/dashboard", { role: "reseller", onboardingStatus: "pending_review" })).toBe(false);
    expect(canAccessRoute("/reseller/dashboard", { role: "reseller", onboardingStatus: "complete" })).toBe(true);
  });

  it("allows approved reseller profiles into the reseller route family", () => {
    const approvedReseller = { role: "reseller", onboardingStatus: "complete" } as const;

    for (const pathname of [
      "/reseller/dashboard",
      "/reseller/products",
      "/reseller/shop",
      "/reseller/my-products",
      "/reseller/wallet"
    ]) {
      expect(canAccessRoute(pathname, approvedReseller)).toBe(true);
    }
  });

  it("blocks customer and reseller profiles from supplier-owner and admin route families", () => {
    const customer = { role: "customer", onboardingStatus: "complete" } as const;
    const approvedReseller = { role: "reseller", onboardingStatus: "complete" } as const;

    for (const pathname of [
      "/supplier/dashboard",
      "/supplier/products",
      "/supplier/inventory",
      "/supplier/settlements",
      "/supplier/team"
    ]) {
      expect(canAccessRoute(pathname, customer)).toBe(false);
      expect(canAccessRoute(pathname, approvedReseller)).toBe(false);
    }

    expect(canAccessRoute("/admin/onboarding-requests", approvedReseller)).toBe(false);
    expect(canAccessRoute("/admin/dashboard", approvedReseller)).toBe(false);
  });

  it("keeps rejected supplier requests from implying supplier-owner route access", () => {
    const rejectedSupplierRequester = { role: "reseller", onboardingStatus: "complete" } as const;

    expect(canAccessRoute("/reseller/dashboard", rejectedSupplierRequester)).toBe(true);
    expect(canAccessRoute("/supplier/dashboard", rejectedSupplierRequester)).toBe(false);
    expect(canAccessRoute("/supplier/products", rejectedSupplierRequester)).toBe(false);
  });

  it("maps profile roles into route access without treating primary_role admin as sufficient", () => {
    expect(
      getVerifiedRouteAccessProfile({
        primaryRole: "reseller"
      })
    ).toEqual({
      role: "reseller",
      onboardingStatus: "complete"
    });

    expect(
      getVerifiedRouteAccessProfile({
        primaryRole: "customer",
        hasActiveAdminStaff: true
      })
    ).toEqual({
      role: "admin",
      onboardingStatus: "complete"
    });

    expect(
      getVerifiedRouteAccessProfile({
        primaryRole: "admin",
        hasActiveAdminStaff: false
      })
    ).toBeNull();
  });

  it("returns role home paths from trusted profile role data", () => {
    expect(getRoleHomePath({ role: "customer", onboardingStatus: "not_started" })).toBe("/checkout/account");
    expect(getRoleHomePath({ role: "supplier_owner", onboardingStatus: "complete" })).toBe("/supplier/dashboard");
  });
});
