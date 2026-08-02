import SwiftUI

struct TenantsView: View {
    @EnvironmentObject var data: DataService
    @State private var searchText   = ""
    @State private var showAddTenant = false

    var filtered: [Tenant] {
        guard !searchText.isEmpty else { return data.tenants }
        return data.tenants.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.unit_number ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.property_name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search name, room or property", text: $searchText)
                }
                .padding(11)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.vertical, 10)

                if data.tenantsLoading && data.tenants.isEmpty {
                    Spacer()
                    ProgressView("Loading tenants…")
                    Spacer()
                } else if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "person.slash").font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(data.tenants.isEmpty ? "No tenants found" : "No results for \"\(searchText)\"")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filtered) { tenant in
                                NavigationLink(destination: TenantDetailView(tenant: tenant)) {
                                    TenantCard(tenant: tenant)
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tenants (\(data.tenants.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddTenant = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "2E6DB4"))
                    }
                }
            }
            .onAppear { data.loadTenants() }
            .refreshable { data.loadTenants() }
            .sheet(isPresented: $showAddTenant) {
                AddEditTenantView().environmentObject(data)
            }
        }
    }
}

// MARK: - Tenant Card

struct TenantCard: View {
    let tenant: Tenant
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: "2E6DB4").opacity(0.12)).frame(width: 50, height: 50)
                Text(tenant.initials).font(.system(size: 18, weight: .semibold)).foregroundColor(Color(hex: "2E6DB4"))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(tenant.name).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                HStack(spacing: 6) {
                    Label(tenant.displayRoom, systemImage: "door.left.hand.closed")
                        .font(.caption).foregroundColor(.secondary)
                    if let prop = tenant.property_name {
                        Text("·").foregroundColor(.secondary)
                        Text(prop).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                Text(tenant.phone).font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(tenant.displayRent))
                    .font(.subheadline.bold()).foregroundColor(Color(hex: "1A3A6B"))
                Text("/month").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(16).background(Color.white).cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

// MARK: - Tenant Detail

struct TenantDetailView: View {
    let tenant: Tenant
    @EnvironmentObject var data: DataService
    @State private var showEdit = false

    var tenantPayments: [Payment] {
        data.payments.filter { $0.tenant_id == tenant.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: "1A3A6B"), Color(hex: "2E6DB4")],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                        Text(tenant.initials).font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                    }
                    Text(tenant.name).font(.title2.bold())
                    Label(tenant.displayRoom, systemImage: "door.left.hand.closed")
                        .font(.subheadline).foregroundColor(.secondary)
                    if let prop = tenant.property_name {
                        Text(prop).font(.caption).foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity).padding(24).background(Color.white)

                // Info
                VStack(spacing: 12) {
                    InfoRow(icon: "phone.fill",            label: "Phone",       value: tenant.phone)
                    InfoRow(icon: "envelope.fill",         label: "Email",       value: tenant.email ?? "—")
                    InfoRow(icon: "indianrupeesign.circle.fill", label: "Rent",  value: formatCurrency(tenant.displayRent))
                    if let start = tenant.start_date {
                        InfoRow(icon: "calendar",          label: "Lease Start", value: start)
                    }
                    if let end = tenant.end_date {
                        InfoRow(icon: "calendar.badge.clock", label: "Lease End", value: end)
                    }
                }
                .padding(16).background(Color.white).cornerRadius(16).padding(.horizontal)

                // Payment history
                if !tenantPayments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Payments").font(.headline).padding(.horizontal)
                        VStack(spacing: 10) {
                            ForEach(tenantPayments.prefix(6), id: \.listId) { payment in
                                LivePaymentRow(payment: payment)
                            }
                        }.padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(tenant.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showEdit = true } label: {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(Color(hex: "2E6DB4"))
                }
            }
        }
        .onAppear { data.loadPayments() }
        .sheet(isPresented: $showEdit) {
            AddEditTenantView(tenant: tenant).environmentObject(data)
        }
    }
}

struct InfoRow: View {
    let icon: String; let label: String; let value: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15))
                .foregroundColor(Color(hex: "2E6DB4")).frame(width: 24)
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.medium))
        }
        Divider()
    }
}

// Shared payment row using live Payment model
struct LivePaymentRow: View {
    let payment: Payment
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(statusColor.opacity(0.12)).frame(width: 42, height: 42)
                Image(systemName: payment.status == "paid" ? "checkmark" : "clock")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(statusColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.tenant_name).font(.subheadline.weight(.semibold))
                Text("Room \(payment.unit_number) · \(monthYMToLabel(payment.payment_month))")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(payment.amount_paid > 0 ? payment.amount_paid : payment.rent_amount))
                    .font(.subheadline.bold())
                Text(payment.status.capitalized).font(.caption.weight(.medium)).foregroundColor(statusColor)
            }
        }
        .padding(14).background(Color.white).cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }

    var statusColor: Color {
        switch payment.status {
        case "paid":    return Color(hex: "27AE60")
        case "partial": return Color(hex: "E67E22")
        default:        return Color(hex: "E74C3C")
        }
    }
}

#Preview {
    TenantsView().environmentObject(DataService.shared)
}
