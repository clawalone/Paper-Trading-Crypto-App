import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/app_theme.dart';
import '../../../core/currency_formatters.dart';
import '../../../core/trading_view_chart.dart';
import '../../../data/market_provider.dart';
import '../../../data/user_provider.dart';

class WebChartPanel extends ConsumerStatefulWidget {
  final String symbol;
  const WebChartPanel({super.key, required this.symbol});

  @override
  ConsumerState<WebChartPanel> createState() => _WebChartPanelState();
}

class _WebChartPanelState extends ConsumerState<WebChartPanel> {
  int _chartType = 0; // 0: TradingView, 1: Candle, 2: Line

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(marketProvider);
    final stock = market.firstWhere((s) => s.symbol == widget.symbol, orElse: () => market.first);
    final good = stock.changePercentage >= 0;
    final color = good ? AppColors.profit : AppColors.loss;
    final userState = ref.watch(userProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(stock.symbol, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(width: 8),
              Text(stock.name, style: const TextStyle(fontSize: 16, color: Colors.white54, height: 1.5)),
              const SizedBox(width: 24),
              Text(formatter.format(stock.currentPrice), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text('${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const Spacer(),
              // Chart Toggles
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _chartType = 0),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: _chartType == 0 ? const Color(0xFF2B3139) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFF2962FF), borderRadius: BorderRadius.circular(2)),
                              child: const Text('TV', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            const Text('TradingView', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    _ToggleBtn(
                      icon: Icons.candlestick_chart,
                      active: _chartType == 1,
                      onTap: () => setState(() => _chartType = 1),
                    ),
                    _ToggleBtn(
                      icon: Icons.show_chart,
                      active: _chartType == 2,
                      onTap: () => setState(() => _chartType = 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFF2B3139)),
        
        // Chart Body
        Expanded(
          child: _chartType == 0
              ? TradingViewChart(
                  key: ValueKey('web_tv_${stock.symbol}'),
                  symbol: stock.symbol,
                  initialInterval: '15',
                  enableDrawingToolbar: true,
                  showFullscreenAction: true,
                  isFullScreen: true,
                  onToggleNative: () => setState(() => _chartType = 1),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _chartType == 1 ? SfCartesianChart(
              trackballBehavior: TrackballBehavior(
                enable: true,
                activationMode: ActivationMode.singleTap,
                tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
                tooltipSettings: const InteractiveTooltip(color: Color(0xFF2B3139), textStyle: TextStyle(color: Colors.white)),
              ),
              zoomPanBehavior: ZoomPanBehavior(enablePanning: true, enablePinching: true, zoomMode: ZoomMode.x),
              primaryXAxis: DateTimeAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: const TextStyle(color: Color(0xFF848E9C), fontSize: 10),
                axisLine: const AxisLine(color: Color(0xFF2B3139)),
              ),
              primaryYAxis: NumericAxis(
                opposedPosition: true,
                majorGridLines: const MajorGridLines(color: Color(0xFF2B3139), dashArray: [4, 4]),
                labelStyle: const TextStyle(color: Color(0xFF848E9C), fontSize: 10),
                axisLine: const AxisLine(width: 0),
                numberFormat: CurrencyFormatters.getFormatter(userState.profile.preferredCurrency, decimalDigits: 0),
              ),
              series: <CartesianSeries>[
                CandleSeries<dynamic, DateTime>(
                  dataSource: stock.candleHistory,
                  xValueMapper: (data, _) => data.date,
                  lowValueMapper: (data, _) => data.low,
                  highValueMapper: (data, _) => data.high,
                  openValueMapper: (data, _) => data.open,
                  closeValueMapper: (data, _) => data.close,
                  bearColor: AppColors.loss,
                  bullColor: AppColors.profit,
                  enableSolidCandles: true,
                  animationDuration: 0,
                )
              ],
            ) : SfCartesianChart(
              trackballBehavior: TrackballBehavior(
                enable: true,
                activationMode: ActivationMode.singleTap,
                tooltipSettings: const InteractiveTooltip(color: Color(0xFF2B3139)),
              ),
              primaryXAxis: DateTimeAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: const TextStyle(color: Color(0xFF848E9C), fontSize: 10),
                axisLine: const AxisLine(color: Color(0xFF2B3139)),
              ),
              primaryYAxis: NumericAxis(
                opposedPosition: true,
                majorGridLines: const MajorGridLines(color: Color(0xFF2B3139), dashArray: [4, 4]),
                labelStyle: const TextStyle(color: Color(0xFF848E9C), fontSize: 10),
                axisLine: const AxisLine(width: 0),
                numberFormat: CurrencyFormatters.getFormatter(userState.profile.preferredCurrency, decimalDigits: 0),
              ),
              series: <CartesianSeries>[
                AreaSeries<dynamic, DateTime>(
                  dataSource: stock.candleHistory,
                  xValueMapper: (data, _) => data.date,
                  yValueMapper: (data, _) => data.close,
                  color: color.withValues(alpha: 0.1),
                  borderColor: color,
                  borderWidth: 2,
                  animationDuration: 0,
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToggleBtn({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2B3139) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: active ? Colors.white : const Color(0xFF848E9C), size: 20),
      ),
    );
  }
}
