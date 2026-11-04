import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/currency_formatters.dart';
import '../../../data/user_provider.dart';
import '../../../data/market_provider.dart';
import '../../../data/models.dart';

class WebPortfolioPanel extends ConsumerStatefulWidget {
  const WebPortfolioPanel({super.key});

  @override
  ConsumerState<WebPortfolioPanel> createState() => _WebPortfolioPanelState();
}

class _WebPortfolioPanelState extends ConsumerState<WebPortfolioPanel> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final market = ref.watch(marketProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tabs
        Container(
          color: const Color(0xFF161A1E),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _Tab(title: 'Futures Positions', isActive: _tabIndex == 0, onTap: () => setState(() => _tabIndex = 0)),
              _Tab(title: 'Spot Portfolio', isActive: _tabIndex == 1, onTap: () => setState(() => _tabIndex = 1)),
              _Tab(title: 'Active Quests', isActive: _tabIndex == 2, onTap: () => setState(() => _tabIndex = 2)),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFF2B3139)),
        
        Expanded(
          child: Container(
            color: AppColors.background,
            child: _tabIndex == 0
                ? _buildFutures(userState, market, formatter)
                : _tabIndex == 1
                    ? _buildSpot(userState, market, formatter)
                    : _buildQuests(userState, ref),
          ),
        ),
      ],
    );
  }

  Widget _buildFutures(UserState userState, List<dynamic> market, AppCurrencyFormatter formatter) {
    if (userState.futuresPositions.isEmpty) {
      return const Center(child: Text('No open positions.', style: TextStyle(color: Color(0xFF848E9C))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userState.futuresPositions.length,
      itemBuilder: (context, index) {
        final pos = userState.futuresPositions[index];
        final stock = market.firstWhere((s) => s.symbol == pos.symbol, orElse: () => market.first);
        final isLong = pos.side == OrderSide.buy;
        final diff = stock.currentPrice - pos.entryPrice;
        final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
        final isProfit = pnl >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: (isLong ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(isLong ? 'LONG ${pos.leverage}x' : 'SHORT ${pos.leverage}x', style: TextStyle(color: isLong ? AppColors.profit : AppColors.loss, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Text(pos.symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Margin', style: TextStyle(color: Color(0xFF848E9C), fontSize: 10)),
                  Text(formatter.format(pos.margin), style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Entry Price', style: TextStyle(color: Color(0xFF848E9C), fontSize: 10)),
                  Text(formatter.format(pos.entryPrice), style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Mark Price', style: TextStyle(color: Color(0xFF848E9C), fontSize: 10)),
                  Text(formatter.format(stock.currentPrice), style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Unrealized PNL', style: TextStyle(color: Color(0xFF848E9C), fontSize: 10)),
                  Text('${isProfit ? '+' : ''}${formatter.format(pnl)}', style: TextStyle(color: isProfit ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              FilledButton(
                onPressed: () => ref.read(userProvider.notifier).closeFuturesPosition(pos, stock.currentPrice),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2B3139),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpot(UserState userState, List<dynamic> market, AppCurrencyFormatter formatter) {
    if (userState.holdings.isEmpty) {
      return const Center(child: Text('Spot portfolio empty.', style: TextStyle(color: Color(0xFF848E9C))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userState.holdings.length,
      itemBuilder: (context, index) {
        final pos = userState.holdings[index];
        final stock = market.firstWhere((s) => s.symbol == pos.symbol, orElse: () => market.first);
        final value = stock.currentPrice * pos.quantity;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(pos.symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Holdings', style: TextStyle(color: Color(0xFF848E9C), fontSize: 10)),
                  Text(pos.quantity.toStringAsFixed(4), style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Avg Price', style: TextStyle(color: Color(0xFF848E9C), fontSize: 10)),
                  Text(formatter.format(pos.averagePrice), style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Value', style: TextStyle(color: Color(0xFF848E9C), fontSize: 10)),
                  Text(formatter.format(value), style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuests(UserState userState, WidgetRef ref) {
    if (userState.missions.isEmpty) {
      return const Center(child: Text('No active quests.', style: TextStyle(color: Color(0xFF848E9C))));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userState.missions.length,
      itemBuilder: (context, index) {
        final m = userState.missions[index];
        final progress = (m.progress / m.target).clamp(0.0, 1.0);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: m.completed ? AppColors.profit.withValues(alpha: 0.05) : const Color(0xFF1E2329),
            borderRadius: BorderRadius.circular(8),
            border: m.completed ? Border.all(color: AppColors.profit.withValues(alpha: 0.3)) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (!m.completed) ...[
                      LinearProgressIndicator(value: progress, backgroundColor: const Color(0xFF2B3139), color: AppColors.primary),
                      const SizedBox(height: 4),
                      Text('${m.progress}/${m.target} • +${m.reward} XP', style: const TextStyle(color: Color(0xFF848E9C), fontSize: 11)),
                    ] else
                      Text('Completed! +${m.reward} XP', style: TextStyle(color: AppColors.profit, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              if (m.completed) ...[
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () => ref.read(userProvider.notifier).claimMission(m.id),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Claim Reward', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab({required this.title, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isActive ? AppColors.primary : Colors.transparent, width: 2)),
        ),
        child: Text(title, style: TextStyle(color: isActive ? AppColors.primary : const Color(0xFF848E9C), fontWeight: FontWeight.bold)),
      ),
    );
  }
}
