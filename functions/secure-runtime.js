'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

const ALLOWED_NOTIFICATION_TYPES = new Set(['story_completed', 'new_prompt']);

function deterministicPartnershipId(userA, userB) {
  return userA < userB ? `${userA}_${userB}` : `${userB}_${userA}`;
}

async function markQueueItem(snap, fields) {
  await snap.ref.update({
    processed: true,
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...fields,
  });
}

async function processNotificationQueue(snap) {
  const data = snap.data();

  try {
    const { requesterId, targetUserId, type, partnershipId, storyId } = data;

    if (!requesterId || !targetUserId || !type || !partnershipId) {
      await markQueueItem(snap, { error: 'Missing required notification fields' });
      return null;
    }

    if (!ALLOWED_NOTIFICATION_TYPES.has(type)) {
      await markQueueItem(snap, { error: 'Unsupported notification type' });
      return null;
    }

    if (requesterId === targetUserId) {
      await markQueueItem(snap, { error: 'Self-targeted notifications are not allowed' });
      return null;
    }

    const expectedPartnershipId = deterministicPartnershipId(requesterId, targetUserId);
    if (partnershipId !== expectedPartnershipId) {
      await markQueueItem(snap, { error: 'Invalid partnership identifier' });
      return null;
    }

    const partnershipSnapshot = await db.collection('partnerships').doc(partnershipId).get();
    if (!partnershipSnapshot.exists) {
      await markQueueItem(snap, { error: 'Partnership not found' });
      return null;
    }

    const partnership = partnershipSnapshot.data();
    const members = [partnership.user1Id, partnership.user2Id];
    if (!members.includes(requesterId) || !members.includes(targetUserId)) {
      await markQueueItem(snap, { error: 'Notification users are not partnership members' });
      return null;
    }

    let authorName = 'Your partner';
    const requesterProfile = await db.collection('users').doc(requesterId).get();
    if (requesterProfile.exists) {
      authorName = requesterProfile.data().displayName || authorName;
    }

    if (type === 'story_completed' && storyId) {
      const storySnapshot = await db
        .collection('partnerships')
        .doc(partnershipId)
        .collection('stories')
        .doc(storyId)
        .get();

      if (!storySnapshot.exists) {
        await markQueueItem(snap, { error: 'Story not found' });
        return null;
      }

      const story = storySnapshot.data();
      if (story.authorId !== requesterId || !(story.text || '').trim()) {
        await markQueueItem(snap, { error: 'Requester did not complete this story' });
        return null;
      }
    }

    const tokenSnapshot = await db
      .collection('users')
      .doc(targetUserId)
      .collection('private')
      .doc('notifications')
      .get();

    const token = tokenSnapshot.exists ? tokenSnapshot.data().fcmToken : null;
    if (!token) {
      await markQueueItem(snap, { error: 'Target user has no notification token' });
      return null;
    }

    const copy = type === 'story_completed'
      ? {
          title: 'New Disney Story! ✨',
          body: `${authorName} finished a new Daydream.`,
        }
      : {
          title: 'New Daydream! ✨',
          body: 'A new writing prompt is ready.',
        };

    const messageData = {
      type,
      requesterId,
      partnershipId,
    };
    if (storyId) messageData.storyId = storyId;
    if (type === 'story_completed') messageData.authorName = authorName;

    try {
      await admin.messaging().send({
        token,
        notification: copy,
        data: messageData,
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      await markQueueItem(snap, {});
    } catch (error) {
      if (error.code === 'messaging/registration-token-not-registered') {
        await tokenSnapshot.ref.delete();
      }
      await markQueueItem(snap, { error: error.message || 'Notification delivery failed' });
    }
  } catch (error) {
    console.error('Secure notification processor failed:', error);
    await markQueueItem(snap, { error: error.message || 'Notification processing failed' });
  }

  return null;
}

const PROFANITY_PATTERNS = [
  /\bdamn\b/i,
  /\bcrap\b/i,
  /\bpiss\b/i,
  /\bbastard\b/i,
  /\bporn\b/i,
  /\bxxx\b/i,
  /\bnude\b/i,
];

const SPAM_PHRASES = [
  'click here',
  'buy now',
  'free money',
  'earn cash',
  'get rich',
];

function moderationFindings(text) {
  const findings = [];
  const normalized = String(text || '').trim();

  if (PROFANITY_PATTERNS.some((pattern) => pattern.test(normalized))) {
    findings.push('profanity');
  }

  const lower = normalized.toLowerCase();
  if (SPAM_PHRASES.some((phrase) => lower.includes(phrase))) {
    findings.push('spam_keyword');
  }

  const urls = normalized.match(/(https?:\/\/|www\.)/gi) || [];
  if (urls.length > 3) findings.push('excessive_urls');

  const letters = normalized.match(/[A-Za-z]/g) || [];
  const uppercase = normalized.match(/[A-Z]/g) || [];
  if (letters.length >= 30 && uppercase.length / letters.length > 0.7) {
    findings.push('excessive_caps');
  }

  if (/(.)\1{10,}/.test(normalized)) findings.push('character_repetition');
  if (/\b(\w+)(?:\s+\1){5,}\b/i.test(normalized)) findings.push('word_repetition');

  return [...new Set(findings)];
}

async function writeModerationResult(ref, findings) {
  const update = {
    moderationStatus: findings.length ? 'flagged' : 'approved',
    moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  update.moderationReasons = findings.length
    ? findings
    : admin.firestore.FieldValue.delete();

  await ref.update(update);
}

async function moderateStoryContent(change, context) {
  if (!change.after.exists) return null;

  const after = change.after.data();
  const before = change.before.exists ? change.before.data() : {};
  const text = String(after.text || '').trim();

  if (!text || text === String(before.text || '').trim()) return null;

  const findings = moderationFindings(text);
  await writeModerationResult(change.after.ref, findings);

  if (findings.length) {
    await db.collection('moderationQueue').add({
      contentType: 'story',
      userId: after.authorId,
      contentId: `${context.params.partnershipId}/${context.params.storyId}`,
      content: text.substring(0, 1000),
      flagReasons: findings,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      autoFlagged: true,
    });
  }

  return null;
}

async function moderateUserProfile(change, context) {
  if (!change.after.exists) return null;

  const after = change.after.data();
  const before = change.before.exists ? change.before.data() : {};
  const displayNameChanged = after.displayName !== before.displayName;
  const bioChanged = after.bio !== before.bio;
  if (!displayNameChanged && !bioChanged) return null;

  const findings = [];
  if (displayNameChanged) {
    findings.push(...moderationFindings(after.displayName).map((item) => `displayName_${item}`));
  }
  if (bioChanged) {
    findings.push(...moderationFindings(after.bio).map((item) => `bio_${item}`));
  }

  await writeModerationResult(change.after.ref, [...new Set(findings)]);
  return null;
}

module.exports = {
  processNotificationQueue: functions.firestore
    .document('notificationQueue/{queueId}')
    .onCreate(processNotificationQueue),
  moderateStoryContent: functions.firestore
    .document('partnerships/{partnershipId}/stories/{storyId}')
    .onWrite(moderateStoryContent),
  moderateUserProfile: functions.firestore
    .document('users/{userId}')
    .onWrite(moderateUserProfile),
  _test: {
    deterministicPartnershipId,
    moderationFindings,
  },
};
