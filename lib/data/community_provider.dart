import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class CommunityState {
  final List<CommunityPost> posts;
  final Map<String, List<PostComment>> commentsByPostId;
  final Map<String, PublicUserProfile> profiles;
  final Set<String> bookmarkedPostIds;
  final Set<String> followingUserIds;

  const CommunityState({
    required this.posts,
    required this.commentsByPostId,
    required this.profiles,
    this.bookmarkedPostIds = const {},
    this.followingUserIds = const {},
  });

  CommunityState copyWith({
    List<CommunityPost>? posts,
    Map<String, List<PostComment>>? commentsByPostId,
    Map<String, PublicUserProfile>? profiles,
    Set<String>? bookmarkedPostIds,
    Set<String>? followingUserIds,
  }) {
    return CommunityState(
      posts: posts ?? this.posts,
      commentsByPostId: commentsByPostId ?? this.commentsByPostId,
      profiles: profiles ?? this.profiles,
      bookmarkedPostIds: bookmarkedPostIds ?? this.bookmarkedPostIds,
      followingUserIds: followingUserIds ?? this.followingUserIds,
    );
  }
}

class CommunityNotifier extends Notifier<CommunityState> {
  StreamSubscription? _postsSub;
  StreamSubscription? _commentsSub;
  StreamSubscription? _followingSub;
  StreamSubscription? _authSub;

