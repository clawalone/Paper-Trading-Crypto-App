import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme.dart';
import '../../../core/coin_icon.dart';
import '../../../data/community_provider.dart';
import '../../../data/models.dart';
import '../../futures/futures_pro_screen.dart';
import '../../stock_detail/stock_detail_screen.dart';

class PostCard extends ConsumerWidget {
  final CommunityPost post;
  final bool isBookmarked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onTip;
  final VoidCallback onVote;
  final VoidCallback onBookmark;
  final VoidCallback onProfileTap;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.post,
    this.isBookmarked = false,
    required this.onLike,
    required this.onComment,
    required this.onTip,
    required this.onVote,
    required this.onBookmark,
    required this.onProfileTap,
    this.onDelete,
  });

  String _formatTimestamp(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  void _showPostOptionsMenu(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    final isAuthor = (currentUserId.isNotEmpty && currentUserId == post.authorId);
    final isAdmin = (currentUserEmail == 'admin@gmail.com');
    final canDelete = isAuthor || isAdmin;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (canDelete) ...[
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.loss, size: 22),
                  title: Text(
                    'Delete post',
                    style: GoogleFonts.inter(color: AppColors.loss, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.subtle, size: 22),
                title: Text(
                  'Report post',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post reported')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline),
        ),
        title: Text(
          'Delete post?',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This can’t be undone and it will be removed from your timeline.',
          style: GoogleFonts.inter(color: AppColors.subtle, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.loss,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthorAdmin = post.authorName.toLowerCase().contains('admin') ||
        post.authorBadge.toLowerCase().contains('admin') ||
        post.authorId.toLowerCase().contains('admin');
    final isVerified = isAuthorAdmin || ref.watch(isUserVerifiedProvider(post.authorId));
    final communityState = ref.watch(communityProvider);
    final isFollowing = communityState.followingUserIds.contains(post.authorId);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwnPost = currentUserId.isNotEmpty && (post.authorId == currentUserId || post.authorId == 'current_user');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.outline, width: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Avatar, Name, Handle, Timestamp, Options ─────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outline, width: 1),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: ClipOval(
                    child: Image.network(
                      post.authorAvatar,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, color: AppColors.subtle, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onProfileTap,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.authorName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF0095F6), // Instagram verified blue
                          size: 14,
                        ),
                      ],
                      const SizedBox(width: 6),
                      const Text(
                        '·',
                        style: TextStyle(color: AppColors.subtle, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTimestamp(post.timestamp),
                        style: GoogleFonts.inter(
                          color: AppColors.subtle,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isOwnPost && post.authorId.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    ref.read(communityProvider.notifier).toggleFollowUser(post.authorId);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 28,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isFollowing ? Colors.transparent : const Color(0xFFEFF3F4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isFollowing ? const Color(0xFF536471) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: GoogleFonts.inter(
                        color: isFollowing ? const Color(0xFFEFF3F4) : const Color(0xFF0F1419),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: AppColors.subtle, size: 20),
                onPressed: () => _showPostOptionsMenu(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Post Text Content (Full width, no left gap) ───────────────────
          Text(
            post.content,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),

          // ── Hashtags (Full width) ──────────────────────────────────────────
          if (post.hashtags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: post.hashtags.map((tag) {
                return Text(
                  '#$tag',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                );
              }).toList(),
            ),
          ],

          // ── Quoted / Attached Trade Card (Only if trade attached) ──────────
          if (post.attachedTrade != null) ...[
            const SizedBox(height: 12),
            _buildQuotedTradeCard(context, post.attachedTrade!),
          ],

          const SizedBox(height: 12),

          // ── Action Row (Full width) ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Reply / Comment
              _buildActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                count: post.commentsCount,
                color: AppColors.subtle,
                activeColor: AppColors.primary,
                isActive: false,
                onTap: onComment,
              ),

              // Prediction / Signal Poll
              _buildActionButton(
                icon: Icons.track_changes_rounded,
                activeIcon: Icons.track_changes_rounded,
                count: post.totalVotes > 0 ? post.totalVotes : null,
                label: post.totalVotes > 0 ? '${post.agreePercentage}%' : null,
                color: AppColors.subtle,
                activeColor: post.myVote == 'agree'
                    ? AppColors.profit
                    : post.myVote == 'disagree'
                        ? AppColors.loss
                        : AppColors.primary,
                isActive: post.myVote != null,
                onTap: onVote,
              ),

              // Like
              _buildActionButton(
                icon: Icons.favorite_border_rounded,
                activeIcon: Icons.favorite_rounded,
                count: post.likesCount > 0 ? post.likesCount : null,
                color: AppColors.subtle,
                activeColor: const Color(0xFFF91880),
                isActive: post.isLikedByMe,
                onTap: onLike,
              ),

              // Tip
              _buildActionButton(
                icon: Icons.monetization_on_outlined,
                activeIcon: Icons.monetization_on_rounded,
                count: post.tipsReceived > 0 ? post.tipsReceived : null,
                label: post.tipsReceived > 0 ? '\$${post.tipsReceived}' : null,
                color: AppColors.subtle,
                activeColor: AppColors.warning,
                isActive: post.tipsReceived > 0,
                onTap: onTip,
              ),

              // Bookmark / Save
              _buildActionButton(
                icon: Icons.bookmark_border_rounded,
                activeIcon: Icons.bookmark_rounded,
                color: AppColors.subtle,
                activeColor: AppColors.primary,
                isActive: isBookmarked,
                onTap: onBookmark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required IconData activeIcon,
    int? count,
    String? label,
    required Color color,
    required Color activeColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final effectiveColor = isActive ? activeColor : color;
    final displayCount = label ?? ((count != null && count > 0) ? count.toString() : '');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 18,
              color: effectiveColor,
            ),
            if (displayCount.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(
                displayCount,
                style: GoogleFonts.inter(
                  color: effectiveColor,
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Attached Trade Card (Clean & Compact) ──────────────────────────────────
  Widget _buildQuotedTradeCard(BuildContext context, AttachedTradeInfo trade) {
    final isProfit = trade.pnlPercentage >= 0;
    final pnlColor = isProfit ? AppColors.profit : AppColors.loss;
    final cleanSym = CoinIcon.cleanSymbol(trade.symbol);
    final targetSymbol = cleanSym.isNotEmpty ? cleanSym : trade.symbol;
    final isFutures = trade.leverage > 1 || trade.symbol.toUpperCase().contains('PERP');

    return InkWell(
      onTap: () {
        if (isFutures) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FuturesProScreen(stockSymbol: targetSymbol),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockDetailScreen(stockSymbol: targetSymbol),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: AppColors.surfaceAlt,
              child: Row(
                children: [
                  CoinIcon(symbol: trade.symbol, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '$cleanSym-PERP',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: trade.isLong
                          ? AppColors.profit.withValues(alpha: 0.15)
                          : AppColors.loss.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      trade.isLong ? 'LONG ${trade.leverage}X' : 'SHORT ${trade.leverage}X',
                      style: GoogleFonts.inter(
                        color: trade.isLong ? AppColors.profit : AppColors.loss,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${isProfit ? "+" : ""}${trade.pnlPercentage.toStringAsFixed(1)}% ROE',
                    style: GoogleFonts.inter(
                      color: pnlColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_outward_rounded, color: AppColors.primary, size: 14),
                ],
              ),
            ),
          const Divider(height: 1, color: AppColors.outline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompactMetric('Entry', '\$${_formatPrice(trade.entryPrice)}'),
                _buildCompactMetric('Mark', '\$${_formatPrice(trade.currentPrice)}'),
                if (trade.targetPrice != null)
                  _buildCompactMetric('Target', '\$${_formatPrice(trade.targetPrice!)}', isAccent: true)
                else if (trade.stopLossPrice != null)
                  _buildCompactMetric('Stop', '\$${_formatPrice(trade.stopLossPrice!)}')
                else
                  _buildCompactMetric('Signal', 'Active'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  String _formatPrice(double price) {
    if (price >= 1000) {
      return NumberFormat('#,##0.00').format(price);
    } else if (price >= 1) {
      return price.toStringAsFixed(2);
    } else {
      return price.toStringAsFixed(4);
    }
  }

  Widget _buildCompactMetric(String label, String value, {bool isAccent = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: AppColors.subtle, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: isAccent ? AppColors.profit : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
