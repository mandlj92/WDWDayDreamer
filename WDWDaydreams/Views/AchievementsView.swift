import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var manager: ScenarioManager
    @Environment(\.theme) var theme: Theme

    var body: some View {
        List {
            Section(header: Text("Your Achievements")) {
                ForEach(Badge.allBadges) { badge in
                    HStack(spacing: 12) {
                        Text(badge.icon)
                            .font(.system(size: 28))

                        VStack(alignment: .leading) {
                            Text(badge.name)
                                .font(.headline)
                            Text(badge.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if auth.userProfile?.achievements.contains(badge.id) ?? false {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Achievements")
    }
}

struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
            .environmentObject(AuthViewModel())
            .environmentObject(ScenarioManager())
            .environmentObject(ThemeManager())
    }
}
