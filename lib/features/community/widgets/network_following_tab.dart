import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/app_theme.dart';
import '../../../data/community_provider.dart';
import 'user_profile_modal.dart';

class NetworkFollowingTab extends ConsumerStatefulWidget {
  const NetworkFollowingTab({super.key});

  @override
  ConsumerState<NetworkFollowingTab> createState() => _NetworkFollowingTabState();
}

class _NetworkFollowingTabState extends ConsumerState<NetworkFollowingTab> {
  int _subTabIndex = 0; // 0: Following, 1: Followers

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final communityState = ref.watch(communityProvider);

    return Column(
      children: [
        // Sub-tab Segment Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surfaceAlt,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _subTabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _subTabIndex == 0 ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _subTabIndex == 0 ? AppColors.primary : AppColors.outline,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Following',
                      style: GoogleFonts.inter(
                        color: _subTabIndex == 0 ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _subTabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _subTabIndex == 1 ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _subTabIndex == 1 ? AppColors.primary : AppColors.outline,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Followers',
                      style: GoogleFonts.inter(
                        color: _subTabIndex == 1 ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tab Content List
        Expanded(
          child: _subTabIndex == 0
              ? _buildFollowingList(currentUserId, communityState)
              : _buildFollowersList(currentUserId),
        ),
      ],
    );
  }

  // ── 1. FOLLOWING LIST ──────────────────────────────────────────────────────
  Widget _buildFollowingList(String currentUserId, CommunityState communityState) {
    if (currentUserId.isEmpty) {
      return _buildSeedFollowingList(communityState);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final docs = snapshot.data?.docs ?? [];
        final firestoreTargetIds = docs.map((d) => d.id).toList();

        // Also check seed profiles from state
        final seedFollowing = communityState.profiles.values
            .where((p) => p.isFollowing)
            .map((p) => p.id)
            .toList();

        final allFollowingIds = {...firestoreTargetIds, ...seedFollowing}.toList();

        if (allFollowingIds.isEmpty) {
          return Center(child: _buildEmptyState(
            icon: Icons.person_add_disabled_outlined,
            title: 'Not following anyone yet',
            subtitle: 'Explore traders in the Community Feed to follow their trading insights!',
          ));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: allFollowingIds.length,
          itemBuilder: (context, index) {
            final targetId = allFollowingIds[index];
            return _UserNetworkCard(
              key: ValueKey(targetId),
              targetUserId: targetId,
              isFollowing: true,
              onToggleFollow: () => _toggleFollow(currentUserId, targetId, true),
            );
          },
        );
      },
    );
  }

