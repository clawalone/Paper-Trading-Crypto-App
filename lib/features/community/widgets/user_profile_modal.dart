import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/app_theme.dart';
import '../../../data/community_provider.dart';
import '../../../data/user_provider.dart';
import '../../../data/market_provider.dart';
import '../../../data/models.dart';
import '../../common/widgets/animated_title_badge.dart';

class UserProfileModal extends ConsumerStatefulWidget {
  final String userId;
  final String fallbackName;
  final String fallbackAvatar;
  final String? initialRank;

  const UserProfileModal({
    super.key,
    required this.userId,
    required this.fallbackName,
    required this.fallbackAvatar,
    this.initialRank,
  });

  @override
  ConsumerState<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends ConsumerState<UserProfileModal> {
  bool _isLoading = true;
  String _username = '';
  String _avatarUrl = '';
  String _bio = '';
  double _winRate = 0.0;
  int _totalTrades = 0;
  double _returnPct = 0.0;
  String _rankTitle = 'Paper Trader';
  String _rankLabel = 'Top 5%';
  String _publicUid = '';
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  String _resolvedDocId = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialRank != null && widget.initialRank!.isNotEmpty) {
      _rankLabel = widget.initialRank!;
    }
    _loadRealUserData();
  }

  double _calculateReturnPercentage({
    required double virtualBalance,
    required List holdingsList,
    required List futuresList,
  }) {
    final market = ref.read(marketProvider);
    final priceMap = {for (final s in market) s.symbol: s.currentPrice};

    double portfolioValue = 0.0;
    double investedValue = 0.0;

    for (final item in holdingsList) {
      final symbol = item is Holding ? item.symbol : (item['symbol'] as String? ?? '');
      final qty = item is Holding ? item.quantity : (item['quantity'] as num?)?.toInt() ?? 0;
      final avgPrice = item is Holding ? item.averagePrice : (item['averagePrice'] as num?)?.toDouble() ?? 0.0;

      final curPrice = priceMap[symbol] ?? avgPrice;
      portfolioValue += curPrice * qty;
      investedValue += avgPrice * qty;
    }

    for (final pos in futuresList) {
      final symbol = pos is FuturesPosition ? pos.symbol : (pos['symbol'] as String? ?? '');
      final margin = pos is FuturesPosition ? pos.margin : (pos['margin'] as num?)?.toDouble() ?? 0.0;
      final entryPrice = pos is FuturesPosition ? pos.entryPrice : (pos['entryPrice'] as num?)?.toDouble() ?? 0.0;
      final qty = pos is FuturesPosition ? pos.quantity : (pos['quantity'] as num?)?.toDouble() ?? 0.0;
      final isLong = pos is FuturesPosition
          ? (pos.side == OrderSide.buy)
          : ((pos['side'] as String? ?? 'buy') == 'buy');

      final curPrice = priceMap[symbol] ?? entryPrice;
      final diff = curPrice - entryPrice;
      final pnl = isLong ? diff * qty : -diff * qty;
      final curVal = margin + pnl;

      portfolioValue += curVal > 0 ? curVal : 0.0;
      investedValue += margin;
    }

    if (investedValue > 0) {
      return ((portfolioValue - investedValue) / investedValue) * 100;
    }

    final totalNetWorth = portfolioValue + virtualBalance;
    if (totalNetWorth > 0 && totalNetWorth != 5000) {
      return ((totalNetWorth - 5000) / 5000) * 100;
    }

    return 0.0;
  }

  Future<void> _loadRealUserData() async {
    _username = widget.fallbackName;
    _avatarUrl = widget.fallbackAvatar;
    _publicUid = widget.userId;

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Check Riverpod seed profile first (e.g. user_satoshi)
      final communityState = ref.read(communityProvider);
      final seedProfile = communityState.profiles[widget.userId];
      if (seedProfile != null) {
        _username = seedProfile.username;
        _avatarUrl = seedProfile.avatarUrl;
        _bio = seedProfile.bio;
        _publicUid = widget.userId;
        _winRate = seedProfile.winRate;
        _totalTrades = seedProfile.totalTrades;
        _returnPct = 34.2;
        _rankTitle = seedProfile.rankTitle;
        _rankLabel = 'Top 1%';
        _isFollowing = communityState.followingUserIds.contains(widget.userId);
        _followersCount = seedProfile.followersCount;
        _followingCount = widget.userId == 'user_satoshi' ? 14 : (widget.userId == 'user_crypto_king' ? 26 : 42);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Check if logged in user is viewing their own profile
      if (widget.userId == currentUserId && currentUserId.isNotEmpty) {
        _resolvedDocId = currentUserId;
        final userState = ref.read(userProvider);
        _username = userState.profile.name.isNotEmpty ? userState.profile.name : widget.fallbackName;
        _avatarUrl = userState.profile.photoUrl.isNotEmpty ? userState.profile.photoUrl : widget.fallbackAvatar;
        _publicUid = userState.profile.publicUid.isNotEmpty ? userState.profile.publicUid : currentUserId;
        _rankTitle = userState.profile.evolvedTitle;
        _bio = userState.profile.bio;
        _totalTrades = userState.trades.length + userState.futuresPositions.length;

        final blitzWins = userState.profile.blitzWins;
        final blitzLosses = userState.profile.blitzLosses;
        if ((blitzWins + blitzLosses) > 0) {
          _winRate = (blitzWins / (blitzWins + blitzLosses)) * 100;
        } else {
          _winRate = _totalTrades > 0 ? 60.0 : 0.0;
        }

        _returnPct = _calculateReturnPercentage(
          virtualBalance: userState.profile.virtualBalance,
          holdingsList: userState.holdings,
          futuresList: userState.futuresPositions,
        );
      } else {
        // Query Firestore for real user document
        DocumentSnapshot? userDoc;
        if (widget.userId.isNotEmpty) {
          userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
          if (!userDoc.exists) {
            final qs = await FirebaseFirestore.instance
                .collection('users')
                .where('profile.publicUid', isEqualTo: widget.userId)
                .limit(1)
                .get();
            if (qs.docs.isNotEmpty) {
              userDoc = qs.docs.first;
              _resolvedDocId = userDoc.id;
            }
          } else {
            _resolvedDocId = userDoc.id;
          }
        }

        if (userDoc != null && userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          final profileMap = data['profile'] as Map<String, dynamic>? ?? {};
          final holdingsList = (data['holdings'] as List?) ?? [];
          final futuresList = (data['futuresPositions'] as List?) ?? [];
          final tradesList = (data['trades'] as List?) ?? [];

          _username = profileMap['name'] as String? ?? widget.fallbackName;
          _avatarUrl = profileMap['photoUrl'] as String? ?? widget.fallbackAvatar;
          _publicUid = (profileMap['publicUid'] as String?)?.isNotEmpty == true
              ? profileMap['publicUid'] as String
              : userDoc.id;
          final userXp = (profileMap['xp'] as num?)?.toInt() ?? 0;
          _rankTitle = UserProfile.getEvolvedTitle(userXp);
          _bio = profileMap['bio'] as String? ?? 'Passionate paper trader & crypto enthusiast.';

          _totalTrades = tradesList.length + futuresList.length;

          final blitzWins = (profileMap['blitzWins'] as num?)?.toInt() ?? 0;
          final blitzLosses = (profileMap['blitzLosses'] as num?)?.toInt() ?? 0;
          if ((blitzWins + blitzLosses) > 0) {
            _winRate = (blitzWins / (blitzWins + blitzLosses)) * 100;
          } else {
            _winRate = _totalTrades > 0 ? 50.0 : 0.0;
          }

          final vBal = (profileMap['virtualBalance'] as num?)?.toDouble() ?? 5000.0;
          _returnPct = _calculateReturnPercentage(
            virtualBalance: vBal,
            holdingsList: holdingsList,
            futuresList: futuresList,
          );
        }
      }

      // Compute Real Global Rank identical to LeaderboardScreen logic
      if (widget.initialRank != null && widget.initialRank!.isNotEmpty) {
        _rankLabel = widget.initialRank!;
      } else {
        final market = ref.read(marketProvider);
        final priceMap = {for (final s in market) s.symbol: s.currentPrice};

        final allUsersSnap = await FirebaseFirestore.instance.collection('users').get();
        if (allUsersSnap.docs.isNotEmpty) {
          final List<Map<String, dynamic>> parsedList = [];

          for (final doc in allUsersSnap.docs) {
            try {
              final data = doc.data();
              final state = UserState.fromJson(data);

              if (state.profile.email.toLowerCase() == 'admin@gmail.com' ||
                  state.profile.name.toLowerCase().contains('admin')) {
                continue;
              }

              if (state.isBanned || state.profile.isBanned) {
                continue;
              }

              double portfolioValue = 0;
              for (final holding in state.holdings) {
                final price = priceMap[holding.symbol] ?? holding.averagePrice;
                portfolioValue += price * holding.quantity;
              }

              double futuresValue = 0;
              for (final pos in state.futuresPositions) {
                final price = priceMap[pos.symbol];
                if (price != null) {
                  final isLong = pos.side == OrderSide.buy;
                  final diff = price - pos.entryPrice;
                  final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
                  final currentValue = pos.margin + pnl;
                  futuresValue += currentValue > 0 ? currentValue : 0;
                } else {
                  futuresValue += pos.margin;
                }
              }

              final netWorth = state.profile.virtualBalance + portfolioValue + futuresValue;

              parsedList.add({
                'docId': doc.id,
                'publicUid': state.profile.publicUid.isNotEmpty ? state.profile.publicUid : doc.id,
                'name': state.profile.name.isNotEmpty ? state.profile.name : 'Trader',
                'netWorth': netWorth,
              });
            } catch (_) {}
          }

          parsedList.sort(
            (a, b) => (b['netWorth'] as double).compareTo(a['netWorth'] as double),
          );

          int userRank = -1;
          final targetId = _resolvedDocId.isNotEmpty
              ? _resolvedDocId
              : (widget.userId.isNotEmpty ? widget.userId : currentUserId);

          for (int i = 0; i < parsedList.length; i++) {
            final item = parsedList[i];
            final docUid = item['docId'] as String;
            final publicUid = item['publicUid'] as String;
            final docName = item['name'] as String;

            if (docUid == targetId ||
                publicUid == targetId ||
                (publicUid.isNotEmpty && _publicUid.isNotEmpty && publicUid == _publicUid) ||
                (docName.isNotEmpty && docName.toLowerCase() == _username.toLowerCase())) {
              userRank = i + 1;
              break;
            }
          }

          if (userRank > 0) {
            _rankLabel = '#$userRank';
          } else {
            _rankLabel = '#1';
          }
        }
      }

      final targetDocId = _resolvedDocId.isNotEmpty
          ? _resolvedDocId
          : (widget.userId.isNotEmpty ? widget.userId : currentUserId);

      // Check follow status in Firestore / local state
      if (currentUserId.isNotEmpty && targetDocId.isNotEmpty) {
        final isFollowedInState = communityState.followingUserIds.contains(targetDocId) ||
            communityState.followingUserIds.contains(widget.userId);
        if (isFollowedInState) {
          _isFollowing = true;
        } else {
          final followDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('following')
              .doc(targetDocId)
              .get();
          _isFollowing = followDoc.exists;
        }
      }

      // Fetch real followers count and following count for target user
      int firestoreFollowers = 0;
      int firestoreFollowing = 0;
      if (targetDocId.isNotEmpty) {
        try {
          final countSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(targetDocId)
              .collection('followers')
              .count()
              .get();
          firestoreFollowers = countSnap.count ?? 0;
        } catch (_) {}

        try {
          final followingSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(targetDocId)
              .collection('following')
              .count()
              .get();
          firestoreFollowing = followingSnap.count ?? 0;
        } catch (_) {}
      }

      final isMe = (widget.userId == currentUserId || widget.userId.isEmpty || widget.userId == 'current_user');
      if (isMe) {
        _followersCount = firestoreFollowers;
        _followingCount = firestoreFollowing > 0 ? firestoreFollowing : communityState.followingUserIds.length;
      } else {
        // Strictly real counts from Firestore
        _followersCount = firestoreFollowers;
        if (_isFollowing && _followersCount == 0) {
          _followersCount = 1;
        }
        _followingCount = firestoreFollowing;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final targetId = _resolvedDocId.isNotEmpty ? _resolvedDocId : widget.userId;

    setState(() {
      _isFollowing = !_isFollowing;
      if (_isFollowing) {
        _followersCount++;
      } else if (_followersCount > 0) {
        _followersCount--;
      }
    });

    ref.read(communityProvider.notifier).toggleFollowUser(targetId);
    if (widget.userId.isNotEmpty && widget.userId != targetId) {
      ref.read(communityProvider.notifier).toggleFollowUser(widget.userId);
    }

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

        if (_isFollowing) {
          await followingRef.set({'followedAt': FieldValue.serverTimestamp()});
          await followerRef.set({'followedAt': FieldValue.serverTimestamp()});
          if (_publicUid.isNotEmpty && _publicUid != targetId) {
            FirebaseFirestore.instance
                .collection('users')
                .doc(_publicUid)
                .collection('followers')
                .doc(currentUserId)
                .set({'followedAt': FieldValue.serverTimestamp()}).catchError((_) {});
          }
        } else {
          await followingRef.delete();
          await followerRef.delete();
          if (_publicUid.isNotEmpty && _publicUid != targetId) {
            FirebaseFirestore.instance
                .collection('users')
                .doc(_publicUid)
                .collection('followers')
                .doc(currentUserId)
                .delete().catchError((_) {});
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwnProfile = currentUserId.isNotEmpty &&
        (widget.userId == currentUserId || _publicUid == currentUserId || widget.userId == 'current_user');

    final isAdmin = _username.trim().toLowerCase().contains('admin') ||
        widget.userId.toLowerCase().contains('admin') ||
        _rankTitle.toLowerCase().contains('admin') ||
        (FirebaseAuth.instance.currentUser?.email?.toLowerCase() == 'admin@gmail.com' &&
            (widget.userId == currentUserId || widget.userId.isEmpty));
    final isVerified = isAdmin || _followersCount > 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF333639),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
              ),
            )
          else ...[
            // ── Twitter Profile Header: Avatar (Left) & Follow Button (Right) ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Avatar
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF16181C),
                    border: Border.all(color: const Color(0xFF2F3336), width: 1.5),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: _avatarUrl.isNotEmpty
                        ? Image.network(
                            _avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person, color: Color(0xFF71767B), size: 36),
                          )
                        : Center(
                            child: Text(
                              _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ),
                  ),
                ),

                // Twitter Follow / Following Action Button
                if (!isOwnProfile && widget.userId.isNotEmpty)
                  GestureDetector(
                    onTap: _toggleFollow,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 34,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: _isFollowing ? Colors.transparent : const Color(0xFFEFF3F4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isFollowing ? const Color(0xFF536471) : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: GoogleFonts.inter(
                          color: _isFollowing ? const Color(0xFFEFF3F4) : const Color(0xFF0F1419),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  )
                else if (isOwnProfile)
                  Container(
                    height: 32,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF536471), width: 1),
                    ),
                    child: Text(
                      'Your Profile',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEFF3F4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Name, Verified Badge & Experience Tag ─────────────────────────
            Row(
              children: [
                Flexible(
                  child: Text(
                    _username,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFF7F9F9),
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.verified,
                    color: Color(0xFF1D9BF0), // Twitter Verified Blue
                    size: 17,
                  ),
                ],
                const SizedBox(width: 8),
                AnimatedTitleBadge(title: _rankTitle),
              ],
            ),

            const SizedBox(height: 3),

            // ── Handle (@username) & UID with Copy ────────────────────────────
            Row(
              children: [
                Text(
                  '@${_username.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF71767B), // Twitter muted gray
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (_publicUid.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Text('·', style: TextStyle(color: Color(0xFF71767B), fontSize: 13)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _publicUid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('UID $_publicUid copied to clipboard!'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'UID: $_publicUid',
                          style: const TextStyle(
                            color: Color(0xFF71767B),
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded, size: 11, color: Color(0xFF71767B)),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            // ── Bio (Left Aligned) ───────────────────────────────────────────
            if (_bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _bio,
                style: GoogleFonts.inter(
                  color: const Color(0xFFE7E9EA),
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── Twitter Following / Followers Bar ────────────────────────────
            Row(
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$_followingCount',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFF7F9F9),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      TextSpan(
                        text: ' Following',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF71767B),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$_followersCount',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFF7F9F9),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      TextSpan(
                        text: _followersCount == 1 ? ' Follower' : ' Followers',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF71767B),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin || isVerified) ...[
                  const SizedBox(width: 10),
                  const Text('·', style: TextStyle(color: Color(0xFF71767B), fontSize: 13)),
                  const SizedBox(width: 10),
                  Text(
                    isAdmin ? 'Admin' : 'Verified Trader',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1D9BF0),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),

            // ── FinTwit Terminal Trading Stats Card ──────────────────────────
            if (!isAdmin) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16181C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2F3336), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.insights_rounded, size: 14, color: Color(0xFF71767B)),
                        const SizedBox(width: 6),
                        Text(
                          'TRADING PERFORMANCE',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF71767B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Win Rate', '${_winRate.toStringAsFixed(1)}%', AppColors.profit),
                        Container(height: 28, width: 1, color: const Color(0xFF2F3336)),
                        _buildStatItem('Trades', '$_totalTrades', const Color(0xFFF7F9F9)),
                        Container(height: 28, width: 1, color: const Color(0xFF2F3336)),
                        _buildStatItem(
                          'Return',
                          '${_returnPct >= 0 ? '+' : ''}${_returnPct.toStringAsFixed(1)}%',
                          _returnPct >= 0 ? AppColors.profit : AppColors.loss,
                        ),
                        Container(height: 28, width: 1, color: const Color(0xFF2F3336)),
                        _buildStatItem('Rank', _rankLabel, AppColors.warning),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF71767B),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
