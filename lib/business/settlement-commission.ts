export type AdminVerificationStatus = "Not Submitted" | "Proof Submitted" | "Verifying" | "Verified" | "Rejected";

export type SettlementStatus =
  | "Due"
  | "Overdue"
  | "Paid"
  | "Partially Paid"
  | "Proof Submitted"
  | "Verifying"
  | "Cancelled"
  | "Disputed";

export type CommissionStatus =
  | "Pending"
  | "Awaiting Settlement"
  | "Available"
  | "Withdrawal Requested"
  | "Paid"
  | "Cancelled"
  | "Disputed"
  | "On Hold";

export type SupplierRestrictionLevel = "Good Standing" | "Warning" | "Limited" | "Restricted" | "Suspended";

export type SupplierSettlementInput = {
  orderId: string;
  customerPaidAmount: number;
  supplierBaseAmount: number;
  risellarMargin: number;
  resellerCommission: number;
  amountPaid?: number;
  dueDate: string;
  currentDate?: string;
  proofSubmitted?: boolean;
  adminVerificationStatus?: AdminVerificationStatus;
  hasOpenDispute?: boolean;
  hasOpenReturn?: boolean;
  orderCancelled?: boolean;
  partialSettlementAllowed?: boolean;
};

export type CommissionLifecycleInput = {
  amount: number;
  settlementStatus: SettlementStatus;
  adminVerificationStatus?: AdminVerificationStatus;
  hasOpenDispute?: boolean;
  hasOpenReturn?: boolean;
  orderCancelled?: boolean;
  withdrawalRequested?: boolean;
  withdrawalPaid?: boolean;
};

export type WithdrawalEligibilityInput = {
  availableBalance: number;
  requestedAmount: number;
  minimumWithdrawalAmount?: number;
  pendingPayoutReview?: boolean;
  hasAccountHold?: boolean;
};

export type SupplierRestrictionInput = {
  overdueSettlementAmount: number;
  maxDaysOverdue: number;
  overdueSettlementCount: number;
};

export function calculateSupplierSettlementDue(settlement: SupplierSettlementInput) {
  return {
    amountDue: settlement.risellarMargin + settlement.resellerCommission,
    platformMargin: settlement.risellarMargin,
    resellerCommission: settlement.resellerCommission,
    supplierKeeps: settlement.supplierBaseAmount,
    customerPaidAmount: settlement.customerPaidAmount
  };
}

export function calculatePartialSettlementBalance(settlement: SupplierSettlementInput) {
  const amountDue = calculateSupplierSettlementDue(settlement).amountDue;
  const amountPaid = clampMoney(settlement.amountPaid ?? 0);
  const outstandingBalance = Math.max(amountDue - amountPaid, 0);
  const isPartial = amountPaid > 0 && outstandingBalance > 0;
  const partialSettlementAllowed = settlement.partialSettlementAllowed === true;

  return {
    amountDue,
    amountPaid,
    outstandingBalance,
    isPartial,
    partialSettlementAllowed,
    canAcceptPartialSettlement: isPartial && partialSettlementAllowed
  };
}

export function getSettlementStatus(settlement: SupplierSettlementInput): SettlementStatus {
  if (settlement.orderCancelled) {
    return "Cancelled";
  }

  if (settlement.hasOpenDispute || settlement.hasOpenReturn) {
    return "Disputed";
  }

  const { amountDue, outstandingBalance, isPartial } = calculatePartialSettlementBalance(settlement);
  const isFullyPaid = amountDue > 0 && outstandingBalance === 0;

  if (isFullyPaid && settlement.adminVerificationStatus === "Verified") {
    return "Paid";
  }

  if (isFullyPaid && settlement.adminVerificationStatus === "Verifying") {
    return "Verifying";
  }

  if (isFullyPaid && (settlement.proofSubmitted || settlement.adminVerificationStatus === "Proof Submitted")) {
    return "Proof Submitted";
  }

  if (isPartial) {
    return "Partially Paid";
  }

  return isPastDue(settlement.dueDate, settlement.currentDate) ? "Overdue" : "Due";
}

