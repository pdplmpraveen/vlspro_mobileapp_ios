import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var data: DataService

    var report: AnnualReportData? { data.annualReport }
    var availableYears: [Int] {
        report?.available_years ?? [Calendar.current.component(.year, from: Date())]
    }

    var body: some View {
        Group {
            if data.reportLoading && report == nil {
                ProgressView("Loading report…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        // Year selector
                        yearSelector

                        if let r = report {
                            // Annual totals
                            annualTotals(r)

                            // Monthly breakdown
                            monthlyBreakdown(r)

                            // Expense by type
                            if !r.expense_by_type.isEmpty {
                                expenseByType(r)
                            }
                        } else {
                            Text("No data for \(data.reportYear)")
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        }
                    }
                    .padding(.bottom, 32)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Annual Report")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { data.loadAnnualReport() }
        .refreshable { data.loadAnnualReport() }
    }

    // MARK: - Year selector

    var yearSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(availableYears, id: \.self) { year in
                    Button {
                        data.reportYear = year
                        data.loadAnnualReport(year: year)
                    } label: {
                        Text("\(year)")
                            .font(.subheadline.weight(data.reportYear == year ? .semibold : .regular))
                            .foregroundColor(data.reportYear == year ? .white : Color(hex: "2E6DB4"))
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(data.reportYear == year
                                        ? Color(hex: "2E6DB4")
                                        : Color(hex: "2E6DB4").opacity(0.1))
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal).padding(.top, 8)
        }
    }

    // MARK: - Annual totals

    func annualTotals(_ r: AnnualReportData) -> some View {
        VStack(spacing: 0) {
            // Net income banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Income \(r.year)")
                        .font(.caption).foregroundColor(.white.opacity(0.8))
                    Text(formatCurrency(r.net_income))
                        .font(.title.bold()).foregroundColor(.white)
                }
                Spacer()
                Image(systemName: r.net_income >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(20)
            .background(LinearGradient(
                colors: r.net_income >= 0
                    ? [Color(hex: "1A3A6B"), Color(hex: "2E6DB4")]
                    : [Color(hex: "C0392B"), Color(hex: "E74C3C")],
                startPoint: .leading, endPoint: .trailing
            ))
            .cornerRadius(16)
            .padding(.horizontal)

            // Two stat cards
            HStack(spacing: 12) {
                ReportStatCard(title: "Total Rent", amount: r.total_rent,
                               icon: "indianrupeesign.circle.fill", color: Color(hex: "27AE60"))
                ReportStatCard(title: "Total Expenses", amount: r.total_expenses,
                               icon: "arrow.down.circle.fill", color: Color(hex: "E74C3C"))
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }

    // MARK: - Monthly breakdown

    func monthlyBreakdown(_ r: AnnualReportData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Monthly Breakdown", subtitle: "\(r.year)")
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(r.monthly_data.filter { $0.rent_collected > 0 || $0.expenses > 0 }) { m in
                    MonthlyReportRow(row: m)
                }
                if r.monthly_data.allSatisfy({ $0.rent_collected == 0 && $0.expenses == 0 }) {
                    Text("No transactions in \(r.year)")
                        .foregroundColor(.secondary).font(.subheadline)
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Expense by type

    func expenseByType(_ r: AnnualReportData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Expenses by Category", subtitle: "")
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(r.expense_by_type) { item in
                    HStack(spacing: 14) {
                        Text(item.label)
                            .font(.subheadline).foregroundColor(.primary)
                        Spacer()
                        // mini bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.systemGray5)).frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: "E74C3C"))
                                    .frame(
                                        width: geo.size.width * CGFloat(
                                            r.total_expenses > 0 ? item.total / r.total_expenses : 0
                                        ),
                                        height: 6
                                    )
                            }
                        }
                        .frame(width: 80, height: 6)
                        Text(formatCurrency(item.total))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color(hex: "E74C3C"))
                            .frame(width: 90, alignment: .trailing)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    Divider().padding(.leading, 16)
                }
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            .padding(.horizontal)
        }
    }
}

struct MonthlyReportRow: View {
    let row: MonthlyReportData

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(monthLabel(row.month))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatCurrency(row.net))
                    .font(.subheadline.bold())
                    .foregroundColor(row.net >= 0 ? Color(hex: "27AE60") : Color(hex: "E74C3C"))
            }
            HStack(spacing: 12) {
                Label(formatCurrency(row.rent_collected), systemImage: "arrow.up")
                    .font(.caption).foregroundColor(Color(hex: "27AE60"))
                Spacer()
                Label(formatCurrency(row.expenses), systemImage: "arrow.down")
                    .font(.caption).foregroundColor(Color(hex: "E74C3C"))
            }
            // visual bar
            GeometryReader { geo in
                let maxVal = max(row.rent_collected, row.expenses, 1)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray6)).frame(height: 6)
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "27AE60"))
                            .frame(width: geo.size.width * 0.5 * CGFloat(row.rent_collected / maxVal), height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "E74C3C"))
                            .frame(width: geo.size.width * 0.5 * CGFloat(row.expenses / maxVal), height: 6)
                    }
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }

    func monthLabel(_ ym: String) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM"
        guard let d = fmt.date(from: ym) else { return ym }
        let out = DateFormatter(); out.dateFormat = "MMMM yyyy"
        return out.string(from: d)
    }
}

struct ReportStatCard: View {
    let title: String; let amount: Double; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.title3).foregroundColor(color)
                Spacer()
            }
            Text(formatCurrency(amount))
                .font(.title3.bold()).minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .padding(16).background(Color.white).cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack { ReportsView().environmentObject(DataService.shared) }
}
