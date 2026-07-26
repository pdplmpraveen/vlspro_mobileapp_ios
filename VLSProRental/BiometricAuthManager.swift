import LocalAuthentication
import Security

/// Handles Face ID / Touch ID authentication and secure Keychain credential storage.
class BiometricAuthManager {
    static let shared = BiometricAuthManager()

    private let keychainService = "in.co.vlspro.rental"
    private let keychainAccount = "vlspro_biometric_credentials"

    // MARK: - Capability Checks

    /// Returns the biometric type available on this device (.faceID, .touchID, or .none)
    var biometricType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    /// True if Face ID or Touch ID is available and enrolled on this device
    var isAvailable: Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// True if login credentials have been saved to the Keychain for biometric login
    var hasStoredCredentials: Bool {
        return getCredentials() != nil
    }

    // MARK: - Biometric Authentication

    /// Prompts Face ID / Touch ID. Returns true on success.
    func authenticate() async -> Bool {
        let ctx = LAContext()
        let reason = biometricType == .faceID
            ? "Use Face ID to log in to VLSPro Rental"
            : "Use Touch ID to log in to VLSPro Rental"
        do {
            return try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                localizedReason: reason)
        } catch {
            print("[Biometric] Auth error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Keychain (Credential Storage)

    /// Saves email + password securely to the device Keychain.
    func saveCredentials(email: String, password: String) {
        let combined = "\(email)||||\(password)"  // unique separator to handle passwords with special chars
        guard let data = combined.data(using: .utf8) else { return }

        // Remove existing entry first
        deleteCredentials()

        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      keychainService,
            kSecAttrAccount as String:      keychainAccount,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Keychain] Save failed: \(status)")
        }
    }

    /// Retrieves stored credentials from Keychain. Returns nil if none exist.
    func getCredentials() -> (email: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  keychainService,
            kSecAttrAccount as String:  keychainAccount,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let combined = String(data: data, encoding: .utf8) else { return nil }

        let parts = combined.components(separatedBy: "||||")
        guard parts.count >= 2 else { return nil }
        return (email: parts[0], password: parts[1...].joined(separator: "||||"))
    }

    /// Removes stored credentials from Keychain (e.g. when user disables Face ID).
    func deleteCredentials() {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  keychainService,
            kSecAttrAccount as String:  keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
