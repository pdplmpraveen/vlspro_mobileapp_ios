import Foundation

// MARK: - Tenant  (mirrors api/tenants.php response)

struct Tenant: Identifiable, Codable {
    let id: Int
    var name: String
    var phone: String
    var email: String?
    var whatsapp_number: String?
    var is_active: Bool

    // Lease / unit info (nullable — tenant may have no active lease)
    var lease_id: Int?
    var monthly_rent: Double?
    var start_date: String?
    var end_date: String?
    var lease_status: String?
    var unit_id: Int?
    var unit_number: String?
    var unit_type: String?
    var property_id: Int?
    var property_name: String?

    var initials: String {
        name.split(separator: " ").compactMap { $0.first }.map(String.init).prefix(2).joined()
    }

    var displayRoom: String { unit_number ?? "—" }
    var displayProperty: String { property_name ?? "—" }
    var displayRent: Double { monthly_rent ?? 0 }
}

// MARK: - Payment  (mirrors api/payments.php response)

struct Payment: Identifiable, Codable {
    var id: Int?          // nil = pending (no payment recorded yet)
    var receipt_number: String?
    var payment_date: String?
    var payment_month: String        // "2025-06"
    var rent_amount: Double
    var amount_paid: Double
    var balance: Double
    var payment_mode: String?
    var notes: String?
    var tenant_id: Int
    var property_id: Int
    var unit_id: Int
    var tenant_name: String
    var tenant_phone: String?
    var unit_number: String
    var property_name: String
    var status: String               // "paid" | "partial" | "pending"

    // Identifiable — use receipt or synthetic key
    var uniqueKey: String { receipt_number ?? "\(tenant_id)-\(payment_month)" }

    // Conformance: use uniqueKey as id since id can be nil
    var stableId: String { uniqueKey }
}

// Make Payment Identifiable with a String id
extension Payment {
    // Used by ForEach — unique across paid and pending rows
    var listId: String { id.map { "\($0)" } ?? "pending-\(tenant_id)-\(payment_month)" }
}

// MARK: - Expense  (mirrors api/expenses.php response)

struct Expense: Identifiable, Codable {
    let id: Int
    var expense_date: String
    var expense_type: String
    var description: String
    var vendor_name: String?
    var amount: Double
    var paid_by: String
    var notes: String?
    var property_id: Int
    var unit_id: Int?
    var property_name: String
    var unit_number: String?

    var categoryIcon: String {
        switch expense_type {
        case "water_bill":          return "drop.fill"
        case "electricity_common":  return "bolt.fill"
        case "cleaning_labour":     return "sparkles"
        case "plumbing":            return "wrench.and.screwdriver.fill"
        case "electrician":         return "bolt.circle.fill"
        case "sewage_cleaning":     return "arrow.down.circle.fill"
        case "property_tax":        return "doc.text.fill"
        case "maintenance":         return "hammer.fill"
        case "painting":            return "paintbrush.fill"
        default:                    return "ellipsis.circle.fill"
        }
    }

    var categoryLabel: String {
        switch expense_type {
        case "water_bill":          return "Water Bill"
        case "electricity_common":  return "Electricity"
        case "cleaning_labour":     return "Cleaning"
        case "plumbing":            return "Plumbing"
        case "electrician":         return "Electrician"
        case "sewage_cleaning":     return "Sewage"
        case "property_tax":        return "Property Tax"
        case "maintenance":         return "Maintenance"
        case "painting":            return "Painting"
        default:                    return "Other"
        }
    }
}

// MARK: - Dashboard  (mirrors api/dashboard.php response)

struct DashboardSummary: Codable {
    var total_properties: Int
    var total_units: Int
    var occupied_units: Int
    var active_tenants: Int
    var open_damages: Int
    var collected_this_month: Double
    var expected_rent: Double
    var monthly_expenses: Double
    var total_due: Double

    var netIncome: Double { collected_this_month - monthly_expenses }
    var collectionRate: Double {
        guard expected_rent > 0 else { return 0 }
        return min((collected_this_month / expected_rent) * 100, 100)
    }
}

struct RecentPayment: Codable, Identifiable {
    var id: Int
    var amount_paid: Double
    var payment_month: String
    var payment_date: String?    // actual date payment was made
    var created_at: String
    var payment_mode: String?    // nullable — safe decoding
    var tenant_name: String
    var unit_number: String
    var property_name: String
}

