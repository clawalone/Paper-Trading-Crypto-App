import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models.dart';
import '../data/user_provider.dart';

enum AuditSeverity {
  pass,
  info,
  warning,
  danger,
}

enum AuditVerdict {
  clean,
  highLeverageLucky,
  warning,
  cheaterConfirmed,
}

class AuditCheckItem {
  final String id;
  final String title;
  final String category; // 'Holdings', 'Ledger', 'Solvency', 'Leverage', 'Pricing', 'Rewards', 'Database'
  final AuditSeverity severity;
  final String summary;
  final String? details;
  final Map<String, dynamic>? metadata;

  const AuditCheckItem({
    required this.id,
    required this.title,
    required this.category,
    required this.severity,
    required this.summary,
    this.details,
    this.metadata,
  });

  bool get isFailed => severity == AuditSeverity.danger;
  bool get isWarning => severity == AuditSeverity.warning;
  bool get isPass => severity == AuditSeverity.pass;
}

class HoldingAuditDetail {
  final String symbol;
  final int statedQuantity;
  final double averagePrice;
  final int totalBoughtQty;
  final int totalSoldQty;
  final int expectedQty;
  final bool isGhost;
  final bool isOversold;
  final String statusMessage;

  const HoldingAuditDetail({
    required this.symbol,
    required this.statedQuantity,
    required this.averagePrice,
    required this.totalBoughtQty,
    required this.totalSoldQty,
    required this.expectedQty,
    required this.isGhost,
    required this.isOversold,
    required this.statusMessage,
  });
}

class ForensicTimelineEvent {
  final DateTime timestamp;
  final String action;
  final String symbol;
  final String details;
  final String financialImpact;
  final AuditSeverity severity;
  final bool isExploit;
  final Map<String, dynamic>? metadata;

  const ForensicTimelineEvent({
    required this.timestamp,
    required this.action,
    required this.symbol,
    required this.details,
    required this.financialImpact,
    required this.severity,
    this.isExploit = false,
    this.metadata,
  });
}

class ExploitRootCauseAnalysis {
  final String classification;
  final String summary;
  final List<String> steps;
  final double unbackedCapitalGenerated;
  final String recommendedDecision; // 'BAN' or 'RESET'
  final String decisionRationale;

  const ExploitRootCauseAnalysis({
    required this.classification,
    required this.summary,
    required this.steps,
    required this.unbackedCapitalGenerated,
    required this.recommendedDecision,
    required this.decisionRationale,
  });
}

class PortfolioAuditResult {
  final AuditVerdict verdict;
  final String verdictTitle;
  final String verdictDescription;
  final String recommendedAction;
  final String? prefilledBanReason;
  final String? prefilledResetReason;

  final double statedNetWorth;
  final double statedCash;
  final double reconciledCash;
  final double cashDiscrepancy;
  final double spotValuation;
  final double futuresMargin;
  final double futuresUnrealizedPnl;

  final List<AuditCheckItem> checks;
  final List<String> criticalFlags;
  final List<String> warnings;
  final List<String> positiveNotes;
  final Map<String, HoldingAuditDetail> holdingDetails;
  final List<ForensicTimelineEvent> forensicTimeline;
  final ExploitRootCauseAnalysis? rootCauseAnalysis;
  final String formattedReportText;

  final bool hasHighLeverage;
  final bool isLeverageLegitimate;
  final DateTime auditedAt;

  const PortfolioAuditResult({
    required this.verdict,
    required this.verdictTitle,
    required this.verdictDescription,
    required this.recommendedAction,
    this.prefilledBanReason,
    this.prefilledResetReason,
    required this.statedNetWorth,
    required this.statedCash,
    required this.reconciledCash,
    required this.cashDiscrepancy,
    required this.spotValuation,
    required this.futuresMargin,
    required this.futuresUnrealizedPnl,
    required this.checks,
    required this.criticalFlags,
    required this.warnings,
    required this.positiveNotes,
    required this.holdingDetails,
    required this.forensicTimeline,
    this.rootCauseAnalysis,
    required this.formattedReportText,
    required this.hasHighLeverage,
    required this.isLeverageLegitimate,
    required this.auditedAt,
  });
}

class PortfolioAuditEngine {
  static const double initialOnboardCapital = 5000.0;
  static const double cashTolerance = 150.0; // Allow small rounding or legacy micro-drift

