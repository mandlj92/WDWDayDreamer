const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// ===== CONTENT MODERATION CONFIGURATION =====

// Profanity and inappropriate content patterns
const PROFANITY_PATTERNS = [
    // Common profanity (add more as needed)
    '\\bdamn\\b', '\\bhell\\b', '\\bcrap\\b', '\\bpiss\\b', '\\bbastard\\b',
    // Hate speech indicators
    '\\bhate\\b', '\\bkill\\b', '\\bdie\\b', '\\bdeath\\b',
    // Sexual content
    '\\bsex\\b', '\\bporn\\b', '\\bxxx\\b', '\\bnude\\b',
    // Leetspeak variants
    '\\bd4mn\\b', '\\bh3ll\\b', '\\bk1ll\\b', '\\bd1e\\b'
];

// Spam indicators
const SPAM_PATTERNS = [
    'click here', 'buy now', 'limited time', 'act now',
    'free money', 'earn cash', 'work from home',
    'lose weight', 'get rich', 'subscribe',
    'follow me', 'check out my', 'visit my'
];

// Personal information patterns
const PII_PATTERNS = {
    phone: /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b|\(\d{3}\)\s*\d{3}[-.]?\d{4}/,
    email: /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i,
    address: /\b\d+\s+(st|street|ave|avenue|rd|road|blvd|boulevard|dr|drive|ln|lane|ct|court)\b/i,
    ssn: /\b\d{3}-\d{2}-\d{4}\b/
};

// Content moderation helper functions
function normalizeText(text) {
    let normalized = text.toLowerCase();
    // Leetspeak substitutions
    const substitutions = {
        '0': 'o', '1': 'i', '3': 'e', '4': 'a',
        '5': 's', '7': 't', '@': 'a', '$': 's', '!': 'i'
    };
    for (const [leet, normal] of Object.entries(substitutions)) {
        normalized = normalized.replace(new RegExp(leet, 'g'), normal);
    }
    return normalized;
}

function checkProfanity(text) {
    const normalized = normalizeText(text);
    for (const pattern of PROFANITY_PATTERNS) {
        if (new RegExp(pattern, 'i').test(normalized)) {
            return { flagged: true, reason: 'profanity', pattern };
        }
    }
    return { flagged: false };
}

function checkSpam(text) {
    const lowercased = text.toLowerCase();

    // Check for spam keywords
    for (const keyword of SPAM_PATTERNS) {
        if (lowercased.includes(keyword)) {
            return { flagged: true, reason: 'spam_keyword', keyword };
        }
    }

    // Check for excessive URLs
    const urlMatches = (text.match(/(https?:\/\/|www\.)/gi) || []).length;
    if (urlMatches > 3) {
        return { flagged: true, reason: 'excessive_urls', count: urlMatches };
    }

    // Check for excessive capitalization
    const uppercaseCount = (text.match(/[A-Z]/g) || []).length;
    const letterCount = (text.match(/[A-Za-z]/g) || []).length;
    if (letterCount > 0 && uppercaseCount / letterCount > 0.3) {
        return { flagged: true, reason: 'excessive_caps', ratio: uppercaseCount / letterCount };
    }

    return { flagged: false };
}

function checkPersonalInfo(text) {
    for (const [type, pattern] of Object.entries(PII_PATTERNS)) {
        if (pattern.test(text)) {
            return { flagged: true, reason: 'personal_info', type };
        }
    }
    return { flagged: false };
}

function checkExcessiveRepetition(text) {
    // Check for same character repeated >10 times
    if (/(.)\\1{10,}/.test(text)) {
        return { flagged: true, reason: 'character_repetition' };
    }

    // Check for same word repeated >5 times consecutively
    const words = text.split(/\s+/);
    let consecutiveCount = 1;
    let previousWord = '';

    for (const word of words) {
        if (word && word.toLowerCase() === previousWord) {
            consecutiveCount++;
            if (consecutiveCount > 5) {
                return { flagged: true, reason: 'word_repetition', word: previousWord };
            }
        } else {
            consecutiveCount = 1;
            previousWord = word.toLowerCase();
        }
    }

    return { flagged: false };
}

