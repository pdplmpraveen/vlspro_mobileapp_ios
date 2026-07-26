import SwiftUI

struct DamagesView: View {
    @EnvironmentObject var data: DataService
    @State private var filter: String = "open"   // open | all | resolved
    @State private var showAddDamage = false

    var filtered: [Damage] {
        switch filter {
        case "open":     return data.damages.filter { $0.status != "resolved" }
        case "resolved": return data.damages.filter { $0.status == "resolved" }
        default:         return data.damages
        }
    }

    var totalCost: Double { filtered.reduce(0) { $0 + $1.repair_cost } }

    var body: some View {
        VStack(spacing: 0) {
            // Banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(filtered.count) \(filter == "all" ? "" : filter) report\(filtered.count == 1 ? "" : "s")")
                        .font(.caption).foregroundColor(.white.opacity(0.8))
                    Text(formatCurrency(totalCost))
                        .font(.title2.bold()).foregroundColor(.white)
                    Text("Estimated repair cost").font(.caption2).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title).foregroundColor(.white.opacity(0.6))
            }
            .padding(20)
            .background(LinearGradient(colors: [Color(hex: "8E44AD"), Color(hex: "9B59B6")],
                                       startPoint: .leading, endPoint: .trailing))

            // Filter picker
            Picker("Filter", selection: $filter) {
                Text("Open").tag("open")
                Text("All").tag("all")
                Text("Resolved").tag("resolved")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.vertical, 10)
            .background(Color.white)

            if data.damagesLoading && data.damages.isEmpty {
                Spacer(); ProgressView("Loading damages…"); Spacer()
            } else if filtered.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill").font(.system(size: 48))
                        .foregroundColor(Color(hex: "27AE60").opacity(0.6))
                    Text("No \(filter == "all" ? "" : filter) damage reports")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { damage in
                            DamageCard(damage: damage)
                        }
                    }
                    .padding(.horizontal).padding(.top, 12).padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Damages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddDamage = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color(hex: "8E44AD"))
                }
            }
        }
        .onAppear { if data.damages.isEmpty { data.loadDamages() } }
        .refreshable { data.loadDamages() }
        .sheet(isPresented: $showAddDamage) {
            AddDamageView().environmentObject(data)
        }
    }
}

struct DamageCard: View {
    let damage: Damage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: damage.statusColor).opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: damage.damageIcon)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: damage.statusColor))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(damage.damage_type.capitalized)
                        .font(.subheadline.weight(.semibold))
                    Text(damage.description)
                        .font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(damage.repair_cost))
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: "E74C3C"))
                    Text(damage.statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(hex: damage.statusColor))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: damage.statusColor).opacity(0.1))
                        .cornerRadius(6)
                }
            }

            HStack(spacing: 14) {
                Label(damage.property_name, systemImage: "building.2")
                    .font(.caption).foregroundColor(.secondary)
                if let unit = damage.unit_number {
                    Label("Unit \(unit)", systemImage: "door.left.hand.closed")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Label(shortDate(damage.reported_date), systemImage: "calendar")
                    .font(.caption2).foregroundColor(.secondary)
            }

            if let tenant = damage.tenant_name {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill").font(.caption2).foregroundColor(.secondary)
                    Text("Reported by \(tenant)").font(.caption2).foregroundColor(.secondary)
                    if damage.deducted_from_deposit > 0 {
                        Spacer()
                        Text("Deducted: \(formatCurrency(damage.deducted_from_deposit))")
                            .font(.caption2).foregroundColor(Color(hex: "E67E22"))
                    }
                }
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

#Preview {
    NavigationView { DamagesView().environmentObject(DataService.shared) }
}
