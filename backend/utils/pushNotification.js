const { admin } = require('../config/firebase');
const User = require('../models/User');

/**
 * Send push notification to specific users by role(s) or userId(s)
 *
 * @param {Object} options
 * @param {string} options.title - Notification title
 * @param {string} options.body  - Notification body
 * @param {Object} options.data  - Extra data payload (all values must be strings)
 * @param {string[]} [options.roles] - Send to all users with these roles
 * @param {string[]} [options.userIds] - Send to specific user IDs
 * @param {string[]} [options.excludeUserIds] - Exclude these user IDs
 */
async function sendPush({ title, body, data = {}, roles = [], userIds = [], excludeUserIds = [] }) {
  try {
    if (!admin.apps.length) return; // Firebase not initialized

    // Build query
    const query = {};
    if (userIds.length > 0) {
      query._id = { $in: userIds };
    } else if (roles.length > 0) {
      query.role = { $in: roles };
    }

    const users = await User.find(query).select('fcmTokens _id');

    // Collect all tokens, excluding specified users
    const tokens = [];
    for (const user of users) {
      if (excludeUserIds.includes(user._id.toString())) continue;
      tokens.push(...user.fcmTokens);
    }

    if (tokens.length === 0) return;

    // Deduplicate tokens
    const uniqueTokens = [...new Set(tokens)];

    // Send in batches of 500 (FCM limit)
    const batchSize = 500;
    for (let i = 0; i < uniqueTokens.length; i += batchSize) {
      const batch = uniqueTokens.slice(i, i + batchSize);
      const message = {
        notification: { title, body },
        data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
        tokens: batch,
        apns: {
          payload: {
            aps: { sound: 'default', badge: 1 },
          },
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);

      // Clean up invalid tokens
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const code = resp.error?.code;
          if (
            code === 'messaging/invalid-registration-token' ||
            code === 'messaging/registration-token-not-registered'
          ) {
            invalidTokens.push(batch[idx]);
          }
        }
      });

      if (invalidTokens.length > 0) {
        await User.updateMany(
          { fcmTokens: { $in: invalidTokens } },
          { $pull: { fcmTokens: { $in: invalidTokens } } }
        );
      }
    }
  } catch (err) {
    console.error('Push notification error:', err.message);
  }
}

module.exports = { sendPush };
