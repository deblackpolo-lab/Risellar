import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  buildRoleOnboardingRequestDraft,
  buildRoleOnboardingReviewPayload,
  buildRoleOnboardingSubmissionPayload,
  canReviewRoleOnboardingRequests,
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

  it("maps known auth, profile, RPC, duplicate, and validation errors clearly", () => {
    expect(mapRoleOnboardingRpcError("AUTH_REQUIRED")).toMatchObject({
      code: "AUTH_REQUIRED",
      message: "Sign in before submitting a role onboarding request."
    });
    expect(mapRoleOnboardingRpcError("SUPABASE_AUTH_TOKEN_MISSING")).toMatchObject({
      code: "SUPABASE_AUTH_TOKEN_MISSING"
    });
    expect(mapRoleOnboardingRpcError({ code: "api_response_error", message: "Not Found" })).toMatchObject({
      code: "SUPABASE_AUTH_TOKEN_MISSING"
    });
    expect(mapRoleOnboardingRpcError("Authenticated active profile is required to submit role onboarding requests")).toMatchObject({
      code: "PROFILE_NOT_FOUND"
    });
    expect(mapRoleOnboardingRpcError("A pending onboarding request already exists for this role")).toMatchObject({
      code: "DUPLICATE_PENDING_REQUEST"
    });
    expect(mapRoleOnboardingRpcError("Requested role is not eligible for self-service onboarding")).toMatchObject({
      code: "INVALID_ROLE"
    });
    expect(mapRoleOnboardingRpcError("Failed to create Risellar profile: dev failure")).toMatchObject({
      code: "PROFILE_SYNC_FAILED"
    });
    expect(mapRoleOnboardingRpcError("permission denied for function submit_role_onboarding_request")).toMatchObject({
      code: "RPC_PERMISSION_DENIED"
    });
    expect(mapRoleOnboardingRpcError("invalid input value for enum user_role")).toMatchObject({
      code: "RPC_VALIDATION_FAILED"
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

  it("uses the default Clerk session token for onboarding Supabase user-context calls", () => {
    const source = readFileSync(join(process.cwd(), "app/onboarding/actions.ts"), "utf8");

    expect(source).toContain("getToken()");
    expect(source).not.toContain('template: "supabase"');
    expect(source).not.toContain("template: 'supabase'");
  });

  it("builds admin review payloads only for approved or rejected decisions", () => {
    expect(
      buildRoleOnboardingReviewPayload({
        requestId: "11111111-1111-4111-8111-111111111111",
        decision: "approved",
        reviewNotes: "  verified in dev QA  "
      })
    ).toEqual({
      requestId: "11111111-1111-4111-8111-111111111111",
      decision: "approved",
      reviewNotes: "verified in dev QA"
    });

    expect(
      buildRoleOnboardingReviewPayload({
        requestId: "22222222-2222-4222-8222-222222222222",
        decision: "rejected",
        reviewNotes: "   "
      })
    ).toEqual({
      requestId: "22222222-2222-4222-8222-222222222222",
      decision: "rejected",
      reviewNotes: null
    });

    expect(() => buildRoleOnboardingReviewPayload({ requestId: "", decision: "approved" })).toThrow(
      "Role onboarding request id is required"
    );
    expect(() =>
      buildRoleOnboardingReviewPayload({
        requestId: "11111111-1111-4111-8111-111111111111",
        decision: "cancelled"
      })
    ).toThrow("Role onboarding review decision must be approved or rejected");
  });

  it("limits admin onboarding review access to active admin staff membership and protected admin routes", () => {
    expect(
      canReviewRoleOnboardingRequests({
        profile: { id: "profile_admin_staff", primary_role: "customer" },
        hasActiveAdminStaff: true
      })
    ).toBe(true);
    expect(
      canReviewRoleOnboardingRequests({
        profile: { id: "profile_admin_role_only", primary_role: "admin" },
        hasActiveAdminStaff: false
      })
    ).toBe(false);

    for (const role of ["customer", "reseller", "supplier_owner", "supplier_inventory_manager"] as const) {
      expect(
        canReviewRoleOnboardingRequests({
          profile: { id: `profile_${role}`, primary_role: role },
          hasActiveAdminStaff: false
        })
      ).toBe(false);
    }

    expect(getRoutePolicyForPath("/admin/onboarding-requests")).toMatchObject({
      pattern: "/admin/:slug*",
      roles: ["admin"]
    });
    expect(canAccessRoute("/admin/onboarding-requests", null)).toBe(false);
    expect(canAccessRoute("/admin/onboarding-requests", { role: "customer", onboardingStatus: "complete" })).toBe(false);
    expect(canAccessRoute("/admin/onboarding-requests", { role: "admin", onboardingStatus: "complete" })).toBe(true);
  });

  it("keeps admin review UI on the audited RPC path without service-role or direct role mutation", () => {
    const root = process.cwd();
    const files = [
      "app/admin/onboarding-requests/page.tsx",
      "app/admin/onboarding-requests/actions.ts",
      "lib/auth/admin-access.ts"
    ];

    for (const file of files) {
      const source = readFileSync(join(root, file), "utf8");
      expect(source).not.toContain("createSupabaseAdminClient");
      expect(source).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
      expect(source).not.toContain(".from(\"profiles\").update");
      expect(source).not.toContain(".from('profiles').update");
      expect(source).not.toContain("primary_role =");
    }

    const actionSource = readFileSync(join(root, "app/admin/onboarding-requests/actions.ts"), "utf8");
    expect(actionSource).toContain('rpc("review_role_onboarding_request"');
    expect(actionSource).toContain("getToken()");
    expect(actionSource).not.toContain('template: "supabase"');
    expect(actionSource).not.toContain("template: 'supabase'");

    const adminAccessSource = readFileSync(join(root, "lib/auth/admin-access.ts"), "utf8");
    expect(adminAccessSource).toContain('rpc("has_admin_role"');
    expect(adminAccessSource).toContain('required_role: "admin"');
  });
});
