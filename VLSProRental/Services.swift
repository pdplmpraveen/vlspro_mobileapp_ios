import Foundation

// MARK: - API Client

private let baseURL = "https://vlspro.co.in/vlspro-rental"

/// Shared URLSession that persists PHP session cookies across all requests.
private let session: URLSession = {
    let config = URLSessionConfiguration.default
    config.httpCookieStorage = HTTPCookieStorage.shared
    config.httpCookieAcceptPolicy = .always
    config.httpShouldSetCookies = true
    return URLSession(configuration: config)
}()

private func apiURL(_ path: String) -> URL {
    URL(string: baseURL + path)!
}

private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
    var components = URLComponents(url: apiURL(path), resolvingAgainstBaseURL: false)!
    if !query.isEmpty {
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
    let (data, resp) = try await session.data(from: components.url!)
    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
    if status == 401 { throw APIError.unauthorized }
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        let raw = String(data: data, encoding: .utf8) ?? "<binary>"
        print("[VLSPro] Decode error on \(path) (HTTP \(status)): \(error)")
        print("[VLSPro] Raw response: \(raw.prefix(500))")
        // Embed raw response so UI can show it without Xcode
        var detail = ""
        if let de = error as? DecodingError {
            switch de {
            case .typeMismatch(let t, let ctx):
                let path2 = ctx.codingPath.map(\.stringValue).joined(separator: ".")
                detail = "Field '\(path2)' — expected \(t) but got different type."
            case .valueNotFound(let t, let ctx):
                let path2 = ctx.codingPath.map(\.stringValue).joined(separator: ".")
                detail = "Null at '\(path2)' — \(t) cannot be null."
            case .keyNotFound(let k, _):
                detail = "Missing key '\(k.stringValue)' in response."
            case .dataCorrupted(let ctx):
                detail = "Data corrupted: \(ctx.debugDescription)"
            @unknown default:
                detail = error.localizedDescription
            }
        } else {
            detail = error.localizedDescription
        }
        let snippet = String(raw.prefix(300))
        throw APIError.serverError("\(detail)\n\nJSON: \(snippet)")
    }
}

enum APIError: LocalizedError {
    case unauthorized
    case serverError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized:       return "Session expired. Please log in again."
        case .serverError(let m): return m
        case .unknown:            return "Something went wrong. Please try again."
        }
    }
}

