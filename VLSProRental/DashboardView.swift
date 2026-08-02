import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var data: DataService

    private var s: DashboardSummary? { data.dashboard?.summary }

    var body: some View {
        NavigationStack {
            Group {
                if data.dashboardLoading && data.dashboard == nil {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = data.dashboardError, data.dashboard == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(err).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { data.loadDashboard() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            greetingHeader
                            if let s { occupancyBanner(s) }
                            if let s { statsGrid(s) }
                            if let s { collectionProgress(s) }
                            recentPaymentsSection
                            expiringLeasesSection
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout") { auth.logout() }
                        .font(.subheadline).foregroundColor(.red)
                }
            }
            .onAppear { data.loadDashboard() }
            .refreshable { data.loadAll() }
        }
    }

    // MARK: - Sub-views

    var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Good \(greetingTime())")
                    .font(.subheadline).foregroundColor(.secondary)
                Text(auth.ownerName.isEmpty ? "Owner" : auth.ownerName)
                    .font(.title2.bold())
            }
            Spacer()
            if data.dashboardLoading {
                ProgressView().scaleEffect(0.8)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    func occupancyBanner(_ s: DashboardSummary) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Occupancy")
                    .font(.caption.weight(.semibold)).foregroundColor(.white.opacity(0.85))
                Text("\(s.occupied_units)/\(s.total_units) Units")
                    .font(.title2.bold()).foregroundColor(.white)
                Text("\(s.total_properties) Properties · \(s.active_tenants) Tenants")
                    .font(.caption).foregroundColor(.white.opacity(0.75))
            }
            Spacer()
            ZStack {
                Circle().stroke(Color.white.opacity(0.3), lineWidth: 6).frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: s.total_units > 0 ? CGFloat(s.occupied_units) / CGFloat(s.total_units) : 0)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                Text("\(s.total_units > 0 ? Int(Double(s.occupied_units)/Double(s.total_units)*100) : 0)%")
                    .font(.caption.bold()).foregroundColor(.white)
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [Color(hex: "1A3A6B"), Color(hex: "2E6DB4")],
                                   startPoint: .leading, endPoint: .trailing))
        .cornerRadius(20)
        .padding(.horizontal)
    }

    func statsGrid(_ s: DashboardSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatCard(title: "Collected", amount: s.collected_this_month,  icon: "checkmark.circle.fill", color: Color(hex: "27AE60"))
            StatCard(title: "Pending",   amount: s.total_due,             icon: "clock.fill",            color: Color(hex: "E67E22"))
            StatCard(title: "Expenses",  amount: s.monthly_expenses,      icon: "arrow.down.circle.fill", color: Color(hex: "E74C3C"))
            StatCard(title: "Net Income",amount: s.netIncome,             icon: "indianrupeesign.circle.fill", color: Color(hex: "2E6DB4"))
        }
        .padding(.horizontal)
    }

    func collectionProgress(_ s: DashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Collection Rate", subtitle: monthYMToLabel(currentMonthYM()))
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(s.collectionRate))% collected")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(formatCurrency(s.collected_this_month)) / \(formatCurrency(s.expected_rent))")
                        .font(.caption).foregroundColor(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [Color(hex: "27AE60"), Color(hex: "2ECC71")],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(s.collectionRate / 100), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .padding(.horizontal)
    }

    var recentPaymentsSection: some View {
        Group {
            if let payments = data.dashboard?.recent_payments {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(
                        title: "Payments This Month",
                        subtitle: "\(payments.count) received · \(monthYMToLabel(currentMonthYM()))"
                    )

                    if payments.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "tray").font(.title3).foregroundColor(.secondary.opacity(0.5))
                            Text("No payments recorded yet this month.")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(payments) { p in
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle().fill(Color(hex: "27AE60").opacity(0.12)).frame(width: 42, height: 42)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: "27AE60"))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.tenant_name).font(.subheadline.weight(.semibold))
                                        Text("Unit \(p.unit_number) · \(p.property_name)")
                                            .font(.caption).foregroundColor(.secondary)
                                        if let date = p.payment_date {
                                            Text("Paid on \(formatShortDate(date))")
                                                .font(.caption2).foregroundColor(Color(hex: "27AE60"))
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(formatCurrency(p.amount_paid))
                                            .font(.subheadline.bold())
                                        if let mode = p.payment_mode {
                                            Text(paymentModeLabel(mode))
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func formatShortDate(_ str: String) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: str) else { return str }
        let out = DateFormatter(); out.dateFormat = "d MMM yyyy"
        return out.string(from: d)
    }

    private func paymentModeLabel(_ mode: String) -> String {
        switch mode {
        case "upi":           return "UPI"
        case "bank_transfer": return "Bank Transfer"
        case "neft":          return "NEFT/RTGS"
        case "cheque":        return "Cheque"
        default:              return mode.capitalized
        }
    }

    var expiringLeasesSection: some View {
        Group {
            if let leases = data.dashboard?.expiring_leases, !leases.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Leases Expiring Soon", subtitle: "Next 30 days")
                    VStack(spacing: 10) {
                        ForEach(leases) { l in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Color(hex: "E67E22").opacity(0.12)).frame(width: 42, height: 42)
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 16)).foregroundColor(Color(hex: "E67E22"))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l.tenant_name).font(.subheadline.weight(.semibold))
                                    Text("Unit \(l.unit_number) · \(l.property_name)")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("Ends \(l.end_date)").font(.caption).foregroundColor(Color(hex: "E74C3C"))
                            }
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func greetingTime() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Morning" }
        else if h < 17 { return "Afternoon" }
        else { return "Evening" }
    }
}

// MARK: - Reusable Components (used across screens)

struct StatCard: View {
    let title: String; let amount: Double; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: icon).font(.title3).foregroundColor(color); Spacer() }
            Text(formatCurrency(amount)).font(.title3.bold()).minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .padding(16).background(Color.white).cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

struct SectionHeader: View {
    let title: String; let subtitle: String
    var body: some View {
        HStack(alignment: .bottom) {
            Text(title).font(.headline)
            Spacer()
            if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundColor(.secondary) }
        }
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(red: Double((int >> 16) & 0xFF) / 255,
                  green: Double((int >> 8)  & 0xFF) / 255,
                  blue:  Double(int         & 0xFF) / 255)
    }
}

#Preview {
    DashboardView().environmentObject(AuthManager.shared).environmentObject(DataService.shared)
}
