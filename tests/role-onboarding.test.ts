import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  buildRoleOnboardingRequestDraft,
  buildRoleOnboardingSubmissionPayload,
  canRequestRoleOnboarding,
  getRoleOnboardingPendingPath,
  getRoleOnboardingRequestConfig,
  getRoleOnboardingStartPath,
  isRoleOnboardingRequestKind,
  mapRoleOnboardingRpcError,
  roleOnboardingTargetRoles
} from "@/lib/auth/role-onboarding";
import { buildProfileInsert } from "@/lib/auth/profile-sync-core";
import { canAccessRoute, getRoutePolicyForPath } from "@/lib/auth/route-guards";
import { getRoleHomePath } from "@/lib/auth/role-redirect";

describe("role onboarding request foundation", () => {
  it("keeps the default synced profile role as customer", () => {
    expect(
      buildProfileInsert({
        clerkUserId: "user_customer",
        email: "customer@example.invalid"
      }).primary_role
    ).toBe("customer");
  });

  it("allows customer profiles to draft reseller onboarding requests without role promotion", () => {
    const draft = buildRoleOnboardingRequestDraft(
      { id: "profile_customer", primary_role: "customer" },
      {
        requestKind: "reseller",
        businessName: "Campus Beauty Picks",
        contactPhone: " 0240000000 ",
        notes: "Student reseller request"
      }
    );

    expect(draft).toEqual({
      profile_id: "profile_customer",
      requested_role: "reseller",
      status: "pending",
      business_name: "Campus Beauty Picks",
      contact_phone: "0240000000",
      notes: "Student reseller request"
    });
  });

  it("allows customer profiles to draft supplier onboarding requests without role promotion", () => {
    const draft = buildRoleOnboardingRequestDraft(
      { id: "profile_customer", primary_role: "customer" },
      {
        requestKind: "supplier",
        businessName: "Dev Supplier Ltd"
      }
    );

    expect(draft).toMatchObject({
      profile_id: "profile_customer",
      requested_role: "supplier_owner",
      status: "pending",
      business_name: "Dev Supplier Ltd"
    });
  });

  it("does not expose admin or supplier inventory manager as public request kinds", () => {
    expect(isRoleOnboardingRequestKind("reseller")).toBe(true);
    expect(isRoleOnboardingRequestKind("supplier")).toBe(true);
    expect(isRoleOnboardingRequestKind("admin")).toBe(false);
    expect(isRoleOnboardingRequestKind("supplier_inventory_manager")).toBe(false);
    expect(Object.values(roleOnboardingTargetRoles)).not.toContain("admin");
    expect(Object.values(roleOnboardingTargetRoles)).not.toContain("supplier_inventory_manager");
  });

  it("rejects onboarding requests from already-promoted or privileged roles", () => {
    expect(canRequestRoleOnboarding({ id: "profile_customer", primary_role: "customer" })).toBe(true);

    for (const role of ["reseller", "supplier_owner", "supplier_inventory_manager", "admin"] as const) {
      expect(canRequestRoleOnboarding({ id: `profile_${role}`, primary_role: role })).toBe(false);
      expect(() =>
        buildRoleOnboardingRequestDraft({ id: `profile_${role}`, primary_role: role }, { requestKind: "reseller" })
      ).toThrow("Only customer profiles can request reseller or supplier onboarding");
    }
  });

  it("keeps role redirects predictable while onboarding requests are pending", () => {
    expect(getRoleHomePath({ role: "customer", onboardingStatus: "complete" })).toBe("/customer/orders");
    expect(getRoleHomePath({ role: "reseller", onboardingStatus: "pending_review" })).toBe("/reseller/onboarding/complete");
    expect(getRoleHomePath({ role: "supplier_owner", onboardingStatus: "pending_review" })).toBe("/supplier/onboarding/pending");
  });

  it("protects role onboarding pages for signed-in customer profiles", () => {
    expect(getRoutePolicyForPath("/onboarding/reseller")).toMatchObject({
      pattern: "/onboarding/:slug*",
      roles: ["customer"]
    });
    expect(canAccessRoute("/onboarding/supplier", null)).toBe(false);
    expect(canAccessRoute("/onboarding/supplier", { role: "customer", onboardingStatus: "complete" })).toBe(true);
    expect(canAccessRoute("/onboarding/supplier", { role: "reseller", onboardingStatus: "complete" })).toBe(false);
  });

  it("uses fixed request paths instead of client-side role escalation", () => {
    expect(getRoleOnboardingStartPath("reseller")).toBe("/onboarding/reseller");
    expect(getRoleOnboardingStartPath("supplier")).toBe("/onboarding/supplier");
    expect(getRoleOnboardingPendingPath("reseller")).toBe("/onboarding/pending?request=reseller");
    expect(getRoleOnboardingPendingPath("supplier")).toBe("/onboarding/pending?request=supplier");
  });

  it("builds submit payloads with fixed backend roles only", () => {
    expect(getRoleOnboardingRequestConfig("reseller")).toMatchObject({
      requestKind: "reseller",
      requestedRole: "reseller",
      pendingHref: "/onboarding/pending?request=reseller&status=submitted"
    });
    expect(getRoleOnboardingRequestConfig("supplier")).toMatchObject({
      requestKind: "supplier",
      requestedRole: "supplier_owner",
      pendingHref: "/onboarding/pending?request=supplier&status=submitted"
    });

    expect(
      buildRoleOnboardingSubmissionPayload("supplier", {
        businessName: " Dev Supplier Ltd ",
        contactPhone: " 0240000000 ",
        notes: "  Supplier request "
      })
    ).toEqual({
      requestedRole: "supplier_owner",
      businessName: "Dev Supplier Ltd",
      contactPhone: "0240000000",
      notes: "Supplier request"
    });
  });

  it("does not allow admin or supplier inventory manager submit configs", () => {
    expect(() => getRoleOnboardingRequestConfig("admin")).toThrow("Unsupported role onboarding request type");
    expect(() => getRoleOnboardingRequestConfig("supplier_inventory_manager")).toThrow(
      "Unsupported role onboarding request type"
    );
    expect(() =>
      buildRoleOnboardingSubmissionPayload("admin", {
        businessName: "Admin request"
      })
    ).toThrow("Unsupported role onboarding request type");
  });

  it("maps unauthenticated, duplicate, invalid role, and profile sync errors clearly", () => {
    expect(mapRoleOnboardingRpcError("UNAUTHENTICATED")).toMatchObject({
      code: "UNAUTHENTICATED",
      message: "Sign in before submitting a role onboarding request."
    });
    expect(mapRoleOnboardingRpcError("A pending onboarding request already exists for this role")).toMatchObject({
      code: "DUPLICATE_PENDING_REQUEST"
    });
    expect(mapRoleOnboardingRpcError("Requested role is not eligible for self-service onboarding")).toMatchObject({
      code: "INVALID_REQUESTED_ROLE"
    });
    expect(mapRoleOnboardingRpcError("Failed to create Risellar profile: dev failure")).toMatchObject({
      code: "PROFILE_SYNC_REQUIRED"
    });
  });

  it("keeps service role helpers out of onboarding pages and actions", () => {
    const root = process.cwd();
    const files = [
      "app/onboarding/actions.ts",
      "app/onboarding/reseller/page.tsx",
      "app/onboarding/supplier/page.tsx",
      "app/onboarding/pending/page.tsx"
    ];

    for (const file of files) {
      const source = readFileSync(join(root, file), "utf8");
      expect(source).not.toContain("createSupabaseAdminClient");
      expect(source).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
      expect(source).not.toContain('name="requested_role"');
      expect(source).not.toContain("supplier_inventory_manager");
    }
  });
});
