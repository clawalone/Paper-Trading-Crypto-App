import 'package:firebase_auth/firebase_auth.dart';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../core/avatar_helper.dart';
import '../../data/community_provider.dart';
import '../../data/user_provider.dart';
import '../news/news_screen.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/create_post_sheet.dart';
import 'widgets/network_following_tab.dart';
import 'widgets/post_card.dart';
import 'widgets/tip_modal.dart';
import 'widgets/user_profile_modal.dart';
import 'widgets/vote_modal.dart';
import '../../core/app_translations.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Saved',
    'Setups',
    '#BTC',
    '#ETH',
    '#SOL',
    '#Futures',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const CreatePostSheet(),
    );
  }

  void _openTradersDirectory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => const NetworkFollowingTab(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final communityState = ref.watch(communityProvider);
    final userProfile = ref.watch(userProvider).profile;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    final userAvatar = userProfile.photoUrl.isNotEmpty
        ? userProfile.photoUrl
        : AppAvatarHelper.defaultFallback;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        leadingWidth: 54,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () {
                if (currentUserId.isNotEmpty) {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (context) => UserProfileModal(
                      userId: currentUserId,
                      fallbackName: userProfile.name.isNotEmpty ? userProfile.name : 'My Profile',
                      fallbackAvatar: userAvatar,
                    ),
                  );
                }
              },
              child: AppAvatar(
                avatarUrl: userAvatar,
                size: 34,
                fallbackName: userProfile.name,
                backgroundColor: AppColors.surface,
                border: Border.all(color: AppColors.outline, width: 1),
              ),
            ),
          ),
        ),
        title: Center(
          child: Text(
            'Community'.tr(),
            style: GoogleFonts.grandHotel(
              fontSize: 27,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.people_outline_rounded, color: AppColors.textPrimary, size: 22),
            tooltip: 'Traders Network',
            onPressed: _openTradersDirectory,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.outline, width: 0.8),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.subtle,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 15),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'For you'.tr()),
                Tab(text: 'Following'.tr()),
                Tab(text: 'News'.tr()),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: For you ────────────────────────────────────────────────
          _buildTimeline(communityState, isFollowingOnly: false, userAvatar: userAvatar),

          // ── TAB 2: Following ──────────────────────────────────────────────
          _buildTimeline(communityState, isFollowingOnly: true, userAvatar: userAvatar),

          // ── TAB 3: Crypto News ────────────────────────────────────────────
          const NewsScreen(),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _tabController.index != 2
            ? FloatingActionButton(
                key: const ValueKey('twitter_fab'),
                onPressed: _openCreatePostSheet,
                backgroundColor: const Color(0xFF1D9BF0),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: const Icon(
                  Icons.edit_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              )
            : const SizedBox.shrink(key: ValueKey('empty_fab')),
      ),
    );
  }

  // ── Twitter-style Timeline ─────────────────────────────────────────────────
  Widget _buildTimeline(
    CommunityState communityState, {
    required bool isFollowingOnly,
    required String userAvatar,
  }) {
    final posts = communityState.posts.where((post) {
      if (communityState.blockedUserIds.contains(post.authorId)) {
        return false;
      }
      if (isFollowingOnly) {
        final isFollowed = communityState.followingUserIds.contains(post.authorId) ||
            (communityState.profiles[post.authorId]?.isFollowing ?? false);
        if (!isFollowed) return false;
      }

      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Saved') return communityState.bookmarkedPostIds.contains(post.id);
      if (_selectedFilter == 'Setups') return post.attachedTrade != null;

      final tag = _selectedFilter.replaceAll('#', '').trim().toUpperCase();
      return post.hashtags.any((h) => h.toUpperCase() == tag) ||
          post.content.toUpperCase().contains('#$tag') ||
          (post.attachedTrade?.symbol.toUpperCase().contains(tag) ?? false);
    }).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        // Timeline refresh
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: CustomScrollView(
        slivers: [
          // Inline Tweet Composer Bar
          SliverToBoxAdapter(
            child: _buildTweetComposer(userAvatar),
          ),

          // Twitter-style Topic Chips Bar
          SliverToBoxAdapter(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.outline, width: 0.8),
                ),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedFilter = filter);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.outline,
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          filter,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.black : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Posts List
          if (posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.muted, size: 48),
                      const SizedBox(height: 14),
                      Text(
                        isFollowingOnly ? 'Welcome to your timeline!' : 'No posts in $_selectedFilter',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isFollowingOnly
                            ? 'Follow traders to see their signals and thoughts in your timeline.'
                            : 'Be the first to post alpha on this topic.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.subtle,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: isFollowingOnly ? _openTradersDirectory : _openCreatePostSheet,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: Text(
                          isFollowingOnly ? 'Find Traders' : 'Post Alpha',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = posts[index];
                  return PostCard(
                    post: post,
                    isBookmarked: communityState.bookmarkedPostIds.contains(post.id),
                    onBookmark: () async {
                      final isSaved = await ref.read(communityProvider.notifier).toggleBookmark(post.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isSaved ? 'Post saved to Bookmarks' : 'Post removed from Bookmarks'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onLike: () {
                      ref.read(communityProvider.notifier).toggleLike(post.id);
                    },
                    onComment: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppColors.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (context) => CommentsSheet(post: post),
                      );
                    },
                    onTip: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (context) => TipModal(post: post),
                      );
                    },
                    onVote: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (context) => PredictionVoteModal(post: post),
                      );
                    },
                    onProfileTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (context) => UserProfileModal(
                          userId: post.authorId,
                          fallbackName: post.authorName,
                          fallbackAvatar: post.authorAvatar,
                        ),
                      );
                    },
                    onDelete: () {
                      ref.read(communityProvider.notifier).deletePost(post.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post deleted')),
                      );
                    },
                  );
                },
                childCount: posts.length,
              ),
            ),

          // Bottom padding for FAB
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  // ── Twitter-style Inline Composer Box ──────────────────────────────────────
  Widget _buildTweetComposer(String userAvatar) {
    return GestureDetector(
      onTap: _openCreatePostSheet,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            bottom: BorderSide(color: AppColors.outline, width: 0.8),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                AppAvatar(
                  avatarUrl: userAvatar,
                  size: 36,
                  backgroundColor: AppColors.surface,
                  border: Border.all(color: AppColors.outline, width: 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'What is happening in the market?!',
                    style: GoogleFonts.inter(
                      color: AppColors.subtle,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Post',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildComposerIcon(Icons.show_chart_rounded, 'Attach Trade', AppColors.primary),
                const SizedBox(width: 18),
                _buildComposerIcon(Icons.poll_outlined, 'Prediction', AppColors.primary),
                const SizedBox(width: 18),
                _buildComposerIcon(Icons.tag_rounded, 'Hashtags', AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerIcon(IconData icon, String tooltip, Color color) {
    return Icon(
      icon,
      color: color,
      size: 20,
    );
  }
}
