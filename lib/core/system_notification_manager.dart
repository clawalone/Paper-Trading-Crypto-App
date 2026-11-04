import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/models.dart';
import '../features/notifications/notification_navigator.dart';
import '../main.dart';

class SystemNotificationManager {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static const String _channelTrading = 'channel_trading';
  static const String _channelChampionship = 'channel_championship';
  static const String _channelRewards = 'channel_rewards';
  static const String _channelAnnouncements = 'channel_announcements';

  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels & request Android 13+ runtime permission
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // 1. Trading Channel (Heads-up / high importance)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelTrading,
          'Trading & Order Alerts',
          description: 'Liquidations, TP/SL, and order execution alerts',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // 2. Championship Channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelChampionship,
          'Championship & Tournament Alerts',
          description: 'Weekly tournament results, rank changes, and cash prize payouts',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // 3. Rewards & Bonus Channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelRewards,
          'Rewards & Bonuses',
          description: 'Daily check-in bonuses, streak reminders, and promotional offers',
          importance: Importance.defaultImportance,
          playSound: true,
        ),
      );

      // 4. Announcements & Social Channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelAnnouncements,
          'System Announcements & Social',
          description: 'Platform updates, admin broadcasts, tips, and follower updates',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Prompt user for Notification Permission on Android 13+
      await androidPlugin.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final payloadString = response.payload;
    if (payloadString == null || payloadString.isEmpty) return;

    try {
      final json = jsonDecode(payloadString);
      final notif = AppNotification.fromJson(json);
      final context = appNavigatorKey.currentContext;
      if (context != null) {
        NotificationNavigator.handleTap(context, null, notif);
      }
    } catch (e) {
      debugPrint('[SystemNotificationManager] Tap routing error: $e');
    }
  }

  static Future<void> showSystemNotification(AppNotification notif) async {
    if (!_isInitialized) {
      await initialize();
    }

    String channelId = _channelAnnouncements;
    String channelName = 'System Announcements';

    switch (notif.category) {
      case NotificationCategory.trade:
        channelId = _channelTrading;
        channelName = 'Trading & Order Alerts';
        break;
      case NotificationCategory.prize:
        channelId = _channelChampionship;
        channelName = 'Championship Alerts';
        break;
      case NotificationCategory.social:
        channelId = _channelAnnouncements;
        channelName = 'Community & Social';
        break;
      case NotificationCategory.system:
        if (notif.type == 'reward') {
          channelId = _channelRewards;
          channelName = 'Rewards & Bonuses';
        } else {
          channelId = _channelAnnouncements;
          channelName = 'System Announcements';
        }
        break;
      default:
        channelId = _channelAnnouncements;
        channelName = 'Notifications';
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF1D9BF0),
      styleInformation: BigTextStyleInformation(
        notif.message,
        contentTitle: notif.title,
        summaryText: 'Paper Trading',
      ),
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final notifId = notif.id.hashCode & 0x7FFFFFFF;

    await _notifications.show(
      id: notifId,
      title: notif.title,
      body: notif.message,
      notificationDetails: notificationDetails,
      payload: jsonEncode(notif.toJson()),
    );
  }
}
