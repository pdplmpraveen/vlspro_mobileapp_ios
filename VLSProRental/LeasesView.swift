import SwiftUI

struct LeasesView: View {
    @EnvironmentObject var data: DataService
    @State private var filter: String = "active"   // active | all | expired
    @State private var showAddLease = false

    var filtered: [Lease] {
        switch filter {
        case "active":  return data.leases.filter { $0.status == "active" }
        case "expired": return data.leases.filter { $0.status != "active" }
        default:        return data.leases
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter picker
            Picker("Filter", selection: $filter) {
                Text("Active").tag("active")
                Text("All").tag("all")
                Text("Expired").tag("expired")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.vertical, 10)
            .background(Color.white)

            if data.leasesLoading && data.leases.isEmpty {
                Spacer()
                ProgressView("Loading leases…")
                Spacer()
            } else if let err = data.leasesError {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Failed to load leases")
                        .font(.headline)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Retry") { data.loadLeases() }
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "doc.text").font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No \(filter == "all" ? "" : filter) leases").foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { lease in
                            LeaseCard(lease: lease)
                        }
                    }
                    .padding(.horizontal).padding(.top, 12).padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Leases (\(filtered.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddLease = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color(hex: "2E6DB4"))
                }
            }
        }
        .onAppear { if data.leases.isEmpty { data.loadLeases() } }
        .refreshable { data.loadLeases() }
        .sheet(isPresented: $showAddLease) {
            AddLeaseView().environmentObject(data)
        }
    }
}

struct LeaseCard: View {
    let lease: Lease

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: lease.statusColor).opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: lease.statusColor))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(lease.tenant_name).font(.subheadline.weight(.semibold))
                    Text("Unit \(lease.unit_number) · \(lease.property_name)")
                        .font(.caption).foregroundColor(.secondary)
                    if let phone = lease.phone, !phone.isEmpty {
                        Text(phone).font(.caption2).foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(lease.monthly_rent))
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: "1A3A6B"))
                    Text("/month").font(.caption2).foregroundColor(.secondary)
                    Text(lease.statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(hex: lease.statusColor))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: lease.statusColor).opacity(0.1))
                        .cornerRadius(6)
                }
            }

            Divider()

            // Dates + deposit
            HStack(spacing: 0) {
                LeaseInfoCell(icon: "calendar", label: "Start", value: formatLeaseDate(lease.start_date))
                Divider().frame(height: 34)
                LeaseInfoCell(icon: "calendar.badge.clock",
                              label: "End",
                              value: lease.end_date.map { formatLeaseDate($0) } ?? "Open")
                Divider().frame(height: 34)
                LeaseInfoCell(icon: "lock.fill",
                              label: "Deposit",
                              value: formatCurrency(lease.deposit_paid))
            }

            // Expiry warning
            if let days = lease.daysUntilExpiry, lease.isActive {
                if days <= 30 {
                    HStack(spacing: 6) {
                        Image(systemName: days < 0 ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text(days < 0
                             ? "Expired \(abs(days)) days ago"
                             : "Expires in \(days) days")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(days < 7 ? Color(hex: "E74C3C") : Color(hex: "E67E22"))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background((days < 7 ? Color(hex: "E74C3C") : Color(hex: "E67E22")).opacity(0.08))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    func formatLeaseDate(_ str: String) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: str) else { return str }
        let out = DateFormatter(); out.dateFormat = "dd MMM yy"
        return out.string(from: d)
    }
}

struct LeaseInfoCell: View {
    let icon: String; let label: String; let value: String
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.caption).foregroundColor(.secondary)
            Text(value).font(.caption.weight(.semibold)).lineLimit(1)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView { LeasesView().environmentObject(DataService.shared) }
}
