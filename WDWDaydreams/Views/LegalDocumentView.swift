//
//  LegalDocumentView.swift
//  WDWDaydreams
//
//  Created on 12/5/2025.
//

import SwiftUI

struct LegalDocumentView: View {
    let documentType: DocumentType
    @Environment(\.dismiss) private var dismiss

    enum DocumentType {
        case privacyPolicy
        case termsOfService

        var title: String {
            switch self {
            case .privacyPolicy:
                return "Privacy Policy"
            case .termsOfService:
                return "Terms of Service"
            }
        }

        var filename: String {
            switch self {
            case .privacyPolicy:
                return "PRIVACY_POLICY"
            case .termsOfService:
                return "TERMS_OF_SERVICE"
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
                    ProgressView("Loading...")
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)

                        Text("Unable to load document")
                            .font(.headline)

                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(documentContent)
                                .font(.system(size: 14))
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle(documentType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadDocument()
        }
    }

    private func loadDocument() {
        isLoading = true
        errorMessage = nil

        // Try to load from bundle first
        if let filepath = Bundle.main.path(forResource: documentType.filename, ofType: "md") {
            do {
                let contents = try String(contentsOfFile: filepath, encoding: .utf8)
                documentContent = contents
                isLoading = false
            } catch {
                errorMessage = "Error reading document: \(error.localizedDescription)"
                isLoading = false
            }
        } else {
            // Fallback to placeholder text if file not found
            documentContent = getPlaceholderContent()
            isLoading = false
        }
    }

    private func getPlaceholderContent() -> String {
        switch documentType {
        case .privacyPolicy:
            return """
            # Privacy Policy

            Our Privacy Policy is being updated. Please check back soon or contact us for more information.
            """
        case .termsOfService:
            return """
            # Terms of Service

            Our Terms of Service are being updated. Please check back soon or contact us for more information.
            """
        }
    }
}

#Preview("Privacy Policy") {
    LegalDocumentView(documentType: .privacyPolicy)
}

#Preview("Terms of Service") {
    LegalDocumentView(documentType: .termsOfService)
}