struct ExpiringLease: Codable, Identifiable {
    var id: Int
    var end_date: String
    var tenant_name: String
    var phone: String?         // nullable — tenant may have no phone
    var unit_number: String
    var property_name: String
}

struct DashboardData: Codable {
    var summary: DashboardSummary
    var recent_payments: [RecentPayment]
    var expiring_leases: [ExpiringLease]
}

// MARK: - API Wrappers

struct APIResponse<T: Codable>: Codable {
    var success: Bool
    var data: T?
    var error: String?
}

struct LoginResponse: Codable {
    var success: Bool
    var name: String?
    var role: String?
    var id: String?   // PHP returns id as string from PDO fetch
    var error: String?
}

struct PaymentsResponse: Codable {
    var success: Bool
    var month: String?
    var total_collected: Double?
    var data: [Payment]?
    var error: String?
}

struct ExpensesResponse: Codable {
    var success: Bool
    var month: String?
    var total: Double?
    var data: [Expense]?
    var error: String?
}

// MARK: - Property  (mirrors api/properties.php)

struct Property: Identifiable, Codable {
    let id: Int
    var name: String
    var area: String?
    var city: String?
    var address: String?
    var property_type: String
    var total_units: Int
    var occupied_units: Int
    var owner_upi_id: String?    // nullable — UPI payments unavailable until owner sets this