  @override
  CommunityState build() {
    ref.onDispose(() {
      _postsSub?.cancel();
      _commentsSub?.cancel();
      _followingSub?.cancel();
      _authSub?.cancel();
    });

    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
        _listenToFirestore();
      });

      _listenToFirestore();
    } catch (_) {
      // Firebase not initialized in unit tests or offline
    }

    _loadBookmarks();

    return _initialState();
  }

  void _listenToFirestore() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    _postsSub?.cancel();
    _postsSub = FirebaseFirestore.instance
        .collection('community_posts')
        .snapshots()
        .listen((snapshot) {
      try {
        final firestorePosts = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          return CommunityPost.fromJson(data, currentUserId: currentUserId);
        }).toList();

        // Sort descending by timestamp
        firestorePosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Merge Firestore posts with initial seed posts (excluding duplicates)
        final existingIds = firestorePosts.map((p) => p.id).toSet();
        final initialSeed = _initialState().posts.where((p) => !existingIds.contains(p.id)).toList();

        state = state.copyWith(
          posts: [...firestorePosts, ...initialSeed],
        );
      } catch (e) {
        // Log error silently or debug
      }
    }, onError: (_) {
      // Fallback silently to initial state if offline or Firestore unconfigured
    });

    _commentsSub?.cancel();
    _commentsSub = FirebaseFirestore.instance
        .collection('community_comments')
        .snapshots()
        .listen((snapshot) {
      try {
        final updatedCommentsMap = Map<String, List<PostComment>>.from(state.commentsByPostId);
        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          final comment = PostComment.fromJson(data);
          final currentList = updatedCommentsMap[comment.postId] ?? [];
          if (!currentList.any((c) => c.id == comment.id)) {
            updatedCommentsMap[comment.postId] = [...currentList, comment];
          }
        }
        state = state.copyWith(commentsByPostId: updatedCommentsMap);
      } catch (e) {
        // Log error silently
      }
    }, onError: (_) {});

    _followingSub?.cancel();
    if (currentUserId.isNotEmpty) {
      _followingSub = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .snapshots()
          .listen((snapshot) {
        final followingIds = snapshot.docs.map((doc) => doc.id).toSet();
        // Also preserve initial seed follows
        final seedFollowed = _initialState().profiles.values
            .where((p) => p.isFollowing)
            .map((p) => p.id);
        followingIds.addAll(seedFollowed);

        state = state.copyWith(followingUserIds: followingIds);
      }, onError: (_) {});
    } else {
      final seedFollowed = _initialState().profiles.values
          .where((p) => p.isFollowing)
          .map((p) => p.id)
          .toSet();
      state = state.copyWith(followingUserIds: seedFollowed);
    }
  }

  static CommunityState _initialState() {
    final now = DateTime.now();

    final initialProfiles = {
      'user_satoshi': const PublicUserProfile(
        id: 'user_satoshi',
        username: 'SatoshiScalper',
        avatarUrl: 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Cat.png',
        bio: 'Full-time Bitcoin scalper & technical analyst. Risk management is key ⚡',
        winRate: 78.5,
        totalTrades: 142,
        rankTitle: 'Top 1% Trader',
        isFollowing: true,
        sharedPostsCount: 18,
        followersCount: 120,
      ),
      'user_crypto_king': const PublicUserProfile(
        id: 'user_crypto_king',
        username: 'CryptoWhale99',
        avatarUrl: 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Lion.png',
        bio: 'Ethereum & Solana swing trader. Long-term bull 🚀',
        winRate: 69.2,
        totalTrades: 89,
        rankTitle: 'Whale Trader',
        isFollowing: false,
        sharedPostsCount: 12,
        followersCount: 85,
      ),
      'user_degen': const PublicUserProfile(
        id: 'user_degen',
        username: 'LeverageDegen',
        avatarUrl: 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Tiger%20Face.png',
        bio: '50x or bust! Pure momentum trader.',
        winRate: 54.0,
        totalTrades: 310,
        rankTitle: 'High Risk Trader',
        isFollowing: false,
        sharedPostsCount: 24,
        followersCount: 3, // <= 5 followers: does NOT get blue tick
      ),
    };

    final initialPosts = [
      CommunityPost(
        id: 'post_1',
        authorId: 'user_satoshi',
        authorName: 'SatoshiScalper',
        authorAvatar: 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Cat.png',
        authorBadge: 'Top 1% Trader',
        content: 'BTC break above key resistance zone on 4H chart! Target set at \$68,500 with tight Stop Loss. Always control your risk exposure guys! 📈🔥',
        timestamp: now.subtract(const Duration(minutes: 25)),
        attachedTrade: const AttachedTradeInfo(
          symbol: 'BTC/USDT',
          isLong: true,
          leverage: 10,
          entryPrice: 64200.0,
          currentPrice: 65150.0,
          pnlPercentage: 14.8,
          targetPrice: 68500.0,
          stopLossPrice: 63500.0,
        ),
        likesCount: 42,
        commentsCount: 2,
        tipsReceived: 250,
        isLikedByMe: true,
        agreeCount: 38,
        disagreeCount: 7,
        hashtags: ['BTC', 'Futures', 'Breakout'],
      ),
      CommunityPost(
        id: 'post_2',
        authorId: 'user_crypto_king',
        authorName: 'CryptoWhale99',
        authorAvatar: 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Lion.png',
        authorBadge: 'Whale Trader',
        content: 'ETH looking very bullish on weekly support. Accumulating spot holdings for the upcoming network upgrade. What are your targets for Q4? 👇',
        timestamp: now.subtract(const Duration(hours: 2)),
        attachedTrade: const AttachedTradeInfo(
          symbol: 'ETH/USDT',
          isLong: true,
          leverage: 1,
          entryPrice: 3450.0,
          currentPrice: 3580.0,
          pnlPercentage: 3.76,
          targetPrice: 4200.0,
          stopLossPrice: 3200.0,
        ),
        likesCount: 28,
        commentsCount: 0,
        tipsReceived: 100,
        isLikedByMe: false,
        agreeCount: 22,
        disagreeCount: 4,
        hashtags: ['ETH', 'Spot', 'HODL'],
      ),
      CommunityPost(
        id: 'post_3',
        authorId: 'user_degen',
        authorName: 'LeverageDegen',
        authorAvatar: 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Tiger%20Face.png',
        authorBadge: 'High Risk Trader',
        content: 'SOL momentum reversal play! Managed to grab 25x leverage right off the liquidity dip. Pure alpha! 🚀🔥',
        timestamp: now.subtract(const Duration(hours: 5)),
        attachedTrade: const AttachedTradeInfo(
          symbol: 'SOL/USDT',
          isLong: true,
          leverage: 25,
          entryPrice: 142.5,
          currentPrice: 148.2,
          pnlPercentage: 100.0,
          targetPrice: 155.0,
          stopLossPrice: 139.0,
        ),
        likesCount: 64,
        commentsCount: 0,
        tipsReceived: 500,
        isLikedByMe: false,
        agreeCount: 51,
        disagreeCount: 12,
        hashtags: ['SOL', '25x', 'Scalp'],
      ),
    ];

    final initialComments = {
      'post_1': [
        PostComment(
          id: 'c1',
          postId: 'post_1',
          authorId: 'user_crypto_king',
          authorName: 'CryptoWhale99',
          authorAvatar: 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Lion.png',
          text: 'Great entry! 68k target looks very reasonable with current funding rates.',
          timestamp: now.subtract(const Duration(minutes: 18)),
        ),
        PostComment(
          id: 'c2',
          postId: 'post_1',
          authorId: 'user_degen',
          authorName: 'LeverageDegen',
          authorAvatar: 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Tiger%20Face.png',
          text: '10x leverage is too safe bro, push it to 25x! 🚀',
          timestamp: now.subtract(const Duration(minutes: 10)),
        ),
      ],
    };

    final initialFollowing = initialProfiles.values
        .where((p) => p.isFollowing)
        .map((p) => p.id)
        .toSet();

    return CommunityState(
      posts: initialPosts,
      commentsByPostId: initialComments,
      profiles: initialProfiles,
      followingUserIds: initialFollowing,
    );
  }

  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('saved_bookmarked_posts') ?? [];
      state = state.copyWith(bookmarkedPostIds: list.toSet());
    } catch (_) {}
  }

  Future<bool> toggleBookmark(String postId) async {
    final updated = Set<String>.from(state.bookmarkedPostIds);
    final isNowBookmarked = !updated.contains(postId);
    if (isNowBookmarked) {
      updated.add(postId);
    } else {
      updated.remove(postId);
    }
    state = state.copyWith(bookmarkedPostIds: updated);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_bookmarked_posts', updated.toList());
    } catch (_) {}

    return isNowBookmarked;
  }

  void toggleLike(String postId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

    state = state.copyWith(
      posts: state.posts.map((post) {
        if (post.id == postId) {
          final isLiked = !post.isLikedByMe;
          final newCount = isLiked ? post.likesCount + 1 : post.likesCount - 1;

          // Sync to Firestore
          FirebaseFirestore.instance.collection('community_posts').doc(postId).update({
            'likesCount': newCount < 0 ? 0 : newCount,
            'likedBy': isLiked
                ? FieldValue.arrayUnion([currentUserId])
                : FieldValue.arrayRemove([currentUserId]),
          }).catchError((_) {});

          return post.copyWith(
            isLikedByMe: isLiked,
            likesCount: newCount < 0 ? 0 : newCount,
          );
        }
        return post;
      }).toList(),
    );
  }

  void addPost({
    required String authorName,
    required String authorAvatar,
    required String content,
    AttachedTradeInfo? attachedTrade,
    List<String> hashtags = const [],
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final postId = 'post_${DateTime.now().millisecondsSinceEpoch}';

    final newPost = CommunityPost(
      id: postId,
      authorId: currentUserId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorBadge: 'Paper Trader',
      content: content,
      timestamp: DateTime.now(),
      attachedTrade: attachedTrade,
      likesCount: 0,
      commentsCount: 0,
      tipsReceived: 0,
      isLikedByMe: false,
      hashtags: hashtags,
    );

    // Instant local update
    state = state.copyWith(
      posts: [newPost, ...state.posts],
    );

    // Persist to Cloud Firestore
    final postJson = newPost.toJson();
    postJson['likedBy'] = [];
    postJson['timestamp'] = FieldValue.serverTimestamp();
    FirebaseFirestore.instance.collection('community_posts').doc(postId).set(postJson).catchError((_) {});
  }

  void addComment(String postId, {required String text, required String authorName, required String authorAvatar}) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final commentId = 'c_${DateTime.now().millisecondsSinceEpoch}';

    final newComment = PostComment(
      id: commentId,
      postId: postId,
      authorId: currentUserId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      text: text,
      timestamp: DateTime.now(),
    );

    final currentComments = state.commentsByPostId[postId] ?? [];
    final updatedCommentsMap = Map<String, List<PostComment>>.from(state.commentsByPostId);
    updatedCommentsMap[postId] = [...currentComments, newComment];

    final updatedPosts = state.posts.map((post) {
      if (post.id == postId) {
        return post.copyWith(commentsCount: post.commentsCount + 1);
      }
      return post;
    }).toList();

    state = state.copyWith(
      posts: updatedPosts,
      commentsByPostId: updatedCommentsMap,
    );

    // Save comment to Firestore and increment comment count
    final commentJson = newComment.toJson();
    commentJson['timestamp'] = FieldValue.serverTimestamp();
    FirebaseFirestore.instance.collection('community_comments').doc(commentId).set(commentJson).catchError((_) {});
    FirebaseFirestore.instance.collection('community_posts').doc(postId).update({
      'commentsCount': FieldValue.increment(1),
    }).catchError((_) {});

    // Notify post author if not self
    try {
      final postIndex = state.posts.indexWhere((p) => p.id == postId);
      if (postIndex >= 0) {
        final authorId = state.posts[postIndex].authorId;
        if (authorId.isNotEmpty && authorId != currentUserId) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(authorId)
              .collection('notifications')
              .add({
                'userId': authorId,
                'title': 'New Reply on Setup 💬',
                'message': '$authorName commented: "$text"',
                'category': 'social',
                'type': 'comment',
                'createdAt': DateTime.now().toIso8601String(),
                'isRead': false,
                'data': {'postId': postId},
              }).then<void>((_) {}, onError: (_) {});
        }
      }
    } catch (_) {}
  }

  void deletePost(String postId) {
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );

    // Delete from Cloud Firestore
    FirebaseFirestore.instance.collection('community_posts').doc(postId).delete().catchError((_) {});
  }

  void tipPost({
    required String postId,
    required int amount,
    String? recipientId,
    String? recipientName,
    String? senderId,
    String? senderName,
  }) {
    state = state.copyWith(
      posts: state.posts.map((post) {
        if (post.id == postId) {
          return post.copyWith(tipsReceived: post.tipsReceived + amount);
        }
        return post;
      }).toList(),
    );

    // Sync tip to Firestore doc
    FirebaseFirestore.instance.collection('community_posts').doc(postId).update({
      'tipsReceived': FieldValue.increment(amount),
    }).catchError((_) {});

    // Create a pending tip document in community_tips so the recipient gets credited
    if (recipientId != null && recipientId.isNotEmpty) {
      final tipRef = FirebaseFirestore.instance.collection('community_tips').doc();
      tipRef.set({
        'id': tipRef.id,
        'postId': postId,
        'senderId': senderId ?? '',
        'senderName': senderName ?? 'A trader',
        'recipientId': recipientId,
        'recipientName': recipientName ?? 'Trader',
        'amount': amount,
        'amountUsd': amount,
        'claimed': false,
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});

      // Deliver in-app notification to recipient
      FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .collection('notifications')
          .add({
            'userId': recipientId,
            'title': 'New Tip Received! 💸',
            'message': '${senderName ?? "A trader"} tipped you \$${amount.toStringAsFixed(0)} on your setup!',
            'category': 'social',
            'type': 'tip',
            'createdAt': DateTime.now().toIso8601String(),
            'isRead': false,
            'data': {
              'postId': postId,
              'amount': amount,
              'senderId': senderId,
            },
          }).then<void>((_) {}, onError: (_) {});
    }
  }

  void votePrediction(String postId, String voteType) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

    state = state.copyWith(
      posts: state.posts.map((post) {
        if (post.id == postId) {
          final previousVote = post.myVote;
          if (previousVote == voteType) return post;

          int newAgree = post.agreeCount;
          int newDisagree = post.disagreeCount;

          if (previousVote == 'agree') newAgree--;
          if (previousVote == 'disagree') newDisagree--;

          if (voteType == 'agree') newAgree++;
          if (voteType == 'disagree') newDisagree++;

          final finalAgree = newAgree < 0 ? 0 : newAgree;
          final finalDisagree = newDisagree < 0 ? 0 : newDisagree;

          // Sync to Firestore
          FirebaseFirestore.instance.collection('community_posts').doc(postId).update({
            'agreeCount': finalAgree,
            'disagreeCount': finalDisagree,
            'votes.$currentUserId': voteType,
          }).catchError((_) {});

          return post.copyWith(
            agreeCount: finalAgree,
            disagreeCount: finalDisagree,
            myVote: voteType,
          );
        }
        return post;
      }).toList(),
    );
  }

  void toggleFollowUser(String userId) {
    final updatedFollowing = Set<String>.from(state.followingUserIds);
    final isNowFollowing = !updatedFollowing.contains(userId);
    if (isNowFollowing) {
      updatedFollowing.add(userId);
    } else {
      updatedFollowing.remove(userId);
    }

    final currentProfile = state.profiles[userId];
    Map<String, PublicUserProfile>? updatedProfiles;
    if (currentProfile != null) {
      final newFollowers = isNowFollowing
          ? currentProfile.followersCount + 1
          : (currentProfile.followersCount > 0 ? currentProfile.followersCount - 1 : 0);
      final updatedProfile = currentProfile.copyWith(
        isFollowing: isNowFollowing,
        followersCount: newFollowers,
      );
      updatedProfiles = Map<String, PublicUserProfile>.from(state.profiles);
      updatedProfiles[userId] = updatedProfile;
    }

    state = state.copyWith(
      followingUserIds: updatedFollowing,
      profiles: updatedProfiles ?? state.profiles,
    );

    // Persist follow/unfollow to Firestore
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isNotEmpty && userId.isNotEmpty && currentUserId != userId) {
      try {
        final followingRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(userId);

        final followerRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('followers')
            .doc(currentUserId);

        if (isNowFollowing) {
          followingRef.set({'followedAt': FieldValue.serverTimestamp()}).catchError((_) {});
          followerRef.set({'followedAt': FieldValue.serverTimestamp()}).catchError((_) {});

          final currentUserName = FirebaseAuth.instance.currentUser?.displayName ?? 'A trader';
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .add({
                'userId': userId,
                'title': 'New Follower 👤',
                'message': '$currentUserName started following your setups & trades.',
                'category': 'social',
                'type': 'follow',
                'createdAt': DateTime.now().toIso8601String(),
                'isRead': false,
                'data': {'followerId': currentUserId},
              }).then<void>((_) {}, onError: (_) {});
        } else {
          followingRef.delete().catchError((_) {});
          followerRef.delete().catchError((_) {});
        }
      } catch (_) {}
    }
  }
}

