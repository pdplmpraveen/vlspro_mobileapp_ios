import SwiftUI

struct AddElectricityBillView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var data: DataService

    // ── Property & Unit ──────────────────────────────────────────────────────
    @State private var selectedPropertyId: Int = 0
    @State private var availableUnits: [PropertyUnit] = []
    @State private var loadingUnits = false
    @State private var selectedUnitId: Int = 0

    // ── Bill Details ─────────────────────────────────────────────────────────
    @State private var bescomAccountNumber = ""
    @State private var billMonth  = Date()
    @State private var unitsConsumed = ""
    @State private var billAmount = ""
    @State private var hasDueDate = false
    @State private var dueDate    = Date()
    @State private var notes      = ""

    // ── Submission ───────────────────────────────────────────────────────────
    @State private var isSubmitting = false
    @State private var errorMessage = ""

    private var isValid: Bool {
        selectedPropertyId != 0 && selectedUnitId != 0 && !billAmount.isEmpty && (Double(billAmount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Property & Unit ──────────────────────────────────────────
                Section {
                    if data.properties.isEmpty {
                        Label("Loading properties…", systemImage: "building.2")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Property", selection: $selectedPropertyId) {
                            Text("Select property").tag(0)
                            ForEach(data.properties) { p in
                                Text(p.name).tag(p.id)
                            }
                        }
                        .onChange(of: selectedPropertyId) { id in
                            selectedUnitId = 0
                            availableUnits = []
                            bescomAccountNumber = ""
                            if id != 0 { Task { await loadUnits(id) } }
                        }
                    }

                    if selectedPropertyId != 0 {
                        if loadingUnits {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.8)
                                Text("Loading units…").foregroundColor(.secondary)
                            }
                        } else {
                            Picker("Unit", selection: $selectedUnitId) {
                                Text("Select unit").tag(0)
                                ForEach(availableUnits) { u in
                                    Text(u.displayLabel).tag(u.id)
                                }
                            }
                            .onChange(of: selectedUnitId) { id in
                                if bescomAccountNumber.isEmpty,
                                   let unit = availableUnits.first(where: { $0.id == id }),
                                   let acct = unit.bescom_account_number {
                                    bescomAccountNumber = acct
                                }
                            }
                        }
                    }
                } header: {
                    Text("Property & Unit")
                }

                // ── BESCOM & Month ───────────────────────────────────────────
                Section {
                    TextField("BESCOM Account / RR Number", text: $bescomAccountNumber)
                        .keyboardType(.numbersAndPunctuation)

                    DatePicker("Bill Month", selection: $billMonth,
                               displayedComponents: .date)

                    HStack {
                        Text("Units Consumed").foregroundColor(.primary)
                        Spacer()
                        TextField("kWh (optional)", text: $unitsConsumed)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Bill Details")
                }

                // ── Amount & Due Date ────────────────────────────────────────
                Section {
                    HStack {
                        Text("₹").foregroundColor(.secondary)
                        TextField("Bill Amount", text: $billAmount)
                            .keyboardType(.numberPad)
                    }

                    Toggle("Set Due Date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Amount")
                }

                // ── Notes ─────────────────────────────────────────────────────
                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // ── Error ────────────────────────────────────────────────────
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
            .navigationTitle("Add Electricity Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { submit() } label: {
                        if isSubmitting {
                            ProgressView().tint(Color(hex: "E67E22"))
                        } else {
                            Text("Save").bold().foregroundColor(Color(hex: "E67E22"))
                        }
                    }
                    .disabled(isSubmitting || !isValid)
                }
            }
            .onAppear {
                if data.properties.isEmpty { data.loadProperties() }
            }
        }
    }

    // ── Load units ────────────────────────────────────────────────────────────

    @MainActor
    private func loadUnits(_ propertyId: Int) async {
        loadingUnits = true
        defer { loadingUnits = false }
        do {
            availableUnits = try await data.fetchUnits(propertyId: propertyId)
        } catch {
            print("[AddElectricityBill] Units load error: \(error)")
        }
    }

    // ── Submit ────────────────────────────────────────────────────────────────

    private func submit() {
        errorMessage = ""

        let monthFmt = DateFormatter(); monthFmt.dateFormat = "yyyy-MM"
        let dateFmt  = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"

        var payload: [String: Any] = [
            "property_id": selectedPropertyId,
            "unit_id":     selectedUnitId,
            "bill_month":  monthFmt.string(from: billMonth),
            "bill_amount": Double(billAmount) ?? 0,
        ]

        if !bescomAccountNumber.isEmpty { payload["bescom_account_number"] = bescomAccountNumber }
        if let units = Int(unitsConsumed) { payload["units_consumed"] = units }
        if hasDueDate { payload["due_date"] = dateFmt.string(from: dueDate) }
        if !notes.isEmpty { payload["notes"] = notes }

        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await data.addElectricityBill(payload)
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
    AddElectricityBillView().environmentObject(DataService.shared)
}
