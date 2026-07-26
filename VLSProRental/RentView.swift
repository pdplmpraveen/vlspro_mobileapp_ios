import SwiftUI

// Wrapper so `.sheet(item:)` always has a stable, non-nil Identifiable value
private struct PaymentToRecord: Identifiable {
    let id: String
    let payment: Payment
    init(_ p: Payment) { id = p.listId; payment = p }
}

struct RentView: View {
    @EnvironmentObject var data: DataService
    @State private var paymentToRecord: PaymentToRecord?

    var paid: [Payment]   { data.payments.filter { $0.status == "paid" } }
    var pending: [Payment] { data.payments.filter { $0.status != "paid" } }
    var totalCollected: Double { paid.reduce(0) { $0 + $1.amount_paid } }
    var totalPending: Double   { pending.reduce(0) { $0 + $1.rent_amount } }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month scroller
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(lastSixMonths(), id: \.self) { ym in
                            Button {
                                data.selectedMonth = ym
                                data.loadPayments(month: ym)
                            } label: {
                                Text(monthYMToLabel(ym))
                                    .font(.subheadline.weight(data.selectedMonth == ym ? .semibold : .regular))
                                    .foregroundColor(data.selectedMonth == ym ? .white : Color(hex: "2E6DB4"))
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(data.selectedMonth == ym
                                                ? Color(hex: "2E6DB4")
                                                : Color(hex: "2E6DB4").opacity(0.1))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 12)
                }

                // Summary strip
                HStack(spacing: 0) {
                    SummaryPill(label: "Collected", amount: totalCollected, color: Color(hex: "27AE60"))
                    Divider().frame(height: 40)
                    SummaryPill(label: "Pending",   amount: totalPending,   color: Color(hex: "E74C3C"))
                }
                .background(Color.white).cornerRadius(14)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                .padding(.horizontal).padding(.bottom, 12)

                if data.paymentsLoading && data.payments.isEmpty {
                    Spacer()
                    ProgressView("Loading payments…")
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if !pending.isEmpty {
                                sectionLabel("Pending / Overdue", color: Color(hex: "E74C3C"))
                                ForEach(pending, id: \.listId) { p in
                                    RentPaymentCard(payment: p) {
                                        paymentToRecord = PaymentToRecord(p)
                                    }
                                }
                            }
                            if !paid.isEmpty {
                                sectionLabel("Paid", color: Color(hex: "27AE60"))
                                ForEach(paid, id: \.listId) { p in
                                    RentPaymentCard(payment: p, onMarkPaid: nil)
                                }
                            }
                            if data.payments.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "tray").font(.system(size: 40))
                                        .foregroundColor(.secondary.opacity(0.4))
                                    Text("No records for \(monthYMToLabel(data.selectedMonth))")
                                        .foregroundColor(.secondary)
                                }.frame(maxWidth: .infinity).padding(.top, 60)
                            }
                        }
                        .padding(.horizontal).padding(.bottom, 24)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Rent Collection")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { data.loadPayments() }
            .refreshable { data.loadPayments() }
            .sheet(item: $paymentToRecord) { item in
                RecordPaymentSheet(payment: item.payment)
                    .environmentObject(data)
            }
        }
    }

    func sectionLabel(_ text: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption.weight(.semibold)).foregroundColor(color)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }
}

struct SummaryPill: View {
    let label: String; let amount: Double; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(formatCurrency(amount)).font(.title3.bold()).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
    }
}

struct RentPaymentCard: View {
    let payment: Payment
    let onMarkPaid: (() -> Void)?