export function getCommissionStatus(commission: CommissionLifecycleInput): CommissionStatus {
  if (commission.orderCancelled) {
    return "Cancelled";
  }

  if (commission.hasOpenDispute) {
    return "Disputed";
  }

  if (commission.hasOpenReturn) {
    return "On Hold";
  }

  if (commission.withdrawalPaid) {
    return "Paid";
  }

  if (commission.withdrawalRequested) {
    return "Withdrawal Requested";
  }

  if (commission.settlementStatus !== "Paid" || commission.adminVerificationStatus !== "Verified") {
    return "Awaiting Settlement";
  }

  return "Available";
}

export function canReleaseCommission(commission: CommissionLifecycleInput) {
  const status = getCommissionStatus(commission);

  if (status === "Available") {
    return { allowed: true, reason: "Commission can be released." };
  }

  if (commission.hasOpenDispute) {
    return { allowed: false, reason: "Commission has an open dispute." };
  }

  if (commission.hasOpenReturn) {
    return { allowed: false, reason: "Commission is held by a return." };
  }

  if (commission.orderCancelled) {
    return { allowed: false, reason: "Order is cancelled." };
  }

  return { allowed: false, reason: "Settlement proof is not verified." };
}

export function canRequestWithdrawal(input: WithdrawalEligibilityInput) {
  const minimumWithdrawalAmount = input.minimumWithdrawalAmount ?? 50;
  const remainingBalance = input.availableBalance - input.requestedAmount;

  if (input.hasAccountHold) {
    return { allowed: false, reason: "Account has an active hold.", remainingBalance: input.availableBalance };
  }

  if (input.pendingPayoutReview) {
    return { allowed: false, reason: "Payout details are still under review.", remainingBalance: input.availableBalance };
  }

  if (input.requestedAmount < minimumWithdrawalAmount) {
    return { allowed: false, reason: "Requested amount is below the minimum withdrawal amount.", remainingBalance: input.availableBalance };
  }

  if (input.requestedAmount > input.availableBalance) {
    return { allowed: false, reason: "Requested amount exceeds available commission balance.", remainingBalance: input.availableBalance };
  }

  return { allowed: true, reason: "Withdrawal request is eligible.", remainingBalance };
}

export function getSupplierRestrictionState(input: SupplierRestrictionInput) {
  const level = getRestrictionLevel(input);

  return {
    level,
    canCreateProducts: level === "Good Standing" || level === "Warning" || level === "Limited",
    canReceiveNewOrders: level === "Good Standing" || level === "Warning" || level === "Limited",
    canBoostProducts: level === "Good Standing",
    reason: getRestrictionReason(level)
  };
}

function getRestrictionLevel(input: SupplierRestrictionInput): SupplierRestrictionLevel {
  if (input.overdueSettlementAmount <= 0 || input.overdueSettlementCount <= 0 || input.maxDaysOverdue <= 0) {
    return "Good Standing";
  }

  if (input.maxDaysOverdue >= 14 || input.overdueSettlementCount >= 6 || input.overdueSettlementAmount >= 1200) {
    return "Suspended";
  }

  if (input.maxDaysOverdue >= 7 || input.overdueSettlementCount >= 4 || input.overdueSettlementAmount >= 800) {
    return "Restricted";
  }

  if (input.maxDaysOverdue >= 3 || input.overdueSettlementCount >= 2 || input.overdueSettlementAmount >= 300) {
    return "Limited";
  }

  return "Warning";
}

function getRestrictionReason(level: SupplierRestrictionLevel) {
  switch (level) {
    case "Good Standing":
      return "No overdue settlement restrictions.";
    case "Warning":
      return "Supplier has an overdue settlement reminder.";
    case "Limited":
      return "Overdue settlement blocks boosts and promotional actions.";
    case "Restricted":
      return "Repeated overdue settlement blocks product creation and new orders.";
    case "Suspended":
      return "Severe overdue settlement exposure requires admin review.";
  }
}

function isPastDue(dueDate: string, currentDate?: string) {
  const due = parseDateOnly(dueDate);
  const current = parseDateOnly(currentDate ?? new Date().toISOString());

  return current.getTime() > due.getTime();
}

function parseDateOnly(value: string) {
  const [datePart] = value.split("T");
  const [year, month, day] = datePart.split("-").map(Number);

  return new Date(Date.UTC(year, month - 1, day));
}

function clampMoney(amount: number) {
  return Math.max(amount, 0);
}
