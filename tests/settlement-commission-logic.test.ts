import { describe, expect, it } from "vitest";
import {
  calculatePartialSettlementBalance,
  calculateSupplierSettlementDue,
  canReleaseCommission,
  canRequestWithdrawal,
  getCommissionStatus,
  getSettlementStatus,
  getSupplierRestrictionState,
  type CommissionLifecycleInput,
  type SupplierSettlementInput
} from "@/lib/business/settlement-commission";

const baseSettlement: SupplierSettlementInput = {
  orderId: "RSR-20260713-00021",
  customerPaidAmount: 340,
  supplierBaseAmount: 300,
  risellarMargin: 10,
  resellerCommission: 30,
  amountPaid: 0,
  dueDate: "2026-07-15",
  currentDate: "2026-07-17"
};

describe("settlement and commission business logic", () => {
  it("calculates supplier settlement due as platform margin plus reseller commission", () => {
    expect(calculateSupplierSettlementDue(baseSettlement)).toEqual({
      amountDue: 40,
      platformMargin: 10,
      resellerCommission: 30,
      supplierKeeps: 300,
      customerPaidAmount: 340
    });
  });

  it("classifies settlement status from amount paid, proof, admin verification, disputes, and due dates", () => {
    expect(getSettlementStatus(baseSettlement)).toBe("Overdue");
    expect(getSettlementStatus({ ...baseSettlement, currentDate: "2026-07-15" })).toBe("Due");
    expect(getSettlementStatus({ ...baseSettlement, amountPaid: 20, partialSettlementAllowed: true })).toBe("Partially Paid");
    expect(getSettlementStatus({ ...baseSettlement, amountPaid: 40, proofSubmitted: true })).toBe("Proof Submitted");
    expect(getSettlementStatus({ ...baseSettlement, amountPaid: 40, proofSubmitted: true, adminVerificationStatus: "Verifying" })).toBe("Verifying");
    expect(getSettlementStatus({ ...baseSettlement, amountPaid: 40, proofSubmitted: true, adminVerificationStatus: "Verified" })).toBe("Paid");
    expect(getSettlementStatus({ ...baseSettlement, orderCancelled: true })).toBe("Cancelled");
    expect(getSettlementStatus({ ...baseSettlement, hasOpenDispute: true })).toBe("Disputed");
  });

  it("keeps commission pending until settlement is verified and blocks release for disputes or returns", () => {
    const commission: CommissionLifecycleInput = {
      amount: 30,
      settlementStatus: "Paid",
      adminVerificationStatus: "Verified"
    };

    expect(getCommissionStatus({ ...commission, settlementStatus: "Due" })).toBe("Awaiting Settlement");
    expect(getCommissionStatus({ ...commission, hasOpenDispute: true })).toBe("Disputed");
    expect(getCommissionStatus({ ...commission, hasOpenReturn: true })).toBe("On Hold");
    expect(getCommissionStatus(commission)).toBe("Available");
    expect(canReleaseCommission(commission)).toEqual({ allowed: true, reason: "Commission can be released." });
    expect(canReleaseCommission({ ...commission, adminVerificationStatus: "Rejected" })).toEqual({
      allowed: false,
      reason: "Settlement proof is not verified."
    });
  });

  it("checks withdrawal eligibility against available commission balance, minimums, holds, and payout review", () => {
    expect(canRequestWithdrawal({ availableBalance: 240, requestedAmount: 120, minimumWithdrawalAmount: 50 })).toEqual({
      allowed: true,
      reason: "Withdrawal request is eligible.",
      remainingBalance: 120
    });
    expect(canRequestWithdrawal({ availableBalance: 40, requestedAmount: 40, minimumWithdrawalAmount: 50 }).allowed).toBe(false);
    expect(canRequestWithdrawal({ availableBalance: 240, requestedAmount: 260, minimumWithdrawalAmount: 50 })).toEqual({
      allowed: false,
      reason: "Requested amount exceeds available commission balance.",
      remainingBalance: 240
    });
    expect(canRequestWithdrawal({ availableBalance: 240, requestedAmount: 120, pendingPayoutReview: true }).reason).toBe("Payout details are still under review.");
    expect(canRequestWithdrawal({ availableBalance: 240, requestedAmount: 120, hasAccountHold: true }).reason).toBe("Account has an active hold.");
  });

  it("calculates partial settlement balance and enforces admin partial-settlement policy", () => {
    expect(calculatePartialSettlementBalance({ ...baseSettlement, amountPaid: 20, partialSettlementAllowed: true })).toEqual({
      amountDue: 40,
      amountPaid: 20,
      outstandingBalance: 20,
      isPartial: true,
      partialSettlementAllowed: true,
      canAcceptPartialSettlement: true
    });
    expect(calculatePartialSettlementBalance({ ...baseSettlement, amountPaid: 20, partialSettlementAllowed: false }).canAcceptPartialSettlement).toBe(false);
  });

  it("maps overdue settlement exposure to supplier restriction state", () => {
    expect(getSupplierRestrictionState({ overdueSettlementAmount: 0, maxDaysOverdue: 0, overdueSettlementCount: 0 }).level).toBe("Good Standing");
    expect(getSupplierRestrictionState({ overdueSettlementAmount: 40, maxDaysOverdue: 1, overdueSettlementCount: 1 })).toMatchObject({
      level: "Warning",
      canCreateProducts: true,
      canReceiveNewOrders: true,
      canBoostProducts: false
    });
    expect(getSupplierRestrictionState({ overdueSettlementAmount: 320, maxDaysOverdue: 4, overdueSettlementCount: 2 })).toMatchObject({
      level: "Limited",
      canCreateProducts: true,
      canReceiveNewOrders: true,
      canBoostProducts: false
    });
    expect(getSupplierRestrictionState({ overdueSettlementAmount: 900, maxDaysOverdue: 9, overdueSettlementCount: 4 })).toMatchObject({
      level: "Restricted",
      canCreateProducts: false,
      canReceiveNewOrders: false,
      canBoostProducts: false
    });
    expect(getSupplierRestrictionState({ overdueSettlementAmount: 1400, maxDaysOverdue: 15, overdueSettlementCount: 6 })).toMatchObject({
      level: "Suspended",
      canCreateProducts: false,
      canReceiveNewOrders: false,
      canBoostProducts: false
    });
  });
});
