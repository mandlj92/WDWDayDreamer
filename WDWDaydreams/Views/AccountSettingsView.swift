import SwiftUI
import FirebaseAuth

struct AccountSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.theme) var theme: Theme
    @Environment(\.dismiss) private var dismiss

    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var showingDeleteConfirmation = false
    @State private var isExportingData = false
    @State private var exportError: String?
    @State private var exportFileURL: URL?
    @State private var showingShareSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundCream
                    .edgesIgnoringSafeArea(.all)

                Form {
                    Section(header: SectionHeader(title: "Account Information", theme: theme)) {
                        if let user = Auth.auth().currentUser {
                            LabeledFormRow(label: "Email", value: user.email ?? "Not available", theme: theme)
                            LabeledFormRow(label: "User ID", value: String(user.uid.prefix(8)) + "…", theme: theme)
                        }
                    }
                    .listRowBackground(theme.cardBackground)

                    Section(header: SectionHeader(title: "Privacy & Legal", theme: theme)) {
                        Button(action: { showingPrivacyPolicy = true }) {
                            Text("Privacy Policy")
                                .foregroundColor(theme.primaryText)
                        }

                        Button(action: { showingTermsOfService = true }) {
                            Text("Terms of Service")
                                .foregroundColor(theme.primaryText)
                        }
                    }
                    .listRowBackground(theme.cardBackground)

                    Section(
                        header: SectionHeader(title: "Your Data", theme: theme),
                        footer: Text("Download a copy of all your data including stories, partnerships, and settings.")
                            .font(DesignSystem.Typography.meta)
                            .foregroundColor(theme.tertiaryText)
                    ) {
                        Button(action: exportUserData) {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                if isExportingData {
                                    ProgressView().scaleEffect(0.8)
                                }
                                Text("Download My Data")
                            }
                            .foregroundColor(theme.primaryBlue)
                        }
                        .disabled(isExportingData)

                        if let error = exportError {
                            Text(error)
                                .font(DesignSystem.Typography.subtext)
                                .foregroundColor(theme.accentRed)
                        }
                    }
                    .listRowBackground(theme.cardBackground)

                    Section(
                        header: SectionHeader(title: "Danger Zone", theme: theme, color: theme.accentRed),
                        footer: Text("Account deletion is permanent. All your stories, partnerships, and data will be permanently deleted.")
                            .font(DesignSystem.Typography.meta)
                            .foregroundColor(theme.tertiaryText)
                    ) {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("Delete Account")
                        }
                    }
                    .listRowBackground(theme.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.primaryBlue)
                }
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            LegalDocumentView(documentType: .privacyPolicy)
        }
        .sheet(isPresented: $showingTermsOfService) {
            LegalDocumentView(documentType: .termsOfService)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let fileURL = exportFileURL {
                ShareSheet(items: [fileURL])
            }
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This action cannot be undone. All your stories, partnerships, and data will be permanently deleted.")
        }
    }

    private func exportUserData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            exportError = "User not authenticated"
            return
        }

        isExportingData = true
        exportError = nil

        Task {
            do {
                let dataExportService = DataExportService()
                let exportData = try await dataExportService.exportUserData(userId: userId)
                let fileURL = try dataExportService.generateJSONFile(export: exportData)

                await MainActor.run {
                    exportFileURL = fileURL
                    showingShareSheet = true
                    isExportingData = false
                }
            } catch {
                await MainActor.run {
                    exportError = "Error exporting data: \(error.localizedDescription)"
                    isExportingData = false
                }
            }
        }
    }

    private func deleteAccount() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        Task {
            do {
                let dataExportService = DataExportService()
                try await dataExportService.deleteUserData(userId: userId)
                try await Auth.auth().currentUser?.delete()

                await MainActor.run {
                    try? Auth.auth().signOut()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    exportError = "Error deleting account: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Labeled Form Row

/// A label/value pair for use inside a Form — no HStack boilerplate at each call site.
private struct LabeledFormRow: View {
    let label: String
    let value: String
    let theme: Theme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundColor(theme.primaryText)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.subtext)
                .foregroundColor(theme.secondaryText)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    AccountSettingsView()
        .environmentObject(AuthViewModel())
}
