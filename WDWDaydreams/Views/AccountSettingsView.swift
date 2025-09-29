//
//  AccountSettingsView.swift
//  WDWDaydreams
//
//  Created on 12/5/2025.
//

import SwiftUI
import FirebaseAuth

struct AccountSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.theme) var theme: Theme
    @Environment(\.dismiss) private var dismiss

    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var showingDataExport = false
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
                    // Account Information
                    Section(header: Text("Account Information").foregroundColor(theme.magicBlue)) {
                        if let user = Auth.auth().currentUser {
                            HStack {
                                Text("Email")
                                    .foregroundColor(theme.primaryText)
                                Spacer()
                                Text(user.email ?? "Not available")
                                    .foregroundColor(.gray)
                            }

                            HStack {
                                Text("User ID")
                                    .foregroundColor(theme.primaryText)
                                Spacer()
                                Text(user.uid.prefix(8) + "...")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                    }
                    .listRowBackground(theme.cardBackground)

                    // Privacy & Legal
                    Section(header: Text("Privacy & Legal").foregroundColor(theme.magicBlue)) {
                        Button(action: {
                            showingPrivacyPolicy = true
                        }) {
                            HStack {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(theme.magicBlue)
                                Text("Privacy Policy")
                                    .foregroundColor(theme.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }

                        Button(action: {
                            showingTermsOfService = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(theme.magicBlue)
                                Text("Terms of Service")
                                    .foregroundColor(theme.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                    }
                    .listRowBackground(theme.cardBackground)

                    // Your Data
                    Section(header: Text("Your Data").foregroundColor(theme.magicBlue),
                            footer: Text("Download a copy of all your data including stories, partnerships, and settings.")
                        .font(.caption)
                        .foregroundColor(.gray)) {
                        Button(action: {
                            exportUserData()
                        }) {
                            HStack {
                                if isExportingData {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .foregroundColor(theme.magicBlue)
                                }
                                Text("Download My Data")
                                    .foregroundColor(theme.primaryText)
                            }
                        }
                        .disabled(isExportingData)

                        if let error = exportError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .listRowBackground(theme.cardBackground)

                    // Danger Zone
                    Section(header: Text("Danger Zone").foregroundColor(theme.mickeyRed),
                            footer: Text("Account deletion is permanent and cannot be undone. All your stories, partnerships, and data will be permanently deleted.")
                        .font(.caption)
                        .foregroundColor(.gray)) {
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(theme.mickeyRed)
                                Text("Delete Account")
                                    .foregroundColor(theme.mickeyRed)
                                    .fontWeight(.semibold)
                            }
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
                    .foregroundColor(theme.magicBlue)
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
            Text("Are you sure you want to delete your account? This action cannot be undone. All your stories, partnerships, and data will be permanently deleted.")
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
                // Delete user data from Firestore
                let dataExportService = DataExportService()
                try await dataExportService.deleteUserData(userId: userId)

                // Delete Firebase Auth account
                try await Auth.auth().currentUser?.delete()

                // Sign out
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

// MARK: - Share Sheet for iOS

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    AccountSettingsView()
        .environmentObject(AuthViewModel())
}
