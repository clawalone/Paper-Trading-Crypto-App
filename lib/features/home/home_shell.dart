import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/ban_manager.dart';
import '../../data/auth_provider.dart';
import '../../data/community_provider.dart';
import '../../data/market_mode_provider.dart';
import '../../data/market_provider.dart';
import '../../data/user_provider.dart';
import '../auth/login_screen.dart';
import '../auth/onboarding_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../market/market_screen.dart';
import '../portfolio/portfolio_screen.dart';
import '../community/community_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../futures/futures_screen.dart';
import '../../data/notification_provider.dart';
import '../../data/leaderboard_provider.dart';
import '../../l10n/app_localizations.dart';

final homeTabProvider = StateProvider<int>((ref) => 0);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  DateTime? _lastViewedHubTime = DateTime.now();
  Timer? _authTimeoutTimer;
  bool _authTimedOut = false;
  Timer? _userTimeoutTimer;
  bool _userTimedOut = false;

  @override
  void initState() {
    super.initState();
    _startAuthTimer();
    _startUserTimer();
  }

  void _startAuthTimer() {
    _authTimeoutTimer?.cancel();
    _authTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _authTimedOut = true);
    });
  }

  void _startUserTimer() {
    _userTimeoutTimer?.cancel();
    _userTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _userTimedOut = true);
    });
  }

  @override
  void dispose() {
    _authTimeoutTimer?.cancel();
    _userTimeoutTimer?.cancel();
    super.dispose();
  }

  Widget _buildHubIcon({required bool isSelected, required bool hasUnread}) {
    final icon = isSelected ? const Icon(Icons.chat_bubble_rounded) : const Icon(Icons.chat_bubble_outline_rounded);
    if (!hasUnread) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -1,
          right: -3,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFF6465D),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () {
        // Fallback for non-GMS or slow devices: check if currentUser is already cached locally
        final current = FirebaseAuth.instance.currentUser;
        if (current != null) {
          return _buildShellForUser(current);
        }

        if (_authTimedOut) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_clock_outlined, color: AppColors.primary, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Authentication Verification Delayed',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Account verification is taking longer than expected. Please check your network or proceed to login.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _authTimedOut = false;
                              _startAuthTimer();
                            });
                            ref.invalidate(authStateProvider);
                          },
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2B3139)),
                          child: const Text('Retry'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text('Go to Login', style: TextStyle(color: Colors.black)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                SizedBox(height: 16),
                Text('Connecting to account...', style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
              ],
            ),
          ),
        );
      },
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.loss, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Authentication error: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(authStateProvider),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Retry', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }
        return _buildShellForUser(user);
      },
    );
  }

  Widget _buildShellForUser(User user) {
    final userState = ref.watch(userProvider);

    // Prevent premature onboarding: wait until user state finishes loading
    if (userState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                const SizedBox(height: 16),
                const Text(
                  'Loading your profile...',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
                if (_userTimedOut) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Profile sync is taking longer than usual on this connection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _userTimedOut = false;
                            _startUserTimer();
                          });
                          ref.read(userProvider.notifier).retrySync();
                        },
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2B3139)),
                        child: const Text('Retry Sync'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          ref.read(userProvider.notifier).clearLoading();
                        },
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Continue to App', style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Check if account has been banned/suspended by administrator
    if (userState.isBanned || userState.profile.isBanned) {
      final banReason = userState.banReason ?? userState.profile.banReason;
      final displayUid = userState.profile.publicUid.isNotEmpty ? userState.profile.publicUid : user.uid;
      final bannedAt = userState.bannedAt;

      // Auto-delete check for current user if banned > 10 days
      if (BanManager.isBanExpired(bannedAt)) {
        BanManager.checkAndAutoDeleteCurrentUser(
          user: user,
          isBanned: true,
          bannedAt: bannedAt,
        );
      }

      return _buildBannedScreen(banReason, displayUid, bannedAt);
    }

    // Check if account has an unacknowledged administrative reset notice
    final resetNotice = userState.profile.resetNotice;
    final isResetUnacknowledged = resetNotice != null && resetNotice['acknowledged'] != true;
    if (isResetUnacknowledged) {
      final resetReason = resetNotice['reason']?.toString() ?? 'Account reset due to platform policy violation.';
      final resetAtStr = resetNotice['resetAt']?.toString();
      DateTime? resetAt = resetAtStr != null ? DateTime.tryParse(resetAtStr) : null;
      return _buildResetNoticeScreen(resetReason, resetAt);
    }

    // If profile sync timed out or failed without cached profile, show sync error view instead of jumping to Onboarding
    if (userState.hasSyncError && !userState.isOnboarded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: AppColors.loss, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Unable to Sync Profile',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Could not connect to your account profile. Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _userTimedOut = false;
                          _startUserTimer();
                        });
                        ref.read(userProvider.notifier).retrySync();
                      },
                      icon: const Icon(Icons.refresh, size: 18, color: Colors.black),
                      label: const Text('Retry', style: TextStyle(color: Colors.black)),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        ref.read(userProvider.notifier).clearLoading();
                      },
                      child: const Text('Setup New Profile', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!userState.isOnboarded) {
      return const OnboardingScreen();
    }

    final communityState = ref.watch(communityProvider);
    final posts = communityState.posts;
    final currentIndex = ref.watch(homeTabProvider);
    final isMarketOnline = ref.watch(marketOnlineProvider);
    final marketMode = ref.watch(marketModeProvider);
    final isStocks = marketMode == MarketMode.stocks;
    ref.watch(notificationProvider); // Keeps real-time notification listener active app-wide
    ref.watch(leaderboardProvider); // Pre-warms both Global & Streak Leaderboards on app open

    final screens = isStocks
        ? const [
            DashboardScreen(),
            MarketScreen(),
            PortfolioScreen(),
            CommunityScreen(),
            LeaderboardScreen(),
          ]
        : const [
            DashboardScreen(),
            MarketScreen(),
            FuturesScreen(),
            PortfolioScreen(),
            CommunityScreen(),
            LeaderboardScreen(),
          ];

    ref.listen<MarketMode>(marketModeProvider, (prev, next) {
      if (prev != null && prev != next) {
        final current = ref.read(homeTabProvider);
        if (next == MarketMode.stocks) {
          // Crypto [0:Home, 1:Spot, 2:Futures, 3:Portfolio, 4:Hub, 5:Rank]
          // Stocks [0:Home, 1:Stocks, 2:Portfolio, 3:Hub, 4:Rank]
          if (current == 2) {
            ref.read(homeTabProvider.notifier).state = 1;
          } else if (current == 3) {
            ref.read(homeTabProvider.notifier).state = 2;
          } else if (current == 4) {
            ref.read(homeTabProvider.notifier).state = 3;
          } else if (current == 5) {
            ref.read(homeTabProvider.notifier).state = 4;
          }
        } else {
          // Stocks [0:Home, 1:Stocks, 2:Portfolio, 3:Hub, 4:Rank]
          // Crypto [0:Home, 1:Spot, 2:Futures, 3:Portfolio, 4:Hub, 5:Rank]
          if (current == 2) {
            ref.read(homeTabProvider.notifier).state = 3;
          } else if (current == 3) {
            ref.read(homeTabProvider.notifier).state = 4;
          } else if (current == 4) {
            ref.read(homeTabProvider.notifier).state = 5;
          }
        }
      }
    });

    final effectiveIndex = currentIndex.clamp(0, screens.length - 1);
    final hubIndex = isStocks ? 3 : 4;

    bool hasUnreadHubPosts = false;
    if (posts.isNotEmpty && effectiveIndex != hubIndex) {
      final latestPost = posts.first;
      if (_lastViewedHubTime == null || latestPost.timestamp.isAfter(_lastViewedHubTime!)) {
        hasUnreadHubPosts = true;
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        if (effectiveIndex != 0) {
          ref.read(homeTabProvider.notifier).state = 0;
        } else {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E2329),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.exit_to_app, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Exit App', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text('Are you sure you want to exit the simulator?', style: TextStyle(color: Colors.white70, fontSize: 16)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 16)),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF3BA2F)),
                  child: const Text('Exit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    backgroundColor: AppColors.background,
                    selectedIndex: effectiveIndex,
                    onDestinationSelected: (index) {
                      ref.read(homeTabProvider.notifier).state = index;
                      if (index == hubIndex) {
                        _lastViewedHubTime = DateTime.now();
                      }
                    },
                    labelType: NavigationRailLabelType.all,
                    useIndicator: true,
                    indicatorColor: AppColors.primary.withValues(alpha: 0.2),
                    unselectedLabelTextStyle: const TextStyle(color: AppColors.subtle),
                    selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    unselectedIconTheme: const IconThemeData(color: AppColors.subtle),
                    selectedIconTheme: const IconThemeData(color: AppColors.primary),
                    destinations: isStocks
                        ? [
                            const NavigationRailDestination(
                              icon: Icon(Icons.dashboard_outlined),
                              selectedIcon: Icon(Icons.dashboard),
                              label: Text('Home'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.trending_up_rounded),
                              selectedIcon: Icon(Icons.trending_up_rounded),
                              label: Text('Stocks'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.account_balance_wallet_outlined),
                              selectedIcon: Icon(Icons.account_balance_wallet),
                              label: Text('Portfolio'),
                            ),
                            NavigationRailDestination(
                              icon: _buildHubIcon(isSelected: false, hasUnread: hasUnreadHubPosts),
                              selectedIcon: _buildHubIcon(isSelected: true, hasUnread: false),
                              label: const Text('Hub'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.leaderboard_outlined),
                              selectedIcon: Icon(Icons.leaderboard),
                              label: Text('Rank'),
                            ),
                          ]
                        : [
                            const NavigationRailDestination(
                              icon: Icon(Icons.dashboard_outlined),
                              selectedIcon: Icon(Icons.dashboard),
                              label: Text('Home'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.show_chart_outlined),
                              selectedIcon: Icon(Icons.show_chart),
                              label: Text('Spot'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.bolt_outlined),
                              selectedIcon: Icon(Icons.bolt),
                              label: Text('Futures'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.account_balance_wallet_outlined),
                              selectedIcon: Icon(Icons.account_balance_wallet),
                              label: Text('Portfolio'),
                            ),
                            NavigationRailDestination(
                              icon: _buildHubIcon(isSelected: false, hasUnread: hasUnreadHubPosts),
                              selectedIcon: _buildHubIcon(isSelected: true, hasUnread: false),
                              label: const Text('Hub'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.leaderboard_outlined),
                              selectedIcon: Icon(Icons.leaderboard),
                              label: Text('Rank'),
                            ),
                          ],
                  ),
                  VerticalDivider(thickness: 1, width: 1, color: AppColors.outline),
                  Expanded(
                    child: Container(
                      color: AppColors.background, // Match background
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200), // Wide enough for side-by-side
                        child: Column(
                          children: [
                            if (!isMarketOnline) _buildOfflineBanner(),
                            Expanded(child: screens[effectiveIndex]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (!isMarketOnline) _buildOfflineBanner(),
                  Expanded(child: screens[effectiveIndex]),
                ],
              ),
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.outline, width: 0.8)),
              ),
              child: NavigationBar(
              selectedIndex: effectiveIndex,
              onDestinationSelected: (index) {
                ref.read(homeTabProvider.notifier).state = index;
                if (index == hubIndex) {
                  _lastViewedHubTime = DateTime.now();
                }
              },
              destinations: isStocks
                  ? [
                      NavigationDestination(
                        icon: const Icon(Icons.home_outlined),
                        selectedIcon: const Icon(Icons.home_rounded),
                        label: l10n?.navHome ?? 'Home'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.candlestick_chart_outlined),
                        selectedIcon: const Icon(Icons.candlestick_chart_rounded),
                        label: 'Stocks'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
                        label: l10n?.navPortfolio ?? 'Portfolio'.tr(),
                      ),
                      NavigationDestination(
                        icon: _buildHubIcon(isSelected: false, hasUnread: hasUnreadHubPosts),
                        selectedIcon: _buildHubIcon(isSelected: true, hasUnread: false),
                        label: l10n?.navHub ?? 'Hub'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.emoji_events_outlined),
                        selectedIcon: const Icon(Icons.emoji_events_rounded),
                        label: l10n?.leaderboard ?? 'Rank'.tr(),
                      ),
                    ]
                  : [
                      NavigationDestination(
                        icon: const Icon(Icons.home_outlined),
                        selectedIcon: const Icon(Icons.home_rounded),
                        label: l10n?.navHome ?? 'Home'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.candlestick_chart_outlined),
                        selectedIcon: const Icon(Icons.candlestick_chart_rounded),
                        label: l10n?.navSpot ?? 'Spot'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.electric_bolt_outlined),
                        selectedIcon: const Icon(Icons.electric_bolt_rounded),
                        label: l10n?.navFutures ?? 'Futures'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
                        label: l10n?.navPortfolio ?? 'Portfolio'.tr(),
                      ),
                      NavigationDestination(
                        icon: _buildHubIcon(isSelected: false, hasUnread: hasUnreadHubPosts),
                        selectedIcon: _buildHubIcon(isSelected: true, hasUnread: false),
                        label: l10n?.navHub ?? 'Hub'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.emoji_events_outlined),
                        selectedIcon: const Icon(Icons.emoji_events_rounded),
                        label: l10n?.leaderboard ?? 'Rank'.tr(),
                      ),
                    ],
            ),
          ),
        );
      },
    ),
  );
}

  Future<void> _launchAppealEmail(String uid, String? reason, DateTime? bannedAt) async {
    const supportEmail = 'acadrio.query@gmail.com';
    final remainingText = BanManager.getRemainingTimeDescription(bannedAt);
    final subject = 'Account Suspension Appeal - UID: $uid';
    final body = 'Hello Acadrio Support Team,\n\n'
        'I am submitting an appeal regarding the suspension of my trading account.\n\n'
        'Account UID: $uid\n'
        'Suspension Reason: ${reason?.isNotEmpty == true ? reason : "Violation of Community & Trading Guidelines"}\n'
        'Auto-Deletion Window: $remainingText\n\n'
        'Appeal Details / Explanation:\n'
        '[Please enter your explanation or appeal context here]\n\n'
        'Thank you.';

    final emailUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not launch mail client');
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E2329),
            content: const Text(
              'Could not open mail app. Support email copied: acadrio.query@gmail.com',
              style: TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'OK',
              textColor: AppColors.primary,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14171F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D1E24), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFF87171),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Live Market Offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PAUSED',
                        style: TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Orders held until exchange connection is restored',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ref.read(marketProvider.notifier).refresh();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reconnecting to live market feeds...'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Color(0xFF1E2329),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22171A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                    width: 0.9,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF87171)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: Color(0xFFF87171),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannedScreen(String? reason, String uid, DateTime? bannedAt) {
    const supportEmail = 'acadrio.query@gmail.com';
    final isExpired = BanManager.isBanExpired(bannedAt);
    final remainingText = BanManager.getRemainingTimeDescription(bannedAt);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Red Warning Gavel Badge
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.loss.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.loss.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.gavel_rounded, color: AppColors.loss, size: 38),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'ACCOUNT SUSPENDED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                const Text(
                  'Your trading account has been suspended by an administrator for violating community or trading platform guidelines.',
                  style: TextStyle(
                    color: Color(0xFF8E95A2),
                    fontSize: 13,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Reason Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16181D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.loss.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.loss, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Reason for suspension:',
                            style: TextStyle(color: AppColors.loss, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reason?.isNotEmpty == true
                            ? reason!
                            : 'Violation of Community & Trading Guidelines.',
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                      ),
                      const Divider(color: Color(0xFF2B3139), height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ACCOUNT UID',
                                  style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  uid,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 18),
                            tooltip: 'Copy UID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: uid));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Account UID copied to clipboard!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 10-Day Auto-Deletion Policy Notice Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1517),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.loss.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.loss.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.timer_outlined, color: AppColors.loss, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '10-Day Auto-Deletion Policy',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isExpired
                                  ? 'Notice: Your 10-day appeal window has expired. Permanent account deletion is being executed.'
                                  : 'Suspended accounts are automatically and permanently deleted after 10 days. ($remainingText)',
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // How to Appeal Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12161C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2B3139)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'How to Appeal',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'If you believe this suspension is a mistake or wish to appeal, you can submit an appeal directly via email to our support team.',
                        style: TextStyle(color: Color(0xFF9AA3AF), fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 12),

                      // Email Box with quick copy
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F26),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2F3640)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                supportEmail,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(const ClipboardData(text: supportEmail));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Support email copied to clipboard!')),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(Icons.copy_rounded, color: Colors.white54, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '• Tap the button below to open your mail client with pre-filled appeal details.\n• Appeals are typically reviewed within 24–48 hours.',
                        style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Primary Appeal Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchAppealEmail(uid, reason, bannedAt),
                    icon: const Icon(Icons.email_rounded, size: 18),
                    label: const Text(
                      'Email Appeal (acadrio.query@gmail.com)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Copy UID Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: uid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Account UID copied! Email to acadrio.query@gmail.com'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy UID for Appeal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF2B3139)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Sign Out'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.loss,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetNoticeScreen(String reason, DateTime? resetAt) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Amber Reset Notice Badge
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.restart_alt_rounded, color: Color(0xFFF59E0B), size: 40),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'ACCOUNT RESET NOTICE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                const Text(
                  'Your paper trading account has been reset by platform administration.',
                  style: TextStyle(
                    color: Color(0xFF8E95A2),
                    fontSize: 13,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Reason Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16181D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
                          SizedBox(width: 8),
                          Text(
                            'REASON FOR RESET',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reason,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (resetAt != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Reset on: ${DateFormat('dd MMM yyyy, HH:mm').format(resetAt)}',
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Notice details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16181D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2B3139)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What has been updated:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      _buildResetPoint('Virtual cash balance restored to \$5,000.00 starting capital'),
                      _buildResetPoint('All glitched / exploited positions and unearned PnL removed'),
                      _buildResetPoint('You can now continue trading fairly and competing on the leaderboard'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // "I Understand" Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(userProvider.notifier).acknowledgeResetNotice();
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text(
                      'I Understand',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFF8E95A2), fontSize: 12, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

