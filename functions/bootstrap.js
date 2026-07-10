'use strict';

// Keep existing function exports while replacing security-sensitive triggers
// with hardened implementations from secure-runtime.js.
const legacy = require('./index');
const secure = require('./secure-runtime');

module.exports = {
  ...legacy,
  processNotificationQueue: secure.processNotificationQueue,
  moderateStoryContent: secure.moderateStoryContent,
  moderateUserProfile: secure.moderateUserProfile,
};