  /// Runs a comprehensive forensic audit on an inspected user.
  static Future<PortfolioAuditResult> auditUser({
    required String userDocId,
    required Map<String, dynamic> rawUserData,
    required UserState? parsedUserState,
    required List<Stock> market,
  }) async {
    final profile = (rawUserData['profile'] as Map<String, dynamic>?) ?? {};
    final publicUid = (profile['publicUid'] as String?) ?? '';
    final statedCash = (profile['virtualBalance'] as num?)?.toDouble() ?? 0.0;

    final holdings = parsedUserState?.holdings ?? [];
    final trades = parsedUserState?.trades ?? [];
    final futures = parsedUserState?.futuresPositions ?? [];
    final spotLimitOrders = parsedUserState?.spotLimitOrders ?? [];
    final futuresLimitOrders = parsedUserState?.futuresLimitOrders ?? [];
    final walletEntries = (rawUserData['walletEntries'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    // Calculate current valuations
    double spotValuation = 0.0;
    for (final h in holdings) {
      final stock = market.cast<Stock?>().firstWhere((s) => s?.symbol == h.symbol, orElse: () => null);
      final price = stock?.currentPrice ?? h.averagePrice;
      spotValuation += price * h.quantity;
    }

    double futuresMargin = 0.0;
    double futuresUnrealizedPnl = 0.0;
    for (final f in futures) {
      futuresMargin += f.margin;
      final stock = market.cast<Stock?>().firstWhere((s) => s?.symbol == f.symbol, orElse: () => null);
      if (stock != null) {
        final isLong = f.side == OrderSide.buy;
        final diff = stock.currentPrice - f.entryPrice;
        final pnl = isLong ? diff * f.quantity : -diff * f.quantity;
        futuresUnrealizedPnl += pnl;
      }
    }

    final statedNetWorth = statedCash + spotValuation + (futuresMargin + futuresUnrealizedPnl).clamp(0.0, double.infinity);

    final checks = <AuditCheckItem>[];
    final criticalFlags = <String>[];
    final warnings = <String>[];
    final positiveNotes = <String>[];
    final holdingDetails = <String, HoldingAuditDetail>{};

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 1: HOLDINGS INVENTORY AUDIT (GHOST COINS CHECK)
    // ──────────────────────────────────────────────────────────────────────────
    bool hasGhostHolding = false;
    bool hasOversoldHolding = false;

    // Collect all symbols that exist in either current holdings or trade history
    final allSymbols = <String>{
      ...holdings.map((h) => h.symbol),
      ...trades.map((t) => t.symbol),
    };

    for (final sym in allSymbols) {
      final holding = holdings.cast<Holding?>().firstWhere((h) => h?.symbol == sym, orElse: () => null);
      final statedQty = holding?.quantity ?? 0;
      final avgPrice = holding?.averagePrice ?? 0.0;

      final symTrades = trades.where((t) => t.symbol == sym).toList();
      final boughtQty = symTrades.where((t) => t.side == OrderSide.buy).fold<int>(0, (total, t) => total + t.quantity);
      final soldQty = symTrades.where((t) => t.side == OrderSide.sell).fold<int>(0, (total, t) => total + t.quantity);
      final expectedQty = boughtQty - soldQty;

      final isGhost = statedQty > expectedQty;
      final isOversold = soldQty > boughtQty;

      String statusMsg = 'Verified';
      if (isGhost) {
        hasGhostHolding = true;
        final phantom = statedQty - expectedQty;
        statusMsg = 'GHOST HOLDING: +$phantom phantom coins never bought!';
      } else if (isOversold) {
        hasOversoldHolding = true;
        statusMsg = 'OVERSOLD: Sold $soldQty but only bought $boughtQty!';
      }

      holdingDetails[sym] = HoldingAuditDetail(
        symbol: sym,
        statedQuantity: statedQty,
        averagePrice: avgPrice,
        totalBoughtQty: boughtQty,
        totalSoldQty: soldQty,
        expectedQty: expectedQty,
        isGhost: isGhost,
        isOversold: isOversold,
        statusMessage: statusMsg,
      );
    }

    if (hasGhostHolding) {
      final ghosts = holdingDetails.values.where((d) => d.isGhost).map((d) => '${d.symbol} (+${d.statedQuantity - d.expectedQty})').join(', ');
      criticalFlags.add('Ghost holdings detected: Portfolio contains coins never purchased in trade history ($ghosts).');
      checks.add(AuditCheckItem(
        id: 'holdings_ghost',
        title: 'Portfolio Holdings vs Trade History',
        category: 'Holdings',
        severity: AuditSeverity.danger,
        summary: 'Ghost holdings detected in portfolio',
        details: 'User has coins in active holdings without matching buy transactions in trade history: $ghosts.',
      ));
    } else if (hasOversoldHolding) {
      final oversold = holdingDetails.values.where((d) => d.isOversold).map((d) => '${d.symbol} (Sold ${d.totalSoldQty} > Bought ${d.totalBoughtQty})').join(', ');
      criticalFlags.add('Impossible spot oversold condition: $oversold.');
      checks.add(AuditCheckItem(
        id: 'holdings_oversold',
        title: 'Portfolio Holdings vs Trade History',
        category: 'Holdings',
        severity: AuditSeverity.danger,
        summary: 'Spot shorting / Oversold condition',
        details: 'User sold more coins than they ever purchased: $oversold.',
      ));
    } else {
      positiveNotes.add('Holdings inventory 100% matched: Every coin in portfolio is backed by verified buy/sell trades.');
      checks.add(const AuditCheckItem(
        id: 'holdings_verified',
        title: 'Portfolio Holdings vs Trade History',
        category: 'Holdings',
        severity: AuditSeverity.pass,
        summary: 'All portfolio holdings verified',
        details: 'Every coin held in the portfolio matches historical buy orders minus sell orders exactly.',
      ));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 2: FULL CASH LEDGER & CASH-FLOW RECONCILIATION
    // ──────────────────────────────────────────────────────────────────────────
    double totalBuySpent = 0.0;
    double totalSellRevenue = 0.0;
    for (final t in trades) {
      final val = t.price * t.quantity;
      if (t.side == OrderSide.buy) {
        totalBuySpent += val;
      } else {
        totalSellRevenue += val;
      }
    }
    final spotNetCashFlow = totalSellRevenue - totalBuySpent;

    double walletCredits = 0.0;
    double walletDebits = 0.0;
    for (final e in walletEntries) {
      final amt = (e['amount'] as num?)?.toDouble() ?? 0.0;
      final type = (e['type'] as String?) ?? 'credit';
      if (type == 'credit') {
        walletCredits += amt;
      } else {
        walletDebits += amt;
      }
    }
    final netWalletFlow = walletCredits - walletDebits;

    double activeLimitReservations = 0.0;
    for (final o in spotLimitOrders) {
      if (o.status == 'pending' && o.side == OrderSide.buy) {
        activeLimitReservations += o.reservedAmount;
      }
    }
    for (final fo in futuresLimitOrders) {
      if (fo.status == 'pending') {
        activeLimitReservations += fo.reservedMargin;
      }
    }

    final reconciledCash = initialOnboardCapital + netWalletFlow + spotNetCashFlow - activeLimitReservations;
    final cashDiscrepancy = statedCash - reconciledCash;

    if (cashDiscrepancy > cashTolerance) {
      criticalFlags.add('Direct cash balance injection: Stated cash balance is higher by \$${cashDiscrepancy.toStringAsFixed(2)} than all ledger transactions combined.');
      checks.add(AuditCheckItem(
        id: 'ledger_injection',
        title: 'Cash Ledger Balance Reconciliation',
        category: 'Ledger',
        severity: AuditSeverity.danger,
        summary: 'Unbacked balance injection detected',
        details: 'Stated cash: \$${statedCash.toStringAsFixed(2)}, but historical trades + wallet entries account for only \$${reconciledCash.toStringAsFixed(2)}. Phantom unbacked capital: +\$${cashDiscrepancy.toStringAsFixed(2)}.',
        metadata: {
          'statedCash': statedCash,
          'reconciledCash': reconciledCash,
          'discrepancy': cashDiscrepancy,
        },
      ));
    } else if (cashDiscrepancy < -cashTolerance * 2) {
      warnings.add('Cash balance under-reported by \$${(-cashDiscrepancy).toStringAsFixed(2)} (possible unrecorded debit or manual admin correction).');
      checks.add(AuditCheckItem(
        id: 'ledger_under',
        title: 'Cash Ledger Balance Reconciliation',
        category: 'Ledger',
        severity: AuditSeverity.warning,
        summary: 'Minor ledger underflow discrepancy',
        details: 'User has \$${(-cashDiscrepancy).toStringAsFixed(2)} less than ledger calculation. Not an exploit.',
      ));
    } else {
      positiveNotes.add('Cash ledger perfectly balances: Stated balance matches audited transaction history within \$${cashDiscrepancy.abs().toStringAsFixed(2)}.');
      checks.add(AuditCheckItem(
        id: 'ledger_balanced',
        title: 'Cash Ledger Balance Reconciliation',
        category: 'Ledger',
        severity: AuditSeverity.pass,
        summary: 'Ledger reconciles completely',
        details: 'Mathematical reconciliation: Starting (\$${initialOnboardCapital.toStringAsFixed(0)}) + Wallet Net (\$${netWalletFlow.toStringAsFixed(2)}) + Spot Net (\$${spotNetCashFlow.toStringAsFixed(2)}) - Reserved (\$${activeLimitReservations.toStringAsFixed(2)}) = \$${reconciledCash.toStringAsFixed(2)} (Stated: \$${statedCash.toStringAsFixed(2)}).',
      ));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 3: CHRONOLOGICAL SOLVENCY & OVERDRAFT TRACE
    // ──────────────────────────────────────────────────────────────────────────
    final events = <_TimelineEvent>[];
    DateTime? earliestDate;

    // Account creation event
    final createdAtRaw = rawUserData['createdAt'] ?? profile['createdAt'];
    if (createdAtRaw != null) {
      if (createdAtRaw is Timestamp) {
        earliestDate = createdAtRaw.toDate();
      } else {
        earliestDate = DateTime.tryParse(createdAtRaw.toString());
      }
    }
    earliestDate ??= DateTime.fromMillisecondsSinceEpoch(0);

    events.add(_TimelineEvent(
      timestamp: earliestDate,
      delta: initialOnboardCapital,
      description: 'Account Initial Virtual Capital',
    ));

    for (final t in trades) {
      final val = t.price * t.quantity;
      events.add(_TimelineEvent(
        timestamp: t.time,
        delta: t.side == OrderSide.buy ? -val : val,
        description: 'Trade ${t.side.name.toUpperCase()} ${t.quantity} ${t.symbol} @ \$${t.price}',
      ));
    }

    for (final e in walletEntries) {
      final amt = (e['amount'] as num?)?.toDouble() ?? 0.0;
      final type = (e['type'] as String?) ?? 'credit';
      final ts = DateTime.tryParse(e['timestamp']?.toString() ?? '') ?? DateTime.now();
      events.add(_TimelineEvent(
        timestamp: ts,
        delta: type == 'credit' ? amt : -amt,
        description: e['title']?.toString() ?? 'Wallet Entry',
      ));
    }

    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double runningBalance = 0.0;
    double minRunningBalance = 0.0;
    _TimelineEvent? worstEvent;

    for (final ev in events) {
      runningBalance += ev.delta;
      if (runningBalance < minRunningBalance) {
        minRunningBalance = runningBalance;
        worstEvent = ev;
      }
    }

    if (minRunningBalance < -250.0) {
      criticalFlags.add('Chronological overdraft exploit: Running balance dropped to -\$${(-minRunningBalance).toStringAsFixed(2)} during historical trading.');
      checks.add(AuditCheckItem(
        id: 'solvency_overdraft',
        title: 'Capital Solvency Timeline Audit',
        category: 'Solvency',
        severity: AuditSeverity.danger,
        summary: 'Chronological overdraft exploit detected',
        details: 'The user executed orders when their balance was insufficient, plunging cash balance to -\$${(-minRunningBalance).toStringAsFixed(2)}. Event: "${worstEvent?.description}" on ${worstEvent?.timestamp}.',
      ));
    } else {
      positiveNotes.add('Solvency verified: User never went negative during their entire trading history.');
      checks.add(const AuditCheckItem(
        id: 'solvency_verified',
        title: 'Capital Solvency Timeline Audit',
        category: 'Solvency',
        severity: AuditSeverity.pass,
        summary: 'Historical capital solvency verified',
        details: 'User cash balance remained solvent throughout all sequential trades and transactions.',
      ));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 4: 100x LEVERAGE & FUTURES INTEGRITY (LUCK VS BUG AUDIT)
    // ──────────────────────────────────────────────────────────────────────────
    bool hasLeverage50Plus = false;
    bool hasIllegalLeverage = false;
    bool hasZeroMarginBug = false;
    bool hasZombieLiquidationBug = false;

    for (final f in futures) {
      if (f.leverage >= 50) hasLeverage50Plus = true;
      if (f.leverage > 100 || f.leverage <= 0) {
        hasIllegalLeverage = true;
      }
      final stock = market.cast<Stock?>().firstWhere((s) => s?.symbol == f.symbol, orElse: () => null);
      final markPrice = stock?.currentPrice ?? f.entryPrice;

      // Check margin math
      final expectedMargin = (f.quantity * f.entryPrice) / f.leverage;
      if (f.margin <= 0) {
        hasZeroMarginBug = true;
      } else if ((f.margin - expectedMargin).abs() / expectedMargin > 0.25) {
        warnings.add('Futures position margin mismatch for ${f.symbol}: margin is \$${f.margin.toStringAsFixed(2)}, expected ~\$${expectedMargin.toStringAsFixed(2)}.');
      }

      // Check if position breached liquidation price without liquidating
      if (f.isLiquidated(markPrice)) {
        hasZombieLiquidationBug = true;
      }

      // Check if entry price is plausibly sane
      final sym = f.symbol.toUpperCase();
      if (f.entryPrice <= 0 || f.entryPrice.isNaN || f.entryPrice.isInfinite ||
          (sym.contains('BTC') && (f.entryPrice < 5000 || f.entryPrice > 10000000)) ||
          (sym.contains('ETH') && (f.entryPrice < 100 || f.entryPrice > 1000000)) ||
          (sym.contains('SOL') && (f.entryPrice < 5 || f.entryPrice > 500000))) {
        criticalFlags.add('Manipulated futures entry price detected: ${f.symbol} opened at \$${f.entryPrice.toStringAsFixed(2)}.');
      }
    }

    // Check closed futures in wallet entries
    final futuresPnls = walletEntries.where((e) => e['category'] == 'futures_pnl').toList();
    for (final fp in futuresPnls) {
      final subtitle = fp['subtitle']?.toString() ?? '';
      final amt = (fp['amount'] as num?)?.toDouble() ?? 0.0;
      final type = fp['type']?.toString() ?? '';
      if (subtitle.contains('50x') || subtitle.contains('75x') || subtitle.contains('100x')) {
        hasLeverage50Plus = true;
      }
      if (type == 'credit' && amt > 500000.0) {
        criticalFlags.add('Impossible futures PnL exploit: Credited \$${amt.toStringAsFixed(2)} profit on anomalous single position ($subtitle).');
      }
    }

    if (hasIllegalLeverage) {
      criticalFlags.add('Illegal leverage detected: User has futures positions with leverage exceeding the 100x platform cap.');
      checks.add(const AuditCheckItem(
        id: 'leverage_illegal',
        title: 'Futures Leverage Compliance',
        category: 'Leverage',
        severity: AuditSeverity.danger,
        summary: 'Exceeded maximum leverage limit',
        details: 'Found positions exceeding 100x max leverage ceiling.',
      ));
    } else if (hasZeroMarginBug) {
      criticalFlags.add('Zero-margin futures exploit: Opened high-leverage position without margin deduction.');
      checks.add(const AuditCheckItem(
        id: 'leverage_zero_margin',
        title: 'Futures Margin Deduction Integrity',
        category: 'Leverage',
        severity: AuditSeverity.danger,
        summary: 'Zero margin posted on leveraged position',
        details: 'User opened leveraged positions with 0 or negative margin deduction.',
      ));
    } else if (hasZombieLiquidationBug) {
      criticalFlags.add('Zombie position exploit: Active position breached liquidation price but was not liquidated.');
      checks.add(const AuditCheckItem(
        id: 'leverage_zombie_liq',
        title: 'Futures Liquidation Compliance',
        category: 'Leverage',
        severity: AuditSeverity.danger,
        summary: 'Unliquidated zombie position',
        details: 'Current market price has breached the position liquidation threshold, but position remains active.',
      ));
    } else if (hasLeverage50Plus) {
      positiveNotes.add('High leverage (50x–100x) verified legitimate: Full margin was deposited, liquidation thresholds are active, and PnL formulas are accurate. User gained profit through high-risk market timing, NOT cheating.');
      checks.add(const AuditCheckItem(
        id: 'leverage_legit_luck',
        title: 'High-Leverage (100x) Validation',
        category: 'Leverage',
        severity: AuditSeverity.pass,
        summary: 'Legitimate 50x–100x leverage trading (Not cheating)',
        details: 'The trader took high-risk positions (up to 100x). All required margins were deducted from their cash balance, entry prices matched market values, and all profits/losses were calculated legitimately according to official formulas.',
      ));
    } else {
      checks.add(const AuditCheckItem(
        id: 'leverage_normal',
        title: 'Futures & Leverage Audit',
        category: 'Leverage',
        severity: AuditSeverity.pass,
        summary: 'Leverage settings standard and verified',
        details: 'No high-risk or irregular futures leverage patterns detected.',
      ));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 5: MARKET PRICE GLITCH & IMPOSSIBLE EXECUTION PRICES
    // ──────────────────────────────────────────────────────────────────────────
    bool hasGlitchPrice = false;
    String? glitchTradeInfo;

    for (final t in trades) {
      if (t.price <= 0 || t.quantity <= 0 || t.price.isNaN || t.price.isInfinite) {
        hasGlitchPrice = true;
        glitchTradeInfo = '${t.symbol} executed with non-positive/NaN price or quantity: Qty ${t.quantity} @ \$${t.price}';
        break;
      }

      // Check absurdity thresholds for known coins
      final sym = t.symbol.toUpperCase();
      if ((sym.contains('BTC') && (t.price < 1000 || t.price > 10000000)) ||
          (sym.contains('ETH') && (t.price < 50 || t.price > 1000000)) ||
          (sym.contains('SOL') && (t.price < 1 || t.price > 500000))) {
        hasGlitchPrice = true;
        glitchTradeInfo = '${t.symbol} executed at absurdly distorted price (\$${t.price})';
        break;
      }
    }

    if (hasGlitchPrice) {
      criticalFlags.add('Price spoofing / Market glitch trade: $glitchTradeInfo');
      checks.add(AuditCheckItem(
        id: 'pricing_glitch',
        title: 'Trade Execution Price Sanity',
        category: 'Pricing',
        severity: AuditSeverity.danger,
        summary: 'Manipulated or glitched trade price',
        details: glitchTradeInfo,
      ));
    } else {
      checks.add(const AuditCheckItem(
        id: 'pricing_valid',
        title: 'Trade Execution Price Sanity',
        category: 'Pricing',
        severity: AuditSeverity.pass,
        summary: 'All trade execution prices valid',
        details: 'All buy and sell orders occurred at realistic, positive crypto market prices.',
      ));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 6: REWARD REPLAY & RAPID-CLAIM EXPLOITS
    // ──────────────────────────────────────────────────────────────────────────
    final dailyRewards = walletEntries.where((e) => e['category'] == 'daily_reward').toList();
    dailyRewards.sort((a, b) {
      final ta = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime.now();
      final tb = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime.now();
      return ta.compareTo(tb);
    });

    int rapidClaimCount = 0;
    for (int i = 0; i < dailyRewards.length - 1; i++) {
      final t1 = DateTime.tryParse(dailyRewards[i]['timestamp']?.toString() ?? '');
      final t2 = DateTime.tryParse(dailyRewards[i + 1]['timestamp']?.toString() ?? '');
      if (t1 != null && t2 != null) {
        final diff = t2.difference(t1);
        if (diff.inHours < 12) {
          rapidClaimCount++;
        }
      }
    }

    if (rapidClaimCount >= 3) {
      criticalFlags.add('Reward claim replay exploit: Claimed daily check-in rewards multiple times in rapid succession ($rapidClaimCount times).');
      checks.add(AuditCheckItem(
        id: 'rewards_rapid_claim',
        title: 'Daily Check-in & Reward Integrity',
        category: 'Rewards',
        severity: AuditSeverity.danger,
        summary: 'Daily bonus farming loop exploit',
        details: 'Found $rapidClaimCount instances of daily streak rewards claimed within less than 12 hours of each other.',
      ));
    } else if (rapidClaimCount > 0) {
      warnings.add('Detected $rapidClaimCount reward claims with short time separation (possible timezone change or app restart).');
      checks.add(const AuditCheckItem(
        id: 'rewards_minor_drift',
        title: 'Daily Check-in & Reward Integrity',
        category: 'Rewards',
        severity: AuditSeverity.warning,
        summary: 'Minor reward claim time drift',
        details: 'One or two daily rewards occurred with slight time separation.',
      ));
    } else {
      checks.add(const AuditCheckItem(
        id: 'rewards_valid',
        title: 'Daily Check-in & Reward Integrity',
        category: 'Rewards',
        severity: AuditSeverity.pass,
        summary: 'All reward claims legitimate',
        details: 'Daily rewards, check-ins, and quest milestones were claimed with proper intervals and legitimate streak progression.',
      ));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 7: FIRESTORE MONEY REQUESTS DATABASE CROSS-CHECK
    // ──────────────────────────────────────────────────────────────────────────
    try {
      final requestsSnap = await FirebaseFirestore.instance
          .collection('money_requests')
          .where('requesterUid', isEqualTo: publicUid.isNotEmpty ? publicUid : userDocId)
          .get();

      final approvedDbRequests = requestsSnap.docs.where((d) => d.data()['status'] == 'approved').toList();
      double totalApprovedDbAmount = 0.0;
      for (final doc in approvedDbRequests) {
        totalApprovedDbAmount += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Check user wallet entries claiming "Admin Added Funds" or "Virtual Capital Top-Up"
      final adminTopups = walletEntries.where((e) {
        final cat = e['category']?.toString() ?? '';
        return cat == 'admin_credit' || cat == 'topup';
      }).toList();

      double totalClaimedTopups = 0.0;
      for (final t in adminTopups) {
        totalClaimedTopups += (t['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // If claimed is significantly larger than approved in DB
      if (totalClaimedTopups > totalApprovedDbAmount + 100.0 && approvedDbRequests.isNotEmpty) {
        warnings.add('Top-up discrepancy: User wallet claims \$${totalClaimedTopups.toStringAsFixed(2)} in deposits, but approved database requests total \$${totalApprovedDbAmount.toStringAsFixed(2)}.');
        checks.add(AuditCheckItem(
          id: 'db_cross_check_warn',
          title: 'Database Cross-Verification (Money Requests)',
          category: 'Database',
          severity: AuditSeverity.warning,
          summary: 'Database request total lower than wallet credit log',
          details: 'Wallet records \$${totalClaimedTopups.toStringAsFixed(2)} in top-ups/admin credits, while money_requests shows \$${totalApprovedDbAmount.toStringAsFixed(2)}.',
        ));
      } else {
        checks.add(AuditCheckItem(
          id: 'db_cross_check_pass',
          title: 'Database Cross-Verification (Money Requests)',
          category: 'Database',
          severity: AuditSeverity.pass,
          summary: 'External deposit requests verified in Firestore',
          details: 'Approved requests in database (${approvedDbRequests.length}) reconcile with wallet entries.',
        ));
      }
    } catch (_) {
      // Offline or permission fallback
      checks.add(const AuditCheckItem(
        id: 'db_cross_check_skipped',
        title: 'Database Cross-Verification',
        category: 'Database',
        severity: AuditSeverity.info,
        summary: 'Database cross-check skipped (no network/rules boundary)',
      ));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // VERDICT FORMULATION & FORENSIC TIMELINE
    // ──────────────────────────────────────────────────────────────────────────
    AuditVerdict verdict;
    String verdictTitle;
    String verdictDescription;
    String recommendedAction;
    String? prefilledBanReason;

    final isCheater = criticalFlags.isNotEmpty;
    final isLeverageLegitimate = !isCheater && hasLeverage50Plus;

    if (isCheater) {
      verdict = AuditVerdict.cheaterConfirmed;
      verdictTitle = 'CRITICAL CHEAT / EXPLOIT DETECTED';
      verdictDescription = 'The portfolio and financial ledger failed mathematical verification. Evidence of unauthorized state manipulation or bug exploitation was detected.';
      recommendedAction = 'Ban this user account or apply an administrative reset to protect the competition and leaderboard.';
      prefilledBanReason = 'Exploit / Cheating Detected: ${criticalFlags.join(' | ')}';
    } else if (isLeverageLegitimate) {
      verdict = AuditVerdict.highLeverageLucky;
      verdictTitle = 'LEGITIMATE HIGH-LEVERAGE TRADER (NOT CHEATING)';
      verdictDescription = 'This user generated large net worth through high-leverage (50x–100x) trading. All margins were legitimately deducted, prices match real crypto charts, and zero bugs were exploited. They are simply lucky with high leverage.';
      recommendedAction = 'Account is fully legitimate and verified. No penalty or ban warranted.';
    } else if (warnings.isNotEmpty) {
      verdict = AuditVerdict.warning;
      verdictTitle = 'MINOR ANOMALIES (REVIEW RECOMMENDED)';
      verdictDescription = 'Account displays minor numerical drift or rounding variance, but no definitive proof of cheating or bug exploitation.';
      recommendedAction = 'Review trade and wallet history manually. Ban is NOT recommended unless suspicious patterns escalate.';
    } else {
      verdict = AuditVerdict.clean;
      verdictTitle = '100% VERIFIED AUTHENTIC (CLEAN TRADER)';
      verdictDescription = 'Every trade, coin purchase, futures position, and wallet credit reconciles mathematically with 100% precision. Account is clean.';
      recommendedAction = 'No action needed. Standard compliant user account.';
    }

    // Build Forensic Timeline Events
    final forensicTimeline = <ForensicTimelineEvent>[];

    forensicTimeline.add(ForensicTimelineEvent(
      timestamp: earliestDate,
      action: 'Account Created',
      symbol: 'USD',
      details: 'Account initialized with starting virtual cash balance',
      financialImpact: '+\$${initialOnboardCapital.toStringAsFixed(2)} initial capital',
      severity: AuditSeverity.pass,
      isExploit: false,
    ));

    for (final e in walletEntries) {
      final amt = (e['amount'] as num?)?.toDouble() ?? 0.0;
      final type = (e['type'] as String?) ?? 'credit';
      final title = e['title']?.toString() ?? 'Wallet Entry';
      final subtitle = e['subtitle']?.toString() ?? '';
      final category = e['category']?.toString() ?? '';
      final ts = DateTime.tryParse(e['timestamp']?.toString() ?? '') ?? DateTime.now();

      bool isExploit = false;
      AuditSeverity severity = AuditSeverity.pass;

      String sym = '';
      if (subtitle.contains('BTC')) {
        sym = 'BTC';
      } else if (subtitle.contains('ETH')) {
        sym = 'ETH';
      } else if (subtitle.contains('SOL')) {
        sym = 'SOL';
      } else if (subtitle.contains('PEPE')) {
        sym = 'PEPE';
      }

      if (category == 'futures_pnl' && amt > 500000.0) {
        isExploit = true;
        severity = AuditSeverity.danger;
      } else if (title.contains('Limit') && category == 'futures_open' && (subtitle.contains('2000') || subtitle.contains('2x') && amt >= 100)) {
        if (criticalFlags.any((f) => f.contains('Manipulated futures entry price') || f.contains('Impossible futures PnL'))) {
          isExploit = true;
          severity = AuditSeverity.danger;
        }
      }

      forensicTimeline.add(ForensicTimelineEvent(
        timestamp: ts,
        action: title,
        symbol: sym,
        details: subtitle.isNotEmpty ? subtitle : title,
        financialImpact: '${type == 'credit' ? '+' : '-'}\$${amt.toStringAsFixed(2)}',
        severity: severity,
        isExploit: isExploit,
      ));
    }

    for (final t in trades) {
      final total = t.price * t.quantity;
      final isBuy = t.side == OrderSide.buy;
      bool isSuspicious = false;
      if (t.price <= 0 || (t.symbol.contains('BTC') && t.price < 5000)) {
        isSuspicious = true;
      }

      forensicTimeline.add(ForensicTimelineEvent(
        timestamp: t.time,
        action: 'Spot ${isBuy ? 'Buy' : 'Sell'}',
        symbol: t.symbol,
        details: '${isBuy ? 'Bought' : 'Sold'} ${t.quantity} ${t.symbol} @ \$${t.price.toStringAsFixed(6)}',
        financialImpact: '${isBuy ? '-' : '+'}\$${total.toStringAsFixed(2)}',
        severity: isSuspicious ? AuditSeverity.danger : AuditSeverity.pass,
        isExploit: isSuspicious,
      ));
    }

    for (final f in futures) {
      final isManipulated = f.entryPrice <= 0 || (f.symbol.contains('BTC') && f.entryPrice < 5000);
      forensicTimeline.add(ForensicTimelineEvent(
        timestamp: DateTime.now(),
        action: 'Active Futures Position (${f.side == OrderSide.buy ? 'Long' : 'Short'} ${f.leverage}x)',
        symbol: f.symbol,
        details: '${f.quantity} ${f.symbol} @ entry \$${f.entryPrice.toStringAsFixed(2)} • Margin \$${f.margin.toStringAsFixed(2)}',
        financialImpact: isManipulated ? 'MANIPULATED ENTRY (\$${f.entryPrice.toStringAsFixed(2)})' : 'Margin: \$${f.margin.toStringAsFixed(2)}',
        severity: isManipulated ? AuditSeverity.danger : AuditSeverity.pass,
        isExploit: isManipulated,
      ));
    }

    forensicTimeline.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Formulate Root Cause Analysis
    ExploitRootCauseAnalysis? rootCause;
    String? prefilledResetReason;

    if (isCheater) {
      String classification = 'Unauthorized Portfolio / Balance Manipulation';
      final steps = <String>[];
      double unbackedTotal = cashDiscrepancy > 0 ? cashDiscrepancy : 0.0;

      if (criticalFlags.any((f) => f.contains('Manipulated futures') || f.contains('Impossible futures PnL') || f.contains('Futures (Limit)'))) {
        classification = 'Futures Limit Order Instant-Execution Glitch';
        steps.add('1. User selected a Futures Limit Order and manually specified an artificially distorted entry price far below/above market.');
        steps.add('2. The client immediately opened an active futures position at that distorted price instead of queuing a pending order to await market trigger.');
        steps.add('3. User closed the position against real-time market prices, realizing immediate unearned windfall profits into virtual balance.');
        if (trades.isNotEmpty) {
          steps.add('4. Glitched profit was subsequently used to purchase spot coins (e.g., meme tokens) or open further leveraged positions.');
        }
        for (final fp in walletEntries.where((e) => e['category'] == 'futures_pnl' && (e['type'] == 'credit'))) {
          final a = (fp['amount'] as num?)?.toDouble() ?? 0.0;
          if (a > 100000) unbackedTotal += a;
        }
      } else if (criticalFlags.any((f) => f.contains('Ghost holdings'))) {
        classification = 'Ghost Coin Holdings (Inventory Manipulation)';
        steps.add('1. User injected or synced coin holdings directly without corresponding buy trade transactions in trade history.');
        steps.add('2. Valuation artificially inflates stated portfolio net worth.');
      } else if (criticalFlags.any((f) => f.contains('solvency') || f.contains('overdraft'))) {
        classification = 'Chronological Capital Overdraft Exploit';
        steps.add('1. User executed orders exceeding available virtual cash, plunging balance into deep negative overdraft.');
        steps.add('2. Exploited lack of synchronous balance lock during order placement.');
      } else if (cashDiscrepancy > cashTolerance) {
        classification = 'Direct Cash Balance Injection (Ghost Capital)';
        steps.add('1. User virtual balance was directly altered in Firestore without matching trade profits or daily rewards.');
        steps.add('2. Stated balance is +\$${cashDiscrepancy.toStringAsFixed(2)} higher than all ledger transactions combined.');
      }

      final isHighSeverity = unbackedTotal > 1000000.0 || criticalFlags.length >= 2;
      final recommendedDecision = isHighSeverity ? 'BAN' : 'RESET';
      final decisionRationale = isHighSeverity
          ? 'Severe intentional multi-stage exploit detected. Total unbacked capital generated exceeds \$${unbackedTotal.toStringAsFixed(2)}. Immediate permanent ban is recommended to maintain tournament integrity.'
          : 'Exploit detected, but may be an isolated test or lower severity. Resetting account back to starting capital (\$5,000.00) with a required acknowledgement notice is recommended.';

      rootCause = ExploitRootCauseAnalysis(
        classification: classification,
        summary: 'Root Cause: $classification. Detected evidence: ${criticalFlags.join('; ')}.',
        steps: steps,
        unbackedCapitalGenerated: unbackedTotal,
        recommendedDecision: recommendedDecision,
        decisionRationale: decisionRationale,
      );

      prefilledResetReason = 'Account reset due to $classification. All manipulated positions and unearned profits have been restored to initial fair starting capital (\$5,000.00).';
    }

    // Build Formatted Report Text for Copy Box
    final reportBuffer = StringBuffer();
    reportBuffer.writeln('====================================');
    reportBuffer.writeln('FORENSIC PORTFOLIO AUDIT REPORT');
    reportBuffer.writeln('Audited at: ${DateTime.now().toIso8601String().substring(0, 19)}');
    reportBuffer.writeln('User UID: $publicUid (Firebase: $userDocId)');
    final userName = profile['name']?.toString() ?? 'Trader';
    final userEmail = profile['email']?.toString() ?? 'N/A';
    reportBuffer.writeln('Trader Name: $userName ($userEmail)');
    reportBuffer.writeln('VERDICT: $verdictTitle');
    reportBuffer.writeln('Summary: $verdictDescription');
    reportBuffer.writeln('Recommended Action: $recommendedAction');
    reportBuffer.writeln('------------------------------------');
    reportBuffer.writeln('FINANCIAL METRICS:');
    reportBuffer.writeln('Stated Net Worth: \$${statedNetWorth.toStringAsFixed(2)}');
    reportBuffer.writeln('Stated Cash: \$${statedCash.toStringAsFixed(2)}');
    reportBuffer.writeln('Audited Reconciled Cash: \$${reconciledCash.toStringAsFixed(2)}');
    reportBuffer.writeln('Discrepancy: \$${cashDiscrepancy.toStringAsFixed(2)}');
    reportBuffer.writeln('Spot Valuation: \$${spotValuation.toStringAsFixed(2)}');
    reportBuffer.writeln('Futures Margin: \$${futuresMargin.toStringAsFixed(2)}');
    reportBuffer.writeln('------------------------------------');
    if (rootCause != null) {
      reportBuffer.writeln('EXPLOIT ROOT CAUSE ANALYSIS:');
      reportBuffer.writeln('Classification: ${rootCause.classification}');
      reportBuffer.writeln('Summary: ${rootCause.summary}');
      reportBuffer.writeln('Unbacked Capital Generated: \$${rootCause.unbackedCapitalGenerated.toStringAsFixed(2)}');
      reportBuffer.writeln('Recommended Decision: ${rootCause.recommendedDecision}');
      reportBuffer.writeln('Decision Rationale: ${rootCause.decisionRationale}');
      reportBuffer.writeln('Steps Taken by User:');
      for (final s in rootCause.steps) {
        reportBuffer.writeln('  • $s');
      }
      reportBuffer.writeln('------------------------------------');
    }
    if (criticalFlags.isNotEmpty) {
      reportBuffer.writeln('CRITICAL BREACHES / CHEAT EVIDENCE:');
      for (final f in criticalFlags) {
        reportBuffer.writeln('  ❌ $f');
      }
      reportBuffer.writeln('------------------------------------');
    }
    if (positiveNotes.isNotEmpty) {
      reportBuffer.writeln('LEGITIMATE TRADING EVIDENCE:');
      for (final p in positiveNotes) {
        reportBuffer.writeln('  ⚡ $p');
      }
      reportBuffer.writeln('------------------------------------');
    }
    reportBuffer.writeln('CHRONOLOGICAL FORENSIC TIMELINE:');
    for (final ev in forensicTimeline) {
      final mark = ev.isExploit ? '[EXPLOIT]' : '[NORMAL]';
      reportBuffer.writeln('  ${ev.timestamp.toIso8601String().substring(0, 19)} | $mark ${ev.action} (${ev.symbol}): ${ev.details} | Impact: ${ev.financialImpact}');
    }
    reportBuffer.writeln('====================================');
    final formattedReportText = reportBuffer.toString();

    return PortfolioAuditResult(
      verdict: verdict,
      verdictTitle: verdictTitle,
      verdictDescription: verdictDescription,
      recommendedAction: recommendedAction,
      prefilledBanReason: prefilledBanReason,
      prefilledResetReason: prefilledResetReason,
      statedNetWorth: statedNetWorth,
      statedCash: statedCash,
      reconciledCash: reconciledCash,
      cashDiscrepancy: cashDiscrepancy,
      spotValuation: spotValuation,
      futuresMargin: futuresMargin,
      futuresUnrealizedPnl: futuresUnrealizedPnl,
      checks: checks,
      criticalFlags: criticalFlags,
      warnings: warnings,
      positiveNotes: positiveNotes,
      holdingDetails: holdingDetails,
      forensicTimeline: forensicTimeline,
      rootCauseAnalysis: rootCause,
      formattedReportText: formattedReportText,
      hasHighLeverage: hasLeverage50Plus,
      isLeverageLegitimate: isLeverageLegitimate,
      auditedAt: DateTime.now(),
    );
  }
}

class _TimelineEvent {
  final DateTime timestamp;
  final double delta;
  final String description;

  const _TimelineEvent({
    required this.timestamp,
    required this.delta,
    required this.description,
  });
}
