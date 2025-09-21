const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentCreated, onDocumentDeleted} = require('firebase-functions/v2/firestore');
const {beforeUserCreated, beforeUserSignedIn} = require('firebase-functions/v2/identity');
const admin = require('firebase-admin');
const {logger} = require('firebase-functions');

admin.initializeApp();

// Authorize a user by email (call this from admin panel)
exports.authorizeUser = onCall({cors: true}, async (request) => {
  // Only allow existing admins to authorize new users
  if (!request.auth || !request.auth.token.role || request.auth.token.role !== 'admin') {
    throw new HttpsError(
      'permission-denied',
      'Only admins can authorize users'
    );
  }

  const {email, role = 'user'} = request.data;
  
  if (!email) {
    throw new HttpsError(
      'invalid-argument',
      'Email is required'
    );
  }

  try {
    // Find user by email
    const userRecord = await admin.auth().getUserByEmail(email);
    
    // Set custom claims
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      authorized: true,
      role: role,
      authorizedAt: new Date().toISOString(),
      authorizedBy: request.auth.uid
    });

    // Create/update user profile document
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      email: email,
      role: role,
      authorized: true,
      authorizedAt: admin.firestore.FieldValue.serverTimestamp(),
      authorizedBy: request.auth.uid
    }, { merge: true });

    // Log the authorization
    await admin.firestore().collection('admin').doc('userAuthorizations').collection('log').add({
      action: 'authorize',
      targetUserId: userRecord.uid,
      targetUserEmail: email,
      role: role,
      performedBy: request.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    logger.info(`User ${email} authorized by ${request.auth.token.email}`);

    return {
      success: true,
      message: `User ${email} authorized successfully`,
      userId: userRecord.uid
    };
    
  } catch (error) {
    logger.error('Error authorizing user:', error);
    
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError(
        'not-found',
        `No user found with email: ${email}. User must sign in at least once before being authorized.`
      );
    }
    
    throw new HttpsError(
      'internal',
      'Failed to authorize user: ' + error.message
    );
  }
});

