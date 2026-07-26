import SwiftUI

struct MoreView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var data: DataService
    @State private var showDeleteAccount = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Management
                Section("Management") {
                    NavigationLink {
                        PropertiesView()
                            .environmentObject(data)
                    } label: {
                        MoreRow(
                            icon: "building.2.fill",
                            color: "2E6DB4",
                            title: "Properties",
                            subtitle: "\(data.properties.count) propert\(data.properties.count == 1 ? "y" : "ies")"
                        )
                    }

                    NavigationLink {
                        LeasesView()
                            .environmentObject(data)
                    } label: {
                        MoreRow(
                            icon: "doc.text.fill",
                            color: "8E44AD",
                            title: "Leases",
                            subtitle: "\(data.leases.filter { $0.isActive }.count) active"
                        )
                    }

                    NavigationLink {
                        DamagesView()
                            .environmentObject(data)
                    } label: {
                        MoreRow(
                            icon: "exclamationmark.triangle.fill",
                            color: "E74C3C",
                            title: "Damages",
                            subtitle: "\(data.damages.filter { $0.status != "resolved" }.count) open"
                        )
                    }

                    NavigationLink {
                        ElectricityView()
                            .environmentObject(data)
                    } label: {
                        MoreRow(
                            icon: "bolt.fill",
                            color: "E67E22",
                            title: "Electricity",
                            subtitle: "\(data.electricityBills.filter { $0.status != "paid" }.count) due"
                        )
                    }
                }

                // MARK: - Reports
                Section("Reports") {
                    NavigationLink {
                        ReportsView()
                            .environmentObject(data)
                    } label: {
                        MoreRow(
                            icon: "chart.bar.fill",
                            color: "27AE60",
                            title: "Annual Report",
                            subtitle: "Income & expense summary"
                        )
                    }
                }

                // MARK: - Account
                Section("Account") {
                    // User info row
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "1A3A6B"), Color(hex: "2E6DB4")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 42, height: 42)
                            Text(auth.ownerName.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.ownerName)
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 4) {
                                Text(auth.ownerRole.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if auth.isLifetimeFree {
                                    Text("· Lifetime")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(Color(hex: "27AE60"))
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)

                    // Face ID management
                    if BiometricAuthManager.shared.isAvailable {
                        if BiometricAuthManager.shared.hasStoredCredentials {
                            Button(role: .destructive) {
                                BiometricAuthManager.shared.deleteCredentials()
                            } label: {
                                Label(
                                    BiometricAuthManager.shared.biometricType == .faceID
                                        ? "Disable Face ID Login"
                                        : "Disable Touch ID Login",
                                    systemImage: BiometricAuthManager.shared.biometricType == .faceID
                                        ? "faceid" : "touchid"
                                )
                            }
                        }
                    }

                    // Sign out
                    Button(role: .destructive) {
                        auth.logout()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    // Delete account — required by App Store Review Guideline 5.1.1(v)
                    Button(role: .destructive) {
                        showDeleteAccount = true
                    } label: {
                        Label("Delete Account", systemImage: "trash.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if data.properties.isEmpty       { data.loadProperties() }
                if data.leases.isEmpty           { data.loadLeases()    }
                if data.damages.isEmpty          { data.loadDamages()   }
                if data.electricityBills.isEmpty { data.loadElectricityBills() }
            }
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountView().environmentObject(auth)
            }
        }
    }
}

// MARK: - Simple row label (not a NavigationLink itself)

struct MoreRow: View {
    let icon: String
    let color: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(hex: color))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    MoreView()
        .environmentObject(AuthManager.shared)
        .environmentObject(DataService.shared)
}