// MARK: - Auth Manager

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isLoggedIn   = false
    @Published var ownerName    = ""
    @Published var ownerRole    = ""
    @Published var ownerEmail   = ""
    @Published var isLoading    = false
    @Published var errorMessage = ""

    /// Triggers the Face ID setup alert in ContentView after login/signup.
    @Published var showBiometricOffer = false
    private(set) var pendingBiometricEmail    = ""
    private(set) var pendingBiometricPassword = ""

    /// Accounts that bypass the subscription paywall (lifetime free access).
    private let lifetimeAccounts: Set<String> = ["owner@vlspro.co.in"]

    var isLifetimeFree: Bool {
        lifetimeAccounts.contains(ownerEmail.lowercased())
    }

    // MARK: - Login

    func login(email: String, password: String) {
        isLoading = true
        errorMessage = ""

        Task { @MainActor in
            defer { isLoading = false }
            do {
                var request = URLRequest(url: apiURL("/api/login.php"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body = ["email": email, "password": password]
                request.httpBody = try JSONEncoder().encode(body)

                let (data, response) = try await session.data(for: request)
                let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0

                let raw = String(data: data, encoding: .utf8) ?? "<binary>"
                print("[VLSPro] Login (\(httpStatus)): \(raw.prefix(500))")

                do {
                    let result = try JSONDecoder().decode(LoginResponse.self, from: data)
                    if result.success {
                        ownerName  = result.name ?? email
                        ownerRole  = result.role ?? ""
                        ownerEmail = email
                        isLoggedIn = true
                        offerBiometricIfNeeded(email: email, password: password)
                    } else {
                        errorMessage = result.error ?? "Invalid email or password."
                    }
                } catch {
                    let preview = raw.prefix(200).trimmingCharacters(in: .whitespacesAndNewlines)
                    if httpStatus == 404 {
                        errorMessage = "API not found (404). Deploy api/login.php to the server first."
                    } else if preview.hasPrefix("<") {
                        errorMessage = "Server returned HTML instead of JSON (status \(httpStatus)). Check Xcode console for details."
                    } else {
                        errorMessage = "Server response error (\(httpStatus)): \(preview.isEmpty ? error.localizedDescription : preview)"
                    }
                    print("[VLSPro] Login decode error: \(error)")
                }
            } catch {
                errorMessage = "Network error: \(error.localizedDescription)"
                print("[VLSPro] Login network error: \(error)")
            }
        }
    }

    // MARK: - Signup

    func signup(name: String, email: String, phone: String, password: String) {
        isLoading = true
        errorMessage = ""

        Task { @MainActor in
            defer { isLoading = false }
            do {
                var request = URLRequest(url: apiURL("/api/register.php"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body = ["name": name, "email": email, "phone": phone, "password": password]
                request.httpBody = try JSONEncoder().encode(body)

                let (data, response) = try await session.data(for: request)
                let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
                let raw = String(data: data, encoding: .utf8) ?? "<binary>"
                print("[VLSPro] Signup (\(httpStatus)): \(raw.prefix(500))")

                do {
                    let result = try JSONDecoder().decode(LoginResponse.self, from: data)
                    if result.success {
                        ownerName  = result.name ?? name
                        ownerRole  = result.role ?? "owner"
                        ownerEmail = email
                        isLoggedIn = true
                        offerBiometricIfNeeded(email: email, password: password)
                    } else {
                        errorMessage = result.error ?? "Registration failed. Please try again."
                    }
                } catch {
                    let preview = raw.prefix(200).trimmingCharacters(in: .whitespacesAndNewlines)
                    if httpStatus == 404 {
                        errorMessage = "API not found (404). Deploy api/register.php first."
                    } else if preview.hasPrefix("<") {
                        errorMessage = "Server returned HTML (status \(httpStatus)). Check server logs."
                    } else {
                        errorMessage = "Server error (\(httpStatus)): \(preview.isEmpty ? error.localizedDescription : preview)"
                    }
                }
            } catch {
                errorMessage = "Network error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Logout

    func logout() {
        if let cookies = HTTPCookieStorage.shared.cookies {
            cookies.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        }
        isLoggedIn   = false
        ownerName    = ""
        ownerRole    = ""
        ownerEmail   = ""
        showBiometricOffer = false
    }

    // MARK: - Delete Account
    // Required by App Store Review Guideline 5.1.1(v): since this app supports
    // in-app account creation (SignupView), it must also support in-app account
    // deletion — completed entirely here, no "visit our website" step.

    func deleteAccount(password: String) async throws {
        var request = URLRequest(url: apiURL("/api/delete_account.php"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["password": password])

        let (data, resp) = try await session.data(for: request)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            throw APIError.serverError("Incorrect password.")
        }

        struct SR: Decodable { var success: Bool; var error: String? }
        let result = try JSONDecoder().decode(SR.self, from: data)
        guard result.success else {
            throw APIError.serverError(result.error ?? "Failed to delete account.")
        }

        await MainActor.run {
            BiometricAuthManager.shared.deleteCredentials()
            logout()
        }
    }

    // MARK: - Face ID Offer

    private func offerBiometricIfNeeded(email: String, password: String) {
        let bio = BiometricAuthManager.shared
        guard bio.isAvailable && !bio.hasStoredCredentials else { return }
        pendingBiometricEmail    = email
        pendingBiometricPassword = password
        showBiometricOffer       = true
    }

    func resolveBiometricOffer(accept: Bool) {
        if accept {
            BiometricAuthManager.shared.saveCredentials(
                email: pendingBiometricEmail,
                password: pendingBiometricPassword
            )
        }
        pendingBiometricEmail    = ""
        pendingBiometricPassword = ""
        showBiometricOffer       = false
    }
}

// MARK: - Data Service

class DataService: ObservableObject {
    static let shared = DataService()

    // Dashboard
    @Published var dashboard: DashboardData? = nil
    @Published var dashboardLoading = false
    @Published var dashboardError: String? = nil

    // Tenants
    @Published var tenants: [Tenant] = []
    @Published var tenantsLoading = false

    // Payments
    @Published var payments: [Payment] = []
    @Published var paymentsLoading = false
    @Published var selectedMonth: String = currentMonthYM()

    // Expenses
    @Published var expenses: [Expense] = []
    @Published var expensesLoading = false

    // Properties
    @Published var properties: [Property] = []
    @Published var propertiesLoading = false

    // Leases
    @Published var leases: [Lease] = []
    @Published var leasesLoading = false
    @Published var leasesError: String? = nil

    // Damages
    @Published var damages: [Damage] = []
    @Published var damagesLoading = false

    // Electricity (BESCOM) bills
    @Published var electricityBills: [ElectricityBill] = []
    @Published var electricityBillsLoading = false

    // Annual Report
    @Published var annualReport: AnnualReportData? = nil
    @Published var reportLoading = false
    @Published var reportYear: Int = Calendar.current.component(.year, from: Date())

    // MARK: Dashboard

    func loadDashboard() {
        dashboardLoading = true
        dashboardError = nil
        Task { @MainActor in
            defer { dashboardLoading = false }
            do {
                let resp: APIResponse<DashboardData> = try await get("/api/dashboard.php")
                if resp.success, let data = resp.data {
                    dashboard = data
                } else {
                    dashboardError = resp.error ?? "Failed to load dashboard."
                }
            } catch APIError.unauthorized {
                AuthManager.shared.logout()
            } catch {
                dashboardError = error.localizedDescription
                print("[VLSPro] Dashboard error: \(error)")
            }
        }
    }

    // MARK: Tenants

    func loadTenants() {
        tenantsLoading = true
        Task { @MainActor in
            defer { tenantsLoading = false }
            do {
                let resp: APIResponse<[Tenant]> = try await get("/api/tenants.php")
                if resp.success, let data = resp.data {
                    tenants = data
                }
            } catch APIError.unauthorized {
                AuthManager.shared.logout()
            } catch {
                print("[VLSPro] Tenants error: \(error)")
            }
        }
    }

    // MARK: Payments

    func loadPayments(month: String? = nil) {
        let m = month ?? selectedMonth
        paymentsLoading = true
        Task { @MainActor in
            defer { paymentsLoading = false }
            do {
                let resp: PaymentsResponse = try await get("/api/payments.php", query: ["month": m])
                if resp.success, let data = resp.data {
                    payments = data
                }
            } catch APIError.unauthorized {
                AuthManager.shared.logout()
            } catch {
                print("[VLSPro] Payments error: \(error)")
            }
        }
    }

    // MARK: Expenses

    func loadExpenses(month: String? = nil) {
        let m = month ?? selectedMonth
        expensesLoading = true
        Task { @MainActor in
            defer { expensesLoading = false }
            do {
                let resp: ExpensesResponse = try await get("/api/expenses.php", query: ["month": m])
                if resp.success, let data = resp.data {
                    expenses = data
                }
            } catch APIError.unauthorized {
                AuthManager.shared.logout()
            } catch {
                print("[VLSPro] Expenses error: \(error)")
            }
        }
    }

    // MARK: Properties

    func loadProperties() {
        propertiesLoading = true
        Task { @MainActor in
            defer { propertiesLoading = false }
            do {
                let resp: APIResponse<[Property]> = try await get("/api/properties.php")
                if resp.success, let data = resp.data { properties = data }
            } catch APIError.unauthorized { AuthManager.shared.logout()
            } catch { print("[VLSPro] Properties error: \(error)") }
        }
    }

    // MARK: Leases

    func loadLeases() {
        leasesLoading = true
        leasesError = nil
        Task { @MainActor in
            defer { leasesLoading = false }
            do {
                let resp: APIResponse<[Lease]> = try await get("/api/leases.php")
                if resp.success, let data = resp.data {
                    leases = data
                    leasesError = nil
                } else {
                    leasesError = resp.error ?? "Server returned no data."
                }
            } catch APIError.unauthorized {
                AuthManager.shared.logout()
            } catch {
                leasesError = error.localizedDescription
                print("[VLSPro] Leases error: \(error)")
            }
        }
    }

    // MARK: Damages

    func loadDamages() {
        damagesLoading = true
        Task { @MainActor in
            defer { damagesLoading = false }
            do {
                let resp: APIResponse<[Damage]> = try await get("/api/damages.php")
                if resp.success, let data = resp.data { damages = data }
            } catch APIError.unauthorized { AuthManager.shared.logout()
            } catch { print("[VLSPro] Damages error: \(error)") }
        }
    }

    // MARK: Electricity (BESCOM) bills

    func loadElectricityBills(propertyId: Int? = nil, status: String? = nil) {
        electricityBillsLoading = true
        Task { @MainActor in
            defer { electricityBillsLoading = false }
            do {
                var query: [String: String] = [:]
                if let propertyId { query["property_id"] = "\(propertyId)" }
                if let status     { query["status"] = status }
                let resp: APIResponse<[ElectricityBill]> = try await get("/api/electricity_bills.php", query: query)
                if resp.success, let data = resp.data { electricityBills = data }
            } catch APIError.unauthorized { AuthManager.shared.logout()
            } catch { print("[VLSPro] Electricity bills error: \(error)") }
        }
    }

    // MARK: Add Electricity Bill

    func addElectricityBill(_ payload: [String: Any]) async throws {
        var request = URLRequest(url: apiURL("/api/add_electricity_bill.php"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await session.data(for: request)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            await MainActor.run { AuthManager.shared.logout() }
            throw APIError.unauthorized
        }
        struct SR: Decodable { var success: Bool; var error: String? }
        let result = try JSONDecoder().decode(SR.self, from: data)
        if !result.success { throw APIError.serverError(result.error ?? "Failed to save electricity bill.") }
    }

    // MARK: Pay Electricity Bill (mark paid, e.g. after UPI payment confirmed)

    func payElectricityBill(id: Int, paymentMode: String = "upi", transactionId: String? = nil, paidDate: String? = nil) async throws {
        var payload: [String: Any] = ["id": id, "payment_mode": paymentMode]
        if let transactionId, !transactionId.isEmpty { payload["transaction_id"] = transactionId }
        if let paidDate { payload["paid_date"] = paidDate }

        var request = URLRequest(url: apiURL("/api/pay_electricity_bill.php"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await session.data(for: request)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            await MainActor.run { AuthManager.shared.logout() }
            throw APIError.unauthorized
        }
        struct SR: Decodable { var success: Bool; var error: String? }
        let result = try JSONDecoder().decode(SR.self, from: data)
        if !result.success { throw APIError.serverError(result.error ?? "Failed to mark bill as paid.") }
    }

    // MARK: Annual Report

    func loadAnnualReport(year: Int? = nil) {
        let y = year ?? reportYear
        reportLoading = true
        Task { @MainActor in
            defer { reportLoading = false }
            do {
                let resp: AnnualReportResponse = try await get("/api/reports.php", query: ["year": "\(y)"])
                if resp.success {
                    annualReport = AnnualReportData(
                        year:             resp.year ?? y,
                        available_years:  resp.available_years,
                        total_rent:       resp.total_rent ?? 0,
                        total_expenses:   resp.total_expenses ?? 0,
                        net_income:       resp.net_income ?? 0,
                        monthly_data:     resp.monthly_data ?? [],
                        expense_by_type:  resp.expense_by_type ?? []
                    )
                }
            } catch APIError.unauthorized { AuthManager.shared.logout()
            } catch { print("[VLSPro] Report error: \(error)") }
        }
    }

    // MARK: Units (for form pickers)

    /// Fetches all units for a property — used by AddLeaseView and AddDamageView.
    func fetchUnits(propertyId: Int) async throws -> [PropertyUnit] {
        let resp: APIResponse<[PropertyUnit]> = try await get("/api/units.php",
                                                              query: ["property_id": "\(propertyId)"])
        if let units = resp.data { return units }
        throw APIError.serverError(resp.error ?? "Failed to load units.")
    }

    // MARK: Add Lease

    func addLease(_ payload: [String: Any]) async throws {
        var request = URLRequest(url: apiURL("/api/add_lease.php"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await session.data(for: request)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            await MainActor.run { AuthManager.shared.logout() }
            throw APIError.unauthorized
        }
        struct SR: Decodable { var success: Bool; var error: String? }
        let result = try JSONDecoder().decode(SR.self, from: data)
        if !result.success { throw APIError.serverError(result.error ?? "Failed to create lease.") }
    }

    // MARK: Add Damage

    func addDamage(_ payload: [String: Any]) async throws {
        var request = URLRequest(url: apiURL("/api/add_damage.php"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await session.data(for: request)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            await MainActor.run { AuthManager.shared.logout() }
            throw APIError.unauthorized
        }
        struct SR: Decodable { var success: Bool; var error: String? }
        let result = try JSONDecoder().decode(SR.self, from: data)
        if !result.success { throw APIError.serverError(result.error ?? "Failed to create damage report.") }
    }

    // MARK: Add Payment

    func addPayment(_ payload: [String: Any]) async throws {
        var request = URLRequest(url: apiURL("/api/add_payment.php"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await session.data(for: request)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            await MainActor.run { AuthManager.shared.logout() }
            throw APIError.unauthorized
        }
        struct SR: Decodable { var success: Bool; var error: String? }
        let result = try JSONDecoder().decode(SR.self, from: data)
        if !result.success { throw APIError.serverError(result.error ?? "Failed to record payment.") }
    }

    // MARK: Add / Edit Tenant

    func addTenant(_ payload: [String: Any]) async throws {
        var request = URLRequest(url: apiURL("/api/add_tenant.php"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await session.data(for: request)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            await MainActor.run { AuthManager.shared.logout() }
            throw APIError.unauthorized
        }
        struct SR: Decodable { var success: Bool; var error: String? }
        let result = try JSONDecoder().decode(SR.self, from: data)
        if !result.success { throw APIError.serverError(result.error ?? "Failed to add tenant.") }
    }

    func editTenant(_ id: Int, _ payload: [String: Any]) async throws {
        var body = payload
        body["id"] = id
        var request = URLRequest(url: apiURL("/api/edit_tenant.php"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: request)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            await MainActor.run { AuthManager.shared.logout() }
            throw APIError.unauthorized
        }
        struct SR: Decodable { var success: Bool; var error: String? }
        let result = try JSONDecoder().decode(SR.self, from: data)
        if !result.success { throw APIError.serverError(result.error ?? "Failed to update tenant.") }
    }

    // MARK: Add Expense

    func addExpense(_ payload: [String: Any]) async throws {
        var request = URLRequest(url: apiURL("/api/add_expense.php"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await session.data(for: request)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            await MainActor.run { AuthManager.shared.logout() }
            throw APIError.unauthorized
        }
        struct SimpleResp: Decodable { var success: Bool; var error: String? }
        let result = try JSONDecoder().decode(SimpleResp.self, from: data)
        if !result.success {
            throw APIError.serverError(result.error ?? "Failed to save expense.")
        }
    }

    // MARK: Load all

    func loadAll() {
        loadDashboard()
        loadTenants()
        loadPayments()
        loadExpenses()
    }
}

// MARK: - Helpers

func currentMonthYM() -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM"
    return fmt.string(from: Date())
}

func monthYMToLabel(_ ym: String) -> String {
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM"
    guard let d = fmt.date(from: ym) else { return ym }
    let out = DateFormatter(); out.dateFormat = "MMMM yyyy"
    return out.string(from: d)
}

func formatCurrency(_ amount: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencySymbol = "₹"
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
}
