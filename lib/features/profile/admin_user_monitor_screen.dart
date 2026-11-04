import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../core/ban_manager.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';

class AdminUserMonitorScreen extends ConsumerStatefulWidget {
  final String? initialUid;
  const AdminUserMonitorScreen({super.key, this.initialUid});

  @override
  ConsumerState<AdminUserMonitorScreen> createState() => _AdminUserMonitorScreenState();
}

class _AdminUserMonitorScreenState extends ConsumerState<AdminUserMonitorScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;

  bool _isSearching = false;
  bool _isTogglingBan = false;
  String? _foundDocId;
  Map<String, dynamic>? _userData;
  UserState? _parsedUserState;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialUid != null && widget.initialUid!.isNotEmpty) {
      _searchController.text = widget.initialUid!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchUser();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _errorMessage = 'Please enter a UID, Email, or Username');
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _userData = null;
      _foundDocId = null;
      _parsedUserState = null;
    });

    try {
      // 1. Try publicUid match
      var qs = await FirebaseFirestore.instance
          .collection('users')
          .where('profile.publicUid', isEqualTo: query)
          .limit(1)
          .get();

      // 2. Try direct docId (Auth UID)
      if (qs.docs.isEmpty) {
        final directDoc = await FirebaseFirestore.instance.collection('users').doc(query).get();
        if (directDoc.exists && directDoc.data() != null) {
          final data = directDoc.data()!;
          setState(() {
            _foundDocId = directDoc.id;
            _userData = data;
            _parsedUserState = _safeParseUserState(data);
            _isSearching = false;
          });
          return;
        }
      }

      // 3. Try email match
      if (qs.docs.isEmpty && query.contains('@')) {
        qs = await FirebaseFirestore.instance
            .collection('users')
            .where('profile.email', isEqualTo: query.toLowerCase())
            .limit(1)
            .get();
      }

      // 4. Try username match
      if (qs.docs.isEmpty) {
        qs = await FirebaseFirestore.instance
            .collection('users')
            .where('profile.name', isEqualTo: query)
            .limit(1)
            .get();
      }

      if (qs.docs.isNotEmpty) {
        final doc = qs.docs.first;
        final data = doc.data();
        setState(() {
          _foundDocId = doc.id;
          _userData = data;
          _parsedUserState = _safeParseUserState(data);
          _isSearching = false;
        });
      } else {
        setState(() {
          _errorMessage = 'No account found matching "$query"';
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Search error: $e';
        _isSearching = false;
      });
    }
  }

  UserState? _safeParseUserState(Map<String, dynamic> data) {
    try {
      return UserState.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _showBanToggleDialog({required bool ban}) async {
    if (_foundDocId == null || _userData == null) return;
    final profile = Map<String, dynamic>.from((_userData!['profile'] as Map?) ?? {});
    final userName = profile['name']?.toString() ?? 'Trader';
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2329),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              ban ? Icons.gavel_rounded : Icons.check_circle_rounded,
              color: ban ? AppColors.loss : AppColors.profit,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              ban ? 'Ban User Account' : 'Lift User Ban',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ban
                  ? 'Are you sure you want to suspend "$userName"?\n\nThey will be immediately locked out from paper trading, tipping, and accessing all platform features.'
                  : 'Are you sure you want to lift the suspension for "$userName"?\n\nFull access to their trading account will be restored immediately.',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            if (ban) ...[
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ban reason (e.g. Balance manipulation)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF14171A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ban ? AppColors.loss : AppColors.profit,
              foregroundColor: ban ? Colors.white : Colors.black,
            ),
            child: Text(ban ? 'Confirm Ban' : 'Confirm Unban', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isTogglingBan = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(_foundDocId);
      final reason = reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : 'Violation of Community & Trading Guidelines';

      profile['isBanned'] = ban;
      profile['banReason'] = ban ? reason : null;
      profile['bannedAt'] = ban ? DateTime.now().toIso8601String() : null;

      await docRef.update({
        'isBanned': ban,
        'banReason': ban ? reason : null,
        'bannedAt': ban ? FieldValue.serverTimestamp() : null,
        'profile': profile,
      });

      setState(() {
        _isTogglingBan = false;
        _userData!['isBanned'] = ban;
        _userData!['banReason'] = ban ? reason : null;
        _userData!['profile'] = profile;
        _parsedUserState = _safeParseUserState(_userData!);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ban ? 'User "$userName" has been banned.' : 'Ban lifted for "$userName"! Access restored.'),
            backgroundColor: ban ? AppColors.loss : AppColors.profit,
          ),
        );
      }
    } catch (e) {
      setState(() => _isTogglingBan = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.loss),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(marketProvider);
    final currentAdminCurrency = ref.watch(userProvider).profile.preferredCurrency;
    final formatter = AppCurrencyFormatter(currentAdminCurrency, decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF141A21),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Color(0xFFF59E0B), size: 20),
            SizedBox(width: 8),
            Text(
              'User Activity & Portfolio Inspector',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Search Bar Section ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            color: const Color(0xFF141A21),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _searchUser(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF848E9C), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _userData = null;
                                  _foundDocId = null;
                                  _parsedUserState = null;
                                  _errorMessage = null;
                                });
                              },
                            )
                          : null,
                      hintText: 'Enter UID (PT-XXXXXX), Auth UID, or Email',
                      hintStyle: const TextStyle(color: Color(0xFF5E6673), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF1E2329),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2B3139)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2B3139)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSearching ? null : _searchUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text(
                            'Inspect',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search Results or State View ─────────────────────────────────
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.loss.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.loss.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.loss, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_userData == null && !_isSearching)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF141A21),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.manage_search_rounded, color: Color(0xFF848E9C), size: 48),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ready to Inspect User Portfolio',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Search by Public UID (PT-XXXXXX), Firebase UID, or Email\nto view real-time holdings, futures positions, and recent trades.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF848E9C), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            )
          else if (_userData != null)
            Expanded(
              child: _buildInspectedUserView(market, formatter),
            ),
        ],
      ),
    );
  }

  Widget _buildInspectedUserView(List<Stock> market, AppCurrencyFormatter formatter) {
    final profile = (_userData!['profile'] as Map<String, dynamic>?) ?? {};
    final name = (profile['name'] as String?) ?? 'Unknown';
    final email = (profile['email'] as String?) ?? 'No email';
    final publicUid = (profile['publicUid'] as String?) ?? 'N/A';
    final cashBalance = (profile['virtualBalance'] as num?)?.toDouble() ?? 0.0;
    final streak = (profile['streak'] as num?)?.toInt() ?? 1;
    final xp = (profile['xp'] as num?)?.toInt() ?? 0;
    final isBanned = (_userData!['isBanned'] as bool?) ?? false;
    final banReason = (_userData!['banReason'] as String?) ?? '';

    // Calculate Portfolio Values
    final holdings = _parsedUserState?.holdings ?? [];
    final futures = _parsedUserState?.futuresPositions ?? [];
    final trades = _parsedUserState?.trades ?? [];
    final walletEntries = (_userData!['walletEntries'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

    double spotValuation = 0.0;
    for (final h in holdings) {
      final stock = market.cast<Stock?>().firstWhere((s) => s?.symbol == h.symbol, orElse: () => null);
      final price = stock?.currentPrice ?? h.averagePrice;
      spotValuation += price * h.quantity;
    }

    double futuresMargin = 0.0;
    double futuresUnrealizedPnl = 0.0;
    for (final f in futures) {
      futuresMargin += f.margin;
      final stock = market.cast<Stock?>().firstWhere((s) => s?.symbol == f.symbol, orElse: () => null);
      if (stock != null) {
        final isLong = f.side == OrderSide.buy;
        final diff = stock.currentPrice - f.entryPrice;
        final pnl = isLong ? diff * f.quantity : -diff * f.quantity;
        futuresUnrealizedPnl += pnl;
      }
    }

    final totalNetWorth = cashBalance + spotValuation + (futuresMargin + futuresUnrealizedPnl).clamp(0.0, double.infinity);

    // Anomalies check
    final hasHighLeverage = futures.any((f) => f.leverage >= 50);
    final hasLargeTrades = trades.any((t) => t.price * t.quantity >= 100000);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141A21),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isBanned ? AppColors.loss : const Color(0xFF2B3139),
                        width: isBanned ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF2B3139),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isBanned
                                              ? AppColors.loss.withValues(alpha: 0.2)
                                              : AppColors.profit.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isBanned ? 'BANNED' : 'ACTIVE',
                                          style: TextStyle(
                                            color: isBanned ? AppColors.loss : AppColors.profit,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    email,
                                    style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: publicUid));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Public UID copied')),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E2329),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF2B3139)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.fingerprint, color: Color(0xFFF59E0B), size: 13),
                                              const SizedBox(width: 4),
                                              Text(
                                                publicUid,
                                                style: const TextStyle(
                                                  color: Color(0xFFF59E0B),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.copy, color: Colors.white38, size: 10),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (_foundDocId != null)
                                        GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: _foundDocId!));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Firebase UID copied')),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E2329),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF2B3139)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.key, color: Colors.white54, size: 12),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _foundDocId!.length > 8
                                                      ? '${_foundDocId!.substring(0, 8)}...'
                                                      : _foundDocId!,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.copy, color: Colors.white38, size: 10),
                                              ],
                                            ),
                                          ),
                                        ),
                                      Text(
                                        '🔥 $streak',
                                        style: const TextStyle(
                                          color: Color(0xFFF59E0B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '• $xp XP',
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isBanned && banReason.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.loss.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.gavel, color: AppColors.loss, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Reason: $banReason',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Builder(
                                  builder: (_) {
                                    final rawBannedAt = _userData!['bannedAt'] ?? profile['bannedAt'];
                                    DateTime? bAt;
                                    if (rawBannedAt is Timestamp) {
                                      bAt = rawBannedAt.toDate();
                                    } else if (rawBannedAt != null) {
                                      bAt = DateTime.tryParse(rawBannedAt.toString());
                                    }
                                    final isExpired = BanManager.isBanExpired(bAt);
                                    final rem = BanManager.getRemainingTimeDescription(bAt);
                                    return Text(
                                      isExpired
                                          ? '⚠️ 10-day retention expired. Account eligible for auto-deletion.'
                                          : '⏱️ Auto-delete in: $rem (10-day policy)',
                                      style: TextStyle(
                                        color: isExpired ? AppColors.loss : const Color(0xFFF59E0B),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Direct Ban / Unban Button
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: isBanned
                              ? ElevatedButton.icon(
                                  onPressed: _isTogglingBan ? null : () => _showBanToggleDialog(ban: false),
                                  icon: _isTogglingBan
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                      : const Icon(Icons.check_circle_outline_rounded, size: 18),
                                  label: const Text(
                                    'UNBAN USER / RESTORE ACCESS',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.profit,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                )
                              : OutlinedButton.icon(
                                  onPressed: _isTogglingBan ? null : () => _showBanToggleDialog(ban: true),
                                  icon: _isTogglingBan
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.loss))
                                      : const Icon(Icons.gavel_rounded, size: 18),
                                  label: const Text(
                                    'BAN USER ACCOUNT',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.loss,
                                    side: const BorderSide(color: AppColors.loss),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Risk / Unusual Activity Flags
                  if (hasHighLeverage || hasLargeTrades) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Risk Signals Detected',
                                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (hasHighLeverage)
                            const Text('• User has positions with >= 50x leverage.', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                          if (hasLargeTrades)
                            const Text('• Large volume trade execution detected (>= \$100k equivalent).', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Financial Net Worth Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141A21),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2B3139)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL NET WORTH',
                          style: TextStyle(color: Color(0xFF848E9C), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatter.format(totalNetWorth),
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Cash Balance',
                                value: formatter.format(cashBalance),
                                color: Colors.white,
                              ),
                            ),
                            Container(width: 1, height: 28, color: const Color(0xFF2B3139)),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Spot Value',
                                value: formatter.format(spotValuation),
                                color: AppColors.profit,
                              ),
                            ),
                            Container(width: 1, height: 28, color: const Color(0xFF2B3139)),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Futures Margin',
                                value: formatter.format(futuresMargin),
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFF59E0B),
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF848E9C),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                tabs: [
                  Tab(text: 'Spot (${holdings.length})'),
                  Tab(text: 'Futures (${futures.length})'),
                  Tab(text: 'Trades (${trades.length})'),
                  Tab(text: 'Wallet (${walletEntries.length})'),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Spot Holdings ──────────────────────────────────────────
          _buildSpotTab(holdings, market, formatter),

          // ── Tab 2: Futures Positions ──────────────────────────────────────
          _buildFuturesTab(futures, market, formatter),

          // ── Tab 3: Recent Trades ──────────────────────────────────────────
          _buildTradesTab(trades, formatter),

          // ── Tab 4: Wallet Log ─────────────────────────────────────────────
          _buildWalletTab(walletEntries, formatter),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF848E9C), fontSize: 10.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSpotTab(List<Holding> holdings, List<Stock> market, AppCurrencyFormatter formatter) {
    if (holdings.isEmpty) {
      return _buildEmptyState('No Spot Holdings', 'This user currently has 0 coins in their spot portfolio.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: holdings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final h = holdings[index];
        final stock = market.cast<Stock?>().firstWhere((s) => s?.symbol == h.symbol, orElse: () => null);
        final currentPrice = stock?.currentPrice ?? h.averagePrice;
        final totalValue = currentPrice * h.quantity;
        final costBasis = h.averagePrice * h.quantity;
        final pnl = totalValue - costBasis;
        final pnlPct = costBasis > 0 ? (pnl / costBasis) * 100 : 0.0;
        final isProfit = pnl >= 0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141A21),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B3139)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1E2329),
                child: Text(
                  h.symbol.isNotEmpty ? h.symbol.substring(0, h.symbol.length > 3 ? 3 : h.symbol.length) : '?',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.symbol,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qty: ${h.quantity} • Avg: ${formatter.format(h.averagePrice)}',
                      style: const TextStyle(color: Color(0xFF848E9C), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(totalValue),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${isProfit ? '+' : ''}${pnlPct.toStringAsFixed(2)}% (${isProfit ? '+' : ''}${formatter.format(pnl)})',
                    style: TextStyle(
                      color: isProfit ? AppColors.profit : AppColors.loss,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFuturesTab(List<FuturesPosition> futures, List<Stock> market, AppCurrencyFormatter formatter) {
    if (futures.isEmpty) {
      return _buildEmptyState('No Open Futures Positions', 'This user has no active leveraged positions.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: futures.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final f = futures[index];
        final stock = market.cast<Stock?>().firstWhere((s) => s?.symbol == f.symbol, orElse: () => null);
        final markPrice = stock?.currentPrice ?? f.entryPrice;
        final isLong = f.side == OrderSide.buy;
        final diff = markPrice - f.entryPrice;
        final pnl = isLong ? diff * f.quantity : -diff * f.quantity;
        final roe = f.margin > 0 ? (pnl / f.margin) * 100 : 0.0;
        final isProfit = pnl >= 0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141A21),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: f.leverage >= 50 ? Colors.amber.withValues(alpha: 0.5) : const Color(0xFF2B3139),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLong ? AppColors.profit.withValues(alpha: 0.15) : AppColors.loss.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isLong ? 'LONG' : 'SHORT',
                      style: TextStyle(
                        color: isLong ? AppColors.profit : AppColors.loss,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    f.symbol,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${f.leverage}x',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${isProfit ? '+' : ''}${roe.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isProfit ? AppColors.profit : AppColors.loss,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubStat('Entry Price', formatter.format(f.entryPrice)),
                  _buildSubStat('Mark Price', formatter.format(markPrice)),
                  _buildSubStat('Margin', formatter.format(f.margin)),
                  _buildSubStat(
                    'PnL',
                    '${isProfit ? '+' : ''}${formatter.format(pnl)}',
                    color: isProfit ? AppColors.profit : AppColors.loss,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Liq. Price: ${formatter.format(f.liquidationPrice)} • Size: ${f.quantity.toStringAsFixed(4)}',
                style: const TextStyle(color: Color(0xFF848E9C), fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTradesTab(List<Trade> trades, AppCurrencyFormatter formatter) {
    if (trades.isEmpty) {
      return _buildEmptyState('No Recent Trades', 'This user has not executed any trades yet.');
    }

    final sorted = List<Trade>.from(trades)..sort((a, b) => b.time.compareTo(a.time));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final t = sorted[index];
        final isBuy = t.side == OrderSide.buy;
        final total = t.price * t.quantity;
        final timeStr = DateFormat('dd MMM yyyy, HH:mm').format(t.time.toLocal());

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141A21),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B3139)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isBuy ? AppColors.profit.withValues(alpha: 0.15) : AppColors.loss.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBuy ? Icons.call_made_rounded : Icons.call_received_rounded,
                  color: isBuy ? AppColors.profit : AppColors.loss,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isBuy ? 'BUY' : 'SELL',
                          style: TextStyle(
                            color: isBuy ? AppColors.profit : AppColors.loss,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t.symbol,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: const TextStyle(color: Color(0xFF848E9C), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(total),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${t.quantity} @ ${formatter.format(t.price)}',
                    style: const TextStyle(color: Color(0xFF848E9C), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWalletTab(List<Map<String, dynamic>> walletEntries, AppCurrencyFormatter formatter) {
    if (walletEntries.isEmpty) {
      return _buildEmptyState('No Wallet Activity', 'This user has no recorded wallet transactions.');
    }

    final entries = List<Map<String, dynamic>>.from(walletEntries).reversed.toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final e = entries[index];
        final title = (e['title'] as String?) ?? 'Transaction';
        final subtitle = (e['subtitle'] as String?) ?? '';
        final amount = (e['amount'] as num?)?.toDouble() ?? 0.0;
        final type = (e['type'] as String?) ?? 'credit';
        final isCredit = type == 'credit';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141A21),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B3139)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCredit ? AppColors.profit.withValues(alpha: 0.15) : AppColors.loss.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: isCredit ? AppColors.profit : AppColors.loss,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF848E9C), fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${isCredit ? '+' : '-'}${formatter.format(amount.abs())}',
                style: TextStyle(
                  color: isCredit ? AppColors.profit : AppColors.loss,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF848E9C), fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color ?? Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded, color: Color(0xFF5E6673), size: 40),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF141A21),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
