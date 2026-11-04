const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Maps notification category to Android Notification Channel ID
 */
function getChannelId(category) {
  switch (category) {
    case 'order_fill':
    case 'liquidation':
    case 'stop_loss':
    case 'market':
      return 'channel_trading';
    case 'weekly_prize':
    case 'championship':
      return 'channel_championship';
    case 'reward':
    case 'bonus':
      return 'channel_rewards';
    case 'announcement':
    case 'system':
    default:
      return 'channel_announcements';
  }
}

/**
 * 1. AUTOMATED TRIGGER: Fires whenever a notification is added to users/{userId}/notifications/{notifId}
 * Handles direct notifications (tips, trade executions, direct admin messages, prizes)
 */
exports.onUserNotificationCreated = onDocumentCreated(
  'users/{userId}/notifications/{notifId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const userId = event.params.userId;

    // If this is part of a bulk global broadcast, the topic broadcast handles it to avoid duplicate notifications
    if (data.data && data.data.broadcast === true && data.data.handledByTopic === true) {
      return;
    }

    try {
      // 1. Fetch user's registered FCM tokens
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      const userData = userDoc.data();
      const tokens = userData.fcmTokens || [];

      if (!Array.isArray(tokens) || tokens.length === 0) {
        console.log(`[FCM] No tokens registered for user ${userId}`);
        return;
      }

      const channelId = getChannelId(data.category);

      // 2. Build multi-platform FCM payload
      const payload = {
        tokens: tokens,
        notification: {
          title: data.title || 'TradeQuest Alert',
          body: data.message || '',
        },
        data: {
          id: data.id || event.params.notifId,
          category: data.category || 'system',
          type: data.type || 'announcement',
          userId: userId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: channelId,
            color: '#1D9BF0', // Twitter Blue
            icon: '@mipmap/ic_launcher',
            sound: 'default',
            priority: 'high',
          },
        },
      };

      // 3. Dispatch multicast message
      const response = await admin.messaging().sendEachForMulticast(payload);
      console.log(`[FCM] Delivered to ${response.successCount}/${tokens.length} devices for user ${userId}`);

      // 4. Clean up invalid/stale tokens
      if (response.failureCount > 0) {
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errCode = resp.error?.code;
            if (
              errCode === 'messaging/invalid-registration-token' ||
              errCode === 'messaging/registration-token-not-registered'
            ) {
              failedTokens.push(tokens[idx]);
            }
          }
        });

        if (failedTokens.length > 0) {
          await admin.firestore().collection('users').doc(userId).update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...failedTokens),
          });
          console.log(`[FCM] Pruned ${failedTokens.length} stale tokens for user ${userId}`);
        }
      }
    } catch (err) {
      console.error(`[FCM] Error sending to user ${userId}:`, err);
    }
  }
);

/**
 * 2. AUTOMATED GLOBAL TOPIC BROADCAST: Fires when an admin writes to admin_broadcasts/{broadcastId}
 * Instant global push to ALL closed devices subscribed to 'all_traders'
 */
exports.onAdminBroadcastCreated = onDocumentCreated(
  'admin_broadcasts/{broadcastId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const title = data.title || 'Platform Announcement';
    const message = data.message || '';
    const category = data.category || 'announcement';
    const channelId = getChannelId(category);

    try {
      console.log(`[FCM Broadcast] Broadcasting to topic 'all_traders': ${title}`);

      const topicMessage = {
        topic: 'all_traders',
        notification: {
          title: title,
          body: message,
        },
        data: {
          id: event.params.broadcastId,
          category: category,
          type: data.type || 'announcement',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: channelId,
            color: '#1D9BF0', // Twitter Blue
            icon: '@mipmap/ic_launcher',
            sound: 'default',
            priority: 'high',
          },
        },
      };

      const response = await admin.messaging().send(topicMessage);
      console.log(`[FCM Broadcast] Successfully sent topic broadcast: ${response}`);
    } catch (err) {
      console.error('[FCM Broadcast] Failed to send topic broadcast:', err);
    }
  }
);

/**
 * 3. HTTPS CALLABLE: Dispatches admin push directly from Flutter app code
 */
exports.dispatchAdminPush = onCall(async (request) => {
  // Only authenticated admins can trigger
  if (!request.auth || request.auth.token.email !== 'admin@gmail.com') {
    throw new HttpsError('permission-denied', 'Only administrators can dispatch push broadcasts.');
  }

  const { title, message, category, targetMode, targetUid } = request.data;
  const channelId = getChannelId(category);

  if (targetMode === 'all') {
    // Instant broadcast via FCM topic
    const topicMessage = {
      topic: 'all_traders',
      notification: {
        title: title || 'TradeQuest Announcement',
        body: message || '',
      },
      data: {
        category: category || 'announcement',
        type: 'admin_broadcast',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: channelId,
          color: '#1D9BF0',
          icon: '@mipmap/ic_launcher',
          sound: 'default',
        },
      },
    };

    const response = await admin.messaging().send(topicMessage);
    return { success: true, messageId: response, mode: 'topic' };
  } else {
    // Send to specific target user
    const userDoc = await admin.firestore().collection('users').doc(targetUid).get();
    const tokens = userDoc.data()?.fcmTokens || [];

    if (tokens.length === 0) {
      return { success: false, reason: 'No registered device tokens' };
    }

    const payload = {
      tokens: tokens,
      notification: {
        title: title || 'TradeQuest Alert',
        body: message || '',
      },
      data: {
        category: category || 'system',
        type: 'direct_admin_message',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: channelId,
          color: '#1D9BF0',
          icon: '@mipmap/ic_launcher',
        },
      },
    };

    const result = await admin.messaging().sendEachForMulticast(payload);
    return { success: true, successCount: result.successCount, failureCount: result.failureCount };
  }
});
