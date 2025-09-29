import Foundation
import SwiftUI

@MainActor
class PalsViewModel: ObservableObject {
    @Published var partnerships: [StoryPartnership] = []
    @Published var partnerProfiles: [String: UserProfile] = [:] // Map of userId to profile
    @Published var myInvitations: [PalInvitation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var generatedInviteCode: String?

    private let palsService = PalsService()
    private let userService = UserService()

    // MARK: - Load Data

    func loadPartnerships(for userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            partnerships = try await palsService.getUserPartnerships(userId: userId)

            // Load partner profiles
            for partnership in partnerships {
                if let partnerId = partnership.getPartnerId(for: userId) {
                    if partnerProfiles[partnerId] == nil {
                        if let profile = try await userService.getUserProfile(userId: partnerId) {
                            partnerProfiles[partnerId] = profile
                        }
                    }
                }
            }

            print("✅ Loaded \(partnerships.count) partnerships")
        } catch {
            errorMessage = "Failed to load story pals: \(error.localizedDescription)"
            print("❌ Error loading partnerships: \(error)")
        }

        isLoading = false
    }

    func loadMyInvitations(for userId: String) async {
        do {
            myInvitations = try await palsService.getUserInvitations(userId: userId)
            print("✅ Loaded \(myInvitations.count) invitations")
        } catch {
            print("❌ Error loading invitations: \(error)")
        }
    }

    // MARK: - Create Invitation

    func createInvitation(fromUser: UserProfile) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let invitation = try await palsService.createInvitation(fromUser: fromUser)
            generatedInviteCode = invitation.invitationCode
            myInvitations.insert(invitation, at: 0)
            successMessage = "Invitation created! Share code: \(invitation.invitationCode)"
            print("✅ Created invitation with code: \(invitation.invitationCode)")
        } catch {
            errorMessage = "Failed to create invitation: \(error.localizedDescription)"
            print("❌ Error creating invitation: \(error)")
        }

        isLoading = false
    }

    // MARK: - Accept Invitation

    func acceptInvitation(code: String, userId: String, userName: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            guard let invitation = try await palsService.getInvitationByCode(code) else {
                errorMessage = "Invalid or expired invitation code"
                isLoading = false
                return
            }

            if invitation.fromUserId == userId {
                errorMessage = "You cannot accept your own invitation"
                isLoading = false
                return
            }

            if invitation.isExpired {
                errorMessage = "This invitation has expired"
                isLoading = false
                return
            }

            let partnership = try await palsService.acceptInvitation(invitation, byUser: userId)
            partnerships.append(partnership)

            // Load partner profile
            if let profile = try await userService.getUserProfile(userId: invitation.fromUserId) {
                partnerProfiles[invitation.fromUserId] = profile
            }

            successMessage = "Successfully connected with \(invitation.fromUserName)!"
            print("✅ Accepted invitation and created partnership")

            // Trigger haptic feedback
            HapticManager.instance.notification(type: .success)

        } catch {
            errorMessage = "Failed to accept invitation: \(error.localizedDescription)"
            print("❌ Error accepting invitation: \(error)")

            // Trigger haptic feedback
            HapticManager.instance.notification(type: .error)
        }

        isLoading = false
    }

    // MARK: - Remove Partnership

    func removePartnership(_ partnership: StoryPartnership, currentUserId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await palsService.removePartnership(
                partnership.id,
                user1Id: partnership.user1Id,
                user2Id: partnership.user2Id
            )

            partnerships.removeAll { $0.id == partnership.id }

            if let partnerId = partnership.getPartnerId(for: currentUserId) {
                partnerProfiles.removeValue(forKey: partnerId)
            }

            successMessage = "Story Pal removed"
            print("✅ Removed partnership")

            // Trigger haptic feedback
            HapticManager.instance.notification(type: .success)

        } catch {
            errorMessage = "Failed to remove story pal: \(error.localizedDescription)"
            print("❌ Error removing partnership: \(error)")

            // Trigger haptic feedback
            HapticManager.instance.notification(type: .error)
        }

        isLoading = false
    }

    // MARK: - Helper Methods

    func getPartnerName(for partnership: StoryPartnership, currentUserId: String) -> String {
        guard let partnerId = partnership.getPartnerId(for: currentUserId),
              let profile = partnerProfiles[partnerId] else {
            return "Unknown"
        }
        return profile.displayName
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
        generatedInviteCode = nil
    }
}
