import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import '../core/fcm_manager.dart';
import '../core/system_notification_manager.dart';
import '../features/notifications/in_app_notification_banner.dart';
import '../features/notifications/notification_navigator.dart';
import '../main.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  StreamSubscription? _sub;
  StreamSubscription? _authSub;
  String? _currentUid;
  bool _isFirstSnapshot = true;

  @override
  NotificationState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _authSub?.cancel();
    });

    _initAuthListener();
    return const NotificationState(isLoading: true);
  }

  void _initAuthListener() {
    // Immediately wire up if user is already signed in
    final initialUser = FirebaseAuth.instance.currentUser;
    if (initialUser != null) {
      _currentUid = initialUser.uid;
      _loadCachedNotifications(initialUser.uid);
      _listenToNotifications(initialUser.uid);
      FcmManager.syncDeviceToken(initialUser.uid);
    }

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        if (_currentUid != user.uid) {
          _currentUid = user.uid;
          _isFirstSnapshot = true;
          _loadCachedNotifications(user.uid);
          _listenToNotifications(user.uid);
          FcmManager.syncDeviceToken(user.uid);
        }
      } else {
        if (_currentUid != null) {
          FcmManager.removeDeviceToken(_currentUid!);
        }
        _currentUid = null;
        _isFirstSnapshot = true;
        _sub?.cancel();
        state = const NotificationState(notifications: [], isLoading: false);
      }
    });
  }

  Future<void> _loadCachedNotifications(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_notifications_$uid');
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        final cached = list.map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
        if (state.notifications.isEmpty && cached.isNotEmpty) {
          state = state.copyWith(notifications: cached, isLoading: false);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCachedNotifications(String uid, List<AppNotification> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(list.map((e) => e.toJson()).toList());
      await prefs.setString('cached_notifications_$uid', raw);
    } catch (_) {}
  }

  void _listenToNotifications(String uid) {
    _sub?.cancel();
    _isFirstSnapshot = true;
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .listen(
      (snapshot) {
        final items = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return AppNotification.fromJson(data);
        }).toList();

        // If newly created user and empty, seed an initial welcome notification
        if (items.isEmpty && snapshot.metadata.isFromCache == false) {
          _seedWelcomeNotification(uid);
          return;
        }

        // Trigger in-app top banner for new incoming alerts while user is active
        if (!_isFirstSnapshot && items.isNotEmpty) {
          final existingIds = state.notifications.map((n) => n.id).toSet();
          for (final item in items) {
            if (!existingIds.contains(item.id) && !item.isRead) {
              final age = DateTime.now().difference(item.createdAt);
              if (age.inMinutes.abs() <= 15) {
                final ctx = appNavigatorKey.currentContext;
                if (ctx != null) {
                  InAppNotificationBanner.show(
                    item,
                    onTap: () => NotificationNavigator.handleTap(ctx, ref, item),
                  );
                }
                // Also trigger OS system tray push notification
                SystemNotificationManager.showSystemNotification(item);
              }
            }
          }
        }
        _isFirstSnapshot = false;

        state = NotificationState(notifications: items, isLoading: false);
        _saveCachedNotifications(uid, items);
      },
      onError: (e) {
        // Fallback to cache without crashing
        state = state.copyWith(isLoading: false);
      },
    );
  }

  Future<void> _seedWelcomeNotification(String uid) async {
    final welcome = AppNotification(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      userId: uid,
      title: 'Welcome to Paper Trading 🚀',
      message: 'Explore markets, test your trading strategies with zero risk, and compete in the Weekly Championship!',
      category: NotificationCategory.system,
      type: 'welcome',
      createdAt: DateTime.now(),
      isRead: false,
    );
    await addNotification(welcome);
  }

  Future<bool> addNotification(AppNotification notif) async {
    final targetUid = notif.userId.isNotEmpty ? notif.userId : _currentUid;
    if (targetUid == null || targetUid.isEmpty) return false;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('notifications')
          .doc(notif.id.isNotEmpty ? notif.id : null);

      final toSave = notif.copyWith(id: docRef.id);
      await docRef.set(toSave.toJson());

      // Local state optimistic update if target is current user
      if (targetUid == _currentUid) {
        final updated = [toSave, ...state.notifications.where((n) => n.id != toSave.id)];
        state = state.copyWith(notifications: updated);
        _saveCachedNotifications(targetUid, updated);

        final ctx = appNavigatorKey.currentContext;
        if (ctx != null && !toSave.isRead && toSave.type != 'welcome') {
          InAppNotificationBanner.show(
            toSave,
            onTap: () => NotificationNavigator.handleTap(ctx, ref, toSave),
          );
        }
        if (!toSave.isRead && toSave.type != 'welcome') {
          SystemNotificationManager.showSystemNotification(toSave);
        }
      }
      return true;
    } catch (e) {
      debugPrint('[Notifications] Failed to add notification to $targetUid: $e');
      // Offline fallback: keep in local state if targeting self
      if (targetUid == _currentUid) {
        final updated = [notif, ...state.notifications.where((n) => n.id != notif.id)];
        state = state.copyWith(notifications: updated);
      }
      return false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final uid = _currentUid;
    if (uid == null) return;

    final updated = state.notifications.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    state = state.copyWith(notifications: updated);
    _saveCachedNotifications(uid, updated);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final uid = _currentUid;
    if (uid == null) return;

    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated);
    _saveCachedNotifications(uid, updated);

    try {
      final unreadDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> deleteNotification(String notificationId) async {
    final uid = _currentUid;
    if (uid == null) return;

    final updated = state.notifications.where((n) => n.id != notificationId).toList();
    state = state.copyWith(notifications: updated);
    _saveCachedNotifications(uid, updated);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (_) {}
  }

  Future<void> clearAll() async {
    final uid = _currentUid;
    if (uid == null) return;

    state = state.copyWith(notifications: []);
    _saveCachedNotifications(uid, []);

    try {
      final docs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, NotificationState>(
  () => NotificationNotifier(),
);
