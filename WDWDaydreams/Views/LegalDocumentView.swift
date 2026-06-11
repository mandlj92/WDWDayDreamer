import SwiftUI

struct LegalDocumentView: View {
    let documentType: DocumentType
    @Environment(\.dismiss) private var dismiss

    enum DocumentType {
        case privacyPolicy
        case termsOfService

        var title: String {
            switch self {
            case .privacyPolicy: return "Privacy Policy"
            case .termsOfService: return "Terms of Service"
            }
        }

        var filename: String {
            switch self {
            case .privacyPolicy: return "PRIVACY_POLICY"
            case .termsOfService: return "TERMS_OF_SERVICE"
            }
        }
    }

    @State private var documentContent: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Unable to load document")
                            .font(DesignSystem.Typography.sectionTitle)

                        Text(error)
                            .font(DesignSystem.Typography.subtext)
                            .foregroundColor(.secondary)
                    }
                    .padding(DesignSystem.Spacing.pageMargin)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ScrollView {
                        Text(documentContent)
                            .font(.system(size: 14))
                            .padding(DesignSystem.Spacing.pageMargin)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle(documentType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { loadDocument() }
    }

    private func loadDocument() {
        isLoading = true
        errorMessage = nil

        if let filepath = Bundle.main.path(forResource: documentType.filename, ofType: "md") {
            do {
                documentContent = try String(contentsOfFile: filepath, encoding: .utf8)
                isLoading = false
            } catch {
                errorMessage = "Error reading document: \(error.localizedDescription)"
                isLoading = false
            }
        } else {
            documentContent = placeholderContent
            isLoading = false
        }
    }

    private var placeholderContent: String {
        switch documentType {
        case .privacyPolicy:
            return "# Privacy Policy\n\nOur Privacy Policy is being updated. Please check back soon or contact us for more information."
        case .termsOfService:
            return "# Terms of Service\n\nOur Terms of Service are being updated. Please check back soon or contact us for more information."
        }
    }
}

#Preview("Privacy Policy") {
    LegalDocumentView(documentType: .privacyPolicy)
}

#Preview("Terms of Service") {
    LegalDocumentView(documentType: .termsOfService)
}
