export const sampleSettlements = [
  {
    id: "SET-8842",
    supplier: "KNUST Gadgets",
    status: "Settlement Due",
    dueAmount: "GH₵40",
    platformMargin: "GH₵10",
    resellerCommission: "GH₵30",
    dueDate: "15 May 2025"
  },
  {
    id: "SET-8799",
    supplier: "Beauty Central GH",
    status: "Settlement Overdue",
    dueAmount: "GH₵52",
    platformMargin: "GH₵12",
    resellerCommission: "GH₵40",
    dueDate: "12 May 2025"
  }
];

export const sampleCommissions = [
  {
    id: "COM-8842",
    reseller: "Kofi Mensah",
    status: "Commission Pending",
    amount: "GH₵30",
    source: "Nike Air Force 1 '07"
  },
  {
    id: "COM-8799",
    reseller: "Ama Reseller",
    status: "Available",
    amount: "GH₵40",
    source: "The Ordinary Skincare Set"
  }
];

export const sampleWallet = {
  availableBalance: "Available Balance GH₵240",
  pendingCommission: "GH₵320",
  totalEarned: "GH₵1,250"
};
