import { supplierCoreMock } from "@/lib/mock/supplier-core";

export function formatGhc(amount: number) {
  return `GH₵${amount.toLocaleString("en-GH", { maximumFractionDigits: 0 })}`;
}

export type SupplierSettlementStatus = "Due" | "Overdue" | "Paid" | "Partially Paid" | "Proof Submitted" | "Verifying" | "Cancelled";
export type SettlementPaymentMethod = "MTN Mobile Money" | "Telecel Cash" | "AirtelTigo Money" | "Bank Transfer";

export type SupplierSettlement = {
  id: string;
  settlementNumber: string;
  supplier: string;
  orderId: string;
  customer: string;
  orderDate: string;
  customerPaidAmount: number;
  supplierBaseAmount: number;
  risellarMargin: number;
  resellerCommission: number;
  amountDue: number;
  amountPaid: number;
  dueDate: string;
  daysOverdue?: number;
  status: SupplierSettlementStatus;
  paymentMethod?: SettlementPaymentMethod;
  reference?: string;
  linkedOrderSummary: string;
};

export type SettlementHistoryEvent = {
  id: string;
  settlementId: string;
  label: string;
  detail: string;
  timestamp: string;
  status: string;
};

export type RestrictionLevel = {
  level: "Warning" | "Limited" | "Restricted" | "Suspended";
  description: string;
  impact: string;
};

