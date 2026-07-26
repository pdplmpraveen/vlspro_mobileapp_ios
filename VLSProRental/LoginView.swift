import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var email        = ""
    @State private var password     = ""
    @State private var showPassword = false
    @State private var showSignup   = false
    @FocusState private var focusedField: Field?

    private let bio = BiometricAuthManager.shared

    enum Field { case email, password }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "1A3A6B"), Color(hex: "2E6DB4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.18))
                                .frame(width: 88, height: 88)
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        Text("VLSPro Rental")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Property Management")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .padding(.top, 72)
                    .padding(.bottom, 44)

                    // Login card
                    VStack(spacing: 20) {
                        Text("Welcome Back")
                            .font(.title2.bold())
                            .foregroundColor(Color(hex: "1A3A6B"))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(Color(hex: "2E6DB4"))
                                    .frame(width: 20)
                                TextField("Enter email address", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                            }
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(Color(hex: "2E6DB4"))
                                    .frame(width: 20)
                                Group {
                                    if showPassword {
                                        TextField("Enter password", text: $password)
                                    } else {
                                        SecureField("Enter password", text: $password)
                                    }
                                }
                                .focused($focusedField, equals: .password)
                                .submitLabel(.done)
                                .onSubmit { attemptLogin() }
                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Error
                        if !auth.errorMessage.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(auth.errorMessage).font(.caption)
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Login button
                        Button(action: attemptLogin) {
                            ZStack {
                                if auth.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Login")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "1A3A6B"), Color(hex: "2E6DB4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                        }
                        .disabled(auth.isLoading || email.isEmpty || password.isEmpty)
                        .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1)

                        // Face ID / Touch ID button
                        if bio.isAvailable && bio.hasStoredCredentials {
                            VStack(spacing: 14) {
                                HStack {
                                    Rectangle().frame(height: 0.5)
                                        .foregroundColor(Color(.separator).opacity(0.5))
                                    Text("or")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                    Rectangle().frame(height: 0.5)
                                        .foregroundColor(Color(.separator).opacity(0.5))
                                }

                                Button(action: loginWithBiometric) {
                                    HStack(spacing: 10) {
                                        Image(systemName: bio.biometricType == .faceID
                                              ? "faceid" : "touchid")
                                            .font(.system(size: 22))
                                        Text(bio.biometricType == .faceID
                                             ? "Login with Face ID"
                                             : "Login with Touch ID")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundColor(Color(hex: "1A3A6B"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(hex: "1A3A6B").opacity(0.08))
                                    .cornerRadius(14)
                                }
                                .disabled(auth.isLoading)
                            }
                        }

                        // Trouble logging in? — opens mail app pre-addressed to support
                        if let supportMailURL {
                            Link(destination: supportMailURL) {
                                HStack(spacing: 6) {
                                    Image(systemName: "envelope.fill")
                                        .font(.caption)
                                    Text("Trouble logging in? Contact Support")
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundColor(Color(hex: "2E6DB4"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                        }
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
                    .padding(.horizontal, 24)

                    // Create Account
                    Button {
                        showSignup = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("New to VLSPro?")
                                .foregroundColor(.white.opacity(0.75))
                            Text("Create Account")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .onTapGesture { focusedField = nil }
        .fullScreenCover(isPresented: $showSignup) {
            SignupView().environmentObject(auth)
        }
    }

    // MARK: - Support Contact

    /// mailto: link pre-filled with a login-issue subject/body, sent to support.
    /// Includes whatever email the user typed so we know which account to look up.
    private var supportMailURL: URL? {
        var comps = URLComponents(string: "mailto:publicshreyaspraveen@gmail.com")
        let bodyLines = [
            "Hi,",
            "",
            "I'm having trouble logging into the VLSPro Rental app.",
            "",
            "Email I'm trying to log in with: \(email.isEmpty ? "(enter here)" : email)",
            "What's happening: ",
        ]
        comps?.queryItems = [
            URLQueryItem(name: "subject", value: "VLSPro Rental — Login Issue"),
            URLQueryItem(name: "body", value: bodyLines.joined(separator: "\n")),
        ]
        return comps?.url
    }

    // MARK: - Actions

    private func attemptLogin() {
        focusedField = nil
        auth.login(email: email, password: password)
    }

    private func loginWithBiometric() {
        Task { @MainActor in
            let success = await bio.authenticate()
            guard success, let creds = bio.getCredentials() else { return }
            auth.login(email: creds.email, password: creds.password)
        }
    }
}

#Preview {
    LoginView().environmentObject(AuthManager())
}
