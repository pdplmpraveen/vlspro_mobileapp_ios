import SwiftUI

// MARK: - Damage type data

private struct DamageType: Identifiable {
    let id: String       // raw value sent to API
    let label: String
    let icon: String
}

private let damageTypes: [DamageType] = [
    .init(id: "plumbing",     label: "Plumbing",     icon: "drop.fill"),
    .init(id: "electrical",   label: "Electrical",   icon: "bolt.fill"),
    .init(id: "structural",   label: "Structural",   icon: "building.2.crop.circle"),
    .init(id: "painting",     label: "Painting",     icon: "paintbrush.fill"),
    .init(id: "appliance",    label: "Appliance",    icon: "washer.fill"),
    .init(id: "water_damage", label: "Water Damage", icon: "cloud.rain.fill"),
    .init(id: "pest",         label: "Pest",         icon: "ant.fill"),
    .init(id: "door_window",  label: "Door/Window",  icon: "door.left.hand.open"),
    .init(id: "flooring",     label: "Flooring",     icon: "square.grid.3x3.fill"),
    .init(id: "other",        label: "Other",        icon: "exclamationmark.triangle.fill"),
]

// MARK: - View

struct AddDamageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var data: DataService

    // ── Property & Unit ──────────────────────────────────────────────────────
    @State private var selectedPropertyId: Int = 0
    @State private var availableUnits: [PropertyUnit] = []
    @State private var loadingUnits = false
    @State private var selectedUnitId: Int = 0     // 0 = "None / whole property"

    // ── Tenant ───────────────────────────────────────────────────────────────
    @State private var selectedTenantId: Int = 0   // 0 = no specific tenant

    // ── Damage Details ───────────────────────────────────────────────────────
    @State private var selectedType  = "plumbing"
    @State private var descriptionText = ""
    @State private var reportedDate  = Date()
    @State private var repairCost    = ""
    @State private var deductedFromDeposit = ""

    // ── Status ───────────────────────────────────────────────────────────────
    @State private var status = "reported"

    // ── Submission ───────────────────────────────────────────────────────────
    @State private var isSubmitting  = false
    @State private var errorMessage  = ""

    private var activeTenants: [Tenant] {
        data.tenants.filter { $0.is_active }
    }

    private var isValid: Bool {
        selectedPropertyId != 0 && !descriptionText.isEmpty
    }

    // Status display helper
    private let statusOptions = [
        ("reported",    "Reported"),
        ("in_progress", "In Progress"),
        ("resolved",    "Resolved"),
    ]

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
                            Picker("Unit (optional)", selection: $selectedUnitId) {
                                Text("Whole property / common area").tag(0)
                                ForEach(availableUnits) { u in
                                    Text(u.displayLabel).tag(u.id)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Property & Unit")
                }

                // ── Tenant ───────────────────────────────────────────────────
                Section {
                    Picker("Tenant (optional)", selection: $selectedTenantId) {
                        Text("None / Unknown").tag(0)
                        ForEach(activeTenants) { t in
                            Text("\(t.name) · \(t.phone)").tag(t.id)
                        }
                    }
                } header: {
                    Text("Tenant")
                }

                // ── Damage Type ──────────────────────────────────────────────
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                              spacing: 10) {
                        ForEach(damageTypes) { type in
                            DamageTypeButton(
                                type: type,
                                isSelected: selectedType == type.id
                            ) {
                                selectedType = type.id
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Damage Type")
                }

                // ── Description & Date ───────────────────────────────────────
                Section {
                    TextField("Describe the damage…", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)

                    DatePicker("Date Reported", selection: $reportedDate,
                               in: ...Date(), displayedComponents: .date)
                } header: {
                    Text("Details")
                }

                // ── Costs ────────────────────────────────────────────────────
                Section {
                    HStack {
                        Text("₹").foregroundColor(.secondary)
                        TextField("Estimated Repair Cost", text: $repairCost)
                            .keyboardType(.numberPad)
                    }

                    HStack {
                        Text("₹").foregroundColor(.secondary)
                        TextField("Deducted from Deposit", text: $deductedFromDeposit)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text("Costs")
                } footer: {
                    Text("Leave blank if unknown. You can update these later.")
                }

                // ── Status ───────────────────────────────────────────────────
                Section {
                    Picker("Status", selection: $status) {
                        ForEach(statusOptions, id: \.0) { raw, label in
                            Text(label).tag(raw)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("Status")
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
            .navigationTitle("Report Damage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { submit() } label: {
                        if isSubmitting {
                            ProgressView().tint(Color(hex: "E74C3C"))
                        } else {
                            Text("Save").bold().foregroundColor(Color(hex: "E74C3C"))
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

    // ── Load units ────────────────────────────────────────────────────────────

    @MainActor
    private func loadUnits(_ propertyId: Int) async {
        loadingUnits = true
        defer { loadingUnits = false }
        do {
            availableUnits = try await data.fetchUnits(propertyId: propertyId)
        } catch {
            print("[AddDamage] Units load error: \(error)")
        }
    }

    // ── Submit ────────────────────────────────────────────────────────────────

    private func submit() {
        errorMessage = ""
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"

        var payload: [String: Any] = [
            "property_id":   selectedPropertyId,
            "damage_type":   selectedType,
            "description":   descriptionText,
            "reported_date": fmt.string(from: reportedDate),
            "status":        status,
            "repair_cost":              Double(repairCost)             ?? 0,
            "deducted_from_deposit":    Double(deductedFromDeposit)    ?? 0,
        ]

        if selectedUnitId  != 0 { payload["unit_id"]   = selectedUnitId  }
        if selectedTenantId != 0 { payload["tenant_id"] = selectedTenantId }

        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await data.addDamage(payload)
                data.loadDamages()
                dismiss()
            } catch APIError.serverError(let msg) {
                errorMessage = msg
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Damage type grid button

private struct DamageTypeButton: View {
    let type: DamageType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : Color(hex: "E74C3C"))
                Text(type.label)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(isSelected ? Color(hex: "E74C3C") : Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddDamageView().environmentObject(DataService.shared)
}
