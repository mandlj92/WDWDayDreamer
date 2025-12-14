import Foundation

class EditorStateManager: ObservableObject {
    static let shared = EditorStateManager()

    @Published var hasUnsavedStoryChanges = false

    private init() {}
}
