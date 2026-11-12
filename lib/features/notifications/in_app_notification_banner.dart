import 'dart:async';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../data/models.dart';
import '../../main.dart';

class InAppNotificationBanner {
  static OverlayEntry? _activeEntry;
  static Timer? _autoDismissTimer;
  static final Set<String> _recentlyShownKeys = {};

  static void show(
    AppNotification notification, {
    VoidCallback? onTap,
  }) {
    final context = appNavigatorKey.currentContext;
    final overlay = appNavigatorKey.currentState?.overlay;
    if (context == null || overlay == null) return;

    final dedupKey = '${notification.id}_${notification.title}_${notification.message}';
    final contentKey = '${notification.title}_${notification.message}';

    // Prevent duplicate banners from firing within 5 seconds
    if (_recentlyShownKeys.contains(dedupKey) || _recentlyShownKeys.contains(contentKey)) {
      return;
    }

    _recentlyShownKeys.add(dedupKey);
    _recentlyShownKeys.add(contentKey);
    Timer(const Duration(seconds: 5), () {
      _recentlyShownKeys.remove(dedupKey);
      _recentlyShownKeys.remove(contentKey);
    });

    _dismissCurrent();

    HapticFeedback.lightImpact();

    _activeEntry = OverlayEntry(
      builder: (ctx) => _NotificationBannerWidget(
        notification: notification,
        onTap: () {
          _dismissCurrent();
          onTap?.call();
        },
        onDismiss: _dismissCurrent,
      ),
    );

    overlay.insert(_activeEntry!);

    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      _dismissCurrent();
    });
  }

  static void _dismissCurrent() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;

    if (_activeEntry != null) {
      _activeEntry?.remove();
      _activeEntry = null;
    }
  }
}

class _NotificationBannerWidget extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationBannerWidget({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationBannerWidget> createState() => _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<_NotificationBannerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _dismissWithAnimation() {
    _animController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final iconData = _getBannerIcon(widget.notification.type);

    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Dismissible(
              key: ValueKey('banner_${widget.notification.id}'),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16181C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF2F3336),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subtle swipe pull indicator (Twitter/iOS style)
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
                          // Left Icon Badge
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: iconData.bgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconData.icon, color: iconData.color, size: 18),
                          ),
                          const SizedBox(width: 12),

                          // Text Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.notification.title,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '· now',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF71767B),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.notification.message,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFCFD9DE),
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

                          // Clean borderless close icon
                          GestureDetector(
                            onTap: _dismissWithAnimation,
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Color(0xFF71767B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _BannerIconInfo _getBannerIcon(String type) {
    switch (type) {
      case 'liquidation':
        return _BannerIconInfo(
          icon: Icons.warning_rounded,
          color: AppColors.loss,
          bgColor: AppColors.loss.withValues(alpha: 0.15),
        );
      case 'tp_sl':
      case 'order_fill':
        return _BannerIconInfo(
          icon: Icons.trending_up_rounded,
          color: AppColors.profit,
          bgColor: AppColors.profit.withValues(alpha: 0.15),
        );
      case 'prize':
      case 'weekly_prize':
        return _BannerIconInfo(
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFF3BA2F),
          bgColor: const Color(0xFFF3BA2F).withValues(alpha: 0.15),
        );
      case 'admin_credit':
      case 'bonus':
      case 'tip':
        return _BannerIconInfo(
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.profit,
          bgColor: AppColors.profit.withValues(alpha: 0.15),
        );
      case 'like':
        return _BannerIconInfo(
          icon: Icons.favorite_rounded,
          color: const Color(0xFFF91880),
          bgColor: const Color(0xFFF91880).withValues(alpha: 0.15),
        );
      case 'comment':
        return _BannerIconInfo(
          icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF1D9BF0),
          bgColor: const Color(0xFF1D9BF0).withValues(alpha: 0.15),
        );
      case 'follow':
        return _BannerIconInfo(
          icon: Icons.person_add_rounded,
          color: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
        );
      case 'announcement':
      default:
        return _BannerIconInfo(
          icon: Icons.campaign_rounded,
          color: const Color(0xFF1D9BF0),
          bgColor: const Color(0xFF1D9BF0).withValues(alpha: 0.15),
        );
    }
  }
}

class _BannerIconInfo {
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _BannerIconInfo({
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
