import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_theme.dart';
import '../../../data/community_provider.dart';
import '../../../data/market_provider.dart';
import '../../../data/models.dart';
import '../../../data/user_provider.dart';

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

  final List<String> _availableHashtags = [
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
        : 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Unicorn.png';

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

  List<AttachedTradeInfo> _getActiveTrades(UserState userState, List<Stock> market) {
    final List<AttachedTradeInfo> userActiveTrades = [];

    // 1. Active Futures Positions
    for (final pos in userState.futuresPositions) {
      final cleanSymbol = pos.symbol.replaceAll('/USDT', '').replaceAll('USDT', '');
      final stock = market.firstWhere(
        (s) => s.symbol.toUpperCase() == cleanSymbol.toUpperCase(),
        orElse: () => Stock(
          symbol: cleanSymbol,
          name: cleanSymbol,
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
      final currentPrice = stock.currentPrice > 0 ? stock.currentPrice : pos.entryPrice;
      final isLong = pos.side == OrderSide.buy;
      final priceDiff = currentPrice - pos.entryPrice;
      final pnl = isLong ? priceDiff * pos.quantity : -priceDiff * pos.quantity;
      final roe = pos.margin > 0 ? (pnl / pos.margin) * 100 : 0.0;

      userActiveTrades.add(
        AttachedTradeInfo(
          symbol: '$cleanSymbol/USDT',
          isLong: isLong,
          leverage: pos.leverage,
          entryPrice: pos.entryPrice,
          currentPrice: currentPrice,
          pnlPercentage: roe,
        ),
      );
    }

    // 2. Active Spot Holdings
    for (final holding in userState.holdings) {
      if (holding.quantity <= 0) continue;
      final cleanSymbol = holding.symbol.replaceAll('/USDT', '').replaceAll('USDT', '');
      final stock = market.firstWhere(
        (s) => s.symbol.toUpperCase() == cleanSymbol.toUpperCase(),
        orElse: () => Stock(
          symbol: cleanSymbol,
          name: cleanSymbol,
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
      final currentPrice = stock.currentPrice > 0 ? stock.currentPrice : holding.averagePrice;
      final pnlPercentage = holding.averagePrice > 0
          ? ((currentPrice - holding.averagePrice) / holding.averagePrice) * 100
          : 0.0;

      userActiveTrades.add(
        AttachedTradeInfo(
          symbol: '$cleanSymbol/USDT',
          isLong: true,
          leverage: 1,
          entryPrice: holding.averagePrice,
          currentPrice: currentPrice,
          pnlPercentage: pnlPercentage,
        ),
      );
    }

    return userActiveTrades;
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final market = ref.watch(marketProvider);
    final userActiveTrades = _getActiveTrades(userState, market);

    final avatarUrl = userState.profile.photoUrl.isNotEmpty
        ? userState.profile.photoUrl
        : 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Unicorn.png';

    final textLength = _textController.text.length;
    final remainingChars = _maxChars - textLength;
    final hasContent = _textController.text.trim().isNotEmpty;
    final canPost = hasContent && remainingChars >= 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          color: Colors.white,
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
                      onPressed: canPost ? () => _submitPost(userActiveTrades) : null,
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

              const Divider(color: Color(0xFF1E2329), height: 1),

              // ── Main Compose Area ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circular Avatar
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF1F242C),
                      backgroundImage: NetworkImage(avatarUrl),
                      onBackgroundImageError: (_, __) {},
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
                              color: const Color(0xFF14171A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF262D35),
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
                                color: Colors.white,
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
                                color: const Color(0xFF161A1E),
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
                                              color: Colors.white,
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

              // ── Hashtags Tray ──
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
                child: SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableHashtags.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final tag = _availableHashtags[index];
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
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.18) : const Color(0xFF161A1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : const Color(0xFF2B3139),
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

              // ── Active Paper Trades Selector Tray ──
              if (_showTradesTray && userActiveTrades.isNotEmpty) ...[
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
                            'Attach Active Paper Trade',
                            style: GoogleFonts.inter(
                              color: AppColors.subtle,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: userActiveTrades.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final trade = userActiveTrades[index];
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
                            color: isSelected ? AppColors.primaryDark : const Color(0xFF161A1E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : const Color(0xFF2B3139),
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
                                      color: Colors.white,
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
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF1E2329), width: 1),
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