    var vacant_units: Int { total_units - occupied_units }
    var occupancyRate: Double {
        guard total_units > 0 else { return 0 }
        return Double(occupied_units) / Double(total_units)
    }
    var typeIcon: String {
        switch property_type.lowercased() {
        case "apartment":  return "building.2.fill"
        case "house":      return "house.fill"
        case "commercial": return "building.fill"
        default:           return "building.2.fill"
        }
    }
    var locationLabel: String {
        [area, city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Lease  (mirrors api/leases.php)

struct Lease: Identifiable, Codable {
    let id: Int
    var tenant_name: String
    var phone: String?           // nullable — tenant may have no phone
    var unit_number: String      // server may return as String or Int — handled in init
    var unit_type: String?       // nullable — some units may not have type set
    var property_id: Int
    var property_name: String
    var monthly_rent: Double
    var deposit_paid: Double
    var start_date: String
    var end_date: String?
    var status: String           // active | expired | terminated
    var notice_period: Int?
    var rent_increment_pct: Double?

    // Custom init so unit_number works whether server sends "101" or 101
    enum CodingKeys: String, CodingKey {
        case id, tenant_name, phone, unit_number, unit_type
        case property_id, property_name, monthly_rent, deposit_paid
        case start_date, end_date, status, notice_period, rent_increment_pct
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decode(Int.self,    forKey: .id)
        tenant_name       = try c.decode(String.self, forKey: .tenant_name)
        phone             = try c.decodeIfPresent(String.self, forKey: .phone)
        // Accept unit_number as String ("101") or Int (101)
        if let s = try? c.decode(String.self, forKey: .unit_number) {
            unit_number = s
        } else {
            unit_number = String(try c.decode(Int.self, forKey: .unit_number))
        }
        unit_type         = try c.decodeIfPresent(String.self, forKey: .unit_type)
        property_id       = try c.decode(Int.self,    forKey: .property_id)
        property_name     = try c.decode(String.self, forKey: .property_name)
        monthly_rent      = try c.decode(Double.self, forKey: .monthly_rent)
        deposit_paid      = try c.decode(Double.self, forKey: .deposit_paid)
        start_date        = try c.decode(String.self, forKey: .start_date)
        end_date          = try c.decodeIfPresent(String.self, forKey: .end_date)
        status            = try c.decode(String.self, forKey: .status)
        notice_period     = try c.decodeIfPresent(Int.self,    forKey: .notice_period)
        rent_increment_pct = try c.decodeIfPresent(Double.self, forKey: .rent_increment_pct)
    }

    var isActive: Bool { status == "active" }
    var statusColor: String {
        switch status {
        case "active":     return "27AE60"
        case "expired":    return "E74C3C"
        case "terminated": return "95A5A6"
        default:           return "95A5A6"
        }
    }
    var statusLabel: String { status.capitalized }
    var daysUntilExpiry: Int? {
        guard let end = end_date,
              let date = DateFormatter.ymd.date(from: end) else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: date).day
    }
}

extension DateFormatter {
    static let ymd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}

// MARK: - Damage  (mirrors api/damages.php)

struct Damage: Identifiable, Codable {
    let id: Int
    var reported_date: String
    var damage_type: String
    var description: String
    var repair_cost: Double
    var deducted_from_deposit: Double
    var status: String           // reported | in_progress | resolved
    var property_name: String
    var unit_number: String?
    var tenant_name: String?

    var statusColor: String {
        switch status {
        case "resolved":    return "27AE60"
        case "in_progress": return "E67E22"
        default:            return "E74C3C"
        }
    }
    var statusLabel: String {
        switch status {
        case "in_progress": return "In Progress"
        case "resolved":    return "Resolved"
        default:            return "Reported"
        }
    }
    var damageIcon: String {
        switch damage_type.lowercased() {
        case "plumbing":     return "drop.fill"
        case "electrical":   return "bolt.fill"
        case "structural":   return "building.2.crop.circle"
        case "painting":     return "paintbrush.fill"
        case "appliance":    return "washer.fill"
        default:             return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Unit  (mirrors api/units.php)

struct PropertyUnit: Identifiable, Codable {
    let id: Int
    var unit_number: String
    var unit_type: String?     // nullable — some units may not have type set
    var monthly_rent: Double
    var is_occupied: Int       // 0 = vacant, 1 = occupied
    var property_id: Int
    var bescom_account_number: String?   // nullable — BESCOM RR number, may not be set

    var isOccupied: Bool { is_occupied != 0 }
    /// Label shown in the picker
    var displayLabel: String {
        let type = (unit_type ?? "Unit").capitalized
        return "\(unit_number) · \(type)\(isOccupied ? " (Occupied)" : " — Vacant")"
    }
}

// MARK: - Electricity Bill  (mirrors api/electricity_bills.php)

struct ElectricityBill: Identifiable, Codable {
    let id: Int
    var unit_id: Int
    var property_id: Int
    var bescom_account_number: String?   // nullable — BESCOM RR number
    var bill_month: String               // "2026-07"
    var units_consumed: Int?             // nullable — kWh, may be unrecorded
    var bill_amount: Double
    var due_date: String?                // nullable
    var status: String                   // pending | paid | overdue
    var paid_date: String?               // nullable — set once paid
    var payment_mode: String?            // nullable
    var transaction_id: String?          // nullable — UPI ref / cheque no.
    var notes: String?                   // nullable
    var property_name: String
    var owner_name: String?              // nullable
    var owner_upi_id: String?            // nullable — no "Pay via UPI" if unset
    var unit_number: String
    var upi_pay_link: String?            // nullable — precomputed upi://pay deep link

    var isPaid: Bool { status == "paid" }
    var statusColor: String {
        switch status {
        case "paid":    return "27AE60"
        case "overdue": return "E74C3C"
        default:        return "E67E22"   // pending
        }
    }
    var statusLabel: String { status.capitalized }
    var monthLabel: String { monthYMToLabel(bill_month) }
}

// MARK: - Annual Report  (mirrors api/reports.php)

struct MonthlyReportData: Codable, Identifiable {
    var id: String { month }
    var month: String
    var rent_collected: Double
    var expenses: Double
    var net: Double
}

struct ExpenseTypeTotal: Codable, Identifiable {
    var id: String { type }
    var type: String
    var total: Double
    var label: String {
        let map: [String: String] = [
            "water_bill": "Water", "electricity_common": "Electricity",
            "cleaning_labour": "Cleaning", "plumbing": "Plumbing",
            "electrician": "Electrician", "sewage_cleaning": "Sewage",
            "property_tax": "Tax", "maintenance": "Maintenance",
            "painting": "Painting", "other": "Other"
        ]
        return map[type] ?? type.capitalized
    }
}

struct AnnualReportData: Codable {
    var year: Int
    var available_years: [Int]?
    var total_rent: Double
    var total_expenses: Double
    var net_income: Double
    var monthly_data: [MonthlyReportData]
    var expense_by_type: [ExpenseTypeTotal]
}

struct AnnualReportResponse: Codable {
    var success: Bool
    var year: Int?
    var available_years: [Int]?
    var total_rent: Double?
    var total_expenses: Double?
    var net_income: Double?
    var monthly_data: [MonthlyReportData]?
    var expense_by_type: [ExpenseTypeTotal]?
    var error: String?
}
