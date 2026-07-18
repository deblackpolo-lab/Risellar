import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import AuthQaProfileSyncPage from "@/app/auth/qa-profile-sync/page";
import { getCurrentSyncedProfile } from "@/lib/auth/profile-sync";

vi.mock("@clerk/nextjs/server", () => ({
  auth: vi.fn(async () => ({ userId: "clerk_test_user" }))
}));

vi.mock("next/navigation", () => ({
  notFound: vi.fn(() => {
    throw new Error("not found");
  })
}));

vi.mock("@/lib/auth/profile-sync", () => ({
  getCurrentSyncedProfile: vi.fn()
}));

describe("Auth QA profile sync page", () => {
  beforeEach(() => {
    process.env.RISELLAR_ENABLE_AUTH_QA = "true";
    vi.mocked(getCurrentSyncedProfile).mockResolvedValue({
      account_status: "active",
      clerk_user_id: "clerk_test_user",
      email: "qa@example.test",
      full_name: "QA User",
      id: "profile-id",
      primary_role: "customer"
    });
  });

  it("shows a real logout control for signed-in QA account switching", async () => {
    render(await AuthQaProfileSyncPage());

    expect(screen.getByRole("button", { name: "Logout" })).toBeInTheDocument();
    expect(screen.getByText("Default role")).toBeInTheDocument();
    expect(screen.getByText("customer")).toBeInTheDocument();
  });
});