// Remove authorization from a user
exports.deauthorizeUser = onCall({cors: true}, async (request) => {
  if (!request.auth || !request.auth.token.role || request.auth.token.role !== 'admin') {
    throw new HttpsError(
      'permission-denied',
      'Only admins can deauthorize users'
    );
  }

  const {userId} = request.data;
  
  if (!userId) {
    throw new HttpsError(
      'invalid-argument',
      'User ID is required'
    );
  }

  try {
    // Don't allow deauthorizing other admins
    const userRecord = await admin.auth().getUser(userId);
    const userClaims = userRecord.customClaims || {};
    
    if (userClaims.role === 'admin') {
      throw new HttpsError(
        'permission-denied',
        'Cannot deauthorize admin users'
      );
    }

    // Remove custom claims
    await admin.auth().setCustomUserClaims(userId, {
      authorized: false,
      role: null,
      deauthorizedAt: new Date().toISOString(),
      deauthorizedBy: request.auth.uid
    });

    // Update user profile document
    await admin.firestore().collection('users').doc(userId).set({
      authorized: false,
      role: null,
      deauthorizedAt: admin.firestore.FieldValue.serverTimestamp(),
      deauthorizedBy: request.auth.uid
    }, { merge: true });

    // Log the deauthorization
    await admin.firestore().collection('admin').doc('userAuthorizations').collection('log').add({
      action: 'deauthorize',
      targetUserId: userId,
      targetUserEmail: userRecord.email,
      performedBy: request.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    logger.info(`User ${userRecord.email} deauthorized by ${request.auth.token.email}`);

    return {
      success: true,
      message: `User ${userRecord.email} deauthorized successfully`
    };
    
  } catch (error) {
    logger.error('Error deauthorizing user:', error);
    throw new HttpsError(
      'internal',
      'Failed to deauthorize user: ' + error.message
    );
  }
});

// List all authorized users (for admin panel)
exports.listAuthorizedUsers = onCall({cors: true}, async (request) => {
  if (!request.auth || !request.auth.token.role || request.auth.token.role !== 'admin') {
    throw new HttpsError(
      'permission-denied',
      'Only admins can list users'
    );
  }

  try {
    const listUsersResult = await admin.auth().listUsers();
    
    const authorizedUsers = listUsersResult.users
      .filter(user => user.customClaims?.authorized === true)
      .map(user => ({
        uid: user.uid,
        email: user.email,
        role: user.customClaims?.role || 'user',
        authorizedAt: user.customClaims?.authorizedAt,
        lastSignIn: user.metadata.lastSignInTime,
        created: user.metadata.creationTime
      }));

    return { users: authorizedUsers };
    
  } catch (error) {
    logger.error('Error listing users:', error);
    throw new HttpsError(
      'internal',
      'Failed to list users: ' + error.message
    );
  }
});

// Auto-authorize specific email addresses on first sign-in
exports.checkUserAuthorization = beforeUserSignedIn(async (event) => {
  const user = event.data;
  const email = user.email?.toLowerCase();
  
  // Auto-authorize specific emails (your accounts)
  const autoAuthorizeEmails = [
    'jonathanfmandl@gmail.com',
    'carolyningrid9@gmail.com'
  ];
  
  // Check if user should be auto-authorized
  const shouldAutoAuthorize = autoAuthorizeEmails.includes(email);
  
  if (shouldAutoAuthorize) {
    const isFirstAdmin = autoAuthorizeEmails[0] === email;
    const role = isFirstAdmin ? 'admin' : 'user';
    
    // Set custom claims
    const customClaims = {
      authorized: true,
      role: role,
      authorizedAt: new Date().toISOString(),
      autoAuthorized: true
    };

    logger.info(`Auto-authorizing user: ${email} as ${role}`);
    
    return {
      customClaims: customClaims
    };
  }
  
  // For non-authorized emails, explicitly set unauthorized
  return {
    customClaims: {
      authorized: false,
      role: null
    }
  };
});

// Create user profile document when user is created
exports.createUserProfile = beforeUserCreated(async (event) => {
  const user = event.data;
  const email = user.email?.toLowerCase();
  
  // Auto-authorize specific emails
  const autoAuthorizeEmails = [
    'jonathanfmandl@gmail.com',
    'carolyningrid9@gmail.com'
  ];
  
  const shouldAutoAuthorize = autoAuthorizeEmails.includes(email);
  
  if (shouldAutoAuthorize) {
    const isFirstAdmin = autoAuthorizeEmails[0] === email;
    const role = isFirstAdmin ? 'admin' : 'user';
    
    // Set custom claims
    const customClaims = {
      authorized: true,
      role: role,
      authorizedAt: new Date().toISOString(),
      autoAuthorized: true
    };

    logger.info(`Auto-authorizing new user: ${email} as ${role}`);
    
    return {
      customClaims: customClaims
    };
  }
  
  return {};
});

// Clean up user data when account is deleted
exports.cleanupUserData = onDocumentDeleted('users/{userId}', async (event) => {
  const userId = event.params.userId;
  
  try {
    const batch = admin.firestore().batch();
    
    // Delete user's private data collections
    const collectionsToDelete = [
      `userSettings/${userId}`,
      `dailyPrompts/${userId}`,
      `completedStories/${userId}`
    ];
    
    for (const path of collectionsToDelete) {
      const docRef = admin.firestore().doc(path);
      batch.delete(docRef);
    }
    
    await batch.commit();
    
    // Delete user's subcollections (requires recursive delete)
    const userStoriesRef = admin.firestore().collection('userStories').doc(userId);
    await admin.firestore().recursiveDelete(userStoriesRef);
    
    logger.info(`Cleaned up data for deleted user: ${userId}`);
    
  } catch (error) {
    logger.error(`Error cleaning up user data for ${userId}:`, error);
  }
});

// Log important security events
exports.logSecurityEvent = onCall({cors: true}, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated');
  }

  const {event, details} = request.data;
  
  await admin.firestore().collection('admin').doc('securityLog').collection('events').add({
    event: event,
    details: details,
    userId: request.auth.uid,
    userEmail: request.auth.token.email,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    ipAddress: request.rawRequest.ip
  });
  
  return {success: true};
});
