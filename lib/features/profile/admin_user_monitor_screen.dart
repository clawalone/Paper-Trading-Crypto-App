import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../core/ban_manager.dart';
import '../../core/portfolio_audit_engine.dart';
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
  bool _isAuditing = false;
  bool _isTogglingBan = false;
  bool _copiedReport = false;
  String? _foundDocId;
  Map<String, dynamic>? _userData;
  UserState? _parsedUserState;
  PortfolioAuditResult? _auditResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      _auditResult = null;
      _isAuditing = false;
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
          final parsed = _safeParseUserState(data);
          setState(() {
            _foundDocId = directDoc.id;
            _userData = data;
            _parsedUserState = parsed;
            _isSearching = false;
          });
          _runAuditForUser(data, directDoc.id, parsed);
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
        final parsed = _safeParseUserState(data);
        setState(() {
          _foundDocId = doc.id;
          _userData = data;
          _parsedUserState = parsed;
          _isSearching = false;
        });
        _runAuditForUser(data, doc.id, parsed);
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

  Future<void> _runAuditForUser(Map<String, dynamic> data, String docId, UserState? parsed) async {
    setState(() => _isAuditing = true);
    final market = ref.read(marketProvider);
    final result = await PortfolioAuditEngine.auditUser(
      userDocId: docId,
      rawUserData: data,
      parsedUserState: parsed,
      market: market,
    );
    if (mounted) {
      setState(() {
        _auditResult = result;
        _isAuditing = false;
      });
    }
  }

  void _copyAuditReportToClipboard() {
    if (_auditResult == null) return;
    Clipboard.setData(ClipboardData(text: _auditResult!.formattedReportText));
    setState(() => _copiedReport = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copiedReport = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Forensic Exploit Report copied to clipboard'),
        backgroundColor: AppColors.profit,
      ),
    );
  }

  Future<void> _showResetAccountDialog() async {
    if (_foundDocId == null || _userData == null) return;
    final profile = Map<String, dynamic>.from((_userData!['profile'] as Map?) ?? {});
    final userName = profile['name']?.toString() ?? 'Trader';
    final initialReason = _auditResult?.prefilledResetReason ??
        'Account reset due to exploitation of system glitch. All positions, holdings, and balances have been restored to initial fair starting capital (\$5,000.00).';
    final reasonController = TextEditingController(text: initialReason);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2329),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 10),
            Text(
              'Reset User Account',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset "$userName" back to legitimate starting state?\n\n• Virtual Balance will be reset to \$5,000.00.\n• All active futures positions, spot holdings, and open limit orders will be cleared.\n• The user will see a mandatory "Account Reset Notice" screen on their next launch explaining this reason.',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            const Text(
              'REASON FOR RESET (SHOWN TO USER):',
              style: TextStyle(color: Color(0xFF848E9C), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter reason for account reset...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF14171A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
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
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
            ),
            child: const Text('Confirm Reset', style: TextStyle(fontWeight: FontWeight.bold)),
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
          : 'Account reset due to platform policy and fair play enforcement.';

      profile['virtualBalance'] = 5000.0;
      profile['isBanned'] = false;
      profile['banReason'] = null;
      profile['resetNotice'] = {
        'reason': reason,
        'resetAt': DateTime.now().toIso8601String(),
        'acknowledged': false,
      };

      final resetWalletEntry = {
        'title': 'Account Reset by Admin',
        'subtitle': reason,
        'amount': 5000.0,
        'type': 'credit',
        'category': 'admin_reset',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final currentWallet = (_userData!['walletEntries'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      currentWallet.add(resetWalletEntry);

      await docRef.update({
        'profile.virtualBalance': 5000.0,
        'profile.isBanned': false,
        'profile.banReason': null,
        'profile.resetNotice': profile['resetNotice'],
        'resetNotice': profile['resetNotice'],
        'isBanned': false,
        'banReason': null,
        'futuresPositions': [],
        'holdings': [],
        'spotLimitOrders': [],
        'futuresLimitOrders': [],
        'walletEntries': currentWallet,
      });

      await docRef.collection('notifications').add({
        'userId': _foundDocId,
        'title': 'Account Reset Notice ⚙️',
        'message': reason,
        'category': 'system',
        'type': 'announcement',
        'createdAt': DateTime.now().toIso8601String(),
        'isRead': false,
        'data': {'type': 'reset'},
      });

      setState(() {
        _isTogglingBan = false;
        _userData!['profile'] = profile;
        _userData!['isBanned'] = false;
        _userData!['banReason'] = null;
        _userData!['futuresPositions'] = [];
        _userData!['holdings'] = [];
        _userData!['spotLimitOrders'] = [];
        _userData!['futuresLimitOrders'] = [];
        _userData!['walletEntries'] = currentWallet;
        _parsedUserState = _safeParseUserState(_userData!);
      });

      if (_foundDocId != null) {
        _runAuditForUser(_userData!, _foundDocId!, _parsedUserState);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "$userName" has been reset to \$5,000.00. Notice sent!'),
            backgroundColor: AppColors.profit,
          ),
        );
      }
    } catch (e) {
      setState(() => _isTogglingBan = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset Failed: $e'), backgroundColor: AppColors.loss),
        );
      }
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
    final initialReason = (ban && _auditResult?.prefilledBanReason != null)
        ? _auditResult!.prefilledBanReason!
        : '';
    final reasonController = TextEditingController(text: initialReason);

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
                                  _auditResult = null;
                                  _isAuditing = false;
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

                  // ── Comprehensive Forensic Audit & Anti-Cheat Verdict Banner ──
                  _buildAuditVerdictBanner(market, formatter),
                  const SizedBox(height: 12),

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
                isScrollable: true,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _auditResult?.verdict == AuditVerdict.cheaterConfirmed
                              ? Icons.error_rounded
                              : _auditResult?.verdict == AuditVerdict.highLeverageLucky
                                  ? Icons.rocket_launch_rounded
                                  : Icons.verified_user_rounded,
                          size: 13,
                          color: _auditResult?.verdict == AuditVerdict.cheaterConfirmed
                              ? AppColors.loss
                              : _auditResult?.verdict == AuditVerdict.highLeverageLucky
                                  ? const Color(0xFF38BDF8)
                                  : AppColors.profit,
                        ),
                        const SizedBox(width: 4),
                        const Text('Audit Verdict'),
                      ],
                    ),
                  ),
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
          // ── Tab 0: Forensic Audit & Anti-Cheat Breakdown ──────────────────
          _buildAuditTab(_auditResult, formatter),

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

  Widget _buildAuditVerdictBanner(List<Stock> market, AppCurrencyFormatter formatter) {
    if (_isAuditing) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141A21),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFF59E0B)),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Running Deep Forensic Anti-Cheat Audit...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Reconciling ledger, auditing holdings vs trade history, verifying 100x leverage margins...',
                    style: TextStyle(color: Color(0xFF848E9C), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_auditResult == null) return const SizedBox.shrink();

    final result = _auditResult!;
    final isCheater = result.verdict == AuditVerdict.cheaterConfirmed;
    final isLucky100x = result.verdict == AuditVerdict.highLeverageLucky;
    final isWarning = result.verdict == AuditVerdict.warning;

    Color themeColor;
    IconData icon;
    String badgeText;

    if (isCheater) {
      themeColor = AppColors.loss;
      icon = Icons.dangerous_rounded;
      badgeText = 'CRITICAL CHEAT / EXPLOIT';
    } else if (isLucky100x) {
      themeColor = const Color(0xFF38BDF8); // vibrant cyan
      icon = Icons.rocket_launch_rounded;
      badgeText = '100x LUCKY (NOT CHEATING)';
    } else if (isWarning) {
      themeColor = Colors.amber;
      icon = Icons.warning_amber_rounded;
      badgeText = 'DATA VARIANCE';
    } else {
      themeColor = AppColors.profit;
      icon = Icons.verified_user_rounded;
      badgeText = '100% VERIFIED AUTHENTIC';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeColor.withValues(alpha: isCheater ? 0.9 : 0.4),
          width: isCheater ? 2 : 1.2,
        ),
        boxShadow: isCheater
            ? [
                BoxShadow(
                  color: AppColors.loss.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top banner header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(icon, color: themeColor, size: 20),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
                  tooltip: 'Re-run Forensic Audit',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (_userData != null && _foundDocId != null) {
                      _runAuditForUser(_userData!, _foundDocId!, _parsedUserState);
                    }
                  },
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.copy_all_rounded, color: Colors.white54, size: 18),
                  tooltip: 'Copy Forensic Report',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _copyAuditReportToClipboard,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.verdictTitle,
                  style: TextStyle(
                    color: themeColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.verdictDescription,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 12),

                // Reconciled vs Stated metric row
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2329),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('STATED CASH', style: TextStyle(color: Color(0xFF848E9C), fontSize: 9.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(formatter.format(result.statedCash), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: const Color(0xFF2B3139)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AUDITED LEDGER', style: TextStyle(color: Color(0xFF848E9C), fontSize: 9.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(formatter.format(result.reconciledCash), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: const Color(0xFF2B3139)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DISCREPANCY', style: TextStyle(color: Color(0xFF848E9C), fontSize: 9.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              result.cashDiscrepancy.abs() <= 150
                                  ? 'Balanced (\$0)'
                                  : '${result.cashDiscrepancy > 0 ? "+" : ""}${formatter.format(result.cashDiscrepancy)}',
                              style: TextStyle(
                                color: result.cashDiscrepancy > 150 ? AppColors.loss : AppColors.profit,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Highlight critical flags if cheater
                if (result.criticalFlags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.loss.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.loss.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CRITICAL EVIDENCE OF EXPLOIT / CHEATING:',
                          style: TextStyle(color: AppColors.loss, fontWeight: FontWeight.w800, fontSize: 10.5),
                        ),
                        const SizedBox(height: 4),
                        for (final flag in result.criticalFlags)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('❌ ', style: TextStyle(fontSize: 11)),
                                Expanded(
                                  child: Text(
                                    flag,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Highlight 100x leverage legitimacy explanation if lucky trader
                if (isLucky100x && result.positiveNotes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'LEVERAGE VERIFICATION (NOT CHEATING):',
                              style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w800, fontSize: 10.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        for (final note in result.positiveNotes)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('⚡ ', style: TextStyle(fontSize: 11)),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                // Action Buttons Row: View Audit, Reset Account, Ban Account
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _tabController.animateTo(0);
                        },
                        icon: const Icon(Icons.analytics_outlined, size: 14),
                        label: const Text('View Full Audit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF2B3139)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    if (isCheater || result.cashDiscrepancy.abs() > 150) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTogglingBan ? null : _showResetAccountDialog,
                          icon: const Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFFF59E0B)),
                          label: const Text('Reset', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTogglingBan ? null : () => _showBanToggleDialog(ban: true),
                          icon: const Icon(Icons.gavel_rounded, size: 14),
                          label: const Text('Ban', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.loss,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTab(PortfolioAuditResult? audit, AppCurrencyFormatter formatter) {
    if (_isAuditing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFF59E0B)),
            SizedBox(height: 16),
            Text(
              'Running Deep Forensic Audit...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Verifying all spot trades, futures margin deductions,\ncoin inventory, and ledger reconciliation...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF848E9C), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (audit == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security_rounded, color: Color(0xFF5E6673), size: 40),
            const SizedBox(height: 12),
            const Text('No Audit Data', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                if (_userData != null && _foundDocId != null) {
                  _runAuditForUser(_userData!, _foundDocId!, _parsedUserState);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
              ),
              child: const Text('Start Forensic Audit'),
            ),
          ],
        ),
      );
    }

    final isLucky = audit.verdict == AuditVerdict.highLeverageLucky;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 1. Executive Verdict & Action Decision Panel ───────────────────
        _buildDecisionCard(audit, formatter),
        const SizedBox(height: 16),

        // ── 2. Exactly What The User Did Wrong (Root Cause Analysis) ───────
        if (audit.rootCauseAnalysis != null) ...[
          _buildAuditSectionTitle('1. Exactly What The User Did Wrong (Root Cause Analysis)'),
          const SizedBox(height: 8),
          _buildRootCauseCard(audit.rootCauseAnalysis!, formatter),
          const SizedBox(height: 16),
        ],

        // ── 3. Forensic Evidence Copy Box ──────────────────────────────────
        _buildAuditSectionTitle('2. Forensic Evidence Copy Box'),
        const SizedBox(height: 8),
        _buildCopyBoxCard(audit),
        const SizedBox(height: 16),

        // ── 4. Chronological Forensic Timeline ─────────────────────────────
        _buildAuditSectionTitle('3. Chronological Forensic Timeline of Exploit & Events'),
        const SizedBox(height: 8),
        _buildForensicTimelineCard(audit.forensicTimeline, formatter),
        const SizedBox(height: 16),

        // ── 5. Holdings vs Trade History Inventory Check ──────────────────
        _buildAuditSectionTitle('4. Coin Holdings vs Trade History (Ghost Check)'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141A21),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2B3139)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cross-checks every coin in the user portfolio against their historical buy and sell trades. Flags any "ghost coins" added without purchases.',
                style: TextStyle(color: Color(0xFF848E9C), fontSize: 11.5, height: 1.3),
              ),
              const SizedBox(height: 12),
              if (audit.holdingDetails.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('User holds no crypto coins (Clean spot inventory).', style: TextStyle(color: Colors.white70, fontSize: 12)),
                )
              else
                for (final d in audit.holdingDetails.values) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2329),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: d.isGhost
                            ? AppColors.loss
                            : d.isOversold
                                ? Colors.amber
                                : AppColors.profit.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              d.symbol,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (d.isGhost ? AppColors.loss : d.isOversold ? Colors.amber : AppColors.profit).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                d.isGhost
                                    ? 'GHOST HOLDING (+${d.statedQuantity - d.expectedQty})'
                                    : d.isOversold
                                        ? 'OVERSOLD'
                                        : 'VERIFIED MATCH',
                                style: TextStyle(
                                  color: d.isGhost ? AppColors.loss : d.isOversold ? Colors.amber : AppColors.profit,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMiniAuditStat('Stated Qty', '${d.statedQuantity}'),
                            _buildMiniAuditStat('Bought Qty', '+${d.totalBoughtQty}'),
                            _buildMiniAuditStat('Sold Qty', '-${d.totalSoldQty}'),
                            _buildMiniAuditStat('Expected Qty', '${d.expectedQty}'),
                          ],
                        ),
                        if (d.isGhost || d.isOversold) ...[
                          const SizedBox(height: 6),
                          Text(
                            d.statusMessage,
                            style: TextStyle(
                              color: d.isGhost ? AppColors.loss : Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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
        const SizedBox(height: 16),

        // ── 6. Ledger Math & Cash Flow Accounting ──────────────────────────
        _buildAuditSectionTitle('5. Cash Ledger & Flow Accounting'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141A21),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2B3139)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reconstructs exact virtual cash balance starting from \$5,000 baseline by applying every buy/sell trade and wallet debit/credit.',
                style: TextStyle(color: Color(0xFF848E9C), fontSize: 11.5, height: 1.3),
              ),
              const SizedBox(height: 12),
              _buildLedgerRow('Initial Onboarding Capital', formatter.format(5000), isPositive: true),
              _buildLedgerRow('Audited Reconciled Balance', formatter.format(audit.reconciledCash), isBold: true),
              _buildLedgerRow('Stated User Profile Balance', formatter.format(audit.statedCash), isBold: true),
              const Divider(color: Color(0xFF2B3139), height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discrepancy (Phantom Balance):', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(
                    audit.cashDiscrepancy.abs() <= 150
                        ? 'Balanced (\$0.00)'
                        : '${audit.cashDiscrepancy > 0 ? "+" : ""}${formatter.format(audit.cashDiscrepancy)}',
                    style: TextStyle(
                      color: audit.cashDiscrepancy > 150 ? AppColors.loss : AppColors.profit,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (audit.cashDiscrepancy > 150) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.loss.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '⚠️ Cash Injection Detected: User holds +${formatter.format(audit.cashDiscrepancy)} that never originated from any recorded trade, daily reward, or top-up.',
                    style: const TextStyle(color: AppColors.loss, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 7. 100x Leverage Validation (Luck vs Bug Audit) ─────────────────
        _buildAuditSectionTitle('6. 100x Leverage & Futures Audit (Luck vs Cheating)'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141A21),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLucky
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
                  : const Color(0xFF2B3139),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isLucky ? Icons.rocket_launch_rounded : Icons.info_outline,
                    color: isLucky ? const Color(0xFF38BDF8) : const Color(0xFF848E9C),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'High Leverage Policy & Rule Verification',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Many traders get lucky with 100x leverage and win huge multipliers. This is NOT considered cheating as long as:\n• Margin was legitimately deducted from their balance.\n• Leverage stayed <= 100x.\n• Price action and PnL adhere to the mathematical formula.\n• The position did not survive past liquidation price.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2329),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      audit.hasHighLeverage ? Icons.check_circle_rounded : Icons.remove_circle_outline,
                      color: audit.hasHighLeverage ? const Color(0xFF38BDF8) : const Color(0xFF848E9C),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        audit.hasHighLeverage
                            ? (audit.isLeverageLegitimate
                                ? 'Status: 100x Leverage Verified & Legitimate (High-Risk Luck, Not Cheating)'
                                : 'Status: Irregular / Bugged Leverage Activity Detected')
                            : 'Status: Standard Leverage Usage (< 50x)',
                        style: TextStyle(
                          color: audit.hasHighLeverage ? Colors.white : const Color(0xFF848E9C),
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 8. Detailed 10-Point Checklist ─────────────────────────────────
        _buildAuditSectionTitle('7. Full 10-Point Forensic Checklist'),
        const SizedBox(height: 8),
        for (final item in audit.checks) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141A21),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.isFailed
                    ? AppColors.loss
                    : item.isWarning
                        ? Colors.amber
                        : const Color(0xFF2B3139),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.isFailed
                      ? Icons.cancel_rounded
                      : item.isWarning
                          ? Icons.warning_rounded
                          : Icons.check_circle_rounded,
                  color: item.isFailed
                      ? AppColors.loss
                      : item.isWarning
                          ? Colors.amber
                          : AppColors.profit,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2329),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category.toUpperCase(),
                              style: const TextStyle(color: Color(0xFF848E9C), fontSize: 9, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.summary,
                        style: TextStyle(
                          color: item.isFailed ? AppColors.loss : Colors.white70,
                          fontSize: 11.5,
                          fontWeight: item.isFailed ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (item.details != null && item.details!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.details!,
                          style: const TextStyle(color: Color(0xFF848E9C), fontSize: 11, height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Copy Forensic Report Button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _copyAuditReportToClipboard,
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('COPY FULL FORENSIC REPORT TO CLIPBOARD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2329),
              foregroundColor: const Color(0xFFF59E0B),
              side: const BorderSide(color: Color(0xFF2B3139)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDecisionCard(PortfolioAuditResult audit, AppCurrencyFormatter formatter) {
    final isCheater = audit.verdict == AuditVerdict.cheaterConfirmed;
    final isLucky = audit.verdict == AuditVerdict.highLeverageLucky;
    final rca = audit.rootCauseAnalysis;
    final isUserBanned = _userData?['isBanned'] == true ||
        ((_userData?['profile'] as Map?)?['isBanned'] == true);

    final themeColor = isCheater
        ? AppColors.loss
        : isLucky
            ? const Color(0xFF38BDF8)
            : audit.verdict == AuditVerdict.warning
                ? Colors.amber
                : AppColors.profit;

    final recommendedDecision = rca?.recommendedDecision ?? (isCheater ? 'BAN' : 'PASS');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCheater
                      ? Icons.gavel_rounded
                      : isLucky
                          ? Icons.rocket_launch_rounded
                          : Icons.verified_rounded,
                  color: themeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audit.verdictTitle,
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Audited: ${DateFormat('dd MMM yyyy, HH:mm:ss').format(audit.auditedAt)}',
                      style: const TextStyle(color: Color(0xFF848E9C), fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isUserBanned ? AppColors.loss : AppColors.profit).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isUserBanned ? AppColors.loss : AppColors.profit).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUserBanned ? Icons.lock_rounded : Icons.check_circle_rounded,
                      size: 12,
                      color: isUserBanned ? AppColors.loss : AppColors.profit,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isUserBanned ? 'CURRENTLY BANNED' : 'ACCOUNT ACTIVE',
                      style: TextStyle(
                        color: isUserBanned ? AppColors.loss : AppColors.profit,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            audit.verdictDescription,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2329),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2B3139)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.recommend_rounded, color: Color(0xFFF59E0B), size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'VERDICT RECOMMENDATION: ${recommendedDecision.toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rca?.decisionRationale ?? audit.recommendedAction,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Decision Buttons: Ban Account, Reset Account
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isTogglingBan ? null : () => _showBanToggleDialog(ban: !isUserBanned),
                  icon: Icon(
                    isUserBanned ? Icons.lock_open_rounded : Icons.gavel_rounded,
                    size: 15,
                  ),
                  label: Text(
                    isUserBanned ? 'Lift Ban' : 'Ban Account',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUserBanned ? AppColors.profit : AppColors.loss,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isTogglingBan ? null : _showResetAccountDialog,
                  icon: const Icon(Icons.restart_alt_rounded, size: 15),
                  label: const Text(
                    'Reset Account (\$5k)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRootCauseCard(ExploitRootCauseAnalysis rca, AppCurrencyFormatter formatter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.loss.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.loss.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.loss.withValues(alpha: 0.4)),
                ),
                child: Text(
                  rca.classification,
                  style: const TextStyle(
                    color: AppColors.loss,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (rca.unbackedCapitalGenerated > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.loss.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Unbacked Windfall: +${formatter.format(rca.unbackedCapitalGenerated)}',
                    style: const TextStyle(
                      color: AppColors.loss,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'DETAILED ROOT CAUSE & BEHAVIORAL ANALYSIS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rca.summary,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          const Text(
            'STEP-BY-STEP EXPLOIT SEQUENCE:',
            style: TextStyle(
              color: Color(0xFF848E9C),
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < rca.steps.length; i++) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2329),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2B3139)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.loss.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppColors.loss,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rca.steps[i],
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.profit.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.profit.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: AppColors.profit, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vulnerability Patch Applied: Market orders execute strictly at current asset price; limit orders are placed into pending orders book.',
                    style: TextStyle(color: AppColors.profit, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyBoxCard(PortfolioAuditResult audit) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, color: Color(0xFF58A6FF), size: 16),
                const SizedBox(width: 8),
                const Text(
                  'EXPLOIT EVIDENCE COPY BOX',
                  style: TextStyle(
                    color: Color(0xFFC9D1D9),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _copyAuditReportToClipboard,
                  icon: Icon(
                    _copiedReport ? Icons.check_rounded : Icons.copy_rounded,
                    size: 13,
                  ),
                  label: Text(
                    _copiedReport ? 'Copied!' : 'Copy Evidence',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _copiedReport ? AppColors.profit : const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: SelectableText(
                audit.formattedReportText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFE6EDF3),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForensicTimelineCard(List<ForensicTimelineEvent> events, AppCurrencyFormatter formatter) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141A21),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2B3139)),
        ),
        child: const Text(
          'No historical trades or position events found on record for this account.',
          style: TextStyle(color: Color(0xFF848E9C), fontSize: 12),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2B3139)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 8),
              const Text(
                'RECONSTRUCTED TIMELINE LOG',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '${events.length} Events Logged',
                style: const TextStyle(color: Color(0xFF848E9C), fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < events.length; i++)
            _buildTimelineEntry(events[i], isLast: i == events.length - 1),
        ],
      ),
    );
  }

  Widget _buildTimelineEntry(ForensicTimelineEvent e, {required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: e.isExploit ? AppColors.loss : const Color(0xFF38BDF8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: const Color(0xFF2B3139),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2329),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: e.isExploit
                    ? AppColors.loss.withValues(alpha: 0.6)
                    : const Color(0xFF2B3139),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (e.isExploit ? AppColors.loss : const Color(0xFF38BDF8)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        e.isExploit ? 'EXPLOIT ACTION' : 'NORMAL ACTIVITY',
                        style: TextStyle(
                          color: e.isExploit ? AppColors.loss : const Color(0xFF38BDF8),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(e.timestamp),
                      style: const TextStyle(color: Color(0xFF848E9C), fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${e.action} ${e.symbol.isNotEmpty ? "(${e.symbol})" : ""}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (e.financialImpact.isNotEmpty)
                      Text(
                        e.financialImpact,
                        style: TextStyle(
                          color: e.isExploit ? AppColors.loss : AppColors.profit,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  e.details,
                  style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuditSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF848E9C),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildMiniAuditStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF848E9C), fontSize: 9.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
      ],
    );
  }

  Widget _buildLedgerRow(String label, String value, {bool isPositive = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? Colors.white : Colors.white70, fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: isPositive ? AppColors.profit : Colors.white, fontSize: 12, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700)),
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
