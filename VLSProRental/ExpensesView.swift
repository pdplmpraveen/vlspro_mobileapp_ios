import SwiftUI

struct ExpensesView: View {
    @EnvironmentObject var data: DataService
    @State private var selectedType: String? = nil
    @State private var showAddExpense = false

    var filtered: [Expense] {
        guard let t = selectedType else { return data.expenses }
        return data.expenses.filter { $0.expense_type == t }
    }

    var totalFiltered: Double { filtered.reduce(0) { $0 + $1.amount } }

    let allTypes = ["water_bill","electricity_common","cleaning_labour","plumbing",
                    "electrician","sewage_cleaning","property_tax","maintenance","painting","other"]

    var presentTypes: [String] {
        let used = Set(data.expenses.map { $0.expense_type })
        return allTypes.filter { used.contains($0) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Banner
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedType.map { typeLabel($0) } ?? "Total Expenses")
                            .font(.caption).foregroundColor(.white.opacity(0.8))
                        Text(formatCurrency(totalFiltered))
                            .font(.title2.bold()).foregroundColor(.white)
                        Text(monthYMToLabel(data.selectedMonth))
                            .font(.caption2).foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: selectedType.map { typeIcon($0) } ?? "chart.bar.fill")
                        .font(.title).foregroundColor(.white.opacity(0.7))
                }
                .padding(20)
                .background(LinearGradient(colors: [Color(hex: "C0392B"), Color(hex: "E74C3C")],
                                           startPoint: .leading, endPoint: .trailing))

                // Month scroller
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(lastSixMonthsYM(), id: \.self) { ym in
                            Button {
                                data.selectedMonth = ym
                                data.loadExpenses(month: ym)
                            } label: {
                                Text(monthYMToLabel(ym))
                                    .font(.caption.weight(data.selectedMonth == ym ? .semibold : .regular))
                                    .foregroundColor(data.selectedMonth == ym ? .white : Color(hex: "E74C3C"))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(data.selectedMonth == ym
                                                ? Color(hex: "E74C3C")
                                                : Color(hex: "E74C3C").opacity(0.1))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 10)
                }
                .background(Color.white)

                // Category filter chips
                if !presentTypes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryChip(label: "All", icon: "square.grid.2x2",
                                         isSelected: selectedType == nil) { selectedType = nil }
                            ForEach(presentTypes, id: \.self) { t in
                                CategoryChip(label: typeLabel(t), icon: typeIcon(t),
                                             isSelected: selectedType == t) {
                                    selectedType = selectedType == t ? nil : t
                                }
                            }
                        }
                        .padding(.horizontal).padding(.vertical, 8)
                    }
                    .background(Color.white)
                }

                // List
                if data.expensesLoading && data.expenses.isEmpty {
                    Spacer(); ProgressView("Loading expenses…"); Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { expense in
                                ExpenseDetailCard(expense: expense)
                            }
                            if filtered.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "tray").font(.system(size: 40))
                                        .foregroundColor(.secondary.opacity(0.4))
                                    Text("No expenses").foregroundColor(.secondary)
                                }.frame(maxWidth: .infinity).padding(.top, 60)
                            }
                        }
                        .padding(.horizontal).padding(.top, 12).padding(.bottom, 24)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if data.properties.isEmpty { data.loadProperties() }
                        showAddExpense = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color(hex: "C0392B"))
                            .cornerRadius(16)
                    }
                }
            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseSheet(isPresented: $showAddExpense)
                    .environmentObject(data)
            }
            .onAppear { data.loadExpenses() }
            .refreshable { data.loadExpenses() }
        }
    }
}

// MARK: - Add Expense Sheet

