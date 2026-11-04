import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class BanManager {
  /// Accounts banned for more than 10 days are permanently and automatically deleted.
  static const int autoDeleteDaysThreshold = 10;

  /// Checks if a ban has exceeded the 10-day retention threshold.
  static bool isBanExpired(DateTime? bannedAt) {
    if (bannedAt == null) return false;
    final elapsed = DateTime.now().difference(bannedAt);
    return elapsed >= const Duration(days: autoDeleteDaysThreshold);
  }

  /// Calculates human-readable time remaining before permanent deletion.
  static String getRemainingTimeDescription(DateTime? bannedAt) {
    if (bannedAt == null) return '10 days remaining';
    final elapsed = DateTime.now().difference(bannedAt);
    final remaining = const Duration(days: autoDeleteDaysThreshold) - elapsed;

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return 'Expired (Deleting...)';
    }

    final days = remaining.inDays;
    final hours = remaining.inHours % 24;

    if (days > 0) {
      return '$days day${days > 1 ? "s" : ""}${hours > 0 ? " $hours hr" : ""} remaining';
    } else {
      final minutes = remaining.inMinutes % 60;
      if (hours > 0) {
        return '$hours hr${hours > 1 ? "s" : ""}${minutes > 0 ? " $minutes min" : ""} remaining';
      }
      return '$minutes minute${minutes > 1 ? "s" : ""} remaining';
    }
  }

  /// Checks if the logged-in user is banned beyond 10 days.
  /// If expired, automatically deletes their Firestore data, Auth account, and signs them out.
  static Future<bool> checkAndAutoDeleteCurrentUser({
    required User user,
    required bool isBanned,
    required DateTime? bannedAt,
  }) async {
    if (!isBanned) return false;

    // If account is marked banned but has no timestamp, stamp it now to start the 10-day clock
    if (bannedAt == null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'bannedAt': FieldValue.serverTimestamp(),
          'profile.bannedAt': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
      return false;
    }

    if (isBanExpired(bannedAt)) {
      debugPrint('[BanManager] Account ${user.uid} has been banned for >10 days. Executing auto-delete...');
      try {
        // 1. Delete user record in Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      } catch (e) {
        debugPrint('[BanManager] Error deleting user doc: $e');
      }

      try {
        // 2. Clean up tournament record if present
        await FirebaseFirestore.instance.collection('weekly_championship').doc(user.uid).delete();
      } catch (_) {}

      try {
        // 3. Delete Firebase Auth account
        await user.delete();
      } catch (_) {
        // Fallback to sign-out if re-authentication is required
        await FirebaseAuth.instance.signOut();
      }
      return true;
    }

    return false;
  }

  /// System-wide / Admin sweep: Finds all banned accounts and permanently deletes those
  /// banned for more than 10 days.
  static Future<int> sweepExpiredBannedUsers() async {
    int deletedCount = 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isBanned', isEqualTo: true)
          .get();

      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawBannedAt = data['bannedAt'] ?? (data['profile'] as Map?)?['bannedAt'];

        DateTime? bannedAt;
        if (rawBannedAt is Timestamp) {
          bannedAt = rawBannedAt.toDate();
        } else if (rawBannedAt is String) {
          bannedAt = DateTime.tryParse(rawBannedAt);
        }

        if (bannedAt == null) {
          // If no timestamp exists, stamp it so the 10-day countdown begins
          try {
            await doc.reference.update({
              'bannedAt': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
          continue;
        }

        if (now.difference(bannedAt) >= const Duration(days: autoDeleteDaysThreshold)) {
          debugPrint('[BanManager] Auto-deleting expired banned user: ${doc.id}');
          try {
            await doc.reference.delete();
            try {
              await FirebaseFirestore.instance.collection('weekly_championship').doc(doc.id).delete();
            } catch (_) {}
            deletedCount++;
          } catch (e) {
            debugPrint('[BanManager] Failed to delete expired user ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[BanManager] Error running sweepExpiredBannedUsers: $e');
    }
    return deletedCount;
  }
}
