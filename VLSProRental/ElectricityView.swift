import SwiftUI

// Wrapper so `.sheet(item:)` always has a stable, non-nil Identifiable value
private struct BillToMarkPaid: Identifiable {
    let id: Int
    let bill: ElectricityBill
    init(_ b: ElectricityBill) { id = b.id; bill = b }
}

struct ElectricityView: View {
    @EnvironmentObject var data: DataService
    @State private var filter: String = "due"   // due | all | paid
    @State private var showAddBill = false
    @State private var billToMarkPaid: BillToMarkPaid?

    var filtered: [ElectricityBill] {
        switch filter {
        case "due":  return data.electricityBills.filter { $0.status != "paid" }
        case "paid": return data.electricityBills.filter { $0.status == "paid" }
        default:     return data.electricityBills
        }
    }

    var totalDue: Double {
        data.electricityBills.filter { $0.status != "paid" }.reduce(0) { $0 + $1.bill_amount }
    }
    var overdueCount: Int { data.electricityBills.filter { $0.status == "overdue" }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatCurrency(totalDue))
                        .font(.title2.bold()).foregroundColor(.white)
                    Text(overdueCount > 0 ? "\(overdueCount) overdue · BESCOM dues" : "BESCOM dues outstanding")
                        .font(.caption2).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.title).foregroundColor(.white.opacity(0.6))
            }
            .padding(20)
            .background(LinearGradient(colors: [Color(hex: "E67E22"), Color(hex: "F39C12")],
                                       startPoint: .leading, endPoint: .trailing))

            // Filter picker
            Picker("Filter", selection: $filter) {
                Text("Due").tag("due")
                Text("All").tag("all")
                Text("Paid").tag("paid")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.vertical, 10)
            .background(Color.white)

            if data.electricityBillsLoading && data.electricityBills.isEmpty {
                Spacer(); ProgressView("Loading bills…"); Spacer()
            } else if filtered.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 48))
                        .foregroundColor(Color(hex: "27AE60").opacity(0.6))
                    Text(filter == "paid" ? "No paid bills yet" : "No \(filter == "all" ? "" : filter) bills")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { bill in
                            ElectricityBillCard(bill: bill) {
                                billToMarkPaid = BillToMarkPaid(bill)
                            }
                        }
                    }
                    .padding(.horizontal).padding(.top, 12).padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Electricity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddBill = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color(hex: "E67E22"))
                }
            }
        }
        .onAppear { if data.electricityBills.isEmpty { data.loadElectricityBills() } }
        .refreshable { data.loadElectricityBills() }
        .sheet(isPresented: $showAddBill) {
            AddElectricityBillView().environmentObject(data)
        }
        .sheet(item: $billToMarkPaid) { item in
            MarkBillPaidSheet(bill: item.bill).environmentObject(data)
        }
    }
}

// MARK: - Card

struct ElectricityBillCard: View {
    let bill: ElectricityBill
    let onMarkPaid: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: bill.statusColor).opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: bill.statusColor))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Unit \(bill.unit_number) · \(bill.property_name)")
                        .font(.subheadline.weight(.semibold))
                    Text(bill.monthLabel + (bill.bescom_account_number.map { " · A/C \($0)" } ?? ""))
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(bill.bill_amount))
                        .font(.subheadline.bold())
                    Text(bill.statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(hex: bill.statusColor))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: bill.statusColor).opacity(0.1))
                        .cornerRadius(6)
                }
            }

            HStack(spacing: 14) {
                if let units = bill.units_consumed {
                    Label("\(units) kWh", systemImage: "gauge")
                        .font(.caption2).foregroundColor(.secondary)
                }
                if let due = bill.due_date {
                    Label("Due \(shortDate(due))", systemImage: "calendar")
                        .font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
            }

            if bill.status != "paid" {
                HStack(spacing: 10) {
                    if let link = bill.upi_pay_link, let url = URL(string: link) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Pay via UPI", systemImage: "indianrupeesign.circle.fill")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "27AE60"))
                    } else {
                        Text("No UPI ID set for owner")
                            .font(.caption2).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        onMarkPaid()
                    } label: {
                        Text("Mark Paid")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color(hex: "2E6DB4"))
                }
            } else if let paidDate = bill.paid_date {
                Text("Paid \(shortDate(paidDate))" + (bill.payment_mode.map { " via \($0.uppercased())" } ?? ""))
                    .font(.caption2).foregroundColor(Color(hex: "27AE60"))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 5, y: 1)
    }

    func shortDate(_ str: String) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: str) else { return str }
        let out = DateFormatter(); out.dateFormat = "dd MMM yy"
        return out.string(from: d)
    }
}

// MARK: - Mark Paid Sheet

struct MarkBillPaidSheet: View {
    let bill: ElectricityBill
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var data: DataService

    @State private var paymentMode  = "upi"
    @State private var transactionId = ""
    @State private var paidDate     = Date()
    @State private var isSubmitting = false
    @State private var errorMessage = ""

    private let modes: [(String, String)] = [
        ("upi",           "UPI"),
        ("cash",          "Cash"),
        ("bank_transfer", "Bank Transfer"),
        ("cheque",        "Cheque"),
    ]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    LabeledContent("Unit", value: "\(bill.unit_number) · \(bill.property_name)")
                    LabeledContent("Month", value: bill.monthLabel)
                    HStack {
                        Text("Amount").foregroundColor(.primary)
                        Spacer()
                        Text(formatCurrency(bill.bill_amount)).bold()
                    }
                } header: {
                    Text("Bill")
                }

                Section {
                    Picker("Payment Mode", selection: $paymentMode) {
                        ForEach(modes, id: \.0) { raw, label in
                            Text(label).tag(raw)
                        }
                    }
                    TextField("Transaction ID / UPI Ref (optional)", text: $transactionId)
                    DatePicker("Paid Date", selection: $paidDate, in: ...Date(), displayedComponents: .date)
                } header: {
                    Text("Confirm Payment")
                }

                if !errorMessage.isEmpty {
                    Section {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                            Text(errorMessage).font(.caption).foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Mark as Paid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { submit() } label: {
                        if isSubmitting {
                            ProgressView().tint(Color(hex: "27AE60"))
                        } else {
                            Text("Confirm").bold().foregroundColor(Color(hex: "27AE60"))
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() {
        errorMessage = ""
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await data.payElectricityBill(
                    id: bill.id,
                    paymentMode: paymentMode,
                    transactionId: transactionId,
                    paidDate: fmt.string(from: paidDate)
                )
                data.loadElectricityBills()
                dismiss()
            } catch APIError.serverError(let msg) {
                errorMessage = msg
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationView { ElectricityView().environmentObject(DataService.shared) }
}
