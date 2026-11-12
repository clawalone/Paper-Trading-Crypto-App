import 'dart:async';
import 'dart:math';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_theme.dart';
import '../../core/avatar_helper.dart';
import '../../core/coin_icon.dart';
import '../../core/currency_formatters.dart';
import '../../core/update_manager.dart';
import '../../data/market_provider.dart';
import '../../data/stock_market_provider.dart';
import '../../data/market_mode_provider.dart';
import '../../core/widgets/arena_switcher.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../futures/futures_pro_screen.dart';
import '../profile/profile_screen.dart';
import '../stock_detail/stock_detail_screen.dart';
import '../rewards/rewards_screen.dart';
import '../blitz/blitz_duel_screen.dart';
import '../tournaments/tournament_screen.dart';
import '../profile/request_money_screen.dart';
import '../profile/widgets/zero_balance_refill_sheet.dart';
import '../signals/signals_screen.dart';
import '../../core/topup_offer_manager.dart';
import '../../core/championship_prize_manager.dart';
import '../../core/daily_checkin_manager.dart';
import '../../core/app_lock_manager.dart';
import '../../data/notification_provider.dart';
import '../notifications/notification_screen.dart';
import '../../core/widgets/animated_username_text.dart';
import '../../core/prestige_celebration_manager.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InAppUpdateManager.checkForUpdates(context);
      TopUpOfferManager.checkAndShowOffer(context);
      ChampionshipPrizeManager.checkAndShowClaimDialog(context, ref);
      DailyCheckInManager.checkAndShowDailyDialog(context, ref);
      AppLockManager.checkAndPromptSetup(context);
      PrestigeCelebrationManager.checkAndShowCelebration(
          context, userState.profile, ref);
      if (userState.profile.virtualBalance <= 0) {
        ZeroBalanceRefillSheet.checkAndPromptIfZero(
            context, userState.profile.virtualBalance);
      }
    });
    final marketMode = ref.watch(marketModeProvider);
    final isStockMode = marketMode == MarketMode.stocks;
    final cryptoMarket = ref.watch(marketProvider);
    final stockMarket = ref.watch(stockMarketProvider);
    final stockIndices = ref.watch(stockIndicesProvider);
    final market = isStockMode ? stockMarket : cryptoMarket;

    final notifState = ref.watch(notificationProvider);
    final unreadNotifs = notifState.unreadCount;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    final isMarketLoading = market.isEmpty || market.first.currentPrice == 0;
    final isAppLoading = userState.isLoading || isMarketLoading;

    final cryptoMap = {for (final s in cryptoMarket) s.symbol: s};
    final stockMap = {for (final s in stockMarket) s.symbol: s};

    double portfolioValue = 0;
    double investedValue = 0;
    for (final h in userState.holdings) {
      final s = stockMap[h.symbol] ?? cryptoMap[h.symbol];
      if (s != null) {
        final priceUsd = s.currency == 'INR' ? (s.currentPrice / 85.0) : s.currentPrice;
        final avgUsd = s.currency == 'INR' ? (h.averagePrice / 85.0) : h.averagePrice;
        portfolioValue += priceUsd * h.quantity;
        investedValue += avgUsd * h.quantity;
      }
    }

    double futuresPnl = 0;
    double futuresInvested = 0;
    double futuresValue = 0;
    for (final pos in userState.futuresPositions) {
      final s = stockMap[pos.symbol] ?? cryptoMap[pos.symbol];
      if (s != null) {
        final priceUsd = s.currency == 'INR' ? (s.currentPrice / 85.0) : s.currentPrice;
        final isLong = pos.side == OrderSide.buy;
        final diff = priceUsd - pos.entryPrice;
        final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
        futuresPnl += pnl;
        futuresInvested += (pos.quantity * pos.entryPrice);
        final currentValue = pos.margin + pnl;
        futuresValue += currentValue > 0 ? currentValue : 0;
      }
    }

    final totalNetWorth = userState.profile.virtualBalance + portfolioValue + futuresValue;
    final todayPnl = (portfolioValue - investedValue) + futuresPnl;

    final gainers = List.of(market)
      ..sort((a, b) => b.changePercentage.compareTo(a.changePercentage));
    final losers = List.of(market)
      ..sort((a, b) => a.changePercentage.compareTo(b.changePercentage));
    final watchlist = userState.profile.watchlist.toList();
    final level = (userState.profile.xp ~/ 250) + 1;
    final hasUnclaimedRewards = !userState.hasClaimedDaily || userState.missions.any((m) => m.progress >= m.target && !userState.profile.completedMissions.contains(m.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              physics: const ClampingScrollPhysics(),
              children: [

            // ── TOP BAR ─────────────────────────────────────────────────────
            RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppAvatar(
                            avatarUrl: userState.profile.photoUrl,
                            size: 32,
                            fallbackName: userState.profile.name,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: AnimatedUsernameText(
                              name: userState.profile.name,
                              level: userState.profile.level,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestMoneyScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.credit_card_rounded, color: Colors.black, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Top-Up'.tr(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsScreen())),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3BA2F).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.emoji_events, color: Color(0xFFF3BA2F), size: 12),
                              SizedBox(width: 4),
                              Text('Rewards', style: TextStyle(color: Color(0xFFF3BA2F), fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        if (hasUnclaimedRewards)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.loss,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationScreen()),
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.textPrimary,
                            size: 26,
                          ),
                          if (unreadNotifs > 0)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6465D),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.background,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

            // ── TOP CRYPTO AUTO-SCROLLING TICKER STRIP (ISOLATED CONST WIDGET) ──
            const RepaintBoundary(child: _AutoScrollingCryptoTicker()),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;

                // ── GAME MODES BANNER (PRO MINIMALIST FINTECH STYLE) ──────────────────────────
                final gameModesWidget = Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      // 1v1 Blitz Arena Card
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlitzDuelScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.outline, width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.outline, width: 1),
                                  ),
                                  child: const Icon(Icons.flash_on, color: AppColors.primary, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '1v1 Blitz Arena'.tr(),
                                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: -0.2),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${userState.profile.blitzRating} ELO • 3m Duel',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, color: AppColors.subtle, size: 12),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Weekly Championship Card
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TournamentScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.outline, width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.outline, width: 1),
                                  ),
                                  child: const Icon(Icons.emoji_events, color: Color(0xFFF3BA2F), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Weekly Cup',
                                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: -0.2),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Season #3 • 0.0% Base',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, color: AppColors.subtle, size: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                // ── AI SIGNALS & LEVERAGE DESK BANNER (TWITTER / X STYLE) ─────────────────────────
                final aiSignalsBanner = Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignalsScreen())),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.outline, width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.outline, width: 1),
                            ),
                            child: const Center(
                              child: Icon(Icons.auto_awesome, color: Color(0xFF1D9BF0), size: 19),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'AI Trade Signals & Analytics'.tr(),
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Live Buy/Sell signals • Safe Leverage desk'.tr(),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: Text(
                              'Explore'.tr(),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                final portfolioWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── PORTFOLIO SUMMARY ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'NET WORTH'.tr(),
                                style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1),
                              ),
                              const ArenaSwitcher(compact: true),
                            ],
                          ),
                          const SizedBox(height: 2),
                          BlurLoader(
                            isLoading: isAppLoading,
                            child: Text(
                              formatter.format(totalNetWorth),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                todayPnl >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                color: todayPnl >= 0 ? AppColors.profit : AppColors.loss,
                                size: 18,
                              ),
                              Text(
                                '${todayPnl >= 0 ? '+' : ''}${formatter.format(todayPnl)} ${'today'.tr()}',
                                style: TextStyle(
                                  color: todayPnl >= 0 ? AppColors.profit : AppColors.loss,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── 3-COL STATS ROW ──────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          _StatCell(
                            label: 'Cash',
                            value: formatter.format(userState.profile.virtualBalance),
                            isLoading: isAppLoading,
                          ),
                          _divider(),
                          _StatCell(
                            label: 'Spot Value',
                            value: formatter.format(portfolioValue),
                            isLoading: isAppLoading,
                          ),
                          _divider(),
                          _StatCell(
                            label: isStockMode ? 'Margin Value' : 'Futures Value',
                            value: formatter.format(isStockMode ? 0 : futuresValue),
                            isLoading: isAppLoading,
                          ),
                        ],
                      ),
                    ),

                    if (userState.profile.virtualBalance <= 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: InkWell(
                          onTap: () => ZeroBalanceRefillSheet.show(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.outline, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: AppColors.subtle, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Trading cash is empty',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C087).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF00C087).withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_arrow_rounded, color: Color(0xFF00C087), size: 13),
                                      SizedBox(width: 2),
                                      Text(
                                        'Free Refill',
                                        style: TextStyle(color: Color(0xFF00C087), fontSize: 11, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const _Divider(),

                    // ── XP BAR ──────────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: Text(
                              'Lv $level • ${userState.profile.evolvedTitle}',
                              style: const TextStyle(
                                  color: Color(0xFFF0B90B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: (userState.profile.xp % 250) / 250,
                                minHeight: 4,
                                backgroundColor: AppColors.surfaceAlt,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFF0B90B)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${userState.profile.xp} XP',
                            style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => DailyCheckInManager.showDailyDialog(context, ref),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 3),
                                Text(
                                  '${userState.profile.streak}',
                                  style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final marketWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isStockMode) ...[
                      _StockIndicesBanner(indices: stockIndices),
                      const SizedBox(height: 8),
                    ],
                    // ── MARKET TABLE: GAINERS ─────────────────────────────────────────
                    _SectionHeader(
                      title: 'Top Gainers',
                      onTap: null,
                    ),
                    _MarketTable(
                      stocks: gainers.take(5).toList(),
                      formatter: formatter,
                      onTap: (s) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockDetailScreen(stockSymbol: s.symbol),
                        ),
                      ),
                    ),

                    const _Divider(),

                    // ── MARKET TABLE: LOSERS ──────────────────────────────────────────
                    _SectionHeader(
                      title: 'Top Losers',
                      onTap: null,
                    ),
                    _MarketTable(
                      stocks: losers.take(5).toList(),
                      formatter: formatter,
                      onTap: (s) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockDetailScreen(stockSymbol: s.symbol),
                        ),
                      ),
                    ),

                    if (!isStockMode) ...[
                      const _Divider(),

                      // ── FUTURES OVERVIEW ──────────────────────────────────────────────
                      _SectionHeader(title: 'Futures Markets', onTap: null),
                      // Positions summary strip (Twitter / X Card Style)
                      if (userState.futuresPositions.isNotEmpty) ...[
                        Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.outline, width: 1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'OPEN POSITIONS'.tr(),
                                      style: const TextStyle(
                                        color: Color(0xFF71767B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${userState.futuresPositions.length}',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: AppColors.outline,
                                margin: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOTAL INVESTED',
                                      style: TextStyle(
                                        color: Color(0xFF71767B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        formatter.format(futuresInvested),
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: AppColors.outline,
                                margin: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'UNREALIZED P&L',
                                      style: TextStyle(
                                        color: Color(0xFF71767B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${futuresPnl >= 0 ? '+' : ''}${formatter.format(futuresPnl)}',
                                        style: TextStyle(
                                          color: futuresPnl >= 0 ? AppColors.profit : AppColors.loss,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _SectionHeader(
                        title: 'Futures Holdings',
                        onTap: null,
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      ),
                      ...userState.futuresPositions.map((pos) {
                        final stock = stockMap[pos.symbol] ?? cryptoMap[pos.symbol];
                        final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
                        final markPriceUsd = stock != null
                            ? (stock.currency == 'INR' ? (stock.currentPrice / inrRate) : stock.currentPrice)
                            : pos.entryPrice;
                        final isLong = pos.side == OrderSide.buy;
                        final diff = markPriceUsd - pos.entryPrice;
                        final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
                        final isProfit = pnl >= 0;

                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => FuturesProScreen(stockSymbol: pos.symbol)),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.outline, width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: (isLong ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: (isLong ? AppColors.profit : AppColors.loss).withValues(alpha: 0.35),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              isLong ? 'LONG ${pos.leverage}x' : 'SHORT ${pos.leverage}x',
                                              style: TextStyle(
                                                color: isLong ? AppColors.profit : AppColors.loss,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            pos.symbol,
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14.5,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Text(
                                            'Invested: ',
                                            style: TextStyle(color: Color(0xFF71767B), fontSize: 12),
                                          ),
                                          Text(
                                            formatter.format(pos.quantity * pos.entryPrice),
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatter.format(pos.margin + pnl > 0 ? pos.margin + pnl : 0),
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isProfit ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                            color: isProfit ? AppColors.profit : AppColors.loss,
                                            size: 16,
                                          ),
                                          Text(
                                            '${isProfit ? '+' : ''}${formatter.format(pnl)}',
                                            style: TextStyle(
                                              color: isProfit ? AppColors.profit : AppColors.loss,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                    _FuturesTable(
                      stocks: market.take(6).toList(),
                      formatter: formatter,
                      onTap: (s) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FuturesProScreen(stockSymbol: s.symbol),
                        ),
                      ),
                    ),
                  ],
                ],
              );

                if (isWide) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: portfolioWidget),
                        const SizedBox(width: 16),
                        Container(width: 1, height: 600, color: const Color(0xFF2B3139)), // Divider
                        const SizedBox(width: 16),
                        Expanded(flex: 6, child: marketWidget),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    portfolioWidget,
                    if (!isStockMode) gameModesWidget,
                    aiSignalsBanner,
                    const _Divider(),
                    marketWidget,
                  ],
                );
              },
            ),

            const _Divider(),

            // ── ACTIVE QUESTS (TWITTER / X STYLE) ────────────────────────────
            if (userState.missions.isNotEmpty) ...[
              _SectionHeader(
                title: 'Active Quests',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsScreen())),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: userState.missions.take(2).map((m) {
                    final safeTarget = m.target <= 0 ? 1 : m.target;
                    final progress = (m.progress / safeTarget).clamp(0.0, 1.0);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsScreen())),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: m.completed
                                  ? AppColors.profit.withValues(alpha: 0.4)
                                  : AppColors.outline,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Quest Title & Reward / Claim
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      m.title,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (m.completed)
                                    GestureDetector(
                                      onTap: () => ref.read(userProvider.notifier).claimMission(m.id),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3BA2F),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Claim!',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(alpha: 0.3),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        '+${m.reward} XP',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Middle: Modern Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 5,
                                  backgroundColor: AppColors.surfaceAlt,
                                  color: m.completed ? AppColors.profit : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 7),
                              // Bottom Row: Progress Counter & Percentage
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    m.completed
                                        ? 'Completed! Ready to claim'
                                        : '${m.progress} of ${m.target} completed',
                                    style: TextStyle(
                                      color: m.completed ? AppColors.profit : const Color(0xFF71767B),
                                      fontSize: 11.5,
                                      fontWeight: m.completed ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      color: Color(0xFF71767B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const _Divider(),
            ],

            // ── WATCHLIST ─────────────────────────────────────────────────────
            Builder(
              builder: (context) {
                final currentModeWatchlist = watchlist
                    .where((sym) => market.any((s) => s.symbol == sym))
                    .map((sym) => market.firstWhere((s) => s.symbol == sym))
                    .toList();

                if (currentModeWatchlist.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: 'Watchlist', onTap: null),
                    _MarketTable(
                      stocks: currentModeWatchlist,
                      formatter: formatter,
                      onTap: (s) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockDetailScreen(stockSymbol: s.symbol),
                        ),
                      ),
                    ),
                    const _Divider(),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: AppColors.outline,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );


}

// ─────────────────────────────────────────────────────────────────────────────
// AUTO SCROLLING CRYPTO TICKER STRIP
// ─────────────────────────────────────────────────────────────────────────────
class _AutoScrollingCryptoTicker extends ConsumerStatefulWidget {
  const _AutoScrollingCryptoTicker();

  @override
  ConsumerState<_AutoScrollingCryptoTicker> createState() => _AutoScrollingCryptoTickerState();
}

class _AutoScrollingCryptoTickerState extends ConsumerState<_AutoScrollingCryptoTicker> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      final isStocks = ref.read(marketModeProvider) == MarketMode.stocks;
      final marketLength = isStocks ? ref.read(stockMarketProvider).length : ref.read(marketProvider).length;
      if (mounted && marketLength > 0) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % marketLength;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStocks = ref.watch(marketModeProvider) == MarketMode.stocks;
    final market = isStocks ? ref.watch(stockMarketProvider) : ref.watch(marketProvider);
    final currency = ref.watch(userProvider.select((u) => u.profile.preferredCurrency));
    final formatter = AppCurrencyFormatter(currency);

    if (market.isEmpty) return const SizedBox.shrink();
    if (_currentIndex >= market.length) _currentIndex = 0;

    final stock = market[_currentIndex];
    final isPositive = stock.changePercentage >= 0;
    final color = isPositive ? AppColors.profit : AppColors.loss;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(
          top: BorderSide(color: AppColors.outline, width: 0.6),
          bottom: BorderSide(color: AppColors.outline, width: 0.6),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StockDetailScreen(stockSymbol: stock.symbol)),
        ),
        child: Row(
          children: [
            // Trending Icon alone
            const Icon(
              Icons.trending_up_rounded,
              color: Color(0xFF71767B),
              size: 16,
            ),
            const SizedBox(width: 8),

            // Animated Switcher for Coin Info
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Row(
                  key: ValueKey<String>(stock.symbol),
                  children: [
                    Text(
                      '${stock.symbol}/USDT',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      stock.isStock
                      ? (stock.currency == 'INR'
                          ? CurrencyFormatters.format(stock.currentPrice, formatter.currencyCode)
                          : CurrencyFormatters.formatUsd(stock.currentPrice, formatter.currencyCode))
                      : formatter.format(stock.currentPrice),
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          color: color,
                          size: 14,
                        ),
                        Text(
                          '${isPositive ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                          style: GoogleFonts.inter(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF71767B), size: 14),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT CELL
// ─────────────────────────────────────────────────────────────────────────────
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final bool isLoading;

  const _StatCell({
    required this.label,
    required this.value,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.tr(),
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          BlurLoader(
            isLoading: isLoading,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPARKLINE — lightweight CustomPainter (replaces fl_chart for perf)
// ─────────────────────────────────────────────────────────────────────────────
class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce(min);
    final maxV = values.reduce(max);
    final range = (maxV - minV).abs();
    // If price is essentially flat, draw a horizontal mid-line
    final effectiveRange = range < 1e-9 ? 1.0 : range;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minV) / effectiveRange) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth cubic bezier
        final prevX = ((i - 1) / (values.length - 1)) * size.width;
        final prevY = size.height - ((values[i - 1] - minV) / effectiveRange) * size.height;
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}


// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const _SectionHeader({required this.title, this.onTap, this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Text(
            title.tr(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Text(
                'View all'.tr(),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HORIZONTAL DIVIDER
// ─────────────────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.outline,
      margin: const EdgeInsets.only(top: 16),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARKET TABLE — Zerodha-style compact rows with sparkline
// ─────────────────────────────────────────────────────────────────────────────
class _MarketTable extends StatelessWidget {
  final List<Stock> stocks;
  final AppCurrencyFormatter formatter;
  final void Function(Stock) onTap;

  const _MarketTable({
    required this.stocks,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Column headers
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: const [
              Expanded(flex: 5, child: _ColHeader('SYMBOL')),
              Expanded(flex: 4, child: _ColHeader('PRICE', align: TextAlign.right)),
              SizedBox(width: 60, child: _ColHeader('CHART', align: TextAlign.center)),
              Expanded(flex: 3, child: _ColHeader('24H %', align: TextAlign.right)),
            ],
          ),
        ),
        ...stocks.map((s) => _MarketRow(
              stock: s,
              formatter: formatter,
              onTap: () => onTap(s),
            )),
      ],
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _ColHeader(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.tr(),
      textAlign: align,
      style: const TextStyle(
          color: Color(0xFF4B5563), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );
  }
}

class _MarketRow extends StatelessWidget {
  final Stock stock;
  final AppCurrencyFormatter formatter;
  final VoidCallback onTap;

  const _MarketRow({
    required this.stock,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final good = stock.changePercentage >= 0;
    final color = good ? AppColors.profit : AppColors.loss;
    final hasHistory = stock.history.length >= 2;

    return RepaintBoundary(
      child: InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.03),
      highlightColor: Colors.white.withValues(alpha: 0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Symbol
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  CoinIcon(symbol: stock.symbol, size: 32),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.symbol,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          stock.name,
                          style: TextStyle(
                              color: AppColors.subtle, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Price
            Expanded(
              flex: 4,
              child: stock.currentPrice == 0
                  ? const Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.2, color: AppColors.primary),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        stock.isStock
                            ? (stock.currency == 'INR'
                                ? CurrencyFormatters.format(stock.currentPrice, formatter.currencyCode)
                                : CurrencyFormatters.formatUsd(stock.currentPrice, formatter.currencyCode))
                            : formatter.format(stock.currentPrice),
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
            ),
            // Sparkline — uses CustomPainter, not fl_chart, for performance
            SizedBox(
              width: 60,
              height: 32,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: hasHistory
                    ? CustomPaint(
                        painter: _SparklinePainter(
                          values: stock.history,
                          color: color,
                        ),
                      )
                    : Center(
                        child: Container(
                          height: 1,
                          color: AppColors.outline,
                        ),
                      ),
              ),
            ),
            // % Change
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: stock.currentPrice == 0
                        ? AppColors.surfaceAlt
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    stock.currentPrice == 0
                        ? '—'
                        : '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                    style: TextStyle(
                        color: stock.currentPrice == 0
                            ? AppColors.subtle
                            : color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

// ─────────────────────────────────────────────────────────────────────────────
// FUTURES TABLE
// ─────────────────────────────────────────────────────────────────────────────
class _FuturesTable extends StatelessWidget {
  final List<Stock> stocks;
  final AppCurrencyFormatter formatter;
  final void Function(Stock) onTap;

  const _FuturesTable({
    required this.stocks,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: const [
              Expanded(flex: 5, child: _ColHeader('CONTRACT')),
              Expanded(flex: 4, child: _ColHeader('PRICE', align: TextAlign.right)),
              Expanded(flex: 3, child: _ColHeader('24H %', align: TextAlign.right)),
              Expanded(flex: 2, child: _ColHeader('LEV', align: TextAlign.right)),
            ],
          ),
        ),
        ...stocks.map((s) => _FuturesRow(
              stock: s,
              formatter: formatter,
              onTap: () => onTap(s),
            )),
      ],
    );
  }
}

class _FuturesRow extends StatelessWidget {
  final Stock stock;
  final AppCurrencyFormatter formatter;
  final VoidCallback onTap;

  const _FuturesRow({
    required this.stock,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final good = stock.changePercentage >= 0;
    final color = good ? AppColors.profit : AppColors.loss;

    return RepaintBoundary(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.03),
        highlightColor: Colors.white.withValues(alpha: 0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Contract name
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  CoinIcon(symbol: stock.symbol, size: 22),
                  const SizedBox(width: 8),
                  if (stock.isStock) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        '5x',
                        style: TextStyle(
                            color: Color(0xFF60A5FA),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      '${stock.symbol}/${formatter.currencyCode ?? 'USD'}',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Price
            Expanded(
              flex: 4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  stock.isStock
                      ? (stock.currency == 'INR'
                          ? CurrencyFormatters.format(stock.currentPrice, formatter.currencyCode)
                          : CurrencyFormatters.formatUsd(stock.currentPrice, formatter.currencyCode))
                      : formatter.format(stock.currentPrice),
                  style: TextStyle(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            // % Change
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // Leverage
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '100x',
                  style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
class BlurLoader extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  
  const BlurLoader({super.key, required this.child, required this.isLoading});

  @override
  State<BlurLoader> createState() => _BlurLoaderState();
}

class _BlurLoaderState extends State<BlurLoader> with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(BlurLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _startAnimation();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _stopAnimation();
    }
  }

  void _startAnimation() {
    _ctrl ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _ctrl!.repeat(reverse: true);
  }

  void _stopAnimation() {
    _ctrl?.stop();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_ctrl!.value * 0.7),
          child: widget.child,
        );
      },
    );
  }
}

class _StockIndicesBanner extends StatelessWidget {
  final List<Stock> indices;
  const _StockIndicesBanner({required this.indices});

  @override
  Widget build(BuildContext context) {
    if (indices.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // On small screens (< 390px), use a smooth horizontal scroll so cards never cramp.
        // On medium & large screens (>= 390px), stretch cards evenly across the row.
        final isSmallScreen = constraints.maxWidth < 390;

        if (isSmallScreen) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: indices.asMap().entries.map((entry) {
                final i = entry.key;
                final idx = entry.value;
                return Padding(
                  padding: EdgeInsets.only(right: i < indices.length - 1 ? 10 : 0),
                  child: SizedBox(
                    width: 132,
                    child: _buildIndexCard(context, idx),
                  ),
                );
              }).toList(),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: indices.asMap().entries.map((entry) {
              final i = entry.key;
              final idx = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < indices.length - 1 ? 8 : 0),
                  child: _buildIndexCard(context, idx),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildIndexCard(BuildContext context, Stock idx) {
    final isPos = idx.changePercentage >= 0;
    final color = isPos ? const Color(0xFF0ECB81) : const Color(0xFFF6465D);
    final curr = idx.currency == 'INR' ? '₹' : '\$';
    String displayName = idx.name.replaceAll(' Composite', '');
    if (displayName.contains('Dow')) {
      displayName = 'DOW 30';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockDetailScreen(stockSymbol: idx.symbol)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.subtle,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${isPos ? "+" : ""}${idx.changePercentage.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$curr${idx.currentPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopRankBadge extends ConsumerStatefulWidget {
  final String userName;
  const TopRankBadge({super.key, required this.userName});

  @override
  ConsumerState<TopRankBadge> createState() => _TopRankBadgeState();
}

class _TopRankBadgeState extends ConsumerState<TopRankBadge> {
  late final Stream<QuerySnapshot> _usersStream;
  int? _cachedRank;
  int _lastDocCount = -1;

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  int _calculateRank(List<QueryDocumentSnapshot> docs) {
    if (_cachedRank != null && docs.length == _lastDocCount) {
      return _cachedRank!;
    }
    _lastDocCount = docs.length;

    final market = ref.read(marketProvider);
    final priceMap = {for (final s in market) s.symbol: s.currentPrice};

    final players = <Map<String, dynamic>>[];
    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final state = UserState.fromJson(data);
        if (state.profile.email == 'admin@gmail.com' || state.profile.name.toLowerCase().contains('admin')) continue;
        
        double portfolioValue = 0;
        for (final holding in state.holdings) {
          final p = priceMap[holding.symbol] ?? holding.averagePrice;
          portfolioValue += p * holding.quantity;
        }
        double futuresValue = 0;
        for (final pos in state.futuresPositions) {
          final p = priceMap[pos.symbol] ?? pos.entryPrice;
          final isLong = pos.side == OrderSide.buy;
          final diff = p - pos.entryPrice;
          final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
          final currentValue = pos.margin + pnl;
          futuresValue += currentValue > 0 ? currentValue : 0;
        }
        players.add({
          'name': state.profile.name,
          'netWorth': state.profile.virtualBalance + portfolioValue + futuresValue,
        });
      } catch (_) {}
    }

    players.sort((a, b) => (b['netWorth'] as double).compareTo(a['netWorth'] as double));

    for (int i = 0; i < players.length; i++) {
      if (players[i]['name'] == widget.userName) {
        return i + 1;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final rank = _calculateRank(snapshot.data!.docs);

        if (rank == 1) {
          return const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.emoji_events, color: Color(0xFFFBBF24), size: 16));
        } else if (rank == 2) {
          return const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.emoji_events, color: Color(0xFFE2E8F0), size: 16));
        } else if (rank == 3) {
          return const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.emoji_events, color: Color(0xFFF97316), size: 16));
        }
        return const SizedBox.shrink();
      },
    );
  }
}

