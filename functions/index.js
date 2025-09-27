const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Notification when story is completed
exports.onStoryCompleted = functions.firestore
    .document('sharedStories/{storyId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        
        // FIXED: Only trigger when story text is actually added (story completion)
        // Check that:
        // 1. Old data had no text OR empty text
        // 2. New data has actual text content
        // 3. Text is substantial (more than just whitespace)
        const oldText = (oldData.text || '').trim();
        const newText = (newData.text || '').trim();
        
        if (oldText === '' && newText.length > 0) {
            console.log(`✅ Story COMPLETED by ${newData.author} for date ${context.params.storyId}`);
            
            const authorName = newData.author;
            const storyPrompt = Object.entries(newData.items || {})
                .map(([key, value]) => `${key}: ${value}`)
                .join(', ');
            
            // Get all users to send notification to partner
            const usersSnapshot = await admin.firestore().collection('users').get();
            
            if (usersSnapshot.empty) {
                console.log('No users found in users collection');
                return null;
            }
            
            // Send notification to each user (will be filtered to partner only)
            for (const userDoc of usersSnapshot.docs) {
                const userData = userDoc.data();
                const fcmToken = userData.fcmToken;
                
                if (!fcmToken) {
                    console.log(`No FCM token for user ${userDoc.id}`);
                    continue;
                }
                
                // Don't send notification to the author themselves
                const userEmail = userData.email || '';
                const isAuthor = (authorName === 'Jon' && userEmail.toLowerCase().includes('jonathan')) ||
                                (authorName === 'Carolyn' && userEmail.toLowerCase().includes('carolyn'));
                
                if (isAuthor) {
                    console.log(`Skipping notification to author ${authorName}`);
                    continue;
                }
                
                // IMPROVED: Better notification message
                const message = {
                    token: fcmToken,
                    notification: {
                        title: 'New Disney Story! ✨',
                        body: `${authorName} just wrote a magical Disney Daydream! Check it out!`
                    },
                    data: {
                        type: 'story_completed',
                        author: authorName,
                        prompt: storyPrompt,
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
                    console.log('✅ Story completion notification sent successfully to:', userDoc.id);
                } catch (error) {
                    console.error('❌ Error sending notification:', error);
                    
                    if (error.code === 'messaging/registration-token-not-registered') {
                        console.log('Removing invalid token for user:', userDoc.id);
                        await userDoc.ref.update({
                            fcmToken: admin.firestore.FieldValue.delete()
                        });
                    }
                }
            }
        } else if (oldText !== '' && newText !== oldText) {
            console.log(`📝 Story EDITED by ${newData.author} (not sending notification for edits)`);
        } else {
            console.log(`🔄 Story updated but no text completion detected (prompt generation, metadata update, etc.)`);
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