export const supplierSettlementMock = {
  supplier: {
    ...supplierCoreMock.supplier,
    businessName: "KNUST Gadgets",
    payoutProvider: "MTN Mobile Money",
    payoutNumber: "+233 24 987 6543",
    payoutAccountName: "Kofi Mensah",
    bankPlaceholder: "Bank option placeholder"
  },
  suppliers: ["KNUST Gadgets", "Palace Beauty Supplies", "Beautiful Living Store"],
  summary: {
    totalSettlementsDue: 4850,
    overdueAmount: 1350,
    paidThisMonth: 3200,
    totalSettledAllTime: 27650,
    trustScore: 88,
    trustLabel: "Good Standing",
    restrictionStatus: "Warning"
  },
  paymentMethods: ["MTN Mobile Money", "Telecel Cash", "AirtelTigo Money", "Bank Transfer"] satisfies SettlementPaymentMethod[],
  paymentInstructions: {
    accountName: "Risellar Settlement Account",
    momoNumber: "+233 24 000 8842",
    businessReference: "Use settlement number as payment reference"
  },
  settlements: [
    {
      id: "stl-rsr-20260713-00021",
      settlementNumber: "STL-RSR-20260713-00021",
      supplier: "KNUST Gadgets",
      orderId: "RSR-20260713-00021",
      customer: "Nana Yaw",
      orderDate: "13 Jul 2026",
      customerPaidAmount: 340,
      supplierBaseAmount: 300,
      risellarMargin: 10,
      resellerCommission: 30,
      amountDue: 40,
      amountPaid: 0,
      dueDate: "15 Jul 2026",
      status: "Due",
      linkedOrderSummary: "Samsung Galaxy A14 delivered to Legon, Accra. Customer paid supplier on delivery."
    },
    {
      id: "stl-rsr-20260712-00018",
      settlementNumber: "STL-RSR-20260712-00018",
      supplier: "KNUST Gadgets",
      orderId: "RSR-20260712-00018",
      customer: "Kojo Appiah",
      orderDate: "12 Jul 2026",
      customerPaidAmount: 280,
      supplierBaseAmount: 248,
      risellarMargin: 8,
      resellerCommission: 24,
      amountDue: 32,
      amountPaid: 0,
      dueDate: "13 Jul 2026",
      daysOverdue: 2,
      status: "Overdue",
      linkedOrderSummary: "Customer paid supplier for perfume order. Settlement is overdue."
    },
    {
      id: "stl-rsr-20260711-00015",
      settlementNumber: "STL-RSR-20260711-00015",
      supplier: "Palace Beauty Supplies",
      orderId: "RSR-20260711-00015",
      customer: "Akosua Boateng",
      orderDate: "11 Jul 2026",
      customerPaidAmount: 450,
      supplierBaseAmount: 398,
      risellarMargin: 12,
      resellerCommission: 40,
      amountDue: 52,
      amountPaid: 20,
      dueDate: "13 Jul 2026",
      daysOverdue: 1,
      status: "Partially Paid",
      linkedOrderSummary: "Beauty set collected by customer. Balance remains unsettled."
    },
    {
      id: "stl-rsr-20260710-00009",
      settlementNumber: "STL-RSR-20260710-00009",
      supplier: "Beautiful Living Store",
      orderId: "RSR-20260710-00009",
      customer: "Esi Owusu",
      orderDate: "10 Jul 2026",
      customerPaidAmount: 380,
      supplierBaseAmount: 300,
      risellarMargin: 20,
      resellerCommission: 60,
      amountDue: 80,
      amountPaid: 80,
      dueDate: "11 Jul 2026",
      status: "Proof Submitted",
      paymentMethod: "MTN Mobile Money",
      reference: "MOMO-8842-771",
      linkedOrderSummary: "Hostel essentials pack delivered. Proof awaits admin verification."
    },
    {
      id: "stl-rsr-20260709-00004",
      settlementNumber: "STL-RSR-20260709-00004",
      supplier: "KNUST Gadgets",
      orderId: "RSR-20260709-00004",
      customer: "Yaw Addo",
      orderDate: "09 Jul 2026",
      customerPaidAmount: 620,
      supplierBaseAmount: 540,
      risellarMargin: 20,
      resellerCommission: 60,
      amountDue: 80,
      amountPaid: 80,
      dueDate: "10 Jul 2026",
      status: "Paid",
      paymentMethod: "Bank Transfer",
      reference: "BNK-RSL-4209",
      linkedOrderSummary: "Phone accessory bundle paid and verified."
    },
    {
      id: "stl-rsr-20260708-00002",
      settlementNumber: "STL-RSR-20260708-00002",
      supplier: "KNUST Gadgets",
      orderId: "RSR-20260708-00002",
      customer: "Ama Serwaa",
      orderDate: "08 Jul 2026",
      customerPaidAmount: 720,
      supplierBaseAmount: 640,
      risellarMargin: 20,
      resellerCommission: 60,
      amountDue: 80,
      amountPaid: 80,
      dueDate: "09 Jul 2026",
      status: "Verifying",
      paymentMethod: "Telecel Cash",
      reference: "TLC-7761-20",
      linkedOrderSummary: "Proof submitted and being checked by finance."
    }
  ] satisfies SupplierSettlement[],
  history: [
    { id: "hist-001", settlementId: "stl-rsr-20260709-00004", label: "Proof verified", detail: "Receipt BNK-RSL-4209 verified.", timestamp: "10 Jul 2026, 2:15 PM", status: "Paid" },
    { id: "hist-002", settlementId: "stl-rsr-20260710-00009", label: "Proof uploaded", detail: "MOMO-8842-771 submitted for verification.", timestamp: "11 Jul 2026, 9:40 AM", status: "Proof Submitted" },
    { id: "hist-003", settlementId: "stl-rsr-20260713-00021", label: "Settlement created", detail: "Supplier received customer payment and settlement became due.", timestamp: "13 Jul 2026, 4:35 PM", status: "Due" },
    { id: "hist-004", settlementId: "stl-rsr-20260712-00018", label: "Marked overdue", detail: "Due date passed without verified proof.", timestamp: "14 Jul 2026, 8:10 AM", status: "Overdue" }
  ] satisfies SettlementHistoryEvent[],
  restrictionLevels: [
    { level: "Warning", description: "You have overdue settlement reminders.", impact: "Settle on time to keep account visibility healthy." },
    { level: "Limited", description: "Some features are restricted.", impact: "Boosts and promotions are unavailable while overdue." },
    { level: "Restricted", description: "New orders may be blocked.", impact: "Repeated overdue settlements may hide products." },
    { level: "Suspended", description: "Account access is paused.", impact: "Repeated settlement breaches require admin review." }
  ] satisfies RestrictionLevel[],
  trustFactors: ["Settle on time", "Keep disputes low", "Upload valid proof", "Complete orders successfully"]
} as const;

export function getSupplierSettlement(settlementId: string): SupplierSettlement {
  return supplierSettlementMock.settlements.find((settlement) => settlement.id === settlementId) ?? supplierSettlementMock.settlements[0];
}

export function getSettlementOutstanding(settlement: SupplierSettlement) {
  return Math.max(settlement.amountDue - settlement.amountPaid, 0);
}

export function getSettlementsByStatus(statuses: SupplierSettlementStatus[]) {
  return supplierSettlementMock.settlements.filter((settlement) => statuses.includes(settlement.status));
}
