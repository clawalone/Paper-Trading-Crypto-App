import 'package:flutter/material.dart';

import '../../core/championship_prize_manager.dart';
import '../../data/models.dart';
import '../../data/notification_provider.dart';
import '../community/community_screen.dart';
import '../futures/futures_pro_screen.dart';
import '../profile/wallet_screen.dart';
import '../rewards/rewards_screen.dart';
import '../stock_detail/stock_detail_screen.dart';
import '../tournaments/tournament_screen.dart';

class NotificationNavigator {
  static void handleTap(BuildContext context, dynamic ref, AppNotification notif) {
    if (ref != null) {
      try {
        ref.read(notificationProvider.notifier).markAsRead(notif.id);
      } catch (_) {}
    }

    final payload = notif.data;

    switch (notif.category) {
      case NotificationCategory.trade:
        final symbol = payload['symbol'] as String? ?? 'BTC';
        final cleanSymbol = symbol.replaceAll('/USDT', '').replaceAll('-PERP', '').replaceAll('USDT', '');
        final isFutures = notif.type.contains('futures') || notif.type == 'liquidation';

        if (isFutures) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FuturesProScreen(
                stockSymbol: '$cleanSymbol/USDT',
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockDetailScreen(stockSymbol: cleanSymbol),
            ),
          );
        }
        break;

      case NotificationCategory.prize:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TournamentScreen(),
          ),
        );
        ChampionshipPrizeManager.checkAndShowClaimDialog(context, ref);
        break;

      case NotificationCategory.social:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CommunityScreen(),
          ),
        );
        break;

      case NotificationCategory.system:
        if (notif.type == 'admin_credit') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WalletScreen(),
            ),
          );
        } else if (notif.type == 'quest' || notif.type == 'reward') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RewardsScreen(),
            ),
          );
        }
        break;

      default:
        break;
    }
  }
}