async function moderateContent(text, contentType, userId, contentId) {
    console.log(`🔍 Moderating ${contentType} from user ${userId}`);

    const checks = [
        checkProfanity(text),
        checkSpam(text),
        checkPersonalInfo(text),
        checkExcessiveRepetition(text)
    ];

    const flaggedChecks = checks.filter(check => check.flagged);

    if (flaggedChecks.length > 0) {
        console.log(`🚫 Content flagged:`, flaggedChecks);

        // Add to moderation queue
        await admin.firestore().collection('moderationQueue').add({
            contentType,
            userId,
            contentId,
            content: text.substring(0, 1000), // Store first 1000 chars
            flagReasons: flaggedChecks.map(c => c.reason),
            details: flaggedChecks,
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            autoFlagged: true
        });

        return {
            approved: false,
            reasons: flaggedChecks
        };
    }

    console.log(`✅ Content approved`);
    return { approved: true };
}

// Notification when story is completed in a partnership
exports.onStoryCompleted = functions.firestore
    .document('partnerships/{partnershipId}/stories/{storyId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();

        // Only trigger when story text is actually added (story completion)
        const oldText = (oldData.text || '').trim();
        const newText = (newData.text || '').trim();

        if (oldText === '' && newText.length > 0) {
            const authorId = newData.authorId;
            const authorName = newData.authorName || 'Your partner';
            const partnershipId = context.params.partnershipId;
            const storyId = context.params.storyId;

            console.log(`📝 Story completion detected - Author: ${authorName} (${authorId}), Partnership: ${partnershipId}, Story: ${storyId}`);

            // SECURITY: Get and verify the partnership FIRST
            const partnershipDoc = await admin.firestore()
                .collection('partnerships')
                .doc(partnershipId)
                .get();

            if (!partnershipDoc.exists) {
                console.error('❌ SECURITY: Partnership not found -', partnershipId);
                return null;
            }

            const partnership = partnershipDoc.data();

            // SECURITY: Verify the author is actually part of this partnership
            const isAuthorized = (authorId === partnership.user1Id || authorId === partnership.user2Id);

            if (!isAuthorized) {
                console.error(`❌ SECURITY VIOLATION: Unauthorized story update attempt by ${authorId} in partnership ${partnershipId}`);
                console.error(`❌ Partnership members: ${partnership.user1Id}, ${partnership.user2Id}`);

                // Log security incident for audit
                await admin.firestore().collection('securityIncidents').add({
                    type: 'unauthorized_story_update',
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    authorId: authorId,
                    partnershipId: partnershipId,
                    storyId: storyId,
                    partnership: {
                        user1Id: partnership.user1Id,
                        user2Id: partnership.user2Id
                    }
                });

                return null;
            }

            console.log(`✅ SECURITY: Author ${authorId} verified as partnership member`);

            const storyPrompt = Object.entries(newData.items || {})
                .map(([key, value]) => `${key}: ${value}`)
                .join(', ');

            // Determine the partner (the other user in the partnership)
            const partnerId = partnership.user1Id === authorId ? partnership.user2Id : partnership.user1Id;

            // SECURITY: Get partner's FCM token from secure private subcollection
            const partnerTokenDoc = await admin.firestore()
                .collection('users')
                .doc(partnerId)
                .collection('private')
                .doc('notifications')
                .get();

            if (!partnerTokenDoc.exists) {
                console.log(`❌ No secure token document found for partner ${partnerId}`);
                return null;
            }

            const tokenData = partnerTokenDoc.data();
            const fcmToken = tokenData.fcmToken;

            if (!fcmToken) {
                console.log(`❌ No FCM token for partner ${partnerId}`);
                return null;
            }

            console.log(`✅ SECURITY: Retrieved FCM token from secure private subcollection`);


            // Send notification to partner
            const message = {
                token: fcmToken,
                notification: {
                    title: 'New Disney Story! ✨',
                    body: `${authorName} just wrote a magical Disney Daydream! Check it out!`
                },
                data: {
                    type: 'story_completed',
                    authorId: authorId,
                    authorName: authorName,
                    prompt: storyPrompt,
                    partnershipId: partnershipId,
                    storyId: context.params.storyId
                },
                apns: {
                    payload: {
                        aps: {
                            alert: {
                                title: 'New Disney Story! ✨',
                                body: `${authorName} just wrote a magical Disney Daydream! Check it out!`
                            },
                            sound: 'default',
                            badge: 1
                        }
                    }
                }
            };

            try {
                await admin.messaging().send(message);
                console.log('✅ Story completion notification sent successfully to partner:', partnerId);
            } catch (error) {
                console.error('❌ Error sending notification:', error);

                if (error.code === 'messaging/registration-token-not-registered') {
                    console.log('⚠️ Removing invalid token for partner:', partnerId);
                    // Delete the invalid token from secure storage
                    await partnerTokenDoc.ref.delete();
                }
            }
        } else if (oldText !== '' && newText !== oldText) {
            console.log(`📝 Story EDITED (not sending notification for edits)`);
        } else {
            console.log(`🔄 Story updated but no text completion detected`);
        }

        return null;
    });

