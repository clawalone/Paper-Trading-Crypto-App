import 'package:stock_arena/core/app_material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models.dart';
import '../features/notifications/in_app_notification_banner.dart';
import '../features/notifications/notification_navigator.dart';
import '../main.dart';
import 'system_notification_manager.dart';

// Top-level background message handler required by FirebaseMessaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  debugPrint('[FCM Background] Received message: ${message.messageId}');

  // CRITICAL: When an FCM message contains a `notification` payload, Android's
  // Google Play Services client automatically renders it in the system tray.
  // Calling showSystemNotification here creates a duplicate 2nd notification in the tray!
  // We ONLY show a local system notification if it was a data-only payload (notification == null).
  if (message.notification == null) {
    final notif = _parseRemoteMessage(message);
    if (notif != null) {
      await SystemNotificationManager.showSystemNotification(notif);
    }
  }
}

AppNotification? _parseRemoteMessage(RemoteMessage message) {
  try {
    final data = Map<String, dynamic>.from(message.data);
    final notification = message.notification;

    final title = notification?.title ?? data['title'] ?? 'Trading Alert';
    final body = notification?.body ?? data['message'] ?? '';
    final categoryStr = data['category'] as String? ?? 'system';
    final type = data['type'] as String? ?? 'announcement';

    final category = NotificationCategory.values.firstWhere(
      (c) => c.name == categoryStr,
      orElse: () => NotificationCategory.system,
    );

    return AppNotification(
      id: message.messageId ?? 'fcm_${DateTime.now().millisecondsSinceEpoch}',
      userId: data['userId'] ?? '',
      title: title,
      message: body,
      category: category,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
      data: data,
    );
  } catch (e) {
    debugPrint('[FCM] Error parsing message: $e');
    return null;
  }
}

class FcmManager {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Set background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // 2. Request permissions on iOS and Android 13+
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[FCM] Authorization status: ${settings.authorizationStatus}');

      // 3. Foreground presentation options:
      // Set alert to false so Android/iOS doesn't post a duplicate system tray notification
      // while the user is actively inside the app; InAppNotificationBanner handles the foreground UI.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      // 4. Subscribe to global broadcast topics
      await messaging.subscribeToTopic('all_traders').catchError((_) {});
      await messaging.subscribeToTopic('announcements').catchError((_) {});
      await messaging.subscribeToTopic('championship').catchError((_) {});

      // 5. Handle foreground push notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Got message: ${message.messageId}');
        final notif = _parseRemoteMessage(message);
        if (notif != null) {
          // Check deduplication (prevent double banners if both topic and direct tokens received)
          if (SystemNotificationManager.shouldSuppressDuplicate(notif.title, notif.message)) {
            debugPrint('[FCM Foreground] Duplicate suppressed: ${notif.title}');
            return;
          }

          // Trigger in-app dropdown banner
          final ctx = appNavigatorKey.currentContext;
          if (ctx != null) {
            InAppNotificationBanner.show(
              notif,
              onTap: () => NotificationNavigator.handleTap(ctx, null, notif),
            );
          }
        }
      });

      // 6. Handle notification click while app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM onMessageOpenedApp] Tapped push: ${message.messageId}');
        final notif = _parseRemoteMessage(message);
        if (notif != null) {
          final ctx = appNavigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            NotificationNavigator.handleTap(ctx, null, notif);
          }
        }
      });

      // 7. Check if app was launched from a terminated state via a notification click
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM getInitialMessage] Launched from terminated: ${initialMessage.messageId}');
        final notif = _parseRemoteMessage(initialMessage);
        if (notif != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = appNavigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              NotificationNavigator.handleTap(ctx, null, notif);
            }
          });
        }
      }

      _isInitialized = true;
      debugPrint('[FCM] Successfully initialized!');
    } catch (e) {
      debugPrint('[FCM] Initialization error: $e');
    }
  }

  /// Syncs the device FCM token with Firestore under users/{uid}
  static Future<void> syncDeviceToken(String uid) async {
    if (uid.isEmpty) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[FCM] Device Token: $token');
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastFcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (newToken.isNotEmpty) {
          FirebaseFirestore.instance.collection('users').doc(uid).set({
            'fcmTokens': FieldValue.arrayUnion([newToken]),
            'lastFcmToken': newToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
    } catch (e) {
      debugPrint('[FCM] Failed to sync token: $e');
    }
  }

  /// Removes current token when user logs out
  static Future<void> removeDeviceToken(String uid) async {
    if (uid.isEmpty) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (_) {}
  }
}
