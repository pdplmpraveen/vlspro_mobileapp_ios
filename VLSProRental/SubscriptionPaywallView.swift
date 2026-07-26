import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @EnvironmentObject var store: StoreKitManager
    @EnvironmentObject var auth: AuthManager

    var monthlyProduct: Product? { store.products.first }

    /// The 2-month free trial offer attached to the monthly plan (nil if none configured).
    private var introOffer: Product.SubscriptionOffer? {
        monthlyProduct?.subscription?.introductoryOffer
    }

    /// "2 Months Free" — nil if there's no trial offer, or this Apple ID already used it.
    private var trialText: String? {
        guard store.isEligibleForIntroOffer,
              let offer = introOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let count = offer.period.value
        let unitName: String
        switch offer.period.unit {
        case .day:   unitName = "Day"
        case .week:  unitName = "Week"
        case .month: unitName = "Month"
        case .year:  unitName = "Year"
        @unknown default: unitName = "Period"
        }
        return "\(count) \(unitName)\(count == 1 ? "" : "s") Free"
    }

    private let features: [(icon: String, color: String, text: String)] = [
        ("chart.bar.fill",               "2E6DB4", "Dashboard & Revenue Analytics"),
        ("person.2.fill",                "8E44AD", "Unlimited Tenant Management"),
        ("indianrupeesign.circle.fill",  "27AE60", "Rent & Payment Tracking"),
        ("cart.fill",                    "E74C3C", "Expense Management"),
        ("building.2.fill",              "1A3A6B", "Properties & Lease Management"),
        ("wrench.and.screwdriver.fill",  "E67E22", "Damage & Repair Reports"),
        ("doc.text.fill",                "16A085", "Annual Financial Reports"),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                headerSection
                VStack(spacing: 20) {
                    featuresCard
                    planCard
                    ctaButtons
                    legalFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button("Sign Out") { auth.logout() }
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.85))
                .padding(.top, 56)
                .padding(.trailing, 20)
        }
    }

    // MARK: - Header

    var headerSection: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 52)

            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 88, height: 88)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text("VLSPro Rental")
                    .font(.title.bold())
                    .foregroundColor(.white)
                Text("Professional Property Management")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }

            Text("Unlock full access to manage your\nproperties, tenants & finances.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "0F2952"), Color(hex: "2E6DB4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Features Card

    var featuresCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What's included")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.bottom, 14)

            ForEach(Array(features.enumerated()), id: \.element.text) { i, feature in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color(hex: feature.color).opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: feature.icon)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: feature.color))
                    }
                    Text(feature.text)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "27AE60"))
                        .font(.system(size: 16))
                }
                .padding(.vertical, 8)

                if i < features.count - 1 {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Plan Card

    var planCard: some View {
        VStack(spacing: 0) {
            if let trialText {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 12))
                    Text(trialText + " — then \(monthlyProduct?.displayPrice ?? "₹1,500")/month")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(hex: "27AE60"))
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Monthly Plan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(hex: "1A3A6B"))

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(monthlyProduct?.displayPrice ?? "₹1,500")
                            .font(.title2.bold())
                            .foregroundColor(Color(hex: "1A3A6B"))
                        Text("/ month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(trialText != nil
                         ? "No charge today · Cancel anytime during trial"
                         : "Auto-renews monthly · Cancel anytime")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color(hex: "1A3A6B").opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: trialText != nil ? "gift.fill" : "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "1A3A6B"))
                }
            }
            .padding(18)
        }
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "1A3A6B").opacity(0.25), lineWidth: 1.5)
        )
        .shadow(color: Color(hex: "1A3A6B").opacity(0.08), radius: 8, y: 2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - CTA Buttons

    var ctaButtons: some View {
        VStack(spacing: 14) {
            // Error message
            if !store.errorMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(store.errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 4)
            }

            // Subscribe button
            Button {
                guard let product = monthlyProduct else { return }
                Task { await store.purchase(product) }
            } label: {
                Group {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    } else if let trialText {
                        Text("Start \(trialText)")
                            .font(.headline)
                    } else {
                        Text(monthlyProduct != nil
                             ? "Subscribe · \(monthlyProduct!.displayPrice)/month"
                             : "Subscribe · ₹1,500/month")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Group {
                        if store.isPurchasing || monthlyProduct == nil {
                            AnyView(Color.gray)
                        } else {
                            AnyView(
                                LinearGradient(
                                    colors: [Color(hex: "0F2952"), Color(hex: "2E6DB4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        }
                    }
                )
                .cornerRadius(14)
            }
            .disabled(store.isPurchasing || monthlyProduct == nil)

            // Restore
            Button {
                Task { await store.restore() }
            } label: {
                Text("Restore Purchase")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "2E6DB4"))
            }
            .disabled(store.isPurchasing)
        }
    }

    // MARK: - Legal Footer

    private var legalFooterText: String {
        let price = monthlyProduct?.displayPrice ?? "₹1,500"
        if let trialText {
            return "New subscribers get \(trialText.lowercased()). After the trial, you'll be charged \(price)/month unless you cancel at least 24 hours before the trial ends. Subscription automatically renews for the same price until cancelled. Manage or cancel in iPhone Settings → Apple ID → Subscriptions."
        }
        return "Payment will be charged to your Apple ID account upon confirmation. Subscription automatically renews for the same price unless cancelled at least 24 hours before the end of the current period. Manage or cancel in iPhone Settings → Apple ID → Subscriptions."
    }

    var legalFooter: some View {
        VStack(spacing: 10) {
            Text(legalFooterText)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 20) {
                Link("Terms of Use",
                     destination: URL(string: "https://vlspro.co.in/vlspro-rental/terms.php")!)
                Link("Privacy Policy",
                     destination: URL(string: "https://vlspro.co.in/vlspro-rental/privacy.php")!)
            }
            .font(.caption2.weight(.medium))
            .foregroundColor(Color(hex: "2E6DB4"))
        }
        .padding(.top, 4)
    }
}

#Preview {
    SubscriptionPaywallView()
        .environmentObject(StoreKitManager.shared)
        .environmentObject(AuthManager.shared)
}
