import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_theme.dart';
import '../../core/coin_icon.dart';
import '../../core/currency_formatters.dart';
import '../../core/update_manager.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../futures/futures_pro_screen.dart';
import '../profile/profile_screen.dart';
import '../stock_detail/stock_detail_screen.dart';
import '../rewards/rewards_screen.dart';
import '../blitz/blitz_duel_screen.dart';
import '../tournaments/tournament_screen.dart';
import '../profile/request_money_screen.dart';
import '../signals/signals_screen.dart';
import '../../core/topup_offer_manager.dart';
import '../../core/championship_prize_manager.dart';
import '../../core/daily_checkin_manager.dart';
import '../../data/notification_provider.dart';
import '../notifications/notification_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InAppUpdateManager.checkForUpdates(context);
      TopUpOfferManager.checkAndShowOffer(context);
      ChampionshipPrizeManager.checkAndShowClaimDialog(context, ref);
      DailyCheckInManager.checkAndShowDailyDialog(context, ref);
    });

    final userState = ref.watch(userProvider);
    final market = ref.watch(marketProvider);
    final notifState = ref.watch(notificationProvider);
    final unreadNotifs = notifState.unreadCount;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    final isMarketLoading = market.isEmpty || market.first.currentPrice == 0;
    final isAppLoading = userState.isLoading || isMarketLoading;

    final marketMap = {for (final s in market) s.symbol: s};

    double portfolioValue = 0;
    double investedValue = 0;
    if (!isMarketLoading) {
      for (final h in userState.holdings) {
        final s = marketMap[h.symbol];
        if (s != null) {
          portfolioValue += s.currentPrice * h.quantity;
          investedValue += h.averagePrice * h.quantity;
        }
      }
    }

    double futuresPnl = 0;
    double futuresInvested = 0;
    double futuresValue = 0;
    if (!isMarketLoading) {
      for (final pos in userState.futuresPositions) {
        final s = marketMap[pos.symbol];
        if (s != null) {
          final isLong = pos.side == OrderSide.buy;
          final diff = s.currentPrice - pos.entryPrice;
          final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
          futuresPnl += pnl;
          futuresInvested += (pos.quantity * pos.entryPrice);
          final currentValue = pos.margin + pnl;
          futuresValue += currentValue > 0 ? currentValue : 0;
        }
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
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E2329),
                            shape: BoxShape.circle,
                          ),
                          child: userState.profile.photoUrl.isNotEmpty
                              ? ClipOval(child: Image.network(userState.profile.photoUrl, fit: BoxFit.cover))
                              : Center(
                                  child: Text(
                                    userState.profile.name.isNotEmpty
                                        ? userState.profile.name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          userState.profile.name.split(' ').first,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestMoneyScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.credit_card_rounded, color: Colors.black, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Top-Up',
                            style: TextStyle(
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
                          const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
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
                              color: const Color(0xFF16181C),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF2F3336), width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF000000),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF2F3336), width: 1),
                                  ),
                                  child: const Icon(Icons.flash_on, color: AppColors.primary, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        '1v1 Blitz Arena',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: -0.2),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${userState.profile.blitzRating} ELO • 3m Duel',
                                        style: const TextStyle(color: Color(0xFF71767B), fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF71767B), size: 12),
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
                              color: const Color(0xFF16181C),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF2F3336), width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF000000),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF2F3336), width: 1),
                                  ),
                                  child: const Icon(Icons.emoji_events, color: Color(0xFFF3BA2F), size: 18),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Weekly Cup',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: -0.2),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Season #3 • 0.0% Base',
                                        style: TextStyle(color: Color(0xFF71767B), fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF71767B), size: 12),
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
                        color: const Color(0xFF16181C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2F3336), width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF000000),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF2F3336), width: 1),
                            ),
                            child: const Center(
                              child: Icon(Icons.auto_awesome, color: Color(0xFF1D9BF0), size: 19),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'AI Trade Signals & Advisor',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Live Buy/Sell signals • Safe Leverage desk',
                                  style: TextStyle(
                                    color: Color(0xFF71767B),
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
                              color: const Color(0xFFEFF3F4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Explore',
                              style: TextStyle(
                                color: Color(0xFF0F141C),
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
                          const Text(
                            'NET WORTH',
                            style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1),
                          ),
                          const SizedBox(height: 2),
                          BlurLoader(
                            isLoading: isAppLoading,
                            child: Text(
                              formatter.format(totalNetWorth),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
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
                                '${todayPnl >= 0 ? '+' : ''}${formatter.format(todayPnl)} today',
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
                            label: 'Futures Value',
                            value: formatter.format(futuresValue),
                            isLoading: isAppLoading,
                          ),
                        ],
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
                              color: const Color(0xFF1E2329),
                              borderRadius: BorderRadius.circular(3),
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
                                backgroundColor: const Color(0xFF1E2329),
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
                          Row(
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
                        ],
                      ),
                    ),
                  ],
                );

                final marketWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            color: const Color(0xFF16181C),
                            border: Border.all(color: const Color(0xFF2F3336), width: 1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'OPEN POSITIONS',
                                      style: TextStyle(
                                        color: Color(0xFF71767B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${userState.futuresPositions.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
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
                                color: const Color(0xFF2F3336),
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
                                        style: const TextStyle(
                                          color: Colors.white,
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
                                color: const Color(0xFF2F3336),
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
                        final stock = market.firstWhere((s) => s.symbol == pos.symbol, orElse: () => market.first);
                        final isLong = pos.side == OrderSide.buy;
                        final diff = stock.currentPrice - pos.entryPrice;
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
                                color: const Color(0xFF16181C),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF2F3336), width: 1),
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
                                            '${pos.symbol} PERP',
                                            style: const TextStyle(
                                              color: Colors.white,
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
                                            style: const TextStyle(
                                              color: Color(0xFFE7E9EA),
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
                                        style: const TextStyle(
                                          color: Colors.white,
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
                    gameModesWidget,
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
                            color: const Color(0xFF16181C),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: m.completed
                                  ? AppColors.profit.withValues(alpha: 0.4)
                                  : const Color(0xFF2F3336),
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
                                      style: const TextStyle(
                                        color: Colors.white,
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
                                  backgroundColor: const Color(0xFF202327),
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
            if (watchlist.isNotEmpty) ...[
              _SectionHeader(title: 'Watchlist', onTap: null),
              _MarketTable(
                stocks: watchlist
                    .map((sym) => market.firstWhere((s) => s.symbol == sym,
                        orElse: () => market.first))
                    .toList(),
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
        color: const Color(0xFF2B3139),
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
      final marketLength = ref.read(marketProvider).length;
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
    final market = ref.read(marketProvider);
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
      decoration: const BoxDecoration(
        color: Color(0xFF16181C),
        border: Border(
          top: BorderSide(color: Color(0xFF262D35), width: 0.6),
          bottom: BorderSide(color: Color(0xFF262D35), width: 0.6),
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
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatter.format(stock.currentPrice),
                      style: GoogleFonts.inter(
                        color: Colors.white,
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
  final Color? valueColor;
  final bool isLoading;

  const _StatCell({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          BlurLoader(
            isLoading: isLoading,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
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
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Text(
                'View all',
                style: TextStyle(
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
      color: const Color(0xFF1E2329),
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
      text,
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
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          stock.name,
                          style: const TextStyle(
                              color: Color(0xFF4B5563), fontSize: 10),
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
                        formatter.format(stock.currentPrice),
                        style: const TextStyle(
                            color: Colors.white,
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
                          color: const Color(0xFF2B3139),
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
                        ? const Color(0xFF1E2329)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    stock.currentPrice == 0
                        ? '—'
                        : '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                    style: TextStyle(
                        color: stock.currentPrice == 0
                            ? const Color(0xFF4B5563)
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F28),
                      border: Border.all(color: const Color(0xFF2B3139)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'PERP',
                      style: TextStyle(
                          color: Color(0xFFF0B90B),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${stock.symbol}/${formatter.currencyCode ?? 'USD'}',
                      style: const TextStyle(
                          color: Colors.white,
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
                  formatter.format(stock.currentPrice),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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




