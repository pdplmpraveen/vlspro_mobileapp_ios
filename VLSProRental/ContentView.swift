import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var store: StoreKitManager

    /// True when this account has full app access (subscribed OR lifetime free).
    private var hasAccess: Bool {
        auth.isLifetimeFree || store.isSubscribed
    }

    var body: some View {
        Group {
            if !auth.isLoggedIn {
                LoginView()
            } else if store.isLoading && !auth.isLifetimeFree {
                // StoreKit is verifying entitlements (skip wait for lifetime accounts)
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.2)
                    Text("Checking subscription…")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
            } else if hasAccess {
                MainTabView()
            } else {
                SubscriptionPaywallView()
            }
        }
        // Face ID setup offer — shown once after first login/signup on a new device
        .alert(
            biometricOfferTitle,
            isPresented: $auth.showBiometricOffer
        ) {
            Button("Enable") { auth.resolveBiometricOffer(accept: true) }
            Button("Not Now", role: .cancel) { auth.resolveBiometricOffer(accept: false) }
        } message: {
            Text("Your credentials are stored securely in the iOS Keychain and protected by your device.")
        }
    }

    private var biometricOfferTitle: String {
        BiometricAuthManager.shared.biometricType == .faceID
            ? "Enable Face ID Login?"
            : "Enable Touch ID Login?"
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(StoreKitManager.shared)
}
