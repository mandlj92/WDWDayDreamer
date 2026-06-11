import SwiftUI

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) var theme: Theme

    var body: some View {
        NavigationView {
            List {
                Section(header: SectionHeader(title: "FAQ", theme: theme)) {
                    Text("How do I reset my password?")
                        .font(DesignSystem.Typography.body)
                    Text("How do I pair with a partner?")
                        .font(DesignSystem.Typography.body)
                    Text("How is my data used?")
                        .font(DesignSystem.Typography.body)
                }
                .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))

                Section(header: SectionHeader(title: "Contact", theme: theme)) {
                    Link("Email support", destination: URL(string: "mailto:support@parkdaydreams.com")!)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(theme.primaryBlue)
                    Link("Privacy policy", destination: URL(string: "https://parkdaydreams.com/privacy")!)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(theme.primaryBlue)
                }
                .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.primaryBlue)
                }
            }
        }
    }
}

#Preview {
    SupportView()
        .environment(\.theme, LightTheme())
}
