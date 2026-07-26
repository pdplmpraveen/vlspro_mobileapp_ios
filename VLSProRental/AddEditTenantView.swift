import SwiftUI

struct AddEditTenantView: View {
    var tenant: Tenant? = nil          // nil = Add mode, non-nil = Edit mode

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var data: DataService

    @State private var name        = ""
    @State private var phone       = ""
    @State private var email       = ""
    @State private var whatsapp    = ""
    @State private var isActive    = true
    @State private var isSubmitting = false
    @State private var errorMessage = ""

    var isEditing: Bool { tenant != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(Color(hex: "2E6DB4")).frame(width: 20)
                        TextField("Full Name", text: $name)
                            .autocorrectionDisabled()
                    }
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(Color(hex: "2E6DB4")).frame(width: 20)
                        TextField("Phone Number", text: $phone)
                            .keyboardType(.phonePad)
                    }
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(Color(hex: "2E6DB4")).frame(width: 20)
                        TextField("Email (optional)", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(Color(hex: "27AE60")).frame(width: 20)
                        TextField("WhatsApp Number (optional)", text: $whatsapp)
                            .keyboardType(.phonePad)
                    }
                } header: {
                    Text("Tenant Details")
                }

                if isEditing {
                    Section {
                        Toggle(isOn: $isActive) {
                            Label("Active Tenant", systemImage: isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isActive ? Color(hex: "27AE60") : .secondary)
                        }
                        .tint(Color(hex: "27AE60"))
                    } header: {
                        Text("Status")
                    }
                }

                if !errorMessage.isEmpty {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                            Text(errorMessage).font(.caption).foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Tenant" : "Add Tenant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { save() } label: {
                        if isSubmitting {
                            ProgressView().tint(Color(hex: "27AE60"))
                        } else {
                            Text("Save").bold().foregroundColor(Color(hex: "27AE60"))
                        }
                    }
                    .disabled(isSubmitting || name.trimmingCharacters(in: .whitespaces).isEmpty
                                            || phone.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let t = tenant {
                    name     = t.name
                    phone    = t.phone
                    email    = t.email ?? ""
                    whatsapp = t.whatsapp_number ?? ""
                    isActive = t.is_active
                }
            }
        }
    }

    private func save() {
        errorMessage = ""
        let trimName  = name.trimmingCharacters(in: .whitespaces)
        let trimPhone = phone.trimmingCharacters(in: .whitespaces)
        guard !trimName.isEmpty, !trimPhone.isEmpty else {
            errorMessage = "Name and phone are required."
            return
        }

        var payload: [String: Any] = [
            "name":  trimName,
            "phone": trimPhone,
        ]
        let trimEmail    = email.trimmingCharacters(in: .whitespaces)
        let trimWhatsapp = whatsapp.trimmingCharacters(in: .whitespaces)
        if !trimEmail.isEmpty    { payload["email"]            = trimEmail    }
        if !trimWhatsapp.isEmpty { payload["whatsapp_number"]  = trimWhatsapp }

        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                if let t = tenant {
                    payload["is_active"] = isActive ? 1 : 0
                    try await data.editTenant(t.id, payload)
                } else {
                    try await data.addTenant(payload)
                }
                data.loadTenants()
                dismiss()
            } catch APIError.serverError(let msg) {
                errorMessage = msg
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
