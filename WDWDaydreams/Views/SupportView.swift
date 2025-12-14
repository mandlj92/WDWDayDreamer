import SwiftUI

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) var theme: Theme

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("FAQ")) {
                    Text("How do I reset my password?")
                    Text("How do I pair with a partner?")
                    Text("How is my data used?")
                }

                Section(header: Text("Contact")) {
                    Link("Email support", destination: URL(string: "mailto:support@parkdaydreams.com")!)
                    Link("View privacy policy", destination: URL(string: "https://parkdaydreams.com/privacy")!)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Help & Support")
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
