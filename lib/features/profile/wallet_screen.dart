import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../../core/app_translations.dart';

// ─── Unified wallet entry ─────────────────────────────────────────────────────
class WalletEntry {
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final DateTime time;
  final IconData icon;

  const WalletEntry({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.time,
    required this.icon,
  });
}

IconData _iconForCategory(String cat) {
  switch (cat) {
    case 'daily_reward':   return Icons.calendar_today_outlined;
    case 'quest_reward':   return Icons.flag_outlined;
    case 'admin_credit':   return Icons.account_balance_outlined;
    case 'futures_open':   return Icons.rocket_launch_outlined;
    case 'futures_close':  return Icons.currency_bitcoin;
    case 'futures_pnl':    return Icons.show_chart_rounded;
    default:               return Icons.swap_horiz_rounded;
  }
}

// ─── Screen — watches provider directly so it always stays in sync ────────────
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch here so the whole screen rebuilds when state changes
    final userState = ref.watch(userProvider);
    final user = FirebaseAuth.instance.currentUser;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Wallet'.tr(),
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: user == null
            ? Center(child: Text('Not logged in'.tr(), style: TextStyle(color: AppColors.textMuted)))
            : _WalletBody(uid: user.uid, userState: userState, formatter: formatter),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────
class _WalletBody extends StatelessWidget {
  final String uid;
  final UserState userState;
  final AppCurrencyFormatter formatter;

  const _WalletBody({required this.uid, required this.userState, required this.formatter});

  @override
  Widget build(BuildContext context) {
    // Stream for admin-approved money requests (covers legacy approvals)
    final moneyStream = FirebaseFirestore.instance
        .collection('money_requests')
        .where('requesterUid', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: moneyStream,
      builder: (context, moneySnap) {
        final List<WalletEntry> entries = [];

        // ── 1. walletEntries stored in user doc (daily/quest/futures/admin) ────
        for (final e in userState.walletEntries) {
          final isCredit = (e['type'] as String?) == 'credit';
          final ts = e['timestamp'] as String?;
          entries.add(WalletEntry(
            title: e['title'] as String? ?? 'Transaction',
            subtitle: e['subtitle'] as String? ?? '',
            amount: (e['amount'] as num?)?.toDouble() ?? 0,
            isCredit: isCredit,
            time: ts != null ? (DateTime.tryParse(ts) ?? DateTime.now()) : DateTime.now(),
            icon: _iconForCategory(e['category'] as String? ?? ''),
          ));
        }

        // ── 2. Spot trades (buy = debit, sell = credit) ───────────────────────
        for (final trade in userState.trades) {
          final total = trade.price * trade.quantity;
          final isBuy = trade.side == OrderSide.buy;
          entries.add(WalletEntry(
            title: '${isBuy ? 'Bought' : 'Sold'} ${trade.symbol}',
            subtitle: '${trade.quantity} qty @ ${formatter.format(trade.price)}',
            amount: total,
            isCredit: !isBuy,   // buy = money out (debit), sell = money in (credit)
            time: trade.time,
            icon: isBuy ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          ));
        }

        // ── 3. Legacy: admin approvals that predate the walletEntries array ────
        //    De-duplicate: skip if already present in walletEntries
        final walletAdminTimestamps = userState.walletEntries
            .where((e) => e['category'] == 'admin_credit')
            .map((e) => e['timestamp'] as String? ?? '')
            .toSet();

        if (moneySnap.hasData) {
          for (final doc in moneySnap.data!.docs) {
            final req = MoneyRequest.fromJson(
                {...doc.data() as Map<String, dynamic>, 'id': doc.id});
            // Only add if we don't already have a matching walletEntry
            if (walletAdminTimestamps.isEmpty) {
              entries.add(WalletEntry(
                title: 'Admin Added Funds',
                subtitle: req.reason.split('(').first.trim().isNotEmpty
                    ? req.reason.split('(').first.trim()
                    : 'Approved by admin',
                amount: req.amount,
                isCredit: true,
                time: req.createdAt ?? DateTime(2024),
                icon: Icons.account_balance_outlined,
              ));
            }
          }
        }

        // Sort newest first
        entries.sort((a, b) => b.time.compareTo(a.time));

        final totalIn  = entries.where((e) =>  e.isCredit).fold(0.0, (s, e) => s + e.amount);
        final totalOut = entries.where((e) => !e.isCredit).fold(0.0, (s, e) => s + e.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Balance card ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available Balance'.tr(),
                        style: TextStyle(
                            color: AppColors.subtle, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Text(
                      formatter.format(userState.profile.virtualBalance),
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: AppColors.outline, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCell(
                            label: 'Total In',
                            value: formatter.format(totalIn),
                            color: AppColors.profit,
                            icon: Icons.arrow_downward_rounded,
                          ),
                        ),
                        Container(width: 1, height: 36, color: AppColors.outline),
                        Expanded(
                          child: _SummaryCell(
                            label: 'Total Out',
                            value: formatter.format(totalOut),
                            color: AppColors.loss,
                            icon: Icons.arrow_upward_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Transactions'.tr(),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 48),
                          const SizedBox(height: 12),
                          Text('No transactions yet'.tr(),
                              style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: AppColors.outline, height: 1),
                      itemBuilder: (_, i) =>
                          _TxTile(entry: entries[i], formatter: formatter),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Transaction tile ─────────────────────────────────────────────────────────
class _TxTile extends StatelessWidget {
  final WalletEntry entry;
  final AppCurrencyFormatter formatter;

  const _TxTile({required this.entry, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final color   = entry.isCredit ? AppColors.profit : AppColors.loss;
    final sign    = entry.isCredit ? '+' : '-';
    final dateStr = DateFormat('dd MMM yyyy  hh:mm a').format(entry.time.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                if (entry.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(entry.subtitle,
                      style: TextStyle(color: AppColors.subtle, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 2),
                Text(dateStr,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$sign${formatter.format(entry.amount)}',
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Summary cell ─────────────────────────────────────────────────────────────
class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 13),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.tr(), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: color, fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
