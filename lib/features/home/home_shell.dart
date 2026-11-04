import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/ban_manager.dart';
import '../../data/auth_provider.dart';
import '../../data/community_provider.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final avatars = [
        'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Cat.png',
        'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Dog%20Face.png',
        'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Fox.png',
        'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Bear.png',
        'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Panda.png',
        'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Rabbit%20Face.png',
        'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Tiger%20Face.png',
        'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Lion.png',
        'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Monkey%20Face.png',
        'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Unicorn.png'
      ];
      for (final url in avatars) {
        precacheImage(NetworkImage(url), context);
      }
    });
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
    final icon = isSelected ? const Icon(Icons.forum_rounded) : const Icon(Icons.forum_outlined);
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

        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
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
    ref.watch(notificationProvider); // Keeps real-time notification listener active app-wide

    bool hasUnreadHubPosts = false;
    if (posts.isNotEmpty && currentIndex != 4) {
      final latestPost = posts.first;
      if (_lastViewedHubTime == null || latestPost.timestamp.isAfter(_lastViewedHubTime!)) {
        hasUnreadHubPosts = true;
      }
    }

    final screens = [
      const DashboardScreen(),
      const MarketScreen(),
      const FuturesScreen(),
      const PortfolioScreen(),
      const CommunityScreen(),
      const LeaderboardScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        if (currentIndex != 0) {
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
                    selectedIndex: currentIndex,
                    onDestinationSelected: (index) {
                      ref.read(homeTabProvider.notifier).state = index;
                      if (index == 4) {
                        _lastViewedHubTime = DateTime.now();
                      }
                    },
                    labelType: NavigationRailLabelType.all,
                    useIndicator: true,
                    indicatorColor: AppColors.primary.withValues(alpha: 0.2),
                    unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
                    selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    unselectedIconTheme: const IconThemeData(color: Colors.white54),
                    selectedIconTheme: const IconThemeData(color: AppColors.primary),
                    destinations: [
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
                        label: Text('Ranks'),
                      ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF2B3139)),
                  Expanded(
                    child: Container(
                      color: AppColors.background, // Match background
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200), // Wide enough for side-by-side
                        child: Column(
                          children: [
                            if (!isMarketOnline) _buildOfflineBanner(),
                            Expanded(child: screens[currentIndex]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (!isMarketOnline) _buildOfflineBanner(),
                  Expanded(child: screens[currentIndex]),
                ],
              ),
            ),
            bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E2329), width: 0.8)),
              ),
              child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                ref.read(homeTabProvider.notifier).state = index;
                if (index == 4) {
                  _lastViewedHubTime = DateTime.now();
                }
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.show_chart_outlined),
                  selectedIcon: Icon(Icons.show_chart),
                  label: 'Spot',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.bolt_outlined),
                  selectedIcon: Icon(Icons.bolt),
                  label: 'Futures',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Portfolio',
                ),
                NavigationDestination(
                  icon: _buildHubIcon(isSelected: false, hasUnread: hasUnreadHubPosts),
                  selectedIcon: _buildHubIcon(isSelected: true, hasUnread: false),
                  label: 'Hub',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.leaderboard_outlined),
                  selectedIcon: Icon(Icons.leaderboard),
                  label: 'Ranks',
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
}

