const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

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

            console.log(`✅ Story COMPLETED by ${authorName} (${authorId}) in partnership ${partnershipId}`);

            const storyPrompt = Object.entries(newData.items || {})
                .map(([key, value]) => `${key}: ${value}`)
                .join(', ');

            // Get the partnership to find the partner
            const partnershipDoc = await admin.firestore()
                .collection('partnerships')
                .doc(partnershipId)
                .get();

            if (!partnershipDoc.exists) {
                console.log('❌ Partnership not found');
                return null;
            }

            const partnership = partnershipDoc.data();
            const partnerId = partnership.user1Id === authorId ? partnership.user2Id : partnership.user1Id;

            // Get partner's FCM token
            const partnerDoc = await admin.firestore()
                .collection('users')
                .doc(partnerId)
                .get();

            if (!partnerDoc.exists) {
                console.log('❌ Partner user not found');
                return null;
            }

            const partnerData = partnerDoc.data();
            const fcmToken = partnerData.fcmToken;

            if (!fcmToken) {
                console.log(`❌ No FCM token for partner ${partnerId}`);
                return null;
            }

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
                    console.log('Removing invalid token for partner:', partnerId);
                    await partnerDoc.ref.update({
                        fcmToken: admin.firestore.FieldValue.delete()
                    });
                }
            }
        } else if (oldText !== '' && newText !== oldText) {
            console.log(`📝 Story EDITED (not sending notification for edits)`);
        } else {
            console.log(`🔄 Story updated but no text completion detected`);
        }

        return null;
    });

// Process notification queue (unchanged)
exports.processNotificationQueue = functions.firestore
    .document('notificationQueue/{queueId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();

        if (data.processed) {
            console.log('Notification already processed');
            return null;
        }

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
            console.log('Queued notification sent successfully');

            await snap.ref.update({
                processed: true,
                processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        } catch (error) {
            console.error('Error sending queued notification:', error);
            await snap.ref.update({
                processed: true,
                error: error.message,
                processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }

        return null;
    });
