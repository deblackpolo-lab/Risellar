import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import {
  AdminDisputeDetailScreen,
  AdminDisputesScreen,
  AdminRefundDetailScreen,
  AdminRefundsScreen,
  AdminReturnDetailScreen,
  AdminReturnsScreen,
  AdminSupportInboxScreen,
  AdminSupportTicketDetailScreen,
  AdminSupportTicketsScreen,
  CustomerDisputeDetailScreen,
  CustomerRefundStatusScreen,
  CustomerReportIssueScreen,
  CustomerReturnRequestScreen,
  CustomerSupportCenterScreen,
  CustomerSupportTicketDetailScreen,
  CustomerSupportTicketsScreen,
  ResellerCommissionDisputeDetailScreen,
  ResellerMissingCommissionScreen,
  ResellerSupportCenterScreen,
  ResellerSupportTicketDetailScreen,
  ResellerSupportTicketsScreen,
  SupplierReturnsScreen,
  SupplierSettlementDisputeDetailScreen,
  SupplierSettlementDisputeScreen,
  SupplierSupportCenterScreen,
  SupplierSupportTicketDetailScreen,
  SupplierSupportTicketsScreen
} from "@/components/support/support-disputes-screens";

describe("Phase 13 support, disputes, returns, and refunds", () => {
  it("renders customer support center, tickets, ticket detail, report issue, returns, refund, and dispute detail", () => {
    const { rerender } = render(<CustomerSupportCenterScreen />);

    expect(screen.getByRole("heading", { name: "Support Center" })).toBeInTheDocument();
    for (const text of [
      "Ghana-friendly support for orders, delivery, Pay on Delivery, returns, and refunds.",
      "Report an order issue",
      "Track support tickets",
      "Return or refund help",
      "Do not share your MoMo PIN, card PIN, or password with anyone."
    ]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<CustomerSupportTicketsScreen />);
    for (const text of ["My Support Tickets", "TKT-RSR-20260713-00021", "Wrong product received", "Evidence Requested", "DSP-RSR-20260713-00021"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<CustomerSupportTicketDetailScreen ticketId="tkt-rsr-20260713-00021" />);
    for (const text of ["Wrong product received", "Ticket timeline", "Evidence requested", "Support reply composer", "No message is sent in this frontend phase."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<CustomerReportIssueScreen id="rsr-20260713-00021" />);
    for (const text of [
      "Report Issue",
      "Wrong product",
      "Damaged product",
      "Product not received",
      "Evidence upload placeholder",
      "Submit Issue Mock",
      "Issue Submitted"
    ]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<CustomerReturnRequestScreen id="rsr-20260713-00021" />);
    for (const text of ["Return Request", "Return Requested", "Shoes and clothing", "Return Under Review", "Submit Return Request Mock"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<CustomerRefundStatusScreen id="rsr-20260713-00021" />);
    for (const text of ["Refund Status", "Refund Pending", "Pay on Delivery refunds may be manual or off-platform.", "Expected refund", "GH₵385"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<CustomerDisputeDetailScreen disputeId="dsp-rsr-20260713-00021" />);
    for (const text of ["Dispute Detail", "Under Review", "Dispute timeline", "Evidence placeholders", "Resolution updates", "Customer view hides supplier base price and reseller commission."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
  });

  it("renders reseller support, tickets, missing commission flow, and commission dispute detail", () => {
    const { rerender } = render(<ResellerSupportCenterScreen />);

    for (const text of ["Reseller Support", "Missing commission", "Commission disputes", "Pending commission is not withdrawable until supplier settlement is verified."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<ResellerSupportTicketsScreen />);
    for (const text of ["Reseller Support Tickets", "TKT-COMMISSION-RSR-20260713-00021", "Missing commission after delivery", "Waiting for Supplier"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<ResellerSupportTicketDetailScreen ticketId="tkt-commission-rsr-20260713-00021" />);
    for (const text of ["Missing commission after delivery", "Commission impact", "GH₵30", "Awaiting supplier settlement verification"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<ResellerMissingCommissionScreen />);
    for (const text of ["Missing Commission", "Order settlement not verified", "Dispute is open", "Order cancelled or returned", "Settlement overdue", "Submit Commission Check Mock"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<ResellerCommissionDisputeDetailScreen disputeId="cmd-rsr-20260713-00021" />);
    for (const text of ["Commission Dispute", "CMD-RSR-20260713-00021", "Commission remains pending", "Supplier settlement must be verified before release."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
  });

  it("renders supplier support, tickets, settlement dispute, and returns management", () => {
    const { rerender } = render(<SupplierSupportCenterScreen />);

    for (const text of ["Supplier Support", "Settlement dispute", "Returns from customers", "No real payout, settlement, or upload integration is connected."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<SupplierSupportTicketsScreen />);
    for (const text of ["Supplier Support Tickets", "TKT-SETTLEMENT-RSR-20260713-00021", "Payment proof waiting for review", "Waiting for Admin"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<SupplierSupportTicketDetailScreen ticketId="tkt-settlement-rsr-20260713-00021" />);
    for (const text of ["Payment proof waiting for review", "Settlement impact", "GH₵40", "Proof verification is mock-only."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<SupplierSettlementDisputeScreen />);
    for (const text of ["Settlement Dispute", "Settlement proof dispute", "Evidence upload placeholder", "Reference number", "Submit Settlement Dispute Mock"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<SupplierSettlementDisputeDetailScreen disputeId="sdp-rsr-20260713-00021" />);
    for (const text of ["Supplier Settlement Dispute", "SDP-RSR-20260713-00021", "Settlement remains disputed", "Admin finance verification required."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<SupplierReturnsScreen />);
    for (const text of ["Supplier Returns", "Return Approved", "Returned to Supplier", "Inspect returned item", "Restock only after review"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
  });

  it("renders admin support inbox, disputes, returns, refunds, and detail resolution tools", () => {
    const { rerender } = render(<AdminSupportInboxScreen />);

    for (const text of ["Admin Support Inbox", "Open tickets", "High priority", "Assigned to me", "SLA watch"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<AdminSupportTicketsScreen />);
    for (const text of ["Support Tickets", "Ticket", "Party", "Priority", "Status", "Owner", "TKT-RSR-20260713-00021"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<AdminSupportTicketDetailScreen ticketId="tkt-rsr-20260713-00021" />);
    for (const text of ["Support Ticket Detail", "Internal notes", "Resolution panel", "Audit preview", "Request Evidence"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<AdminDisputesScreen />);
    for (const text of ["Disputes", "Wrong product", "Missing reseller commission", "Settlement proof dispute", "Escalated"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<AdminDisputeDetailScreen disputeId="dsp-rsr-20260713-00021" />);
    for (const text of ["Admin Dispute Detail", "Commission impact", "Settlement impact", "Evidence review", "Resolve Dispute Mock", "No real refund or commission release is connected."]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<AdminReturnsScreen />);
    for (const text of ["Returns", "Return Requested", "Return Under Review", "Returned to Supplier", "RTN-RSR-20260713-00021"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<AdminReturnDetailScreen returnId="rtn-rsr-20260713-00021" />);
    for (const text of ["Return Detail", "Approve Return Mock", "Reject Return Mock", "Returned item inspection", "Refund link"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<AdminRefundsScreen />);
    for (const text of ["Refunds", "Refund Pending", "Refund Completed", "Manual Pay on Delivery refund", "RFD-RSR-20260713-00021"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }

    rerender(<AdminRefundDetailScreen refundId="rfd-rsr-20260713-00021" />);
    for (const text of ["Refund Detail", "Pay on Delivery refunds may be manual/off-platform.", "Mark Refund Completed Mock", "Reject Refund Mock", "Audit preview"]) {
      expect(screen.getAllByText(text).length).toBeGreaterThan(0);
    }
  });
});
