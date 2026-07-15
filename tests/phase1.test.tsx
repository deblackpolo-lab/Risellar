import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Button } from "@/components/ui/Button";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { designTokens } from "@/lib/constants/design-tokens";
import { sampleProduct } from "@/lib/mock/design-system";

describe("Phase 1 design foundation", () => {
  it("exports the approved Risellar brand tokens", () => {
    expect(designTokens.colors.primary).toBe("#086B4F");
    expect(designTokens.colors.accent).toBe("#F5B300");
    expect(designTokens.colors.cream).toBe("#FFF8EA");
  });

  it("keeps mock examples in Ghana cedi values", () => {
    expect(sampleProduct.customerPrice).toBe("GH₵340");
    expect(sampleProduct.supplierBasePrice).toBe("GH₵300");
    expect(sampleProduct.platformMargin).toBe("GH₵10");
    expect(sampleProduct.resellerMargin).toBe("GH₵30");
  });

  it("renders skeleton components with token-backed classes", () => {
    render(
      <div>
        <Button>Primary action</Button>
        <StatusBadge tone="warning">Delivery Quote Pending</StatusBadge>
      </div>
    );

    expect(screen.getByRole("button", { name: "Primary action" })).toHaveClass("bg-[var(--color-primary)]");
    expect(screen.getByText("Delivery Quote Pending")).toHaveClass("bg-[var(--color-warning-soft)]");
  });
});
