const {onDocumentUpdated, onDocumentCreated} = require('firebase-functions/v2/firestore');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');

// Initialize Firebase Admin
initializeApp();

// Notification when story is completed
exports.onStoryCompleted = onDocumentUpdated('sharedStories/{storyId}', async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    
    // Check if story text was added (story completed)
    if (!oldData.text && newData.text) {
        console.log(`Story completed by ${newData.author} for date ${event.params.storyId}`);
        
        const authorName = newData.author;
        const storyPrompt = Object.entries(newData.items || {})
            .map(([key, value]) => `${key}: ${value}`)
            .join(', ');
        
        // Get all users to send notification to partner
        const db = getFirestore();
        const usersSnapshot = await db.collection('users').get();
        
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
            
            const message = {
                token: fcmToken,
                notification: {
                    title: 'Story Complete! ✨',
                    body: `${authorName} just finished their Disney Daydream!`
                },
                data: {
                    type: 'story_completed',
                    author: authorName,
                    prompt: storyPrompt,
                    storyId: event.params.storyId
                },
                apns: {
                    payload: {
                        aps: {
                            alert: {
                                title: 'Story Complete! ✨',
                                body: `${authorName} just finished their Disney Daydream!`
                            },
                            sound: 'default',
                            badge: 1
                        }
                    }
                }
            };
            
            try {
                await getMessaging().send(message);
                console.log('Notification sent successfully to:', userDoc.id);
            } catch (error) {
                console.error('Error sending notification:', error);
                
                if (error.code === 'messaging/registration-token-not-registered') {
                    console.log('Removing invalid token for user:', userDoc.id);
                    await userDoc.ref.update({
                        fcmToken: getFirestore().FieldValue.delete()
                    });
                }
            }
        }
    } else {
        console.log('Story update did not include text completion');
    }
    
    return null;
});

// Process notification queue
exports.processNotificationQueue = onDocumentCreated('notificationQueue/{queueId}', async (event) => {
    const data = event.data.data();
    
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
        await getMessaging().send(message);
        console.log('Queued notification sent successfully');
        
        // Mark as processed
        await event.data.ref.update({
            processed: true,
            processedAt: getFirestore().FieldValue.serverTimestamp()
        });
    } catch (error) {
        console.error('Error sending queued notification:', error);
        await event.data.ref.update({
            processed: true,
            error: error.message,
            processedAt: getFirestore().FieldValue.serverTimestamp()
        });
    }
    
    return null;
});