  Widget _buildSeedFollowingList(CommunityState communityState) {
    final followingProfiles = communityState.profiles.values.where((p) => p.isFollowing).toList();

    if (followingProfiles.isEmpty) {
      return Center(child: _buildEmptyState(
        icon: Icons.person_add_disabled_outlined,
        title: 'Not following anyone yet',
        subtitle: 'Explore traders in the Community Feed to follow their trading insights!',
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: followingProfiles.length,
      itemBuilder: (context, index) {
        final profile = followingProfiles[index];
        return _UserNetworkCard(
          key: ValueKey(profile.id),
          targetUserId: profile.id,
          overrideName: profile.username,
          overrideAvatar: profile.avatarUrl,
          overrideRank: profile.rankTitle,
          overrideBio: profile.bio,
          isFollowing: true,
          onToggleFollow: () {
            ref.read(communityProvider.notifier).toggleFollowUser(profile.id);
          },
        );
      },
    );
  }

  // ── 2. FOLLOWERS LIST ──────────────────────────────────────────────────────
  Widget _buildFollowersList(String currentUserId) {
    if (currentUserId.isEmpty) {
      return Center(child: _buildEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No followers yet',
        subtitle: 'Share your paper trades in the Community Feed to attract followers!',
      ));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('followers')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: _buildEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No followers yet',
            subtitle: 'Share your paper trades in the Community Feed to build your trading audience!',
          ));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final followerId = docs[index].id;
            return _UserNetworkCard(
              key: ValueKey(followerId),
              targetUserId: followerId,
              isFollowing: false,
              onToggleFollow: () => _toggleFollow(currentUserId, followerId, false),
            );
          },
        );
      },
    );
  }

  void _toggleFollow(String currentUserId, String targetId, bool currentlyFollowing) async {
    ref.read(communityProvider.notifier).toggleFollowUser(targetId);

    if (currentUserId.isNotEmpty && targetId.isNotEmpty) {
      try {
        final followingRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(targetId);

        final followerRef = FirebaseFirestore.instance
            .collection('users')
            .doc(targetId)
            .collection('followers')
            .doc(currentUserId);

        if (currentlyFollowing) {
          await followingRef.delete();
          await followerRef.delete();
        } else {
          await followingRef.set({'followedAt': FieldValue.serverTimestamp()});
          await followerRef.set({'followedAt': FieldValue.serverTimestamp()});
        }
      } catch (_) {}
    }
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.muted, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(color: AppColors.subtle, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── USER NETWORK CARD ────────────────────────────────────────────────────────
class _UserNetworkCard extends ConsumerStatefulWidget {
  final String targetUserId;
  final String? overrideName;
  final String? overrideAvatar;
  final String? overrideRank;
  final String? overrideBio;
  final bool isFollowing;
  final VoidCallback onToggleFollow;

  const _UserNetworkCard({
    super.key,
    required this.targetUserId,
    this.overrideName,
    this.overrideAvatar,
    this.overrideRank,
    this.overrideBio,
    required this.isFollowing,
    required this.onToggleFollow,
  });

  @override
  ConsumerState<_UserNetworkCard> createState() => _UserNetworkCardState();
}

class _UserNetworkCardState extends ConsumerState<_UserNetworkCard> {
  String _name = '';
  String _avatar = '';
  String _bio = '';

  @override
  void initState() {
    super.initState();
    _loadUserCardData();
  }

  @override
  void didUpdateWidget(covariant _UserNetworkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetUserId != widget.targetUserId ||
        oldWidget.overrideName != widget.overrideName) {
      _loadUserCardData();
    }
  }

  Future<void> _loadUserCardData() async {
    if (widget.overrideName != null) {
      _name = widget.overrideName!;
      _avatar = widget.overrideAvatar ?? '';
      _bio = widget.overrideBio ?? '';
      if (mounted) setState(() {});
      return;
    }

    final communityState = ref.read(communityProvider);
    final seedProfile = communityState.profiles[widget.targetUserId];
    if (seedProfile != null) {
      _name = seedProfile.username;
      _avatar = seedProfile.avatarUrl;
      _bio = seedProfile.bio;
      if (mounted) setState(() {});
      return;
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).get();
      if (!doc.exists) {
        final qs = await FirebaseFirestore.instance
            .collection('users')
            .where('profile.publicUid', isEqualTo: widget.targetUserId)
            .limit(1)
            .get();
        if (qs.docs.isNotEmpty) {
          doc = qs.docs.first;
        }
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final profile = data['profile'] as Map<String, dynamic>? ?? {};
        _name = profile['name'] as String? ?? 'Trader';
        _avatar = profile['photoUrl'] as String? ?? '';
        _bio = profile['bio'] as String? ?? profile['publicUid'] as String? ?? '';
      } else {
        _name = 'Trader (${widget.targetUserId.length > 6 ? widget.targetUserId.substring(0, 6) : widget.targetUserId})';
      }
    } catch (_) {
      _name = 'Trader';
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = ref.watch(isUserVerifiedProvider(widget.targetUserId));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (context) => UserProfileModal(
                userId: widget.targetUserId,
                fallbackName: _name,
                fallbackAvatar: _avatar,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.surfaceAlt,
                  backgroundImage: _avatar.isNotEmpty ? NetworkImage(_avatar) : null,
                  child: _avatar.isEmpty
                      ? Text(
                          _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),

                // User details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _name,
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFF0095F6),
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      if (_bio.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: AppColors.subtle, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Action Button
                InkWell(
                  onTap: widget.onToggleFollow,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.isFollowing ? Colors.transparent : AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.isFollowing ? AppColors.primary : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isFollowing ? Icons.check : Icons.person_add_rounded,
                          size: 14,
                          color: widget.isFollowing ? AppColors.primary : Colors.black,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.isFollowing ? 'Following' : 'Follow Back',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.isFollowing ? AppColors.primary : Colors.black,
                          ),
                        ),
                      ],
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
