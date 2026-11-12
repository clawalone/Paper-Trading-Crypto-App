import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../data/user_provider.dart';

class AdminTopUpsScreen extends ConsumerStatefulWidget {
  const AdminTopUpsScreen({super.key});

  @override
  ConsumerState<AdminTopUpsScreen> createState() => _AdminTopUpsScreenState();
}

class _AdminTopUpsScreenState extends ConsumerState<AdminTopUpsScreen> {
  String _filterMethod = 'All'; // 'All', 'google_play', 'admin'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _userNameCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate().toLocal();
    if (val is String) {
      final parsed = DateTime.tryParse(val);
      return parsed?.toLocal();
    }
    return null;
  }

  Future<String> _fetchUserName(String uid, String requesterId) async {
    if (_userNameCache.containsKey(uid)) return _userNameCache[uid]!;
    try {
      if (requesterId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(requesterId).get();
        if (doc.exists && doc.data() != null) {
          final profile = doc.data()!['profile'] as Map<String, dynamic>?;
          final name = profile?['name'] as String?;
          if (name != null && name.isNotEmpty) {
            _userNameCache[uid] = name;
            return name;
          }
        }
      }

      if (uid.isNotEmpty) {
        final qs = await FirebaseFirestore.instance
            .collection('users')
            .where('profile.publicUid', isEqualTo: uid)
            .limit(1)
            .get();
        if (qs.docs.isNotEmpty) {
          final profile = qs.docs.first.data()['profile'] as Map<String, dynamic>?;
          final name = profile?['name'] as String?;
          if (name != null && name.isNotEmpty) {
            _userNameCache[uid] = name;
            return name;
          }
        }
      }
    } catch (_) {}

    _userNameCache[uid] = 'Trader';
    return 'Trader';
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Admin: User Top-Ups',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('money_requests')
            .where('status', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading top-ups: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.loss)),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          // Convert and sort documents descending by timestamp
          final docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final dtA = _parseDate(dataA['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dtB = _parseDate(dataB['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dtB.compareTo(dtA);
          });

          // Calculate Analytics summary
          double totalInrRevenue = 0.0;
          double totalVirtualCapital = 0.0;
          int iapCount = 0;

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final inr = (data['inrAmount'] as num?)?.toDouble() ?? 0.0;
            final virt = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final method = (data['paymentMethod'] as String? ?? '').toLowerCase();

            totalInrRevenue += inr;
            totalVirtualCapital += virt;
            if (method.contains('play') || method.contains('iap') || inr > 0) {
              iapCount++;
            }
          }

          // Apply search and category filter
          final filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final uid = (data['requesterUid'] as String? ?? '').toLowerCase();
            final name = (data['requesterName'] as String? ?? data['userName'] as String? ?? data['name'] as String? ?? '').toLowerCase();
            final pid = (data['paymentId'] as String? ?? '').toLowerCase();
            final reason = (data['reason'] as String? ?? '').toLowerCase();
            final method = (data['paymentMethod'] as String? ?? '').toLowerCase();

            final matchesQuery = _searchQuery.isEmpty ||
                uid.contains(_searchQuery.toLowerCase()) ||
                name.contains(_searchQuery.toLowerCase()) ||
                pid.contains(_searchQuery.toLowerCase()) ||
                reason.contains(_searchQuery.toLowerCase());

            bool matchesFilter = true;
            if (_filterMethod == 'google_play') {
              matchesFilter = method.contains('play') || method.contains('iap') || ((data['inrAmount'] as num?)?.toDouble() ?? 0) > 0;
            } else if (_filterMethod == 'admin') {
              matchesFilter = method.contains('admin') || (!method.contains('play') && !method.contains('iap') && ((data['inrAmount'] as num?)?.toDouble() ?? 0) == 0);
            }

            return matchesQuery && matchesFilter;
          }).toList();

          return CustomScrollView(
            slivers: [
              // Analytics Overview Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header stats grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Real Revenue',
                              value: formatter.format(totalInrRevenue),
                              icon: Icons.payments_rounded,
                              color: AppColors.profit,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Virtual Issued',
                              value: formatter.format(totalVirtualCapital),
                              icon: Icons.account_balance_wallet_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Top-Ups',
                              value: '${docs.length}',
                              icon: Icons.receipt_long_rounded,
                              color: const Color(0xFF818CF8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search by User Name, UID (PT-123456) or Tx ID...',
                          hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF141A21),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All Top-Ups', 'All', docs.length),
                            const SizedBox(width: 8),
                            _buildFilterChip('Play Store IAP', 'google_play', iapCount),
                            const SizedBox(width: 8),
                            _buildFilterChip('Admin Credits', 'admin', docs.length - iapCount),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // List of Top-Ups
              if (filteredDocs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined, color: Color(0xFF4B5563), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No top-ups found matching "$_searchQuery"'
                              : 'No top-up transactions recorded yet.',
                          style: const TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final docId = doc.id;

                        return Dismissible(
                          key: Key(docId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.loss,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_forever_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 6),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await _confirmAndDeleteDoc(docId);
                          },
                          child: _buildTopUpCard(docId, data, formatter),
                        );
                      },
                      childCount: filteredDocs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B3139)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _filterMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _filterMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.18) : const Color(0xFF141A21),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFF2B3139),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : const Color(0xFF9CA3AF),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : const Color(0xFF2B3139),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmAndDeleteDoc(String docId) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141A21),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF2B3139)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.delete_forever_rounded, color: AppColors.loss, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Delete Top-Up Entry?',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: const Text(
                'Are you sure you want to permanently delete this top-up record? This action cannot be undone.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.loss,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirmed) {
      try {
        await FirebaseFirestore.instance.collection('money_requests').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.loss,
              content: Text('Top-up entry deleted successfully.'),
            ),
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete top-up record: $e')),
          );
        }
        return false;
      }
    }

    return false;
  }

  Widget _buildTopUpCard(String docId, Map<String, dynamic> data, AppCurrencyFormatter formatter) {
    final uid = data['requesterUid'] as String? ?? 'Unknown UID';
    final requesterId = data['requesterId'] as String? ?? '';
    final explicitName = data['requesterName'] as String? ?? data['userName'] as String? ?? data['name'] as String?;

    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final inrAmount = (data['inrAmount'] as num?)?.toDouble() ?? 0.0;
    final paymentId = data['paymentId'] as String? ?? '';
    final paymentMethod = (data['paymentMethod'] as String? ?? 'google_play').toLowerCase();
    final reason = data['reason'] as String? ?? 'Virtual Capital Top-Up';
    final previousBalance = (data['previousBalance'] as num?)?.toDouble();
    final newBalance = (data['newBalance'] as num?)?.toDouble();

    final dt = _parseDate(data['createdAt']);
    final dateStr = dt != null ? DateFormat('dd MMM yyyy • hh:mm a').format(dt) : 'Unknown time';

    final isIap = paymentMethod.contains('play') || paymentMethod.contains('iap') || inrAmount > 0;
    final badgeColor = isIap ? AppColors.profit : AppColors.primary;
    final badgeText = isIap ? 'Google Play' : (paymentMethod.contains('admin') ? 'Admin Direct' : 'Approved Request');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B3139)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIap ? Icons.shop_two_rounded : Icons.account_balance_wallet_rounded,
              color: badgeColor,
              size: 20,
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: _buildHeaderTitle(uid, requesterId, explicitName),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User UID copied to clipboard!')),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.copy, size: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${formatter.format(amount)}',
                style: const TextStyle(
                  color: AppColors.profit,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (inrAmount > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Paid ${formatter.format(inrAmount)} Real',
                        style: const TextStyle(
                          color: AppColors.profit,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  dateStr,
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                ),
              ],
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E2329)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Details & Metadata',
                    style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  // Display User Name
                  _buildUserNameDetail(uid, requesterId, explicitName),

                  _buildDetailRow('Reason / Description', reason),
                  if (paymentId.isNotEmpty)
                    _buildDetailRow('Transaction ID', paymentId, isSelectable: true),
                  if (previousBalance != null && newBalance != null)
                    _buildDetailRow(
                      'Balance Change',
                      '${formatter.format(previousBalance)} ➔ ${formatter.format(newBalance)}',
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _confirmAndDeleteDoc(docId),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.loss,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text(
                        'Delete Entry',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTitle(String uid, String requesterId, String? explicitName) {
    if (explicitName != null && explicitName.isNotEmpty) {
      return _buildNameAndUidText(explicitName, uid);
    }
    if (_userNameCache.containsKey(uid)) {
      return _buildNameAndUidText(_userNameCache[uid]!, uid);
    }

    return FutureBuilder<String>(
      future: _fetchUserName(uid, requesterId),
      builder: (context, snapshot) {
        final name = snapshot.data;
        if (name != null && name != 'Trader') {
          return _buildNameAndUidText(name, uid);
        }
        return Text(
          uid,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  Widget _buildNameAndUidText(String name, String uid) {
    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 14),
        children: [
          TextSpan(
            text: name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: ' ($uid)',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildUserNameDetail(String uid, String requesterId, String? explicitName) {
    if (explicitName != null && explicitName.isNotEmpty) {
      return _buildDetailRow('User Name', explicitName);
    }

    if (_userNameCache.containsKey(uid)) {
      return _buildDetailRow('User Name', _userNameCache[uid]!);
    }

    return FutureBuilder<String>(
      future: _fetchUserName(uid, requesterId),
      builder: (context, snapshot) {
        final name = snapshot.data ?? 'Fetching...';
        return _buildDetailRow('User Name', name);
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isSelectable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
          ),
          Expanded(
            child: isSelectable
                ? SelectableText(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                  )
                : Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
          ),
        ],
      ),
    );
  }
}
