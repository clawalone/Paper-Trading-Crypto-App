import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DirectFcmService {
  static const String _prefsKey = 'fcm_service_account_json';
  static Map<String, dynamic>? _cachedCredentials;

  /// Returns true if valid service account credentials are saved
  static Future<bool> hasCredentials() async {
    final creds = await getCredentials();
    return creds != null && creds.containsKey('private_key') && creds.containsKey('client_email');
  }

  /// Retrieves service account credentials from cache, SharedPreferences, or Firestore
  static Future<Map<String, dynamic>?> getCredentials() async {
    if (_cachedCredentials != null) return _cachedCredentials;

    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString(_prefsKey);
      if (localJson != null && localJson.isNotEmpty) {
        _cachedCredentials = jsonDecode(localJson) as Map<String, dynamic>;
        return _cachedCredentials;
      }

      // Check Firestore app_config/fcm_credentials
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('fcm_credentials').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('credentials')) {
          final creds = Map<String, dynamic>.from(data['credentials'] as Map);
          _cachedCredentials = creds;
          await prefs.setString(_prefsKey, jsonEncode(creds));
          return creds;
        }
      }
    } catch (e) {
      debugPrint('[DirectFCM] Error loading credentials: $e');
    }
    return null;
  }

  /// Saves service account JSON to Firestore and local preferences
  static Future<bool> saveCredentials(String rawJson) async {
    try {
      final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
      if (!parsed.containsKey('private_key') || !parsed.containsKey('client_email')) {
        return false;
      }

      _cachedCredentials = parsed;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(parsed));

      // Save to Firestore app_config for persistent admin access across sessions
      await FirebaseFirestore.instance.collection('app_config').doc('fcm_credentials').set({
        'credentials': parsed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('[DirectFCM] Failed to save credentials: $e');
      return false;
    }
  }

  /// Sends a direct FCM v1 push notification to all devices subscribed to a topic (e.g. 'all_traders')
  static Future<bool> sendTopicPush({
    required String topic,
    required String title,
    required String message,
    required String category,
    required String type,
  }) async {
    final creds = await getCredentials();
    if (creds == null) {
      debugPrint('[DirectFCM] Cannot send push: Service account credentials missing');
      return false;
    }

    final projectId = creds['project_id'] as String? ?? 'studio-9401559078-23caf';
    final channelId = _getChannelId(category);

    try {
      final accountCredentials = ServiceAccountCredentials.fromJson(creds);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await clientViaServiceAccount(accountCredentials, scopes);

      final endpoint = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
      final payload = {
        'message': {
          'topic': topic,
          'notification': {
            'title': title,
            'body': message,
          },
          'data': {
            'category': category,
            'type': type,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'android': {
            'priority': 'HIGH',
            'notification': {
              'channel_id': channelId,
              'color': '#1D9BF0', // Twitter Blue
              'icon': '@mipmap/ic_launcher',
              'sound': 'default',
            },
          },
        },
      };

      final response = await authClient.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      authClient.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[DirectFCM] Successfully delivered topic push ($topic): ${response.body}');
        return true;
      } else {
        debugPrint('[DirectFCM] FCM HTTP v1 failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[DirectFCM] Error sending topic push: $e');
      return false;
    }
  }

  /// Sends a direct FCM v1 push notification to specific device tokens
  static Future<int> sendTokensPush({
    required List<String> tokens,
    required String title,
    required String message,
    required String category,
    required String type,
  }) async {
    if (tokens.isEmpty) return 0;

    final creds = await getCredentials();
    if (creds == null) {
      debugPrint('[DirectFCM] Cannot send push: Service account credentials missing');
      return 0;
    }

    final projectId = creds['project_id'] as String? ?? 'studio-9401559078-23caf';
    final channelId = _getChannelId(category);

    int successCount = 0;

    try {
      final accountCredentials = ServiceAccountCredentials.fromJson(creds);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await clientViaServiceAccount(accountCredentials, scopes);

      final endpoint = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      for (final token in tokens) {
        final payload = {
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': message,
            },
            'data': {
              'category': category,
              'type': type,
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
            'android': {
              'priority': 'HIGH',
              'notification': {
                'channel_id': channelId,
                'color': '#1D9BF0',
                'icon': '@mipmap/ic_launcher',
                'sound': 'default',
              },
            },
          },
        };

        try {
          final response = await authClient.post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );

          if (response.statusCode >= 200 && response.statusCode < 300) {
            successCount++;
          } else {
            debugPrint('[DirectFCM] Token push failed (${response.statusCode}): ${response.body}');
          }
        } catch (_) {}
      }

      authClient.close();
      return successCount;
    } catch (e) {
      debugPrint('[DirectFCM] Error sending tokens push: $e');
      return successCount;
    }
  }

  static String _getChannelId(String category) {
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
}