    var statusColor: Color {
        switch payment.status {
        case "paid":    return Color(hex: "27AE60")
        case "partial": return Color(hex: "E67E22")
        default:        return Color(hex: "E74C3C")
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(payment.tenant_name).font(.subheadline.weight(.semibold))
                Text("Unit \(payment.unit_number) · \(payment.property_name)")
                    .font(.caption).foregroundColor(.secondary)
                if let date = payment.payment_date {
                    Text("Paid \(date) via \(payment.payment_mode ?? "")")
                        .font(.caption2).foregroundColor(.secondary)
                }
                if payment.balance > 0 && payment.amount_paid > 0 {
                    Text("Balance: \(formatCurrency(payment.balance))")
                        .font(.caption2).foregroundColor(Color(hex: "E74C3C"))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(formatCurrency(payment.status == "paid" ? payment.amount_paid : payment.rent_amount))
                    .font(.subheadline.bold())
                if let action = onMarkPaid, payment.status != "paid" {
                    Button("Record", action: action)
                        .font(.caption.weight(.semibold)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color(hex: "2E6DB4")).cornerRadius(8)
                } else if payment.status == "paid" {
                    Text("Paid ✓").font(.caption.weight(.semibold))
                        .foregroundColor(Color(hex: "27AE60"))
                }
            }
        }
        .padding(16).background(Color.white).cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 5, y: 1)
    }
}

// MARK: - Record Payment Sheet (native form)

struct RecordPaymentSheet: View {
    let payment: Payment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var data: DataService

    @State private var amountText    = ""
    @State private var paymentMode   = "upi"
    @State private var paymentDate   = Date()
    @State private var notes         = ""
    @State private var isSubmitting  = false
    @State private var errorMessage  = ""

    private let modes: [(String, String)] = [
        ("cash",          "Cash"),
        ("upi",           "UPI"),
        ("bank_transfer", "Bank Transfer"),
        ("cheque",        "Cheque"),
        ("neft",          "NEFT / RTGS"),
    ]

    var body: some View {
        NavigationView {
            Form {
                // ── Summary (read-only) ──────────────────────────────────────
                Section {
                    LabeledRow(label: "Tenant",   value: payment.tenant_name)
                    LabeledRow(label: "Unit",     value: "Unit \(payment.unit_number) · \(payment.property_name)")
                    LabeledRow(label: "Month",    value: monthYMToLabel(payment.payment_month))
                    HStack {
                        Text("Rent Due").foregroundColor(.primary)
                        Spacer()
                        Text(formatCurrency(payment.rent_amount))
                            .foregroundColor(Color(hex: "E74C3C")).bold()
                    }
                } header: {
                    Text("Payment For")
                }

                // ── Payment details ──────────────────────────────────────────
                Section {
                    HStack {
                        Text("₹").foregroundColor(.secondary)
                        TextField("Amount Paid", text: $amountText)
                            .keyboardType(.numberPad)
                    }

                    Picker("Payment Mode", selection: $paymentMode) {
                        ForEach(modes, id: \.0) { raw, label in
                            Text(label).tag(raw)
                        }
                    }

                    DatePicker("Payment Date", selection: $paymentDate,
                               in: ...Date(), displayedComponents: .date)
                } header: {
                    Text("Record Payment")
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if !errorMessage.isEmpty {
                    Section {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage).font(.caption).foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Record Payment")
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
                            Text("Save").bold().foregroundColor(Color(hex: "27AE60"))
                        }
                    }
                    .disabled(isSubmitting || amountText.isEmpty)
                }
            }
            .onAppear {
                amountText = "\(Int(payment.rent_amount))"
            }
        }
    }

    private func submit() {
        errorMessage = ""
        guard let amount = Double(amountText), amount > 0 else {
            errorMessage = "Please enter a valid amount."
            return
        }

        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let payload: [String: Any] = [
            "tenant_id":    payment.tenant_id,
            "property_id":  payment.property_id,
            "unit_id":      payment.unit_id,
            "amount_paid":  amount,
            "rent_amount":  payment.rent_amount,
            "payment_mode": paymentMode,
            "payment_date": fmt.string(from: paymentDate),
            "notes":        notes,
        ]

        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await data.addPayment(payload)
                data.loadPayments()
                data.loadDashboard()
                dismiss()
            } catch APIError.serverError(let msg) {
                errorMessage = msg
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct LabeledRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.primary)
            Spacer()
            Text(value).foregroundColor(.secondary).font(.subheadline)
        }
    }
}

private func lastSixMonths() -> [String] {
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM"
    let cal = Calendar.current
    return (0..<6).compactMap { cal.date(byAdding: .month, value: -$0, to: Date()) }.map { fmt.string(from: $0) }
}

#Preview {
    RentView().environmentObject(DataService.shared)
}