struct AddExpenseSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var data: DataService

    // Form fields
    @State private var selectedPropertyId: Int = 0
    @State private var expenseType: String = "water_bill"
    @State private var description: String = ""
    @State private var amount: String = ""
    @State private var expenseDate: Date = Date()
    @State private var vendorName: String = ""
    @State private var paidBy: String = "owner"
    @State private var paymentMode: String = "cash"
    @State private var notes: String = ""

    @State private var isSubmitting = false
    @State private var errorMessage = ""

    let expenseTypes: [(key: String, label: String, icon: String)] = [
        ("water_bill",         "Water",       "drop.fill"),
        ("electricity_common", "Electricity", "bolt.fill"),
        ("cleaning_labour",    "Cleaning",    "sparkles"),
        ("plumbing",           "Plumbing",    "wrench.and.screwdriver.fill"),
        ("electrician",        "Electrician", "bolt.circle.fill"),
        ("sewage_cleaning",    "Sewage",      "arrow.down.circle.fill"),
        ("property_tax",       "Tax",         "doc.text.fill"),
        ("maintenance",        "Maintenance", "hammer.fill"),
        ("painting",           "Painting",    "paintbrush.fill"),
        ("other",              "Other",       "ellipsis.circle.fill"),
    ]

    var selectedProperty: Property? {
        data.properties.first { $0.id == selectedPropertyId }
    }

    var body: some View {
        NavigationView {
            Form {
                // Category
                Section("Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(expenseTypes, id: \.key) { et in
                                Button {
                                    expenseType = et.key
                                    if description.isEmpty { description = et.label }
                                } label: {
                                    VStack(spacing: 5) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(expenseType == et.key
                                                      ? Color(hex: "E74C3C")
                                                      : Color(hex: "E74C3C").opacity(0.1))
                                                .frame(width: 46, height: 46)
                                            Image(systemName: et.icon)
                                                .font(.system(size: 18))
                                                .foregroundColor(expenseType == et.key ? .white : Color(hex: "E74C3C"))
                                        }
                                        Text(et.label)
                                            .font(.caption2)
                                            .foregroundColor(expenseType == et.key ? Color(hex: "E74C3C") : .secondary)
                                            .fontWeight(expenseType == et.key ? .semibold : .regular)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // Property + Amount + Date
                Section("Details") {
                    if data.properties.isEmpty {
                        Text("Loading properties…").foregroundColor(.secondary)
                    } else {
                        Picker("Property", selection: $selectedPropertyId) {
                            Text("Select property").tag(0)
                            ForEach(data.properties) { p in
                                Text(p.name).tag(p.id)
                            }
                        }
                    }

                    TextField("Description", text: $description)

                    HStack {
                        Text("₹")
                            .foregroundColor(.secondary)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }

                    DatePicker("Date", selection: $expenseDate, displayedComponents: .date)
                }

                // Vendor + payment
                Section("Payment Info") {
                    TextField("Vendor / Service Provider", text: $vendorName)

                    Picker("Paid By", selection: $paidBy) {
                        Text("Owner").tag("owner")
                        Text("Tenant").tag("tenant")
                    }
                    .pickerStyle(.segmented)

                    Picker("Payment Mode", selection: $paymentMode) {
                        Text("Cash").tag("cash")
                        Text("UPI").tag("upi")
                        Text("Bank Transfer").tag("bank_transfer")
                        Text("Cheque").tag("cheque")
                    }
                }

                // Notes
                Section("Notes (optional)") {
                    TextField("Any additional notes", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }

                // Error
                if !errorMessage.isEmpty {
                    Section {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                            Text(errorMessage).font(.caption).foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        submitExpense()
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save").bold()
                        }
                    }
                    .disabled(isSubmitting || selectedPropertyId == 0 || amount.isEmpty)
                }
            }
        }
    }

    private func submitExpense() {
        guard let amountVal = Double(amount), amountVal > 0 else {
            errorMessage = "Please enter a valid amount."
            return
        }
        guard selectedPropertyId != 0 else {
            errorMessage = "Please select a property."
            return
        }

        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let payload: [String: Any] = [
            "property_id":  selectedPropertyId,
            "expense_type": expenseType,
            "description":  description,
            "amount":       amountVal,
            "expense_date": fmt.string(from: expenseDate),
            "vendor_name":  vendorName,
            "paid_by":      paidBy,
            "payment_mode": paymentMode,
            "notes":        notes,
        ]

        isSubmitting = true
        errorMessage = ""

        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await data.addExpense(payload)
                data.loadExpenses()   // refresh list
                isPresented = false
            } catch APIError.serverError(let msg) {
                errorMessage = msg
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Expense Card

struct CategoryChip: View {
    let label: String; let icon: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : Color(hex: "E74C3C"))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isSelected ? Color(hex: "E74C3C") : Color(hex: "E74C3C").opacity(0.1))
            .cornerRadius(20)
        }
    }
}

struct ExpenseDetailCard: View {
    let expense: Expense
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: "E74C3C").opacity(0.10))
                    .frame(width: 48, height: 48)
                Image(systemName: expense.categoryIcon).font(.system(size: 20))
                    .foregroundColor(Color(hex: "E74C3C"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.description).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text("\(expense.categoryLabel) · \(expense.property_name)")
                    .font(.caption).foregroundColor(.secondary)
                if let vendor = expense.vendor_name, !vendor.isEmpty {
                    Text("Vendor: \(vendor)").font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(formatCurrency(expense.amount)).font(.subheadline.bold())
                    .foregroundColor(Color(hex: "E74C3C"))
                Text(expense.expense_date).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(16).background(Color.white).cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 5, y: 1)
    }
}

// MARK: - Helpers

private func typeLabel(_ type: String) -> String {
    let map: [String: String] = [
        "water_bill": "Water", "electricity_common": "Electricity",
        "cleaning_labour": "Cleaning", "plumbing": "Plumbing",
        "electrician": "Electrician", "sewage_cleaning": "Sewage",
        "property_tax": "Tax", "maintenance": "Maintenance",
        "painting": "Painting", "other": "Other"
    ]
    return map[type] ?? type.capitalized
}

private func typeIcon(_ type: String) -> String {
    let map: [String: String] = [
        "water_bill": "drop.fill", "electricity_common": "bolt.fill",
        "cleaning_labour": "sparkles", "plumbing": "wrench.and.screwdriver.fill",
        "electrician": "bolt.circle.fill", "sewage_cleaning": "arrow.down.circle.fill",
        "property_tax": "doc.text.fill", "maintenance": "hammer.fill",
        "painting": "paintbrush.fill", "other": "ellipsis.circle.fill"
    ]
    return map[type] ?? "ellipsis.circle.fill"
}

private func lastSixMonthsYM() -> [String] {
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM"
    let cal = Calendar.current
    return (0..<6).compactMap { cal.date(byAdding: .month, value: -$0, to: Date()) }.map { fmt.string(from: $0) }
}

#Preview {
    ExpensesView().environmentObject(DataService.shared)
}
