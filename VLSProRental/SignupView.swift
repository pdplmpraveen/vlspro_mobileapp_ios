import SwiftUI

struct SignupView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var name        = ""
    @State private var email       = ""
    @State private var phone       = ""
    @State private var password    = ""
    @State private var confirmPwd  = ""
    @State private var showPwd     = false
    @State private var showConfirm = false
    @State private var localError  = ""
    @FocusState private var focused: Field?

    enum Field { case name, email, phone, password, confirm }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F4C3A"), Color(hex: "27AE60")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.18))
                                .frame(width: 80, height: 80)
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        Text("VLSPro Rental")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text("Create your account")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 64)
                    .padding(.bottom, 40)

                    // Form card
                    VStack(spacing: 18) {
                        Text("Get Started")
                            .font(.title2.bold())
                            .foregroundColor(Color(hex: "0F4C3A"))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Full Name
                        InputField(
                            label: "Full Name",
                            icon: "person.fill",
                            color: "27AE60",
                            placeholder: "Enter your full name",
                            text: $name,
                            focus: $focused,
                            tag: .name,
                            next: .email
                        )

                        // Email
                        InputField(
                            label: "Email Address",
                            icon: "envelope.fill",
                            color: "27AE60",
                            placeholder: "Enter email address",
                            text: $email,
                            focus: $focused,
                            tag: .email,
                            next: .phone,
                            keyboard: .emailAddress
                        )

                        // Phone
                        InputField(
                            label: "Phone Number",
                            icon: "phone.fill",
                            color: "27AE60",
                            placeholder: "Enter phone number (optional)",
                            text: $phone,
                            focus: $focused,
                            tag: .phone,
                            next: .password,
                            keyboard: .phonePad
                        )

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(Color(hex: "27AE60"))
                                    .frame(width: 20)
                                Group {
                                    if showPwd {
                                        TextField("Minimum 6 characters", text: $password)
                                    } else {
                                        SecureField("Minimum 6 characters", text: $password)
                                    }
                                }
                                .focused($focused, equals: .password)
                                .submitLabel(.next)
                                .onSubmit { focused = .confirm }
                                Button { showPwd.toggle() } label: {
                                    Image(systemName: showPwd ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Confirm Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(Color(hex: "27AE60"))
                                    .frame(width: 20)
                                Group {
                                    if showConfirm {
                                        TextField("Re-enter password", text: $confirmPwd)
                                    } else {
                                        SecureField("Re-enter password", text: $confirmPwd)
                                    }
                                }
                                .focused($focused, equals: .confirm)
                                .submitLabel(.done)
                                .onSubmit { attemptSignup() }
                                Button { showConfirm.toggle() } label: {
                                    Image(systemName: showConfirm ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Error message
                        let error = localError.isEmpty ? auth.errorMessage : localError
                        if !error.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(error).font(.caption)
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Create Account button
                        Button(action: attemptSignup) {
                            ZStack {
                                if auth.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Create Account")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "0F4C3A"), Color(hex: "27AE60")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                        }
                        .disabled(auth.isLoading || name.isEmpty || email.isEmpty || password.isEmpty)
                        .opacity((name.isEmpty || email.isEmpty || password.isEmpty) ? 0.6 : 1)

                        // Back to Login
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Already have an account?")
                                    .foregroundColor(.secondary)
                                Text("Sign In")
                                    .foregroundColor(Color(hex: "27AE60"))
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .onTapGesture { focused = nil }
    }

    private func attemptSignup() {
        focused = nil
        localError = ""

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            localError = "Please enter your full name."; return
        }
        guard email.contains("@") && email.contains(".") else {
            localError = "Please enter a valid email address."; return
        }
        guard password.count >= 6 else {
            localError = "Password must be at least 6 characters."; return
        }
        guard password == confirmPwd else {
            localError = "Passwords do not match."; return
        }

        auth.signup(name: name, email: email, phone: phone, password: password)
    }
}

// MARK: - Reusable Input Field

private struct InputField: View {
    let label: String
    let icon: String
    let color: String
    let placeholder: String
    @Binding var text: String
    var focus: FocusState<SignupView.Field?>.Binding
    let tag: SignupView.Field
    let next: SignupView.Field?
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: color))
                    .frame(width: 20)
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .autocapitalization(keyboard == .emailAddress ? .none : .words)
                    .autocorrectionDisabled()
                    .focused(focus, equals: tag)
                    .submitLabel(next != nil ? .next : .done)
                    .onSubmit { if let n = next { focus.wrappedValue = n } }
            }
            .padding(14)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    SignupView().environmentObject(AuthManager.shared)
}
