import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_theme.dart';
import '../../../data/community_provider.dart';
import '../../../data/market_mode_provider.dart';
import '../../../data/market_provider.dart';
import '../../../data/models.dart';
import '../../../data/stock_market_provider.dart';
import '../../../data/user_provider.dart';
import '../../../core/avatar_helper.dart';

class CreatePostSheet extends ConsumerStatefulWidget {
  const CreatePostSheet({super.key});

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
  final TextEditingController _textController = TextEditingController();
  AttachedTradeInfo? _selectedTrade;
  final List<String> _selectedHashtags = [];
  bool _showTradesTray = true;

  String _activeTagCategory = 'Stocks';
  String _activeTradesCategory = 'Stocks';
  bool _initializedMode = false;

  static const List<String> _stockHashtags = [
    'Stocks',
    'WallStreet',
    'AAPL',
    'NVDA',
    'TSLA',
    'RELIANCE',
    'TCS',
    'NIFTY',
    'Delivery',
    'IntradayMargin',
  ];

  static const List<String> _cryptoHashtags = [
    'Crypto',
    'BTC',
    'ETH',
    'SOL',
    'PEPE',
    'Futures',
    'Spot',
    'Breakout',
    'Scalp',
  ];

  static const int _maxChars = 280;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitPost(List<AttachedTradeInfo> userActiveTrades) {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something before posting!')),
      );
      return;
    }

    final userState = ref.read(userProvider);
    final authorName = userState.profile.name.isNotEmpty ? userState.profile.name : 'CryptoTrader';
    final authorAvatar = userState.profile.photoUrl.isNotEmpty
        ? userState.profile.photoUrl
        : AppAvatarHelper.defaultFallback;

    AttachedTradeInfo? tradeToAttach;
    if (_selectedTrade != null) {
      tradeToAttach = userActiveTrades.firstWhere(
        (t) => t == _selectedTrade,
        orElse: () => _selectedTrade!,
      );
    }

    ref.read(communityProvider.notifier).addPost(
          authorName: authorName,
          authorAvatar: authorAvatar,
          content: text,
          attachedTrade: tradeToAttach,
          hashtags: _selectedHashtags,
        );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post published to Community! 🚀')),
    );
  }

  ({List<AttachedTradeInfo> cryptoTrades, List<AttachedTradeInfo> stockTrades}) _getActiveTrades(
    UserState userState,
    List<Stock> cryptoMarket,
    List<Stock> stockMarket,
  ) {
    final List<AttachedTradeInfo> cryptoTrades = [];
    final List<AttachedTradeInfo> stockTrades = [];

    // 1. Futures / Margin Positions
    for (final pos in userState.futuresPositions) {
      final isStock = stockMarket.any((s) => s.symbol.toUpperCase() == pos.symbol.toUpperCase()) ||
          pos.symbol.endsWith('.NS');

      final currentPrice = isStock
          ? (stockMarket.firstWhere(
              (s) => s.symbol.toUpperCase() == pos.symbol.toUpperCase(),
              orElse: () => stockMarket.first,
            ).currentPrice)
          : (() {
              final clean = pos.symbol.replaceAll('/USDT', '').replaceAll('USDT', '');
              final s = cryptoMarket.firstWhere(
                (c) => c.symbol.toUpperCase() == clean.toUpperCase(),
                orElse: () => Stock(
                  symbol: clean,
                  name: clean,
                  category: 'Crypto',
                  currentPrice: pos.entryPrice,
                  previousClose: pos.entryPrice,
                  dayHigh: pos.entryPrice,
                  dayLow: pos.entryPrice,
                  volume: 0,
                  history: const [],
                  candleHistory: const [],
                  about: '',
                  supply: 0,
                  rank: 0,
                ),
              );
              return s.currentPrice > 0 ? s.currentPrice : pos.entryPrice;
            })();

      final isLong = pos.side == OrderSide.buy;
      final priceDiff = currentPrice - pos.entryPrice;
      final pnl = isLong ? priceDiff * pos.quantity : -priceDiff * pos.quantity;
      final roe = pos.margin > 0 ? (pnl / pos.margin) * 100 : 0.0;

      final trade = AttachedTradeInfo(
        symbol: isStock ? pos.symbol : '${pos.symbol.replaceAll('/USDT', '').replaceAll('USDT', '')}/USDT',
        isLong: isLong,
        leverage: pos.leverage,
        entryPrice: pos.entryPrice,
        currentPrice: currentPrice,
        pnlPercentage: roe,
      );

      if (isStock) {
        stockTrades.add(trade);
      } else {
        cryptoTrades.add(trade);
      }
    }

    // 2. Spot / Delivery Holdings
    for (final holding in userState.holdings) {
      if (holding.quantity <= 0) continue;
      final isStock = stockMarket.any((s) => s.symbol.toUpperCase() == holding.symbol.toUpperCase()) ||
          holding.symbol.endsWith('.NS');

      final currentPrice = isStock
          ? (stockMarket.firstWhere(
              (s) => s.symbol.toUpperCase() == holding.symbol.toUpperCase(),
              orElse: () => stockMarket.first,
            ).currentPrice)
          : (() {
              final clean = holding.symbol.replaceAll('/USDT', '').replaceAll('USDT', '');
              final s = cryptoMarket.firstWhere(
                (c) => c.symbol.toUpperCase() == clean.toUpperCase(),
                orElse: () => Stock(
                  symbol: clean,
                  name: clean,
                  category: 'Crypto',
                  currentPrice: holding.averagePrice,
                  previousClose: holding.averagePrice,
                  dayHigh: holding.averagePrice,
                  dayLow: holding.averagePrice,
                  volume: 0,
                  history: const [],
                  candleHistory: const [],
                  about: '',
                  supply: 0,
                  rank: 0,
                ),
              );
              return s.currentPrice > 0 ? s.currentPrice : holding.averagePrice;
            })();

      final pnlPercentage = holding.averagePrice > 0
          ? ((currentPrice - holding.averagePrice) / holding.averagePrice) * 100
          : 0.0;

      final trade = AttachedTradeInfo(
        symbol: isStock ? '${holding.symbol} (Delivery)' : '${holding.symbol.replaceAll('/USDT', '').replaceAll('USDT', '')}/USDT',
        isLong: true,
        leverage: 1,
        entryPrice: holding.averagePrice,
        currentPrice: currentPrice,
        pnlPercentage: pnlPercentage,
      );

      if (isStock) {
        stockTrades.add(trade);
      } else {
        cryptoTrades.add(trade);
      }
    }

    return (cryptoTrades: cryptoTrades, stockTrades: stockTrades);
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final cryptoMarket = ref.watch(marketProvider);
    final stockMarket = ref.watch(stockMarketProvider);
    final marketMode = ref.watch(marketModeProvider);

    if (!_initializedMode) {
      _initializedMode = true;
      _activeTagCategory = marketMode == MarketMode.stocks ? 'Stocks' : 'Crypto';
      _activeTradesCategory = marketMode == MarketMode.stocks ? 'Stocks' : 'Crypto';
    }

    final separatedTrades = _getActiveTrades(userState, cryptoMarket, stockMarket);
    final cryptoTrades = separatedTrades.cryptoTrades;
    final stockTrades = separatedTrades.stockTrades;
    final currentTrades = _activeTradesCategory == 'Stocks' ? stockTrades : cryptoTrades;
    final allActiveTrades = [...stockTrades, ...cryptoTrades];

    final currentHashtags = _activeTagCategory == 'Stocks' ? _stockHashtags : _cryptoHashtags;

    final avatarUrl = userState.profile.photoUrl.isNotEmpty
        ? userState.profile.photoUrl
        : AppAvatarHelper.defaultFallback;

    final textLength = _textController.text.length;
    final remainingChars = _maxChars - textLength;
    final hasContent = _textController.text.trim().isNotEmpty;
    final canPost = hasContent && remainingChars >= 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── Top Navigation Bar (Twitter Style) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cancel / Close
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      'New Post',
                      style: GoogleFonts.inter(
                        color: AppColors.subtle,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Post Pill Button
                    ElevatedButton(
                      onPressed: canPost ? () => _submitPost(allActiveTrades) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canPost ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                        foregroundColor: canPost ? Colors.black : Colors.white38,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Post',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: canPost ? Colors.black : Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: AppColors.outline, height: 1),

              // ── Main Compose Area ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circular Avatar
                    AppAvatar(
                      avatarUrl: avatarUrl,
                      radius: 20,
                      backgroundColor: AppColors.surfaceAlt,
                    ),
                    const SizedBox(width: 12),

                    // Content Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rounded Input Box
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.outline,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: TextField(
                              controller: _textController,
                              maxLines: null,
                              minLines: 3,
                              autofocus: true,
                              style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                height: 1.35,
                              ),
                              decoration: InputDecoration(
                                hintText: "What's happening in the market?",
                                hintStyle: GoogleFonts.inter(
                                  color: AppColors.muted,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),

                          // ── Attached Trade Quoted Preview (If selected) ──
                          if (_selectedTrade != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.outline,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _selectedTrade!.isLong ? Icons.trending_up : Icons.trending_down,
                                            size: 16,
                                            color: _selectedTrade!.isLong ? AppColors.profit : AppColors.loss,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _selectedTrade!.symbol,
                                            style: GoogleFonts.inter(
                                              color: AppColors.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: (_selectedTrade!.isLong ? AppColors.profit : AppColors.loss)
                                                  .withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${_selectedTrade!.isLong ? "LONG" : "SHORT"} ${_selectedTrade!.leverage}x',
                                              style: GoogleFonts.inter(
                                                color: _selectedTrade!.isLong ? AppColors.profit : AppColors.loss,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Detach Button
                                      GestureDetector(
                                        onTap: () => setState(() => _selectedTrade = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: AppColors.subtle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Entry: \$${_selectedTrade!.entryPrice.toStringAsFixed(_selectedTrade!.entryPrice < 1 ? 4 : 2)}',
                                        style: GoogleFonts.inter(
                                          color: AppColors.subtle,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        '${_selectedTrade!.pnlPercentage >= 0 ? "+" : ""}${_selectedTrade!.pnlPercentage.toStringAsFixed(1)}% ROE',
                                        style: GoogleFonts.inter(
                                          color: _selectedTrade!.pnlPercentage >= 0 ? AppColors.profit : AppColors.loss,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Hashtags Tray with Arena Separation ──
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 6),
                child: Row(
                  children: [
                    Text(
                      'TAG LINE',
                      style: GoogleFonts.inter(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Stocks tag line pill
                    GestureDetector(
                      onTap: () => setState(() => _activeTagCategory = 'Stocks'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _activeTagCategory == 'Stocks'
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _activeTagCategory == 'Stocks' ? AppColors.primary : AppColors.outline,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '📈 Stocks',
                          style: GoogleFonts.inter(
                            color: _activeTagCategory == 'Stocks' ? AppColors.primary : AppColors.subtle,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Crypto tag line pill
                    GestureDetector(
                      onTap: () => setState(() => _activeTagCategory = 'Crypto'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _activeTagCategory == 'Crypto'
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _activeTagCategory == 'Crypto' ? AppColors.primary : AppColors.outline,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '🪙 Crypto',
                          style: GoogleFonts.inter(
                            color: _activeTagCategory == 'Crypto' ? AppColors.primary : AppColors.subtle,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 8),
                child: SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: currentHashtags.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final tag = currentHashtags[index];
                      final isSelected = _selectedHashtags.contains(tag);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedHashtags.remove(tag);
                            } else {
                              _selectedHashtags.add(tag);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.18)
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.outline,
                              width: isSelected ? 1 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '#$tag',
                              style: GoogleFonts.inter(
                                color: isSelected ? AppColors.primary : AppColors.subtle,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Active Paper Trades Selector Tray with Arena Separation ──
              if (_showTradesTray && allActiveTrades.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.candlestick_chart_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Attach Active Trade:',
                            style: GoogleFonts.inter(
                              color: AppColors.subtle,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Stock active trade tab
                          GestureDetector(
                            onTap: () => setState(() => _activeTradesCategory = 'Stocks'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _activeTradesCategory == 'Stocks'
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _activeTradesCategory == 'Stocks'
                                      ? AppColors.primary
                                      : AppColors.outline,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '📈 Stocks (${stockTrades.length})',
                                style: GoogleFonts.inter(
                                  color: _activeTradesCategory == 'Stocks'
                                      ? AppColors.primary
                                      : AppColors.muted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Crypto active trade tab
                          GestureDetector(
                            onTap: () => setState(() => _activeTradesCategory = 'Crypto'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _activeTradesCategory == 'Crypto'
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _activeTradesCategory == 'Crypto'
                                      ? AppColors.primary
                                      : AppColors.outline,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '🪙 Crypto (${cryptoTrades.length})',
                                style: GoogleFonts.inter(
                                  color: _activeTradesCategory == 'Crypto'
                                      ? AppColors.primary
                                      : AppColors.muted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedTrade != null)
                        GestureDetector(
                          onTap: () => setState(() => _selectedTrade = null),
                          child: Text(
                            'Detach',
                            style: GoogleFonts.inter(
                              color: AppColors.loss,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (currentTrades.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      'No open ${_activeTradesCategory.toLowerCase()} trades found.',
                      style: GoogleFonts.inter(color: AppColors.muted, fontSize: 11),
                    ),
                  )
                else
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: currentTrades.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final trade = currentTrades[index];
                        final isSelected = _selectedTrade != null && _selectedTrade == trade;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTrade = isSelected ? null : trade;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (AppColors.isDarkMode ? AppColors.primaryDark : AppColors.primary.withValues(alpha: 0.2))
                                  : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.outline,
                                width: isSelected ? 1.4 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  trade.isLong ? Icons.trending_up : Icons.trending_down,
                                  size: 14,
                                  color: trade.isLong ? AppColors.profit : AppColors.loss,
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${trade.symbol} ${trade.leverage}x',
                                      style: GoogleFonts.inter(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      '${trade.pnlPercentage >= 0 ? "+" : ""}${trade.pnlPercentage.toStringAsFixed(1)}%',
                                      style: GoogleFonts.inter(
                                        color: trade.pnlPercentage >= 0 ? AppColors.profit : AppColors.loss,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                const SizedBox(height: 8),
              ],

              // ── Bottom Utility Toolbar (Twitter Style) ──
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.outline, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Active trades tray toggle button
                    IconButton(
                      icon: Icon(
                        Icons.candlestick_chart_rounded,
                        color: _showTradesTray ? AppColors.primary : AppColors.subtle,
                        size: 20,
                      ),
                      tooltip: 'Toggle Trades',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _showTradesTray = !_showTradesTray;
                        });
                      },
                    ),
                    // Tag hash button
                    IconButton(
                      icon: const Icon(
                        Icons.tag_rounded,
                        color: AppColors.subtle,
                        size: 20,
                      ),
                      tooltip: 'Add Tag',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final cur = _textController.text;
                        _textController.text = '$cur #';
                        _textController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _textController.text.length),
                        );
                      },
                    ),

                    const Spacer(),

                    // Character counter
                    if (hasContent)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$remainingChars',
                            style: GoogleFonts.inter(
                              color: remainingChars < 0
                                  ? AppColors.loss
                                  : (remainingChars < 20 ? AppColors.warning : AppColors.muted),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              value: (textLength / _maxChars).clamp(0.0, 1.0),
                              strokeWidth: 2,
                              backgroundColor: const Color(0xFF2B3139),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                remainingChars < 0
                                    ? AppColors.loss
                                    : (remainingChars < 20 ? AppColors.warning : AppColors.primary),
                              ),
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
    );
  }
}
