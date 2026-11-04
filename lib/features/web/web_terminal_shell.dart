import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../data/auth_provider.dart';
import '../../data/user_provider.dart';
import 'panels/web_market_panel.dart';
import 'panels/web_chart_panel.dart';
import 'panels/web_trade_panel.dart';
import 'panels/web_portfolio_panel.dart';

class SelectedSymbolNotifier extends Notifier<String> {
  @override
  String build() => 'BTC';
  
  void setSymbol(String symbol) {
    state = symbol;
  }
}

final selectedSymbolProvider = NotifierProvider<SelectedSymbolNotifier, String>(() {
  return SelectedSymbolNotifier();
});
class WebTerminalShell extends ConsumerWidget {
  const WebTerminalShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final selectedSymbol = ref.watch(selectedSymbolProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.currency_bitcoin, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            const Text('PaperTrading PRO', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
            const Spacer(),
            // User Balance
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2329),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Available: ${AppCurrencyFormatter(userState.profile.preferredCurrency).format(userState.profile.virtualBalance)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white54),
              onPressed: () async {
                await AuthController.signOut();
              },
            ),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT PANEL: Markets
          const SizedBox(
            width: 300,
            child: WebMarketPanel(),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF2B3139)),

          // MIDDLE PANEL: Chart & Bottom Portfolio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: WebChartPanel(symbol: selectedSymbol),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFF2B3139)),
                const Expanded(
                  flex: 3,
                  child: WebPortfolioPanel(),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF2B3139)),

          // RIGHT PANEL: Trading
          SizedBox(
            width: 320,
            child: WebTradePanel(symbol: selectedSymbol),
          ),
        ],
      ),
    );
  }
}
