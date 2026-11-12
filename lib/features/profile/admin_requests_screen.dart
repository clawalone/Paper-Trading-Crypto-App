import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../data/models.dart';
import '../../data/market_provider.dart';
import '../../data/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminRequestsScreen extends StatelessWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Admin: Money Requests', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('money_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading requests: ${snapshot.error}', style: const TextStyle(color: AppColors.loss)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('No pending requests!', style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final req = MoneyRequest.fromJson(docs[index].data() as Map<String, dynamic>);
              return _AdminRequestCard(request: req, docRef: docs[index].reference);
            },
          );
        },
      ),
    );
  }
}

class _AdminRequestCard extends ConsumerStatefulWidget {
  final MoneyRequest request;
  final DocumentReference docRef;

  const _AdminRequestCard({required this.request, required this.docRef});

  @override
  ConsumerState<_AdminRequestCard> createState() => _AdminRequestCardState();
}

class _AdminRequestCardState extends ConsumerState<_AdminRequestCard> {
  final _msgController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _handleAction(bool approve) async {
    setState(() => _isProcessing = true);
    final msg = _msgController.text.trim();

    try {
      double? prevBalance;
      double? newBalance;
      if (approve) {
        // Find the user document
        final qs = await FirebaseFirestore.instance
            .collection('users')
            .where('profile.publicUid', isEqualTo: widget.request.requesterUid)
            .limit(1)
            .get();

        if (qs.docs.isNotEmpty) {
          final userDoc = qs.docs.first;
          final data = userDoc.data();
          final profileData = data['profile'] as Map<String, dynamic>;
          final currentBalance = (profileData['virtualBalance'] as num?)?.toDouble() ?? 0.0;

          prevBalance = currentBalance;
          newBalance = currentBalance + widget.request.amount;
          profileData['virtualBalance'] = newBalance;

          // Build the wallet entry
          final walletEntry = {
            'title': 'Admin Added Funds',
            'subtitle': widget.request.reason.split('(').first.trim().isNotEmpty
                ? widget.request.reason.split('(').first.trim()
                : 'Approved by admin',
            'amount': widget.request.amount,
            'type': 'credit',
            'category': 'admin_credit',
            'timestamp': DateTime.now().toIso8601String(),
          };

          // Append wallet entry to existing array in the main user doc
          final existingEntries = List<dynamic>.from(data['walletEntries'] as List? ?? []);
          existingEntries.add(walletEntry);

          await userDoc.reference.update({
            'profile': profileData,
            'walletEntries': existingEntries,
          });

          // Deliver notification to requester
          try {
            final userPrefCurrency =
                (profileData['preferredCurrency'] as String?) ?? 'USD';
            final userFormatter =
                AppCurrencyFormatter(userPrefCurrency, decimalDigits: 0);
            final formattedCredit =
                userFormatter.format(widget.request.amount);

            final notifRef =
                userDoc.reference.collection('notifications').doc();
            await notifRef.set({
              'id': notifRef.id,
              'userId': userDoc.id,
              'title': approve
                  ? '💰 Funds Request Approved!'
                  : '❌ Funds Request Rejected',
              'message': approve
                  ? 'Admin approved your request and credited $formattedCredit to your balance.'
                  : (msg.isNotEmpty
                      ? 'Admin rejected your request: $msg'
                      : 'Admin could not approve your funds request at this time.'),
              'category': 'system',
              'type': 'admin_credit',
              'createdAt': DateTime.now().toIso8601String(),
              'isRead': false,
              'data': {
                'amount': widget.request.amount,
                'status': approve ? 'approved' : 'rejected',
              },
            });
          } catch (_) {}
        } else {
          // User doc not found — skip wallet logging, still approve.
        }
      }

      await widget.docRef.update({
        'status': approve ? 'approved' : 'rejected',
        if (msg.isNotEmpty) 'adminMessage': msg,
        if (prevBalance != null) 'previousBalance': prevBalance,
        if (newBalance != null) 'newBalance': newBalance,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Request approved.' : 'Request rejected.'),
            backgroundColor: approve ? AppColors.profit : AppColors.loss,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final market = ref.watch(marketProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B3139)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    widget.request.requesterUid,
                    style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.request.requesterUid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('UID copied to clipboard')),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              Text(
                formatter.format(widget.request.amount),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('profile.publicUid', isEqualTo: widget.request.requesterUid)
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text(
                  'Net Worth: ${formatter.format(widget.request.requesterNetWorth)}',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                );
              }
              
              final doc = snapshot.data!.docs.first;
              final data = doc.data() as Map<String, dynamic>;
              final state = UserState.fromJson(data);
              
              double portfolioValue = 0;
              for (final holding in state.holdings) {
                try {
                  final stock = market.firstWhere((s) => s.symbol == holding.symbol);
                  portfolioValue += stock.currentPrice * holding.quantity;
                } catch (e) {
                  portfolioValue += holding.averagePrice * holding.quantity;
                }
              }

              double futuresValue = 0;
              for (final pos in state.futuresPositions) {
                try {
                  final stock = market.firstWhere((s) => s.symbol == pos.symbol);
                  final isLong = pos.side == OrderSide.buy;
                  final diff = stock.currentPrice - pos.entryPrice;
                  final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
                  final currentValue = pos.margin + pnl;
                  futuresValue += currentValue > 0 ? currentValue : 0;
                } catch(e) {
                  futuresValue += pos.margin; // fallback
                }
              }
              
              final liveNetWorth = state.profile.virtualBalance + portfolioValue + futuresValue;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.show_chart, color: AppColors.primary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Live Net Worth: ${formatter.format(liveNetWorth)}',
                        style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Balance: ${formatter.format(state.profile.virtualBalance)} | Holdings: ${formatter.format(portfolioValue)} | Futures: ${formatter.format(futuresValue)}',
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'At request time: ${formatter.format(widget.request.requesterNetWorth)}',
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Reason: "${widget.request.reason}"',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _msgController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Reply message (optional)',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2B3139)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleAction(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.loss,
                      side: BorderSide(color: AppColors.loss.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAction(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.profit,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
