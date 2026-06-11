import SwiftUI

/// View for reporting inappropriate content
struct ReportContentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var moderationService = ModerationService()

    let reportedUserId: String
    let contentType: ContentReport.ContentType
    let contentId: String

    @State private var selectedReason: ContentReport.ReportReason = .inappropriate
    @State private var details: String = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Help us understand what's wrong with this content.")
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section("Reason") {
                    Picker("Select a reason", selection: $selectedReason) {
                        ForEach(ContentReport.ReportReason.allCases, id: \.self) { reason in
                            Text(reason.description).tag(reason)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Additional Details (Optional)") {
                    TextEditor(text: $details)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                }

                Section {
                    Text("Your report will be reviewed by our moderation team. False reports may result in account restrictions.")
                        .font(DesignSystem.Typography.meta)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Submit") { submitReport() }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thank you. Our moderation team will review your report shortly.")
            }
        }
    }

    private func submitReport() {
        isSubmitting = true

        Task {
            do {
                try await moderationService.reportContent(
                    reportedUserId: reportedUserId,
                    contentType: contentType,
                    contentId: contentId,
                    reason: selectedReason,
                    details: details.isEmpty ? nil : details
                )

                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
