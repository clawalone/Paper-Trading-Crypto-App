import 'dart:async';
import 'package:stock_arena/core/app_material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../core/championship_prize_manager.dart';
import '../../core/ban_manager.dart';
import '../../core/direct_fcm_service.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../../data/notification_provider.dart';
import '../notifications/in_app_notification_banner.dart';
import '../notifications/notification_navigator.dart';
import '../../main.dart';
import 'admin_top_ups_screen.dart';
import 'admin_user_monitor_screen.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Direct Transfer Controllers
  final _uidController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  // App Version Controllers
  final _versionController = TextEditingController(text: '1.0.24');
  final _buildNumController = TextEditingController(text: '25');
  final _updateMsgController = TextEditingController(
    text:
        'A new version of Acadrio Trade is available on Google Play Store. Update now for new features and performance improvements!',
  );
  bool _forceUpdate = false;

  // Championship State
  bool _isFinalizingChampionship = false;

  // Top-Up Offer Broadcast Controllers
  final _offerTitleController =
      TextEditingController(text: '🔥 50% EXTRA BONUS CAPITAL OFFER!');
  final _offerMsgController = TextEditingController(
    text:
        'Limited time flash deal! Top up your virtual account today and receive up to 50% extra bonus capital for paper trading.',
  );
  final _offerBadgeController =
      TextEditingController(text: 'LIMITED TIME OFFER 🔥');
  final _offerBtnController =
      TextEditingController(text: 'CLAIM OFFER NOW 🚀');
  bool _isOfferActive = false;
  bool _isRepeatActive = false;

  static const List<Map<String, String>> _quickOfferPresets = [
    {
      'label': '🔥 50% Flash Deal',
      'title': '🔥 50% EXTRA BONUS CAPITAL OFFER!',
      'badge': 'FLASH DEAL 🔥 50%',
      'button': 'LOAD MY BAGS 💰',
      'message': 'Limited time flash deal! Top up your virtual account today and receive up to 50% extra bonus capital for paper trading.',
    },
    {
      'label': '🚀 BTC Pumping',
      'title': '🚀 BITCOIN IS PUMPING: DON\'T RUN OUT OF MARGIN!',
      'badge': 'BULL RUN ALERT 📈',
      'button': 'CLAIM BONUS CASH 🚀',
      'message': 'Market volatility is going crazy right now! Don\'t let your positions get liquidated. Top up your virtual war chest today and get up to 50% extra bonus trading power instantly.',
    },
    {
      'label': '🛡️ Liquidation Shield',
      'title': '🛡️ LIQUIDATION SHIELD: BOOST YOUR WAR CHEST',
      'badge': 'RISK SHIELD 🛡️',
      'button': 'BOOST MARGIN NOW ⚡',
      'message': 'High volatility detected across BTC and major altcoins! Strengthen your margin buffer to survive unexpected market dips and ride the next rally.',
    },
    {
      'label': '⚡ Weekend 2X',
      'title': '⚡ WEEKEND TRADING CAPITAL MULTIPLIER!',
      'badge': 'WEEKEND SPECIAL ⚡',
      'button': 'DOUBLE MY BALANCE 🎁',
      'message': 'Crypto never sleeps! Top up your paper trading funds this weekend to unlock exclusive bonus balance and test high-leverage 20x strategies risk-free.',
    },
    {
      'label': '🐋 Whale Tier',
      'title': '🐋 TRADE LIKE A WHALE: VIP LIQUIDITY PACK',
      'badge': 'WHALE TIER 🐋',
      'button': 'UNLOCK WHALE BAGS 💎',
      'message': 'Move markets like an institutional whale! Top up your virtual account to trade the deepest order books with maximum position sizing and zero fear.',
    },
    {
      'label': '🏆 Prize Sprint',
      'title': '🏆 LEADERBOARD SPRINT: TOP 10 PRIZE BOOST',
      'badge': 'PRIZE RACE 🏆',
      'button': 'GET SPRINT FUNDS 🥇',
      'message': 'The weekly leaderboard race is heating up! Secure extra virtual margin now to execute calculated high-ROE trades and climb into the Top 10 prize zone before Sunday midnight.',
    },
  ];

  // Account Ban Management Controllers & State
  final _banUidController = TextEditingController();
  final _banReasonController = TextEditingController(
    text: 'Violation of Community & Trading Guidelines',
  );
  bool _isSearchingBanUser = false;
  bool _isProcessingBan = false;
  Map<String, dynamic>? _foundBanUser;
  String? _foundBanDocId;

  // Broadcast & Push Notification Controllers & State
  static const List<Map<String, dynamic>> _quickNotificationPresets = [
    {
      'label': '💰 Login Cash',
      'title': '💰 Grab Your Today\'s Login Cash!',
      'message': 'Your daily reward is ready! Check in now to claim your free virtual cash and keep your login streak going 🔥',
      'category': 'system',
      'type': 'reward',
      'icon': Icons.monetization_on_rounded,
      'color': Color(0xFF00C087),
    },
    {
      'label': '🔥 Streak Alert',
      'title': '🔥 Don\'t Break Your Login Streak!',
      'message': 'Only a few hours left today! Claim your daily reward to multiply your virtual cash bonus and unlock streak badges.',
      'category': 'system',
      'type': 'reward',
      'icon': Icons.local_fire_department_rounded,
      'color': Color(0xFFFF9800),
    },
    {
      'label': '🏆 Championship Ending',
      'title': '🏆 Weekly Championship Ending Soon!',
      'message': 'The weekly leaderboard finalizes at Sunday midnight! Enter high-conviction trades now to lock in your Top 10 prize.',
      'category': 'prize',
      'type': 'weekly_prize',
      'icon': Icons.emoji_events_rounded,
      'color': Color(0xFFF3BA2F),
    },
    {
      'label': '🥇 Championship Payouts',
      'title': '🥇 Championship Payouts Distributed!',
      'message': 'Congratulations to the Top 10 traders! Cash awards have been credited. All players are reset to 0.0% baseline for the new week.',
      'category': 'prize',
      'type': 'weekly_prize',
      'icon': Icons.workspace_premium_rounded,
      'color': Color(0xFFF3BA2F),
    },
    {
      'label': '🎁 Free Capital Drop',
      'title': '🎁 Free Virtual Capital Drop by Admin!',
      'message': 'Bonus virtual cash has been credited to active traders! Test out fresh Spot and Futures strategies risk-free today.',
      'category': 'system',
      'type': 'reward',
      'icon': Icons.card_giftcard_rounded,
      'color': Color(0xFF00E5FF),
    },
    {
      'label': '⚡ Weekend Trading',
      'title': '⚡ Weekend Crypto Action Is Live!',
      'message': 'Crypto never sleeps! Trade the weekend volatility with up to 20x leverage on BTC, ETH, and trending altcoins.',
      'category': 'system',
      'type': 'announcement',
      'icon': Icons.bolt_rounded,
      'color': Color(0xFF00D09C),
    },
    {
      'label': '⚔️ 1v1 Arena Duels',
      'title': '⚔️ 1v1 Arena Duel Challenge!',
      'message': 'Traders are waiting in the Arena! Put your trading skills to the test in 60-second live blitz duels to earn XP.',
      'category': 'system',
      'type': 'announcement',
      'icon': Icons.sports_kabaddi_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'label': '📈 Market Breakout',
      'title': '📈 High Volatility & Breakout Alert',
      'message': 'Major crypto assets (BTC, ETH, SOL) are breaking resistance! Review your open positions and set stop-loss levels.',
      'category': 'trade',
      'type': 'order_fill',
      'icon': Icons.trending_up_rounded,
      'color': Color(0xFF1D9BF0),
    },
    {
      'label': '🤖 AI Signals Alert',
      'title': '🤖 New AI Signals Generated!',
      'message': 'The AI Signals Desk just published fresh Spot & Futures recommendations with clear Entry, TP, and SL targets.',
      'category': 'trade',
      'type': 'order_fill',
      'icon': Icons.auto_awesome_rounded,
      'color': Color(0xFFE040FB),
    },
    {
      'label': '📢 Platform Update',
      'title': '📢 Platform Upgrade & Performance Boost',
      'message': 'Welcome to the new trading season! Enjoy smoother charts, upgraded indicators, and enhanced server speed.',
      'category': 'system',
      'type': 'announcement',
      'icon': Icons.campaign_rounded,
      'color': Color(0xFF1D9BF0),
    },
  ];

  static const Map<String, Map<String, String>> _categoryDefaults = {
    'announcement': {
      'title': '📢 Platform Announcement',
      'message': 'Welcome to the new trading season! Compete in the Weekly Championship for virtual cash prizes.',
    },
    'weekly_prize': {
      'title': '🏆 Weekly Championship Payout',
      'message': 'Weekly Leaderboard settled! Top 3 traders have received their virtual capital prizes directly to their paper trading wallet.',
    },
    'reward': {
      'title': '🎁 Daily Trading Bonus Credited',
      'message': 'Your daily activity reward has been unlocked! Check in now to maintain your streak and claim bonus virtual cash.',
    },
    'order_fill': {
      'title': '📈 Volatility Alert: High Market Movement',
      'message': 'Crypto markets are experiencing high volume and breakout momentum. Review your open positions and manage stop-losses.',
    },
  };

  final _notifTitleController =
      TextEditingController(text: '📢 Platform Announcement');
  final _notifMsgController = TextEditingController(
    text:
        'Welcome to the new trading season! Compete in the Weekly Championship for virtual cash prizes.',
  );
  final _notifTargetUidController = TextEditingController();
  String _notifTargetMode = 'all';
  String _notifCategory = 'system';
  String _notifType = 'announcement';
  bool _isSendingNotif = false;
  bool _hasFcmCreds = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrentAppVersionConfig();
    _loadCurrentOfferConfig();
    _autoSweepExpiredBans();
    _checkFcmCredentials();
  }

  Future<void> _checkFcmCredentials() async {
    final hasCreds = await DirectFcmService.hasCredentials();
    if (mounted) setState(() => _hasFcmCreds = hasCreds);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _uidController.dispose();
    _amountController.dispose();
    _versionController.dispose();
    _buildNumController.dispose();
    _updateMsgController.dispose();
    _offerTitleController.dispose();
    _offerMsgController.dispose();
    _offerBadgeController.dispose();
    _offerBtnController.dispose();
    _banUidController.dispose();
    _banReasonController.dispose();
    _notifTitleController.dispose();
    _notifMsgController.dispose();
    _notifTargetUidController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BACKEND ACTIONS
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _handleFinalizeChampionship() async {
    final currency = ref.read(userProvider).profile.preferredCurrency;
    final formatter = AppCurrencyFormatter(currency, decimalDigits: 0);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF16181C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF2F3336), width: 1),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F3336),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFF3BA2F), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Finalize Week & Distribute Payouts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'This will instantly distribute ${formatter.format(92000)} total virtual capital to the Top 10 leaderboard traders:',
                style: const TextStyle(
                  color: Color(0xFF71767B),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF202327),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2F3336)),
                ),
                child: Column(
                  children: [
                    _buildPrizeRow('🥇 Rank #1 Winner', formatter.format(50000),
                        const Color(0xFFF3BA2F)),
                    const SizedBox(height: 6),
                    _buildPrizeRow('🥈 Rank #2 Runner-up', formatter.format(25000),
                        const Color(0xFFC0C0C0)),
                    const SizedBox(height: 6),
                    _buildPrizeRow('🥉 Rank #3 Podium', formatter.format(10000),
                        const Color(0xFFCD7F32)),
                    const SizedBox(height: 6),
                    _buildPrizeRow('🎖️ Ranks #4 - #10 (each)',
                        formatter.format(1000), AppColors.profit),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'All winners receive an in-app claim popup. Tournament scores will be safely reset to 0.0% for the next week.',
                style: TextStyle(color: Color(0xFF71767B), fontSize: 11),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2F3336)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3BA2F),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Confirm & Payout',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isFinalizingChampionship = true);
    try {
      final res = await ChampionshipPrizeManager.finalizeAndDistributeRewards(
        weekTitle: 'Weekly Championship',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] as String? ?? 'Payout complete'),
            backgroundColor:
                res['success'] == true ? AppColors.profit : AppColors.loss,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFinalizingChampionship = false);
      }
    }
  }

  Widget _buildPrizeRow(String label, String amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        Text(amount,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _autoSweepExpiredBans() async {
    try {
      final deleted = await BanManager.sweepExpiredBannedUsers();
      if (deleted > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.loss,
            content: Text(
                'Auto-deleted $deleted account(s) banned for more than 10 days.'),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentAppVersionConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            if (data['latestVersion'] != null) {
              _versionController.text = data['latestVersion'].toString();
            }
            if (data['latestBuildNumber'] != null) {
              _buildNumController.text = data['latestBuildNumber'].toString();
            }
            if (data['updateMessage'] != null) {
              _updateMsgController.text = data['updateMessage'].toString();
            }
            if (data['forceUpdate'] is bool) {
              _forceUpdate = data['forceUpdate'] as bool;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentOfferConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('promotions')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            if (data['title'] != null) {
              _offerTitleController.text = data['title'].toString();
            }
            if (data['message'] != null) {
              _offerMsgController.text = data['message'].toString();
            }
            if (data['badgeText'] != null) {
              _offerBadgeController.text = data['badgeText'].toString();
            }
            if (data['buttonText'] != null) {
              _offerBtnController.text = data['buttonText'].toString();
            }
            if (data['isActive'] is bool) {
              _isOfferActive = data['isActive'] as bool;
            }
            if (data['repeat'] is bool) {
              _isRepeatActive = data['repeat'] as bool;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _broadcastOfferAlert() async {
    final title = _offerTitleController.text.trim();
    final msg = _offerMsgController.text.trim();
    if (title.isEmpty || msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and Message cannot be empty')),
      );
      return;
    }

    try {
      final newOfferId = 'offer_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('promotions')
          .set({
        'offerId': newOfferId,
        'title': title,
        'message': msg,
        'badgeText': _offerBadgeController.text.trim(),
        'buttonText': _offerBtnController.text.trim(),
        'isActive': _isOfferActive,
        'repeat': _isRepeatActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1D9BF0),
            content: Text(_isOfferActive
                ? 'Top-Up Offer broadcasted to all users! 🚀'
                : 'Offer broadcast config saved (Disabled).'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _stopAllPopups() async {
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('promotions')
          .set({
        'offerId': 'stopped_${DateTime.now().millisecondsSinceEpoch}',
        'title': '',
        'message': '',
        'badgeText': '',
        'buttonText': '',
        'isActive': false,
        'repeat': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isOfferActive = false;
          _isRepeatActive = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.loss,
            content: Text('All broadcast popups stopped and deactivated! 🛑'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop popups: $e')),
        );
      }
    }
  }

  Future<void> _updateAppVersion() async {
    final v = _versionController.text.trim();
    final b = int.tryParse(_buildNumController.text.trim());
    if (v.isEmpty || b == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid version or build number')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .set({
        'latestVersion': v,
        'latestBuildNumber': b,
        'updateMessage': _updateMsgController.text.trim(),
        'forceUpdate': _forceUpdate,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1D9BF0),
            content: Text(
                'App update broadcast to v$v (Build $b)! Active users will see the update alert.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _transferMoney() async {
    final uid = _uidController.text.trim();
    final amountStr = _amountController.text.trim();
    if (uid.isEmpty || amountStr.isEmpty) return;

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .where('profile.publicUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (qs.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found with that UID')),
          );
        }
      } else {
        final doc = qs.docs.first;
        final currentProfile = doc.data()['profile'] as Map<String, dynamic>;
        final currentBalance =
            (currentProfile['virtualBalance'] as num?)?.toDouble() ?? 0.0;
        final newBalance = currentBalance + amount;

        currentProfile['virtualBalance'] = newBalance;

        // 1. Log wallet history on user doc
        final walletEntry = {
          'title': 'Admin Added Funds',
          'subtitle': 'Direct balance credit from admin',
          'amount': amount,
          'type': 'credit',
          'category': 'admin_credit',
          'timestamp': DateTime.now().toIso8601String(),
        };
        final existingEntries =
            List<dynamic>.from(doc.data()['walletEntries'] as List? ?? []);
        existingEntries.add(walletEntry);

        await doc.reference.update({
          'profile': currentProfile,
          'walletEntries': existingEntries,
        });

        // 2. Audit log in money_requests
        await FirebaseFirestore.instance.collection('money_requests').add({
          'requesterName':
              (currentProfile['name'] as String?) ?? 'CryptoTrader',
          'requesterUid': uid,
          'requesterId': doc.id,
          'amount': amount,
          'inrAmount': 0.0,
          'paymentId': 'ADMIN_DIRECT_${DateTime.now().millisecondsSinceEpoch}',
          'paymentMethod': 'admin_direct',
          'reason': 'Direct Admin Balance Credit',
          'requesterNetWorth': currentBalance,
          'status': 'approved',
          'createdAt': DateTime.now().toIso8601String(),
          'previousBalance': currentBalance,
          'newBalance': newBalance,
        });

        // 3. Deliver notification to credited user
        final userPrefCurrency =
            (currentProfile['preferredCurrency'] as String?) ?? 'USD';
        final userFormatter =
            AppCurrencyFormatter(userPrefCurrency, decimalDigits: 0);
        final formattedCredit = userFormatter.format(amount);
        final formattedNewBalance = userFormatter.format(newBalance);

        final notifRef = doc.reference.collection('notifications').doc();
        await notifRef.set({
          'id': notifRef.id,
          'userId': doc.id,
          'title': '💰 Funds Credited by Admin!',
          'message':
              'Admin has directly credited $formattedCredit to your paper trading balance. New balance: $formattedNewBalance.',
          'category': 'system',
          'type': 'admin_credit',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'data': {
            'amount': amount,
            'previousBalance': currentBalance,
            'newBalance': newBalance,
            'creditedByAdmin': true,
          },
        });

        if (mounted) {
          final currSym = CurrencyFormatters.getSymbol(
              ref.read(userProvider).profile.preferredCurrency);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.profit,
              content: Text('Successfully credited $currSym$amount to $uid!'),
            ),
          );
          _uidController.clear();
          _amountController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _lookupUserForBan() async {
    final query = _banUidController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a UID, Email, or Username')),
      );
      return;
    }

    setState(() {
      _isSearchingBanUser = true;
      _foundBanUser = null;
      _foundBanDocId = null;
    });

    try {
      var qs = await FirebaseFirestore.instance
          .collection('users')
          .where('profile.publicUid', isEqualTo: query)
          .limit(1)
          .get();

      if (qs.docs.isEmpty) {
        final directDoc =
            await FirebaseFirestore.instance.collection('users').doc(query).get();
        if (directDoc.exists && directDoc.data() != null) {
          setState(() {
            _foundBanDocId = directDoc.id;
            _foundBanUser = directDoc.data();
          });
          return;
        }
      }

      if (qs.docs.isEmpty && query.contains('@')) {
        qs = await FirebaseFirestore.instance
            .collection('users')
            .where('profile.email', isEqualTo: query.toLowerCase())
            .limit(1)
            .get();
      }

      if (qs.docs.isEmpty) {
        qs = await FirebaseFirestore.instance
            .collection('users')
            .where('profile.name', isEqualTo: query)
            .limit(1)
            .get();
      }

      if (qs.docs.isNotEmpty) {
        final doc = qs.docs.first;
        setState(() {
          _foundBanDocId = doc.id;
          _foundBanUser = doc.data();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No user found with that UID, Email, or Username')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingBanUser = false);
    }
  }

  Future<void> _toggleBanUser({required bool ban}) async {
    if (_foundBanDocId == null || _foundBanUser == null) return;

    final profile =
        (_foundBanUser!['profile'] as Map<String, dynamic>?) ?? {};
    final userName = (profile['name'] as String?) ?? 'This user';
    final reason = _banReasonController.text.trim().isNotEmpty
        ? _banReasonController.text.trim()
        : 'Violation of Community & Trading Guidelines';

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF16181C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF2F3336), width: 1),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F3336),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    ban ? Icons.gavel_rounded : Icons.check_circle_rounded,
                    color: ban ? AppColors.loss : AppColors.profit,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ban ? 'Ban User Account?' : 'Lift Account Ban?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ban
                    ? 'Are you sure you want to suspend "$userName"?\nThey will be instantly locked out of paper trading, tournaments, and social features.'
                    : 'Are you sure you want to restore full access for "$userName"?',
                style: const TextStyle(
                    color: Color(0xFF71767B), fontSize: 13, height: 1.4),
              ),
              if (ban) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.loss.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.loss.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Reason: $reason',
                    style: const TextStyle(
                        color: AppColors.loss,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2F3336)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ban ? AppColors.loss : AppColors.profit,
                        foregroundColor: ban ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                      ),
                      child: Text(
                        ban ? 'Confirm Ban' : 'Confirm Unban',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessingBan = true);

    try {
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(_foundBanDocId);

      final updatedProfile = Map<String, dynamic>.from(profile);
      updatedProfile['isBanned'] = ban;
      updatedProfile['banReason'] = ban ? reason : null;
      updatedProfile['bannedAt'] =
          ban ? DateTime.now().toIso8601String() : null;

      await docRef.update({
        'isBanned': ban,
        'banReason': ban ? reason : null,
        'bannedAt': ban ? FieldValue.serverTimestamp() : null,
        'profile': updatedProfile,
      });

      setState(() {
        _foundBanUser!['isBanned'] = ban;
        _foundBanUser!['banReason'] = ban ? reason : null;
        _foundBanUser!['profile'] = updatedProfile;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ban
                ? 'User account has been banned.'
                : 'User ban has been lifted.'),
            backgroundColor: ban ? AppColors.loss : AppColors.profit,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBan = false);
    }
  }

  Future<void> _quickUnbanUser({
    required String docId,
    required String userName,
    required Map<String, dynamic> profile,
  }) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF16181C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF2F3336), width: 1),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F3336),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.profit, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Lift User Ban',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to lift the suspension for "$userName"?\nFull access to their paper trading account will be restored immediately.',
                style: const TextStyle(
                    color: Color(0xFF71767B), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2F3336)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.profit,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                      ),
                      child: const Text('Confirm Unban',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final updatedProfile = Map<String, dynamic>.from(profile);
      updatedProfile['isBanned'] = false;
      updatedProfile['banReason'] = null;
      updatedProfile['bannedAt'] = null;

      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'isBanned': false,
        'banReason': null,
        'bannedAt': null,
        'profile': updatedProfile,
      });

      if (_foundBanDocId == docId && _foundBanUser != null) {
        setState(() {
          _foundBanUser!['isBanned'] = false;
          _foundBanUser!['banReason'] = null;
          _foundBanUser!['profile'] = updatedProfile;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.profit,
            content: Text('Ban lifted for "$userName"! Account is active.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.loss),
        );
      }
    }
  }

  void _openFcmCredentialsModal() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16181C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF2F3336), width: 1),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F3336),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.bolt_rounded, color: Color(0xFF1D9BF0), size: 22),
                SizedBox(width: 8),
                Text(
                  'Free Direct Cloud Push Setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Enables 100% Free Push Notifications to closed & locked phones directly from this Admin Panel without Cloud Functions or credit cards.\n\n'
              'How to get your free key:\n'
              '1. Open Firebase Console → Project Settings (⚙️)\n'
              '2. Select Service Accounts tab\n'
              '3. Click "Generate new private key"\n'
              '4. Paste the downloaded JSON file content below:',
              style: TextStyle(color: Color(0xFF71767B), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 5,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              decoration: _buildTwitterInputDecoration(
                hintText: '{\n  "type": "service_account",\n  "project_id": "...",\n  "private_key": "..."\n}',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  final success = await DirectFcmService.saveCredentials(text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    setState(() => _hasFcmCreds = success);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: success ? const Color(0xFF00BA7C) : AppColors.loss,
                        content: Text(
                          success
                              ? '✅ Direct Cloud Push active! Notifications will now wake up closed phones.'
                              : '❌ Invalid Service Account JSON. Please verify the copied file.',
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9BF0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text('Save & Activate Free Cloud Push', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendNotification() async {
    final title = _notifTitleController.text.trim();
    final message = _notifMsgController.text.trim();
    final rawTarget = _notifTargetUidController.text.trim();
    final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both title and message')),
      );
      return;
    }

    if (_notifTargetMode == 'self' && currentAuthUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to detect active logged-in user account')),
      );
      return;
    }

    if (_notifTargetMode == 'single' && rawTarget.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter recipient username, email, or UID')),
      );
      return;
    }

    if (_notifTargetMode == 'all') {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: const Color(0xFF16181C),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: Color(0xFF2F3336), width: 1),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F3336),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.campaign_rounded,
                        color: Color(0xFF1D9BF0), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Broadcast to All Users?',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'This notification will be delivered to EVERY active trader in the system:\n\n"$title"\n$message',
                  style: const TextStyle(
                      color: Color(0xFF71767B), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2F3336)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9BF0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                        ),
                        child: const Text('Confirm Broadcast',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isSendingNotif = true);

    try {
      int deliveredCount = 0;
      final categoryEnum = NotificationCategory.values.firstWhere(
        (c) => c.name == _notifCategory,
        orElse: () => NotificationCategory.system,
      );

      if (_notifTargetMode == 'self' || _notifTargetMode == 'single') {
        String targetUid = '';
        String targetUserName = '';

        if (_notifTargetMode == 'self') {
          targetUid = currentAuthUid!;
          targetUserName = ref.read(userProvider).profile.name;
        } else {
          final currentProfile = ref.read(userProvider).profile;
          if (rawTarget.toLowerCase() == 'me' ||
              rawTarget.toLowerCase() == 'myself' ||
              rawTarget.toLowerCase() == currentProfile.name.toLowerCase() ||
              rawTarget == currentProfile.publicUid ||
              rawTarget == currentAuthUid) {
            targetUid = currentAuthUid ?? rawTarget;
            targetUserName = currentProfile.name;
          } else {
            // 1. Direct docId (Auth UID) lookup
            final directDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(rawTarget)
                .get();
            if (directDoc.exists && directDoc.data() != null) {
              targetUid = directDoc.id;
              final data = directDoc.data()!;
              final profile = data['profile'] as Map<String, dynamic>?;
              targetUserName = profile?['name'] ?? data['name'] ?? 'Trader';
            } else {
              // 2. Search by profile.publicUid or publicUid
              var qs = await FirebaseFirestore.instance
                  .collection('users')
                  .where('profile.publicUid', isEqualTo: rawTarget)
                  .limit(1)
                  .get();
              if (qs.docs.isEmpty) {
                qs = await FirebaseFirestore.instance
                    .collection('users')
                    .where('publicUid', isEqualTo: rawTarget)
                    .limit(1)
                    .get();
              }

              // 3. Search by profile.email or email
              if (qs.docs.isEmpty && rawTarget.contains('@')) {
                qs = await FirebaseFirestore.instance
                    .collection('users')
                    .where('profile.email', isEqualTo: rawTarget.toLowerCase())
                    .limit(1)
                    .get();
                if (qs.docs.isEmpty) {
                  qs = await FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: rawTarget.toLowerCase())
                      .limit(1)
                      .get();
                }
              }

              // 4. Search by profile.name or name
              if (qs.docs.isEmpty) {
                qs = await FirebaseFirestore.instance
                    .collection('users')
                    .where('profile.name', isEqualTo: rawTarget)
                    .limit(1)
                    .get();
                if (qs.docs.isEmpty) {
                  qs = await FirebaseFirestore.instance
                      .collection('users')
                      .where('name', isEqualTo: rawTarget)
                      .limit(1)
                      .get();
                }
              }

              if (qs.docs.isNotEmpty) {
                final doc = qs.docs.first;
                targetUid = doc.id;
                final data = doc.data();
                final profile = data['profile'] as Map<String, dynamic>?;
                targetUserName = profile?['name'] ?? data['name'] ?? 'Trader';
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.loss,
                      content: Text('❌ Trader "$rawTarget" not found. Please verify the UID, Username, or Email.'),
                    ),
                  );
                }
                return;
              }
            }
          }
        }

        final notif = AppNotification(
          id: '',
          userId: targetUid,
          title: title,
          message: message,
          category: categoryEnum,
          type: _notifType,
          createdAt: DateTime.now(),
          isRead: false,
          data: {'sentByAdmin': true},
        );

        // Save & deliver via notification notifier
        final success = await ref.read(notificationProvider.notifier).addNotification(notif);
        if (!success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.loss,
                content: Text('❌ Failed to save notification to Firestore for $targetUserName.'),
              ),
            );
          }
          return;
        }
        deliveredCount = 1;

        // Direct $0 FCM push to target user's closed phone
        if (_hasFcmCreds && targetUid.isNotEmpty) {
          FirebaseFirestore.instance.collection('users').doc(targetUid).get().then((doc) {
            final tokens = doc.data()?['fcmTokens'];
            if (tokens is List && tokens.isNotEmpty) {
              DirectFcmService.sendTokensPush(
                tokens: List<String>.from(tokens),
                title: title,
                message: message,
                category: _notifCategory,
                type: _notifType,
              );
            }
          }).catchError((_) {});
        }

        // Visual confirmation banner on admin screen
        if (targetUid != currentAuthUid && currentAuthUid != null) {
          final adminConfirmNotif = AppNotification(
            id: 'sent_${DateTime.now().millisecondsSinceEpoch}',
            userId: currentAuthUid,
            title: 'Delivered to $targetUserName',
            message: message,
            category: categoryEnum,
            type: _notifType,
            createdAt: DateTime.now(),
            isRead: false,
            data: {'sentByAdmin': true, 'deliveredTo': targetUserName},
          );
          final ctx = appNavigatorKey.currentContext ?? context;
          InAppNotificationBanner.show(
            adminConfirmNotif,
            onTap: () => NotificationNavigator.handleTap(ctx, ref, adminConfirmNotif),
          );
        }
      } else {
        // Global broadcast
        final usersSnap =
            await FirebaseFirestore.instance.collection('users').get();
        final docs = usersSnap.docs;

        for (int i = 0; i < docs.length; i += 400) {
          final chunk =
              docs.sublist(i, (i + 400 > docs.length) ? docs.length : i + 400);
          final batch = FirebaseFirestore.instance.batch();

          for (final userDoc in chunk) {
            final nRef = userDoc.reference.collection('notifications').doc();
            batch.set(nRef, {
              'id': nRef.id,
              'userId': userDoc.id,
              'title': title,
              'message': message,
              'category': _notifCategory,
              'type': _notifType,
              'createdAt': DateTime.now().toIso8601String(),
              'isRead': false,
              'data': {'sentByAdmin': true, 'broadcast': true},
            });
            deliveredCount++;
          }
          await batch.commit();
        }

        // Direct $0 FCM push to all closed devices globally via topic
        if (_hasFcmCreds) {
          unawaited(DirectFcmService.sendTopicPush(
            topic: 'all_traders',
            title: title,
            message: message,
            category: _notifCategory,
            type: _notifType,
          ));
        }

        // Trigger FCM Cloud Function automated push to closed phones across the globe
        try {
          await FirebaseFirestore.instance.collection('admin_broadcasts').add({
            'title': title,
            'message': message,
            'category': _notifCategory,
            'type': _notifType,
            'target': 'all',
            'senderUid': currentAuthUid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}

        // Show banner for admin as well for broadcast confirmation
        if (currentAuthUid != null) {
          final broadcastNotif = AppNotification(
            id: 'broadcast_${DateTime.now().millisecondsSinceEpoch}',
            userId: currentAuthUid,
            title: title,
            message: message,
            category: categoryEnum,
            type: _notifType,
            createdAt: DateTime.now(),
            isRead: false,
            data: {'sentByAdmin': true, 'broadcast': true},
          );
          final ctx = appNavigatorKey.currentContext ?? context;
          InAppNotificationBanner.show(
            broadcastNotif,
            onTap: () => NotificationNavigator.handleTap(ctx, ref, broadcastNotif),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1D9BF0),
            content:
                Text('🚀 Notification delivered to $deliveredCount user(s)!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.loss,
            content: Text('Failed to deliver notification: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingNotif = false);
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BUILD METHOD & 4-TAB NAVIGATION
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userCurrency = ref.watch(userProvider).profile.preferredCurrency;
    final currSym = CurrencyFormatters.getSymbol(userCurrency);
    final adminFormatter = AppCurrencyFormatter(userCurrency, decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Admin Desk',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1D9BF0).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1D9BF0).withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Color(0xFF1D9BF0), size: 12),
                  SizedBox(width: 3),
                  Text(
                    'SUPERADMIN',
                    style: TextStyle(
                      color: Color(0xFF1D9BF0),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorColor: const Color(0xFF1D9BF0),
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: const Color(0xFF2F3336),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF71767B),
                labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Hub'),
                  Tab(text: 'Payouts & Ops'),
                  Tab(text: 'Notifications'),
                  Tab(text: 'Moderation'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHubTab(context, currSym, adminFormatter),
          _buildPayoutsAndOpsTab(context, currSym, adminFormatter),
          _buildNotificationsTab(context),
          _buildModerationTab(context),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: HUB & OVERVIEW
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHubTab(
    BuildContext context,
    String currSym,
    AppCurrencyFormatter adminFormatter,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Live Quick Stats Row
        _buildHubMetricsRow(),
        const SizedBox(height: 18),

        // Section Title
        const Text(
          'MANAGEMENT CONSOLES',
          style: TextStyle(
            color: Color(0xFF71767B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        // Console 1: User & Portfolio Anti-Cheat Monitor
        _buildHubCard(
          icon: Icons.manage_search_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: 'User Activity & Portfolio Monitor',
          description:
              'Search any trader by UID to inspect their live spot portfolio, open futures leverage, and suspicious trading volumes.',
          buttonLabel: 'Launch Monitor',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminUserMonitorScreen()),
            );
          },
        ),
        const SizedBox(height: 12),

        // Console 2: User Top-Ups & In-App Revenue
        _buildHubCard(
          icon: Icons.receipt_long_rounded,
          iconColor: AppColors.profit,
          title: 'User Top-Ups & In-App Revenue',
          description:
              'Track real monetary revenue, Google Play purchase tokens, approval statuses, and user payment timestamps.',
          buttonLabel: 'Review Top-Ups',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminTopUpsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),

        // Console 3: Community Feature Requests
        _buildHubCard(
          icon: Icons.tips_and_updates_outlined,
          iconColor: const Color(0xFF818CF8),
          title: 'Feature Requests Hub',
          description:
              'Inspect ideas, feature suggestions, and UX improvements submitted by traders across the community.',
          buttonLabel: 'Review Ideas',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const FeatureRequestsAdminScreen()),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHubMetricsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('isBanned', isEqualTo: true)
          .snapshots(),
      builder: (context, banSnap) {
        final bannedCount = banSnap.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('feature_requests')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, reqSnap) {
            final pendingIdeas = reqSnap.data?.docs.length ?? 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF16181C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2F3336)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      label: 'STATUS',
                      value: 'ONLINE',
                      valueColor: AppColors.profit,
                      icon: Icons.circle,
                      iconSize: 8,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: const Color(0xFF2F3336),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      label: 'BANNED',
                      value: '$bannedCount',
                      valueColor:
                          bannedCount > 0 ? AppColors.loss : Colors.white70,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: const Color(0xFF2F3336),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      label: 'IDEAS PENDING',
                      value: '$pendingIdeas',
                      valueColor: const Color(0xFF818CF8),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    Color? valueColor,
    IconData? icon,
    double iconSize = 12,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF71767B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: valueColor, size: iconSize),
              const SizedBox(width: 5),
            ],
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHubCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16181C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2F3336)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF71767B),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF202327),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF2F3336)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: PAYOUTS & OPERATIONS (TOP USER PRIORITY)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildPayoutsAndOpsTab(
    BuildContext context,
    String currSym,
    AppCurrencyFormatter adminFormatter,
  ) {
    final profile = ref.watch(userProvider).profile;
    final isSignalsUnlocked = profile.isAiSignalsUnlocked;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // ── 1. Weekly Championship Desk (STAR CARD) ──────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16181C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF3BA2F).withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3BA2F).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: Color(0xFFF3BA2F), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weekly Championship Desk',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Prize Pool: ${adminFormatter.format(92000)} Capital',
                          style: const TextStyle(
                            color: Color(0xFFF3BA2F),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Automated Payout Notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.profit.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.profit.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.profit, size: 15),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Auto-Payout Active: Every Monday at 12:00 AM midnight, top 10 traders are credited and tournament scores reset.',
                        style: TextStyle(
                          color: AppColors.profit,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Prize Distribution Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF202327),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2F3336)),
                ),
                child: Column(
                  children: [
                    _buildPrizeRow('🥇 Rank #1 Winner',
                        adminFormatter.format(50000), const Color(0xFFF3BA2F)),
                    const SizedBox(height: 6),
                    _buildPrizeRow('🥈 Rank #2 Runner-up',
                        adminFormatter.format(25000), const Color(0xFFC0C0C0)),
                    const SizedBox(height: 6),
                    _buildPrizeRow('🥉 Rank #3 3rd Podium',
                        adminFormatter.format(10000), const Color(0xFFCD7F32)),
                    const SizedBox(height: 6),
                    _buildPrizeRow('🎖️ Ranks #4 - #10 (each)',
                        adminFormatter.format(1000), AppColors.profit),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '⚡ Qualification Rule: Only traders who crossed >0.0% profit qualify for payouts. Traders with 0.0% or negative scores are strictly excluded.',
                style: TextStyle(color: Color(0xFFF3BA2F), fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              // Manual Finalize Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isFinalizingChampionship
                      ? null
                      : _handleFinalizeChampionship,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3BA2F),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  icon: _isFinalizingChampionship
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2),
                        )
                      : const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: Text(
                    _isFinalizingChampionship
                        ? 'Distributing Rewards...'
                        : 'Finalize Week & Distribute Payouts',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 2. Direct Money Injection ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16181C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2F3336)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.currency_exchange_rounded,
                      color: AppColors.profit, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Direct Balance Credit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Credit virtual funds into any trader\'s account by their public UID.',
                style: TextStyle(color: Color(0xFF71767B), fontSize: 12),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _uidController,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: _buildTwitterInputDecoration(
                  hintText: 'Target UID (e.g. PT-123456)',
                  prefixIcon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: _buildTwitterInputDecoration(
                  hintText: 'Amount in $currSym (e.g. 50000)',
                  prefixIcon: Icons.attach_money_rounded,
                ),
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _transferMoney,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text(
                          'Credit User Account',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 3. Play Store Force Update Broadcast ─────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16181C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2F3336)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.system_update_alt_rounded,
                      color: Color(0xFF1D9BF0), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Play Store App Version & Force Update',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Broadcast mandatory or recommended app update alerts to traders.',
                style: TextStyle(color: Color(0xFF71767B), fontSize: 12),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _versionController,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildTwitterInputDecoration(
                        hintText: 'Target Version',
                        prefixIcon: Icons.tag_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _buildNumController,
                      keyboardType: TextInputType.number,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildTwitterInputDecoration(
                        hintText: 'Build Number',
                        prefixIcon: Icons.numbers_rounded,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _updateMsgController,
                minLines: 2,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _buildTwitterInputDecoration(
                  hintText: 'Release notes / update reason...',
                ),
              ),
              const SizedBox(height: 8),

              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  title: const Text(
                    'Mandatory Force Update',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Users cannot dismiss the update dialog until upgraded',
                    style: TextStyle(color: Color(0xFF71767B), fontSize: 11),
                  ),
                  value: _forceUpdate,
                  activeThumbColor: const Color(0xFF1D9BF0),
                  onChanged: (val) => setState(() => _forceUpdate = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _updateAppVersion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9BF0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text(
                    'Broadcast Version Update',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 4. AI Signals Paywall Control ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16181C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2F3336)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Color(0xFFFFB800), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Signals Desk Paywall Access',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSignalsUnlocked
                          ? AppColors.profit.withValues(alpha: 0.15)
                          : const Color(0xFFFFB800).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isSignalsUnlocked ? 'UNLOCKED' : 'LOCKED',
                      style: TextStyle(
                        color: isSignalsUnlocked
                            ? AppColors.profit
                            : const Color(0xFFFFB800),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Toggle AI Signals Desk unlock state for testing purposes.',
                style: TextStyle(color: Color(0xFF71767B), fontSize: 12),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(userProvider.notifier).lockAiSignals();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.loss,
                              content: Text('🔒 AI Signals Desk is now LOCKED.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.lock_rounded, size: 16),
                      label: const Text('Lock Paywall',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF2F3336)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref.read(userProvider.notifier).unlockAiSignals();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.profit,
                              content:
                                  Text('🔓 AI Signals Desk is now UNLOCKED.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.lock_open_rounded, size: 16),
                      label: const Text('Unlock Desk',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB800),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 3: NOTIFICATIONS & BROADCASTS (TOP USER PRIORITY)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildNotificationsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // ── 1. Push Notification & Broadcast Composer ────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16181C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1D9BF0).withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.campaign_rounded,
                      color: Color(0xFF1D9BF0), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Push Notification Composer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Broadcast instant notifications to all active paper traders or target a specific user.',
                style: TextStyle(color: Color(0xFF71767B), fontSize: 12),
              ),
              const SizedBox(height: 14),

              // ── FREE DIRECT CLOUD PUSH STATUS PILL ──────────────────────────
              GestureDetector(
                onTap: _openFcmCredentialsModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: _hasFcmCreds
                        ? const Color(0xFF00BA7C).withValues(alpha: 0.1)
                        : const Color(0xFFFFD400).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _hasFcmCreds
                          ? const Color(0xFF00BA7C).withValues(alpha: 0.3)
                          : const Color(0xFFFFD400).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasFcmCreds ? Icons.bolt_rounded : Icons.vpn_key_rounded,
                        color: _hasFcmCreds ? const Color(0xFF00BA7C) : const Color(0xFFFFD400),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _hasFcmCreds
                              ? '🟢 Direct Cloud Push Active (\$0) — Wakes up closed phones'
                              : '⚡ Setup \$0 Direct Push to Closed Phones — Tap here',
                          style: TextStyle(
                            color: _hasFcmCreds ? const Color(0xFF00BA7C) : const Color(0xFFFFD400),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.settings_outlined,
                        color: _hasFcmCreds ? const Color(0xFF00BA7C) : const Color(0xFFFFD400),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Audience Selector Pills
              const Text(
                'TARGET AUDIENCE',
                style: TextStyle(
                  color: Color(0xFF71767B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildAudiencePill(
                      label: '⭐ Myself (Admin)',
                      isSelected: _notifTargetMode == 'self',
                      onTap: () => setState(() => _notifTargetMode = 'self'),
                    ),
                    const SizedBox(width: 8),
                    _buildAudiencePill(
                      label: '📢 All Traders (Global)',
                      isSelected: _notifTargetMode == 'all',
                      onTap: () => setState(() => _notifTargetMode = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _buildAudiencePill(
                      label: '👤 Single Trader',
                      isSelected: _notifTargetMode == 'single',
                      onTap: () => setState(() => _notifTargetMode = 'single'),
                    ),
                  ],
                ),
              ),

              if (_notifTargetMode == 'self') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D9BF0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1D9BF0).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF1D9BF0), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sends directly to your logged-in account (${ref.watch(userProvider).profile.name}) with instant in-app dropdown banner.',
                          style: const TextStyle(color: Color(0xFF1D9BF0), fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_notifTargetMode == 'single') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _notifTargetUidController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _buildTwitterInputDecoration(
                    hintText: 'Recipient Username, Email, or UID (e.g. admin)',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // ── 1-TAP DEFAULT MESSAGES (PRESETS) ───────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 13, color: Color(0xFF1D9BF0)),
                      SizedBox(width: 5),
                      Text(
                        '1-TAP DEFAULT MESSAGES',
                        style: TextStyle(
                          color: Color(0xFF71767B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_quickNotificationPresets.length} Presets Available',
                    style: const TextStyle(
                      color: Color(0xFF71767B),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _quickNotificationPresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final preset = _quickNotificationPresets[index];
                    final isSelected =
                        _notifTitleController.text == preset['title'];
                    final color = preset['color'] as Color;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _notifCategory = preset['category'] as String;
                          _notifType = preset['type'] as String;
                          _notifTitleController.text =
                              preset['title'] as String;
                          _notifMsgController.text =
                              preset['message'] as String;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.22)
                              : const Color(0xFF202327),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : const Color(0xFF2F3336),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(preset['icon'] as IconData,
                                size: 14, color: color),
                            const SizedBox(width: 6),
                            Text(
                              preset['label'] as String,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Category Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'NOTIFICATION CATEGORY',
                    style: TextStyle(
                      color: Color(0xFF71767B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final template = _categoryDefaults[_notifType];
                      if (template != null) {
                        setState(() {
                          _notifTitleController.text = template['title'] ?? '';
                          _notifMsgController.text = template['message'] ?? '';
                        });
                      }
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 12, color: Color(0xFF1D9BF0)),
                        SizedBox(width: 4),
                        Text(
                          'Reset Default',
                          style: TextStyle(
                            color: Color(0xFF1D9BF0),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildNotifCategoryPill('📢 Announcement', 'system', 'announcement'),
                  _buildNotifCategoryPill('🏆 Championship', 'prize', 'weekly_prize'),
                  _buildNotifCategoryPill('🎁 Bonus / Reward', 'system', 'reward'),
                  _buildNotifCategoryPill('📈 Market Signal', 'trade', 'order_fill'),
                ],
              ),
              const SizedBox(height: 16),

              // Title Field
              TextField(
                controller: _notifTitleController,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                decoration: _buildTwitterInputDecoration(
                  hintText: 'Notification Title (e.g. 🚨 Championship Final)',
                  prefixIcon: Icons.title_rounded,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              // Message Body Field
              TextField(
                controller: _notifMsgController,
                minLines: 2,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _buildTwitterInputDecoration(
                  hintText: 'Notification message body for users...',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // LIVE PREVIEW CARD (Twitter Tweet Style)
              const Text(
                'LIVE IN-APP PREVIEW',
                style: TextStyle(
                  color: Color(0xFF71767B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              _buildNotificationLivePreview(),
              const SizedBox(height: 16),

              // Broadcast Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isSendingNotif ? null : _handleSendNotification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9BF0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  icon: _isSendingNotif
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    _isSendingNotif
                        ? 'Broadcasting to Users...'
                        : (_notifTargetMode == 'self'
                            ? '⚡ Send to Myself'
                            : (_notifTargetMode == 'all'
                                ? 'Broadcast to All Users'
                                : 'Deliver to Trader')),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 2. Top-Up Promotional Offer Broadcast ────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16181C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2F3336)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      color: Color(0xFFFF5722), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Promotional Top-Up Offer Broadcast',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Display a flash deal modal banner on every trader\'s dashboard.',
                style: TextStyle(color: Color(0xFF71767B), fontSize: 12),
              ),
              const SizedBox(height: 12),

              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Color(0xFFFF9800), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'QUICK OFFER PRESETS',
                    style: TextStyle(
                      color: Color(0xFF71767B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _quickOfferPresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final preset = _quickOfferPresets[index];
                    final isSelected =
                        _offerTitleController.text == preset['title'];
                    const color = Color(0xFFFF5722);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _offerTitleController.text = preset['title']!;
                          _offerBadgeController.text = preset['badge']!;
                          _offerBtnController.text = preset['button']!;
                          _offerMsgController.text = preset['message']!;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.22)
                              : const Color(0xFF202327),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : const Color(0xFF2F3336),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            preset['label']!,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFFE7E9EA),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _offerTitleController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _buildTwitterInputDecoration(
                  hintText: 'Headline (e.g. 🔥 50% Extra Bonus Capital!)',
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _offerBadgeController,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildTwitterInputDecoration(
                        hintText: 'Badge Tag (e.g. LIMITED TIME)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _offerBtnController,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildTwitterInputDecoration(
                        hintText: 'Button Text',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _offerMsgController,
                minLines: 2,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _buildTwitterInputDecoration(
                  hintText: 'Offer details description...',
                ),
              ),
              const SizedBox(height: 8),

              Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Enable Offer Broadcast Modal',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Banner will appear for users on next dashboard load',
                        style: TextStyle(color: Color(0xFF71767B), fontSize: 11),
                      ),
                      value: _isOfferActive,
                      activeThumbColor: const Color(0xFF1D9BF0),
                      onChanged: (val) => setState(() => _isOfferActive = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Repeat On Every App Open',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Show modal popup every time user launches app',
                        style: TextStyle(color: Color(0xFF71767B), fontSize: 11),
                      ),
                      value: _isRepeatActive,
                      activeThumbColor: const Color(0xFF1D9BF0),
                      onChanged: (val) => setState(() => _isRepeatActive = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: _broadcastOfferAlert,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save & Broadcast',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: _stopAllPopups,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.loss),
                          foregroundColor: AppColors.loss,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Stop Popups',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAudiencePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1D9BF0)
              : const Color(0xFF202327),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1D9BF0)
                : const Color(0xFF2F3336),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF71767B),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNotifCategoryPill(String label, String category, String type) {
    final isSelected = _notifCategory == category && _notifType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _notifCategory = category;
          _notifType = type;
          final template = _categoryDefaults[type];
          if (template != null) {
            _notifTitleController.text = template['title'] ?? '';
            _notifMsgController.text = template['message'] ?? '';
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1D9BF0).withValues(alpha: 0.18)
              : const Color(0xFF202327),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1D9BF0)
                : const Color(0xFF2F3336),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1D9BF0) : Colors.white70,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationLivePreview() {
    final title = _notifTitleController.text.trim().isNotEmpty
        ? _notifTitleController.text.trim()
        : 'System Announcement';
    final message = _notifMsgController.text.trim().isNotEmpty
        ? _notifMsgController.text.trim()
        : 'Your notification message preview will render here.';

    IconData previewIcon = Icons.campaign_rounded;
    Color iconColor = const Color(0xFF1D9BF0);
    if (_notifType == 'weekly_prize') {
      previewIcon = Icons.emoji_events_rounded;
      iconColor = const Color(0xFFF3BA2F);
    } else if (_notifType == 'reward') {
      previewIcon = Icons.card_giftcard_rounded;
      iconColor = AppColors.profit;
    } else if (_notifType == 'order_fill') {
      previewIcon = Icons.trending_up_rounded;
      iconColor = const Color(0xFF00D09C);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16181C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2F3336), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 28,
              height: 3,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2F3336),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(previewIcon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '· now',
                          style: TextStyle(
                            color: Color(0xFF71767B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xFFCFD9DE),
                        fontSize: 12,
                        height: 1.35,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF71767B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 4: MODERATION & BANS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildModerationTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // ── User Search & Lookup Card ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16181C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2F3336)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.gavel_rounded, color: AppColors.loss, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'User Suspension & Ban Control',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Search any trader by Public UID, Email address, or Username.',
                style: TextStyle(color: Color(0xFF71767B), fontSize: 12),
              ),
              const SizedBox(height: 14),

              // Search Bar with Twitter Lookup Pill
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _banUidController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildTwitterInputDecoration(
                        hintText: 'UID, Email, or Username...',
                        prefixIcon: Icons.search_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed:
                          _isSearchingBanUser ? null : _lookupUserForBan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 0,
                      ),
                      child: _isSearchingBanUser
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : const Text(
                              'Lookup',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),

              // Found User Details Card
              if (_foundBanUser != null) ...[
                const SizedBox(height: 16),
                _buildFoundUserCard(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Currently Banned Users Stream Directory ──────────────────────────
        _buildBannedTradersDirectory(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFoundUserCard() {
    final profile = (_foundBanUser!['profile'] as Map<String, dynamic>?) ?? {};
    final name = (profile['name'] as String?) ?? 'Trader';
    final email = (profile['email'] as String?) ?? '';
    final publicUid =
        (profile['publicUid'] as String?) ?? _foundBanDocId ?? '';
    final isCurrentlyBanned = (_foundBanUser!['isBanned'] as bool?) ??
        (profile['isBanned'] as bool?) ??
        false;
    final existingReason = (_foundBanUser!['banReason'] as String?) ??
        (profile['banReason'] as String?);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF202327),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentlyBanned
              ? AppColors.loss
              : AppColors.profit.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF2F3336),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            color: Color(0xFF1D9BF0), size: 13),
                      ],
                    ),
                    if (email.isNotEmpty)
                      Text(email,
                          style: const TextStyle(
                              color: Color(0xFF71767B), fontSize: 11)),
                    Text('UID: $publicUid',
                        style: const TextStyle(
                            color: Color(0xFF71767B),
                            fontSize: 10,
                            fontFamily: 'monospace')),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrentlyBanned
                      ? AppColors.loss.withValues(alpha: 0.15)
                      : AppColors.profit.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrentlyBanned
                        ? AppColors.loss
                        : AppColors.profit.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isCurrentlyBanned ? 'BANNED' : 'ACTIVE',
                  style: TextStyle(
                    color: isCurrentlyBanned
                        ? AppColors.loss
                        : AppColors.profit,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          if (isCurrentlyBanned && existingReason != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.loss.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.loss.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'Active Reason: $existingReason',
                style: const TextStyle(
                  color: AppColors.loss,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],

          if (!isCurrentlyBanned) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _banReasonController,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: _buildTwitterInputDecoration(
                hintText: 'Reason for suspension...',
                prefixIcon: Icons.edit_note_rounded,
              ),
            ),
          ],
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _isProcessingBan
                  ? null
                  : () => _toggleBanUser(ban: !isCurrentlyBanned),
              icon: _isProcessingBan
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      isCurrentlyBanned
                          ? Icons.check_circle_outline_rounded
                          : Icons.gavel_rounded,
                      size: 16),
              label: Text(
                isCurrentlyBanned ? 'Lift Ban (Unban Account)' : 'Ban Account',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isCurrentlyBanned ? AppColors.profit : AppColors.loss,
                foregroundColor:
                    isCurrentlyBanned ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannedTradersDirectory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('isBanned', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  color: Color(0xFF1D9BF0), strokeWidth: 2),
            ),
          );
        }

        final bannedDocs = snapshot.data!.docs;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16181C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2F3336)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'CURRENTLY BANNED TRADERS',
                    style: TextStyle(
                      color: Color(0xFF71767B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.loss.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${bannedDocs.length} Total',
                      style: const TextStyle(
                        color: AppColors.loss,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (bannedDocs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202327),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.profit, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'No traders are currently suspended.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...bannedDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final profile =
                      (data['profile'] as Map<String, dynamic>?) ?? {};
                  final name = (profile['name'] as String?) ?? 'Trader';
                  final email = (profile['email'] as String?) ?? '';
                  final publicUid =
                      (profile['publicUid'] as String?) ?? doc.id;
                  final reason = (data['banReason'] as String?) ??
                      (profile['banReason'] as String?) ??
                      'Policy Violation';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202327),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.loss.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF2F3336),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'UID: $publicUid ${email.isNotEmpty ? '• $email' : ''}',
                                    style: const TextStyle(
                                      color: Color(0xFF71767B),
                                      fontSize: 10.5,
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _quickUnbanUser(
                                docId: doc.id,
                                userName: name,
                                profile: profile,
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor:
                                    AppColors.profit.withValues(alpha: 0.15),
                                foregroundColor: AppColors.profit,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Unban',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.loss.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.loss.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            'Reason: $reason',
                            style: const TextStyle(
                              color: AppColors.loss,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TWITTER-STYLE INPUT DECORATION HELPER
  // ───────────────────────────────────────────────────────────────────────────

  InputDecoration _buildTwitterInputDecoration({
    required String hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF71767B), fontSize: 13),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: const Color(0xFF71767B), size: 18)
          : null,
      filled: true,
      fillColor: const Color(0xFF202327),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2F3336)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2F3336)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1D9BF0), width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURE REQUESTS ADMIN SCREEN (Twitter Style)
// ─────────────────────────────────────────────────────────────────────────────

class FeatureRequestsAdminScreen extends StatefulWidget {
  const FeatureRequestsAdminScreen({super.key});

  @override
  State<FeatureRequestsAdminScreen> createState() =>
      _FeatureRequestsAdminScreenState();
}

class _FeatureRequestsAdminScreenState
    extends State<FeatureRequestsAdminScreen> {
  static const _statuses = ['pending', 'in-progress', 'done', 'rejected'];

  static const _statusColors = {
    'pending': Color(0xFFFBBF24),
    'in-progress': Color(0xFF38BDF8),
    'done': Color(0xFF00D09C),
    'rejected': Color(0xFFF6465D),
  };

  static const _categoryColors = {
    'Trading': Color(0xFF00D09C),
    'UI/UX': Color(0xFF818CF8),
    'Analytics': Color(0xFFFBBF24),
    'Social': Color(0xFF38BDF8),
    'Rewards': Color(0xFFF97316),
    'Other': Color(0xFF94A3B8),
  };

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('feature_requests')
        .doc(docId)
        .update({'status': newStatus});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Feature Requests Hub',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Color(0xFF2F3336), height: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feature_requests')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: AppColors.loss),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF1D9BF0), strokeWidth: 2),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      color: Color(0xFF71767B), size: 48),
                  SizedBox(height: 12),
                  Text('No feature requests yet.',
                      style:
                          TextStyle(color: Color(0xFF71767B), fontSize: 14)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? '(no title)';
              final description = data['description'] as String? ?? '';
              final category = data['category'] as String? ?? 'Other';
              final userName = data['userName'] as String? ?? 'Unknown';
              final status = data['status'] as String? ?? 'pending';
              final ts = data['timestamp'];
              String timeStr = '';
              if (ts != null && ts is Timestamp) {
                final dt = ts.toDate().toLocal();
                timeStr =
                    '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              }

              final catColor =
                  _categoryColors[category] ?? const Color(0xFF94A3B8);
              final statusColor =
                  _statusColors[status] ?? const Color(0xFFFBBF24);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16181C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2F3336)),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                            color: catColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 12, color: Color(0xFF71767B)),
                          const SizedBox(width: 4),
                          Text(userName,
                              style: const TextStyle(
                                  color: Color(0xFF71767B), fontSize: 11)),
                          if (timeStr.isNotEmpty) ...[
                            const Text('  ·  ',
                                style: TextStyle(color: Color(0xFF71767B))),
                            Text(timeStr,
                                style: const TextStyle(
                                    color: Color(0xFF71767B), fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    children: [
                      if (description.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF202327),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            description,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                height: 1.4),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Status:',
                            style: TextStyle(
                                color: Color(0xFF71767B), fontSize: 12),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _statuses.map((s) {
                                final sc = _statusColors[s] ?? Colors.white;
                                final isActive = status == s;
                                return GestureDetector(
                                  onTap: () => _updateStatus(doc.id, s),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? sc.withValues(alpha: 0.2)
                                          : const Color(0xFF202327),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isActive
                                            ? sc
                                            : const Color(0xFF2F3336),
                                      ),
                                    ),
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        color: isActive
                                            ? sc
                                            : const Color(0xFF71767B),
                                        fontSize: 11,
                                        fontWeight: isActive
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
