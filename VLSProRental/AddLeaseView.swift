import SwiftUI

struct AddLeaseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var data: DataService

    // ── Property & Unit ──────────────────────────────────────────────────────
    @State private var selectedPropertyId: Int = 0
    @State private var availableUnits: [PropertyUnit] = []
    @State private var loadingUnits   = false
    @State private var selectedUnitId: Int = 0

    // ── Tenant ───────────────────────────────────────────────────────────────
    @State private var useExistingTenant = true
    @State private var selectedTenantId: Int = 0
    @State private var newName  = ""
    @State private var newPhone = ""
    @State private var newEmail = ""

    // ── Lease Terms ──────────────────────────────────────────────────────────
    @State private var monthlyRent  = ""
    @State private var depositPaid  = ""
    @State private var startDate    = Date()
    @State private var hasEndDate   = true
    @State private var endDate: Date = {
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }()
    @State private var noticePeriod      = "30"
    @State private var rentIncrementPct  = ""

    // ── State ────────────────────────────────────────────────────────────────
    @State private var isSubmitting  = false
    @State private var errorMessage  = ""

    private var activeTenants: [Tenant] {
        data.tenants.filter { $0.is_active }
    }

    private var isValid: Bool {
        guard selectedPropertyId != 0, selectedUnitId != 0,
              !monthlyRent.isEmpty, Double(monthlyRent) != nil else { return false }
        if useExistingTenant { return selectedTenantId != 0 }
        return !newName.isEmpty && !newPhone.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Property & Unit ──────────────────────────────────────────
                Section {
                    if data.properties.isEmpty {
                        Label("Loading properties…", systemImage: "building.2").foregroundColor(.secondary)
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
                            monthlyRent = ""
                            if id != 0 { Task { await loadUnits(id) } }
                        }
                    }

                    if selectedPropertyId != 0 {
                        if loadingUnits {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.8)
                                Text("Loading units…").foregroundColor(.secondary)
                            }
                        } else if availableUnits.isEmpty {
                            Text("No units found for this property.")
                                .foregroundColor(.secondary).font(.caption)
                        } else {
                            Picker("Unit", selection: $selectedUnitId) {
                                Text("Select unit").tag(0)
                                ForEach(availableUnits) { u in
                                    Text(u.displayLabel).tag(u.id)
                                }
                            }
                            .onChange(of: selectedUnitId) { id in
                                if let u = availableUnits.first(where: { $0.id == id }),
                                   monthlyRent.isEmpty {
                                    monthlyRent = "\(Int(u.monthly_rent))"
                                }
                            }
                        }
                    }
                } header: {
                    Text("Property & Unit")
                }

                // ── Tenant ───────────────────────────────────────────────────
                Section {
                    Picker("", selection: $useExistingTenant) {
                        Text("Existing Tenant").tag(true)
                        Text("New Tenant").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    if useExistingTenant {
                        if activeTenants.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No active tenants found.").foregroundColor(.secondary)
                                Text("Switch to 'New Tenant' to add one.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        } else {
                            Picker("Select Tenant", selection: $selectedTenantId) {
                                Text("Select tenant").tag(0)
                                ForEach(activeTenants) { t in
                                    Text("\(t.name) · \(t.phone)").tag(t.id)
                                }
                            }
                        }
                    } else {
                        TextField("Full Name *", text: $newName)
                        TextField("Phone Number *", text: $newPhone)
                            .keyboardType(.phonePad)
                        TextField("Email (optional)", text: $newEmail)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                } header: {
                    Text("Tenant")
                }

                // ── Lease Terms ──────────────────────────────────────────────
                Section {
                    HStack {
                        Text("₹").foregroundColor(.secondary)
                        TextField("Monthly Rent *", text: $monthlyRent)
                            .keyboardType(.numberPad)
                    }

                    HStack {
                        Text("₹").foregroundColor(.secondary)
                        TextField("Security Deposit", text: $depositPaid)
                            .keyboardType(.numberPad)
                    }

                    DatePicker("Start Date", selection: $startDate,
                               displayedComponents: .date)

                    Toggle("Has End Date", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate,
                                   in: startDate..., displayedComponents: .date)
                    }
                } header: {
                    Text("Lease Terms")
                }

                // ── Optional Settings ────────────────────────────────────────
                Section {
                    HStack {
                        Text("Notice Period (days)")
                        Spacer()
                        TextField("30", text: $noticePeriod)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }

                    HStack {
                        Text("Annual Rent Increase %")
                        Spacer()
                        TextField("0", text: $rentIncrementPct)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }
                } header: {
                    Text("Optional")
                }

                // ── Error ────────────────────────────────────────────────────
                if !errorMessage.isEmpty {
                    Section {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                            Text(errorMessage).font(.caption).foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("New Lease")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { submit() } label: {
                        if isSubmitting {
                            ProgressView().tint(Color(hex: "8E44AD"))
                        } else {
                            Text("Save").bold().foregroundColor(Color(hex: "8E44AD"))
                        }
                    }
                    .disabled(isSubmitting || !isValid)
                }
            }
            .onAppear {
                if data.properties.isEmpty { data.loadProperties() }
                if data.tenants.isEmpty    { data.loadTenants()    }
            }
        }
    }

    // ── Load units for selected property ─────────────────────────────────────

    @MainActor
    private func loadUnits(_ propertyId: Int) async {
        loadingUnits = true
        defer { loadingUnits = false }
        do {
            availableUnits = try await data.fetchUnits(propertyId: propertyId)
        } catch {
            print("[AddLease] Units load error: \(error)")
        }
    }

    // ── Submit ────────────────────────────────────────────────────────────────

    private func submit() {
        errorMessage = ""
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"

        var payload: [String: Any] = [
            "property_id":  selectedPropertyId,
            "unit_id":      selectedUnitId,
            "monthly_rent": Double(monthlyRent) ?? 0,
            "deposit_paid": Double(depositPaid) ?? 0,
            "start_date":   fmt.string(from: startDate),
        ]

        if hasEndDate { payload["end_date"] = fmt.string(from: endDate) }
        if let np = Int(noticePeriod),      np > 0  { payload["notice_period"]      = np }
        if let ri = Double(rentIncrementPct), ri > 0 { payload["rent_increment_pct"] = ri }

        if useExistingTenant {
            payload["tenant_id"] = selectedTenantId
        } else {
            payload["new_tenant_name"]  = newName
            payload["new_tenant_phone"] = newPhone
            payload["new_tenant_email"] = newEmail
        }

        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await data.addLease(payload)
                data.loadLeases()
                data.loadTenants()
                data.loadProperties()   // refresh occupancy counts
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
    AddLeaseView().environmentObject(DataService.shared)
}
