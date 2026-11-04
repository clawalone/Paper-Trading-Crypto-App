import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../data/models.dart';
import '../../data/notification_provider.dart';

import 'notification_navigator.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = ['All', 'Trades', 'Social', 'Prizes'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleNotificationTap(AppNotification notif) {
    NotificationNavigator.handleTap(context, ref, notif);
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationProvider);
    final allNotifs = notifState.notifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          if (notifState.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllAsRead(),
              child: Text(
                'Mark read',
                style: GoogleFonts.inter(
                  color: const Color(0xFF1D9BF0),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.subtle, size: 20),
            color: const Color(0xFF161A1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF262D35)),
            ),
            onSelected: (value) {
              if (value == 'read_all') {
                ref.read(notificationProvider.notifier).markAllAsRead();
              } else if (value == 'clear_all') {
                ref.read(notificationProvider.notifier).clearAll();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'read_all',
                child: Row(
                  children: [
                    const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF1D9BF0)),
                    const SizedBox(width: 8),
                    Text('Mark all as read', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.loss),
                    const SizedBox(width: 8),
                    Text('Clear all', style: GoogleFonts.inter(color: AppColors.loss, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E2329), width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorColor: const Color(0xFF1D9BF0),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.subtle,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All
          _buildNotificationList(allNotifs),
          // Trades
          _buildNotificationList(
            allNotifs.where((n) => n.category == NotificationCategory.trade).toList(),
          ),
          // Social
          _buildNotificationList(
            allNotifs.where((n) => n.category == NotificationCategory.social).toList(),
          ),
          // Prizes
          _buildNotificationList(
            allNotifs.where((n) => n.category == NotificationCategory.prize).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D9BF0).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 30, color: Color(0xFF1D9BF0)),
              ),
              const SizedBox(height: 16),
              Text(
                'Nothing to see here — yet',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'From trade fills and liquidation alerts to weekly championship prizes, your alerts will show up here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(
        color: Color(0xFF181B1E),
        height: 1,
        thickness: 0.8,
      ),
      itemBuilder: (context, index) {
        final notif = items[index];
        return _buildNotificationCard(notif);
      },
    );
  }

  Widget _buildNotificationCard(AppNotification notif) {
    final iconData = _getIconForType(notif.type, notif.category);
    final isUnread = !notif.isRead;

    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.loss.withValues(alpha: 0.85),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
      ),
      onDismissed: (_) {
        ref.read(notificationProvider.notifier).deleteNotification(notif.id);
      },
      child: InkWell(
        onTap: () => _handleNotificationTap(notif),
        child: Container(
          color: isUnread ? const Color(0xFF121518) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Twitter style Category Glyph
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

              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and timestamp
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatRelativeTime(notif.createdAt),
                          style: GoogleFonts.inter(
                            color: isUnread ? const Color(0xFF1D9BF0) : AppColors.muted,
                            fontSize: 11,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Body
                    Text(
                      notif.message,
                      style: GoogleFonts.inter(
                        color: isUnread ? Colors.white70 : AppColors.subtle,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),

                    // Inline payload trade chip if present
                    if (notif.data.containsKey('symbol')) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181B20),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF262D35), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              notif.data['symbol']?.toString() ?? '',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            if (notif.data.containsKey('pnlPercentage')) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${(notif.data['pnlPercentage'] as num) >= 0 ? "+" : ""}${(notif.data['pnlPercentage'] as num).toStringAsFixed(1)}%',
                                style: GoogleFonts.inter(
                                  color: (notif.data['pnlPercentage'] as num) >= 0 ? AppColors.profit : AppColors.loss,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Unread blue dot indicator (Twitter style)
              if (isUnread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D9BF0),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _IconDataInfo _getIconForType(String type, NotificationCategory category) {
    switch (type) {
      case 'liquidation':
        return _IconDataInfo(
          icon: Icons.warning_rounded,
          color: AppColors.loss,
          bgColor: AppColors.loss.withValues(alpha: 0.15),
        );
      case 'tp_sl':
      case 'order_fill':
        return _IconDataInfo(
          icon: Icons.trending_up_rounded,
          color: AppColors.profit,
          bgColor: AppColors.profit.withValues(alpha: 0.15),
        );
      case 'prize':
      case 'weekly_prize':
        return _IconDataInfo(
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFF3BA2F),
          bgColor: const Color(0xFFF3BA2F).withValues(alpha: 0.15),
        );
      case 'admin_credit':
      case 'bonus':
      case 'tip':
        return _IconDataInfo(
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.profit,
          bgColor: AppColors.profit.withValues(alpha: 0.15),
        );
      case 'like':
        return _IconDataInfo(
          icon: Icons.favorite_rounded,
          color: const Color(0xFFF91880), // Twitter heart pink
          bgColor: const Color(0xFFF91880).withValues(alpha: 0.15),
        );
      case 'comment':
        return _IconDataInfo(
          icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF1D9BF0), // Twitter blue
          bgColor: const Color(0xFF1D9BF0).withValues(alpha: 0.15),
        );
      case 'follow':
        return _IconDataInfo(
          icon: Icons.person_add_rounded,
          color: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
        );
      default:
        return _IconDataInfo(
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFF1D9BF0),
          bgColor: const Color(0xFF1D9BF0).withValues(alpha: 0.15),
        );
    }
  }
}

class _IconDataInfo {
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _IconDataInfo({
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
