import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/currency_formatters.dart';
import '../../../data/market_provider.dart';
import '../../../data/user_provider.dart';
import '../web_terminal_shell.dart';

class WebMarketPanel extends ConsumerWidget {
  const WebMarketPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ref.watch(marketProvider);
    final userState = ref.watch(userProvider);
    final currSym = CurrencyFormatters.getSymbol(userState.profile.preferredCurrency);
    final selectedSymbol = ref.watch(selectedSymbolProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Markets', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFF2B3139)),
        Expanded(
          child: ListView.builder(
            itemCount: market.length,
            itemBuilder: (context, index) {
              final stock = market[index];
              final isSelected = stock.symbol == selectedSymbol;
              final isPositive = stock.changePercentage >= 0;

              return InkWell(
                onTap: () => ref.read(selectedSymbolProvider.notifier).setSymbol(stock.symbol),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E2329) : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stock.symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(stock.name, style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$currSym${stock.currentPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            '${isPositive ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                            style: TextStyle(color: isPositive ? AppColors.profit : AppColors.loss, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