// Process notification queue with security validation
exports.processNotificationQueue = functions.firestore
    .document('notificationQueue/{queueId}')
    .onCreate(async (snap) => {
        const data = snap.data();
        const queueId = snap.id;

        console.log(`📬 Processing notification queue item: ${queueId}`);

        if (data.processed) {
            console.log('⚠️ Notification already processed');
            return null;
        }

        // SECURITY: Validate required fields to prevent malformed notifications
        if (!data.targetToken || !data.title || !data.body) {
            console.error('❌ SECURITY: Invalid notification data - missing required fields');
            await snap.ref.update({
                processed: true,
                error: 'Invalid notification data',
                processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            return null;
        }

        // SECURITY: Validate requesterId exists (prevents anonymous spam)
        if (!data.requesterId) {
            console.error('❌ SECURITY: No requesterId provided for notification');
            await snap.ref.update({
                processed: true,
                error: 'No requesterId provided',
                processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            return null;
        }

        console.log(`✅ SECURITY: Notification request validated from user ${data.requesterId}`);

        const message = {
            token: data.targetToken,
            notification: {
                title: data.title,
                body: data.body
            },
            data: data.data || {},
            apns: {
                payload: {
                    aps: {
                        alert: {
                            title: data.title,
                            body: data.body
                        },
                        sound: 'default',
                        badge: 1
                    }
                }
            }
        };

        try {
            await admin.messaging().send(message);
            console.log(`✅ Queued notification sent successfully to ${data.targetUserId || 'unknown user'}`);

            await snap.ref.update({
                processed: true,
                processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        } catch (error) {
            console.error('❌ Error sending queued notification:', error);
            await snap.ref.update({
                processed: true,
                error: error.message,
                processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }

        return null;
    });

// ===== CONTENT MODERATION CLOUD FUNCTIONS =====

// Moderate story content when created or updated
exports.moderateStoryContent = functions.firestore
    .document('partnerships/{partnershipId}/stories/{storyId}')
    .onWrite(async (change, context) => {
        // Skip if document was deleted
        if (!change.after.exists) {
            return null;
        }

        const storyData = change.after.data();
        const storyText = (storyData.text || '').trim();

        // Only moderate if there's actual text content
        if (!storyText || storyText.length === 0) {
            return null;
        }

        // Skip if already moderated
        if (storyData.moderationStatus) {
            return null;
        }

        const { partnershipId, storyId } = context.params;
        const authorId = storyData.authorId;

        console.log(`🔍 Moderating story ${storyId} from user ${authorId}`);

        const moderationResult = await moderateContent(
            storyText,
            'story',
            authorId,
            `${partnershipId}/${storyId}`
        );

        // Update story with moderation status
        await change.after.ref.update({
            moderationStatus: moderationResult.approved ? 'approved' : 'flagged',
            moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
            moderationReasons: moderationResult.approved ? null : moderationResult.reasons.map(r => r.reason)
        });

        // If flagged, send notification to user
        if (!moderationResult.approved) {
            console.log(`🚫 Story flagged for review: ${storyId}`);

            // Optionally notify the user their content is under review
            const userTokenDoc = await admin.firestore()
                .collection('users')
                .doc(authorId)
                .collection('private')
                .doc('notifications')
                .get();

            if (userTokenDoc.exists && userTokenDoc.data().fcmToken) {
                try {
                    await admin.messaging().send({
                        token: userTokenDoc.data().fcmToken,
                        notification: {
                            title: 'Content Under Review',
                            body: 'Your story is being reviewed by our moderation team.'
                        },
                        data: {
                            type: 'moderation_review',
                            contentType: 'story',
                            contentId: storyId
                        }
                    });
                } catch (error) {
                    console.error('Error sending moderation notification:', error);
                }
            }
        }

        return null;
    });

// Moderate user profile content (displayName, bio) when created or updated
exports.moderateUserProfile = functions.firestore
    .document('users/{userId}')
    .onWrite(async (change, context) => {
        // Skip if document was deleted
        if (!change.after.exists) {
            return null;
        }

        const userData = change.after.data();
        const { userId } = context.params;

        // Check if profile data changed
        const oldData = change.before.exists ? change.before.data() : {};
        const displayNameChanged = userData.displayName !== oldData.displayName;
        const bioChanged = userData.bio !== oldData.bio;

        if (!displayNameChanged && !bioChanged) {
            return null;
        }

        console.log(`🔍 Moderating profile for user ${userId}`);

        let flagged = false;
        const flagReasons = [];

        // Moderate display name
        if (displayNameChanged && userData.displayName) {
            const displayNameResult = await moderateContent(
                userData.displayName,
                'displayName',
                userId,
                userId
            );
            if (!displayNameResult.approved) {
                flagged = true;
                flagReasons.push(...displayNameResult.reasons.map(r => `displayName_${r.reason}`));
            }
        }

        // Moderate bio
        if (bioChanged && userData.bio) {
            const bioResult = await moderateContent(
                userData.bio,
                'bio',
                userId,
                userId
            );
            if (!bioResult.approved) {
                flagged = true;
                flagReasons.push(...bioResult.reasons.map(r => `bio_${r.reason}`));
            }
        }

        // Update profile with moderation status
        if (flagged) {
            console.log(`🚫 Profile flagged for user ${userId}:`, flagReasons);

            await change.after.ref.update({
                moderationStatus: 'flagged',
                moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
                moderationReasons: flagReasons
            });

            // Notify user
            const userTokenDoc = await admin.firestore()
                .collection('users')
                .doc(userId)
                .collection('private')
                .doc('notifications')
                .get();

            if (userTokenDoc.exists && userTokenDoc.data().fcmToken) {
                try {
                    await admin.messaging().send({
                        token: userTokenDoc.data().fcmToken,
                        notification: {
                            title: 'Profile Under Review',
                            body: 'Your profile information is being reviewed by our moderation team.'
                        },
                        data: {
                            type: 'moderation_review',
                            contentType: 'profile'
                        }
                    });
                } catch (error) {
                    console.error('Error sending profile moderation notification:', error);
                }
            }
        } else {
            // Approved - clear any previous flags
            await change.after.ref.update({
                moderationStatus: 'approved',
                moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
                moderationReasons: admin.firestore.FieldValue.delete()
            });
        }

        return null;
    });

// Handle user content reports
exports.handleContentReport = functions.firestore
    .document('contentReports/{reportId}')
    .onCreate(async (snap, context) => {
        const reportData = snap.data();
        const { reportId } = context.params;

        console.log(`📢 New content report: ${reportId}`);

        // Validate report data
        if (!reportData.reporterId || !reportData.contentType || !reportData.contentId) {
            console.error('❌ Invalid report data');
            return null;
        }

        // Add to moderation queue with higher priority (user-reported)
        await admin.firestore().collection('moderationQueue').add({
            contentType: reportData.contentType,
            userId: reportData.reportedUserId,
            contentId: reportData.contentId,
            reporterId: reportData.reporterId,
            reportReason: reportData.reason,
            reportDetails: reportData.details,
            status: 'pending',
            priority: 'high', // User reports get high priority
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            autoFlagged: false,
            userReported: true
        });

        // Update report status
        await snap.ref.update({
            status: 'queued',
            queuedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log(`✅ Report ${reportId} added to moderation queue`);
        return null;
    });

// Handle user blocking
exports.handleUserBlock = functions.firestore
    .document('users/{userId}/blockedUsers/{blockedUserId}')
    .onCreate(async (snap, context) => {
        const { userId, blockedUserId } = context.params;

        console.log(`🚫 User ${userId} blocked user ${blockedUserId}`);

        // Remove any existing partnerships between these users
        const partnershipsQuery = await admin.firestore()
            .collection('partnerships')
            .where('user1Id', 'in', [userId, blockedUserId])
            .get();

        for (const doc of partnershipsQuery.docs) {
            const partnership = doc.data();
            const isRelated = (
                (partnership.user1Id === userId && partnership.user2Id === blockedUserId) ||
                (partnership.user1Id === blockedUserId && partnership.user2Id === userId)
            );

            if (isRelated) {
                console.log(`Removing partnership ${doc.id}`);
                await doc.ref.update({
                    status: 'blocked',
                    blockedAt: admin.firestore.FieldValue.serverTimestamp(),
                    blockedBy: userId
                });
            }
        }

        // Remove any pending invitations between these users
        const invitationsQuery = await admin.firestore()
            .collection('palInvitations')
            .where('inviterId', '==', userId)
            .where('inviteeId', '==', blockedUserId)
            .get();

        for (const doc of invitationsQuery.docs) {
            console.log(`Removing invitation ${doc.id}`);
            await doc.ref.delete();
        }

        return null;
    });

// ===== ACCOUNT DELETION CLEANUP =====

// Comprehensive cleanup when user account is deleted
exports.onUserDelete = functions.auth.user().onDelete(async (user) => {
    const userId = user.uid;
    const db = admin.firestore();

    console.log(`🗑️ Starting comprehensive cleanup for deleted user: ${userId}`);

    try {
        // Use batched writes for efficiency (max 500 operations per batch)
        let batch = db.batch();
        let operationCount = 0;

        // Helper function to commit batch if it gets too large
        async function commitBatchIfNeeded() {
            if (operationCount >= 450) {
                await batch.commit();
                console.log(`✅ Committed batch with ${operationCount} operations`);
                batch = db.batch();
                operationCount = 0;
            }
        }

        // 1. Delete user profile document
        console.log('📝 Deleting user profile...');
        const userRef = db.collection('users').doc(userId);
        batch.delete(userRef);
        operationCount++;

        // 2. Delete private subcollection (FCM tokens, etc.)
        console.log('🔒 Deleting private data (FCM tokens)...');
        const privateSnapshot = await userRef.collection('private').get();
        for (const doc of privateSnapshot.docs) {
            batch.delete(doc.ref);
            operationCount++;
            await commitBatchIfNeeded();
        }

        // 3. Delete active sessions
        console.log('📱 Deleting active sessions...');
        const sessionsSnapshot = await userRef.collection('sessions').get();
        for (const doc of sessionsSnapshot.docs) {
            batch.delete(doc.ref);
            operationCount++;
            await commitBatchIfNeeded();
        }

        // 4. Delete blocked users list
        console.log('🚫 Deleting blocked users list...');
        const blockedSnapshot = await userRef.collection('blockedUsers').get();
        for (const doc of blockedSnapshot.docs) {
            batch.delete(doc.ref);
            operationCount++;
            await commitBatchIfNeeded();
        }

        // 5. Delete user stories (favorites and personal collections)
        console.log('📖 Deleting user stories...');
        const userStoriesSnapshot = await db.collection('userStories')
            .doc(userId)
            .collection('favorites')
            .get();
        for (const doc of userStoriesSnapshot.docs) {
            batch.delete(doc.ref);
            operationCount++;
            await commitBatchIfNeeded();
        }

        // Delete userStories parent document
        batch.delete(db.collection('userStories').doc(userId));
        operationCount++;

        // 6. Delete user settings
        console.log('⚙️ Deleting user settings...');
        batch.delete(db.collection('userSettings').doc(userId));
        operationCount++;

        // 7. Clean up pal invitations (sent by this user)
        console.log('✉️ Deleting sent invitations...');
        const sentInvitations = await db.collection('palInvitations')
            .where('fromUserId', '==', userId)
            .get();
        for (const doc of sentInvitations.docs) {
            batch.delete(doc.ref);
            operationCount++;
            await commitBatchIfNeeded();
        }

        // Clean up invitations sent to this user
        console.log('📬 Deleting received invitations...');
        const receivedInvitations = await db.collection('palInvitations')
            .where('toUserId', '==', userId)
            .get();
        for (const doc of receivedInvitations.docs) {
            batch.delete(doc.ref);
            operationCount++;
            await commitBatchIfNeeded();
        }

        // 8. Update partnerships (mark as deleted rather than deleting)
        console.log('👥 Updating partnerships...');
        const partnerships1 = await db.collection('partnerships')
            .where('user1Id', '==', userId)
            .get();
        const partnerships2 = await db.collection('partnerships')
            .where('user2Id', '==', userId)
            .get();

        const allPartnerships = [...partnerships1.docs, ...partnerships2.docs];

        for (const partnershipDoc of allPartnerships) {
            // Mark partnership as deleted and anonymize the deleted user
            batch.update(partnershipDoc.ref, {
                status: 'user_deleted',
                deletedUserId: userId,
                deletedAt: admin.firestore.FieldValue.serverTimestamp(),
                // Keep stories but mark them as from deleted user
                [`${partnershipDoc.data().user1Id === userId ? 'user1' : 'user2'}Deleted`]: true
            });
            operationCount++;
            await commitBatchIfNeeded();

            // Note: We keep the stories for the other user, but they should be marked
            // This preserves the other user's story history
        }

        // 9. Clean up notification queue entries
        console.log('🔔 Deleting notification queue entries...');
        const notificationQueue = await db.collection('notificationQueue')
            .where('requesterId', '==', userId)
            .get();
        for (const doc of notificationQueue.docs) {
            batch.delete(doc.ref);
            operationCount++;
            await commitBatchIfNeeded();
        }

        // Also clean up notifications targeted to this user
        const targetedNotifications = await db.collection('notificationQueue')
            .where('targetUserId', '==', userId)
            .get();
        for (const doc of targetedNotifications.docs) {
            batch.delete(doc.ref);
            operationCount++;
            await commitBatchIfNeeded();
        }

        // 10. Delete content reports made by this user
        console.log('📢 Deleting content reports...');
        const reports = await db.collection('contentReports')
            .where('reporterId', '==', userId)
            .get();
        for (const doc of reports.docs) {
            batch.delete(doc.ref);
            operationCount++;
            await commitBatchIfNeeded();
        }

        // Update reports about this user (keep for audit trail but mark user as deleted)
        const reportsAboutUser = await db.collection('contentReports')
            .where('reportedUserId', '==', userId)
            .get();
        for (const doc of reportsAboutUser.docs) {
            batch.update(doc.ref, {
                reportedUserDeleted: true,
                deletedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            operationCount++;
            await commitBatchIfNeeded();
        }

        // 11. Clean up moderation queue entries
        console.log('🛡️ Cleaning moderation queue...');
        const moderationQueue = await db.collection('moderationQueue')
            .where('userId', '==', userId)
            .get();
        for (const doc of moderationQueue.docs) {
            // Mark as user deleted rather than deleting (for audit trail)
            batch.update(doc.ref, {
                userDeleted: true,
                deletedAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'user_deleted'
            });
            operationCount++;
            await commitBatchIfNeeded();
        }

        // 12. Delete connection test documents (if any)
        console.log('🔧 Deleting connection test documents...');
        const connectionTests = await db.collection('connectionTest')
            .where('userId', '==', userId)
            .get();
        for (const doc of connectionTests.docs) {
            batch.delete(doc.ref);
            operationCount++;
            await commitBatchIfNeeded();
        }

        // Commit any remaining operations
        if (operationCount > 0) {
            await batch.commit();
            console.log(`✅ Committed final batch with ${operationCount} operations`);
        }

        console.log(`✅ Successfully completed cleanup for user ${userId}`);
        console.log(`📊 Summary:`);
        console.log(`   - User profile: deleted`);
        console.log(`   - Private data: deleted`);
        console.log(`   - Sessions: deleted`);
        console.log(`   - Blocked users: deleted`);
        console.log(`   - User stories: deleted`);
        console.log(`   - Settings: deleted`);
        console.log(`   - Invitations: deleted`);
        console.log(`   - Partnerships: updated (${allPartnerships.length})`);
        console.log(`   - Notifications: deleted`);
        console.log(`   - Reports: deleted/updated`);
        console.log(`   - Moderation queue: updated`);

        // Log to security incidents for audit trail
        await db.collection('securityIncidents').add({
            type: 'user_account_deleted',
            userId: userId,
            userEmail: user.email || 'unknown',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            cleanupCompleted: true,
            details: {
                partnershipsUpdated: allPartnerships.length,
                sessionsDeleted: sessionsSnapshot.size,
                invitationsDeleted: sentInvitations.size + receivedInvitations.size,
                reportsDeleted: reports.size,
                notificationsDeleted: notificationQueue.size + targetedNotifications.size
            }
        });

        return null;

    } catch (error) {
        console.error(`❌ Error during user deletion cleanup for ${userId}:`, error);

        // Log the error for investigation
        await db.collection('securityIncidents').add({
            type: 'user_deletion_cleanup_error',
            userId: userId,
            userEmail: user.email || 'unknown',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            error: error.message,
            stack: error.stack
        });

        // Don't throw - we want the account deletion to proceed even if cleanup fails
        // The data can be manually cleaned up later if needed
        return null;
    }
});
