// RemoteContentService.swift
//
// Fetches prompt content packs from Firestore (/contentPacks/{packId}),
// replacing the hardcoded lists in DataModel.swift over time.
//
// Pack documents are seeded via scripts/seed-content.mjs and are read-only
// for clients (see firestore.rules). Falls back to DataModel.shared's
// compiled-in lists whenever the remote pack is unavailable (offline first
// launch, fetch error), so prompt generation never breaks.
//
// NOTE: This file was added outside Xcode - drag it into the Services group
// in the Xcode project navigator (or re-add via File > Add Files) so it is
// included in the build target.

import Foundation
import FirebaseFirestore

struct ContentPack: Codable {
    let id: String
    let name: String
    let description: String
    let isFree: Bool
    let version: Int
    let categories: [String: [String]]

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let id = data["id"] as? String,
              let name = data["name"] as? String,
              let description = data["description"] as? String,
              let isFree = data["isFree"] as? Bool,
              let version = data["version"] as? Int,
              let categories = data["categories"] as? [String: [String]]
        else { return nil }

        self.id = id
        self.name = name
        self.description = description
        self.isFree = isFree
        self.version = version
        self.categories = categories
    }
}

@MainActor
final class RemoteContentService: ObservableObject {
    static let shared = RemoteContentService()

    static let basePackId = "wdw-base"

    @Published private(set) var activePack: ContentPack?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private init() {}

    /// Start listening for content pack updates. Firestore's offline cache
    /// serves the last-known pack immediately; live updates arrive when online.
    func start(packId: String = RemoteContentService.basePackId) {
        guard listener == nil else { return }
        listener = db.collection("contentPacks").document(packId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("⚠️ Content pack fetch failed, using bundled content: \(error)")
                    return
                }
                guard let snapshot = snapshot, let pack = ContentPack(document: snapshot) else {
                    print("⚠️ Content pack \(packId) missing/malformed, using bundled content")
                    return
                }
                self?.activePack = pack
                print("✅ Content pack loaded: \(pack.name) v\(pack.version)")
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    /// Items for a category - remote pack first, bundled DataModel fallback.
    func list(for category: Category) -> [String] {
        if let remote = activePack?.categories[category.rawValue], !remote.isEmpty {
            return remote
        }
        return DataModel.shared.list(for: category)
    }

    func randomItem(for category: Category) -> String? {
        return list(for: category).randomElement()
    }
}