final communityProvider = NotifierProvider<CommunityNotifier, CommunityState>(CommunityNotifier.new);

/// Real-time follower count provider for any user ID (seeds or Firestore users)
final userFollowerCountProvider = StreamProvider.family<int, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(0);

  // If it's a seed profile in CommunityState, return its live count from state
  final community = ref.watch(communityProvider);
  final profile = community.profiles[userId];
  if (profile != null) {
    return Stream.value(profile.followersCount);
  }

  // Otherwise, stream real follower collection size from Firestore
  try {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((_) => 0);
  } catch (_) {
    return Stream.value(0);
  }
});

/// Returns true if the user has strictly MORE THAN 5 followers (> 5) OR is an administrator.
final isUserVerifiedProvider = Provider.family<bool, String>((ref, userId) {
  if (userId.isEmpty) return false;

  // Explicit admin check
  if (userId.toLowerCase() == 'admin' || userId.toLowerCase().contains('admin')) {
    return true;
  }
  try {
    final currentAuth = FirebaseAuth.instance.currentUser;
    if (currentAuth != null &&
        currentAuth.email?.toLowerCase() == 'admin@gmail.com' &&
        (userId == currentAuth.uid || userId == 'admin')) {
      return true;
    }
  } catch (_) {}

  // Check seed profiles synchronously to avoid flickering
  final community = ref.watch(communityProvider);
  final profile = community.profiles[userId];
  if (profile != null) {
    if (profile.username.toLowerCase().contains('admin') || profile.rankTitle.toLowerCase().contains('admin')) {
      return true;
    }
    return profile.followersCount > 5;
  }

  final asyncCount = ref.watch(userFollowerCountProvider(userId));
  final count = asyncCount.value ?? 0;
  return count > 5;
});
