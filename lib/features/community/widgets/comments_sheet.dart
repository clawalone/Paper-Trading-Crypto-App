import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme.dart';
import '../../../data/community_provider.dart';
import '../../../data/models.dart';
import '../../../data/user_provider.dart';
import '../../../core/avatar_helper.dart';

class CommentsSheet extends ConsumerStatefulWidget {
  final CommunityPost post;

  const CommentsSheet({super.key, required this.post});

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final userState = ref.read(userProvider);
    final authorName = userState.profile.name.isNotEmpty ? userState.profile.name : 'CryptoTrader';
    final authorAvatar = userState.profile.photoUrl.isNotEmpty
        ? userState.profile.photoUrl
        : AppAvatarHelper.defaultFallback;

    ref.read(communityProvider.notifier).addComment(
          widget.post.id,
          text: text,
          authorName: authorName,
          authorAvatar: authorAvatar,
        );

    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  String _formatTimestamp(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final communityState = ref.watch(communityProvider);
    final rawComments = communityState.commentsByPostId[widget.post.id] ?? [];
    final comments = rawComments.where((c) => !communityState.blockedUserIds.contains(c.authorId)).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Comments (${comments.length})',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.subtle),
                onPressed: () => Navigator.pop(context),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Divider(color: AppColors.outline),

          // Comments List
          Expanded(
            child: comments.isEmpty
                ? Center(
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final isCommentAuthorAdmin = comment.authorName.toLowerCase().contains('admin') ||
                          comment.authorId.toLowerCase().contains('admin');
                      final isCommentAuthorVerified = isCommentAuthorAdmin ||
                          ref.watch(isUserVerifiedProvider(comment.authorId));

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppAvatar(
                            avatarUrl: comment.authorAvatar,
                            radius: 16,
                            fallbackName: comment.authorName,
                            backgroundColor: AppColors.surfaceAlt,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.outline),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                comment.authorName,
                                                style: GoogleFonts.inter(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isCommentAuthorVerified) ...[
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.verified,
                                                color: Color(0xFF0095F6),
                                                size: 12,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _formatTimestamp(comment.timestamp),
                                        style: GoogleFonts.inter(
                                          color: AppColors.muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comment.text,
                                    style: GoogleFonts.inter(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          const SizedBox(height: 8),

          // Comment Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add a reply...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    hintStyle: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendComment,
                icon: const Icon(Icons.send_rounded, size: 18, color: Colors.black),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
