// StoryDraftManager.swift
import Foundation

class StoryDraftManager {
    static let shared = StoryDraftManager()
    private let userDefaults = UserDefaults.standard
    private let draftPrefix = "story_draft_"

    private init() {}

    /// Save a draft for a specific story
    func saveDraft(text: String, forStoryId storyId: UUID) {
        let key = draftPrefix + storyId.uuidString
        userDefaults.set(text, forKey: key)
        userDefaults.set(Date(), forKey: key + "_timestamp")
        print("💾 Draft saved for story: \(storyId)")
    }

    /// Load a draft for a specific story
    /// Returns nil if no draft exists or if draft is older than 7 days
    func loadDraft(forStoryId storyId: UUID) -> String? {
        let key = draftPrefix + storyId.uuidString

        // Check if draft is recent (within 7 days)
        if let timestamp = userDefaults.object(forKey: key + "_timestamp") as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: timestamp, to: Date()).day ?? 0
            if daysSince > 7 {
                // Draft too old, delete it
                print("🗑️ Draft too old (\(daysSince) days), deleting for story: \(storyId)")
                deleteDraft(forStoryId: storyId)
                return nil
            }
        }

        if let draft = userDefaults.string(forKey: key) {
            print("📄 Draft loaded for story: \(storyId)")
            return draft
        }

        return nil
    }

    /// Delete a draft for a specific story
    func deleteDraft(forStoryId storyId: UUID) {
        let key = draftPrefix + storyId.uuidString
        userDefaults.removeObject(forKey: key)
        userDefaults.removeObject(forKey: key + "_timestamp")
        print("🗑️ Draft deleted for story: \(storyId)")
    }

    /// Check if a draft exists for a specific story
    func hasDraft(forStoryId storyId: UUID) -> Bool {
        return loadDraft(forStoryId: storyId) != nil
    }

    /// Get the timestamp when a draft was last saved
    func getDraftTimestamp(forStoryId storyId: UUID) -> Date? {
        let key = draftPrefix + storyId.uuidString + "_timestamp"
        return userDefaults.object(forKey: key) as? Date
    }

    /// Clear all old drafts (older than 7 days)
    func cleanupOldDrafts() {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let draftKeys = allKeys.filter { $0.hasPrefix(draftPrefix) && !$0.hasSuffix("_timestamp") }

        for key in draftKeys {
            if let timestamp = userDefaults.object(forKey: key + "_timestamp") as? Date {
                let daysSince = Calendar.current.dateComponents([.day], from: timestamp, to: Date()).day ?? 0
                if daysSince > 7 {
                    userDefaults.removeObject(forKey: key)
                    userDefaults.removeObject(forKey: key + "_timestamp")
                    print("🧹 Cleaned up old draft: \(key)")
                }
            }
        }
    }
}