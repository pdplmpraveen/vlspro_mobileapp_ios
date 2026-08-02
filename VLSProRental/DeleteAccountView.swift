import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthManager

    @State private var password     = ""
    @State private var confirmText  = ""
    @State private var isSubmitting = false
    @State private var errorMessage = ""

    private var isValid: Bool {
        !password.isEmpty && confirmText.uppercased() == "DELETE"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("This permanently deletes your VLSPro Rental login — your name, email and phone are removed and you won't be able to sign back in. This can't be undone.")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    SecureField("Current password", text: $password)
                } header: {
                    Text("Confirm Password")
                }

                Section {
                    TextField("Type DELETE to confirm", text: $confirmText)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Type DELETE to confirm")
                }

                if !errorMessage.isEmpty {
                    Section {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage).font(.caption).foregroundColor(.red)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Permanently Delete My Account").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting || !isValid)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() {
        errorMessage = ""
        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await auth.deleteAccount(password: password)
                // auth.logout() (called inside deleteAccount) flips isLoggedIn to
                // false, which swaps ContentView back to LoginView and tears down
                // this sheet along with it — no explicit dismiss() needed.
            } catch APIError.serverError(let msg) {
                errorMessage = msg
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    DeleteAccountView().environmentObject(AuthManager.shared)
}
