import 'dart:async';
import 'package:stock_arena/core/app_material.dart';

/// Permanent Market Session & Timeline widget shown directly below the chart,
/// displaying real-time US exchange session states (Pre-market, Regular, Post-market, Closed)
/// with live countdown and a visual 24-hour session timeline.
class MarketSessionBar extends StatefulWidget {
  final String exchange;
  final bool matchTradingViewDelay;
  const MarketSessionBar({
    super.key,
    this.exchange = 'NASDAQ',
    this.matchTradingViewDelay = true,
  });

  @override
  State<MarketSessionBar> createState() => _MarketSessionBarState();
}

class _MarketSessionBarState extends State<MarketSessionBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh countdown every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Calculates the New York Eastern Time.
  /// When [matchTradingViewDelay] is true, accounts for the 15-minute exchange delay
  /// used by TradingView's free NASDAQ / NYSE chart stream.
  DateTime _getNewYorkTime() {
    final nowUtc = DateTime.now().toUtc();
    final year = nowUtc.year;

    // US Daylight Saving Time:
    // Starts second Sunday in March at 02:00 local (07:00 UTC)
    var dstStart = DateTime.utc(year, 3, 8);
    while (dstStart.weekday != DateTime.sunday) {
      dstStart = dstStart.add(const Duration(days: 1));
    }
    // Ends first Sunday in November at 02:00 local (06:00 UTC)
    var dstEnd = DateTime.utc(year, 11, 1);
    while (dstEnd.weekday != DateTime.sunday) {
      dstEnd = dstEnd.add(const Duration(days: 1));
    }

    final isDst = nowUtc.isAfter(dstStart) && nowUtc.isBefore(dstEnd);
    final offsetHours = isDst ? -4 : -5;
    var nyTime = nowUtc.add(Duration(hours: offsetHours));

    if (widget.matchTradingViewDelay) {
      nyTime = nyTime.subtract(const Duration(minutes: 15));
    }

    return nyTime;
  }

  bool _isDaylightSaving() {
    final nowUtc = DateTime.now().toUtc();
    final year = nowUtc.year;
    var dstStart = DateTime.utc(year, 3, 8);
    while (dstStart.weekday != DateTime.sunday) {
      dstStart = dstStart.add(const Duration(days: 1));
    }
    var dstEnd = DateTime.utc(year, 11, 1);
    while (dstEnd.weekday != DateTime.sunday) {
      dstEnd = dstEnd.add(const Duration(days: 1));
    }
    return nowUtc.isAfter(dstStart) && nowUtc.isBefore(dstEnd);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nyTime = _getNewYorkTime();

    final isWeekend = nyTime.weekday == DateTime.saturday ||
        (nyTime.weekday == DateTime.sunday && nyTime.hour < 20) ||
        (nyTime.weekday == DateTime.friday && nyTime.hour >= 20);

    final minuteOfDay = nyTime.hour * 60 + nyTime.minute;

    // US Market Session Boundaries in ET minutes:
    // Overnight: 00:00 - 04:00 (0 - 240)
    // Pre-market: 04:00 - 09:30 (240 - 570)
    // Regular: 09:30 - 16:00 (570 - 960)
    // Post-market: 16:00 - 20:00 (960 - 1200)
    // Overnight: 20:00 - 24:00 (1200 - 1440)

    final String sessionTitle;
    final Color sessionColor;
    final IconData sessionIcon;
    final String line1;
    final String line2;

    if (isWeekend) {
      sessionTitle = 'Market closed';
      sessionColor = const Color(0xFF94A3B8);
      sessionIcon = Icons.bedtime_outlined;
      line1 = 'Market is closed for the weekend.'.tr();
      // Calculate time until Monday 04:00 ET
      int daysUntilMon = (DateTime.monday - nyTime.weekday + 7) % 7;
      if (daysUntilMon == 0) daysUntilMon = 7;
      final targetMonday = DateTime(nyTime.year, nyTime.month, nyTime.day + daysUntilMon, 4, 0);
      final diff = targetMonday.difference(nyTime);
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      line2 = 'Opens for pre-market on Monday at 04:00 AM ET ($hours h $mins m).'.tr();
    } else if (minuteOfDay >= 240 && minuteOfDay < 570) {
      // 04:00 to 09:30: Pre-market
      sessionTitle = 'Pre-market';
      sessionColor = const Color(0xFFF59E0B); // Amber
      sessionIcon = Icons.wb_twilight_rounded;
      line1 = 'Morning. Market is open for pre-market trading.'.tr();
      final diffMins = 570 - minuteOfDay;
      final h = diffMins ~/ 60;
      final m = diffMins % 60;
      line2 = h > 0
          ? "It'll open fully in $h hour${h > 1 ? 's' : ''} and $m minute${m != 1 ? 's' : ''}.".tr()
          : "It'll open fully in $m minute${m != 1 ? 's' : ''}.".tr();
    } else if (minuteOfDay >= 570 && minuteOfDay < 960) {
      // 09:30 to 16:00: Regular Market Open
      sessionTitle = 'Regular market open';
      sessionColor = const Color(0xFF10B981); // Emerald Teal
      sessionIcon = Icons.wb_sunny_rounded;
      line1 = 'Regular trading session is currently active.'.tr();
      final diffMins = 960 - minuteOfDay;
      final h = diffMins ~/ 60;
      final m = diffMins % 60;
      line2 = h > 0
          ? 'Regular session closes in $h hour${h > 1 ? 's' : ''} and $m minute${m != 1 ? 's' : ''}.'.tr()
          : 'Regular session closes in $m minute${m != 1 ? 's' : ''}.'.tr();
    } else if (minuteOfDay >= 960 && minuteOfDay < 1200) {
      // 16:00 to 20:00: Post-market
      sessionTitle = 'Post-market';
      sessionColor = const Color(0xFF3B82F6); // Blue
      sessionIcon = Icons.nightlight_round;
      line1 = 'Evening. Market is open for after-hours trading.'.tr();
      final diffMins = 1200 - minuteOfDay;
      final h = diffMins ~/ 60;
      final m = diffMins % 60;
      line2 = h > 0
          ? 'After-hours closes in $h hour${h > 1 ? 's' : ''} and $m minute${m != 1 ? 's' : ''}.'.tr()
          : 'After-hours closes in $m minute${m != 1 ? 's' : ''}.'.tr();
    } else {
      // Overnight (00:00 - 04:00 or 20:00 - 24:00)
      sessionTitle = 'Overnight';
      sessionColor = const Color(0xFFA855F7); // Purple
      sessionIcon = Icons.bedtime_rounded;
      line1 = 'Overnight. Market is closed.'.tr();
      final diffMins = minuteOfDay < 240 ? (240 - minuteOfDay) : (1440 - minuteOfDay + 240);
      final h = diffMins ~/ 60;
      final m = diffMins % 60;
      line2 = "Pre-market opens in $h hour${h > 1 ? 's' : ''} and $m minute${m != 1 ? 's' : ''}.".tr();
    }

    final cardBg = isDark ? const Color(0xFF131722) : const Color(0xFFF8FAFD);
    final borderColor = isDark ? const Color(0xFF242731) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF868993) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    final dayName = _getWeekdayShort(nyTime.weekday);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Status Row ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark
                      ? (minuteOfDay >= 240 && minuteOfDay < 570
                          ? const Color(0xFF2E2009)
                          : sessionColor.withValues(alpha: 0.18))
                      : sessionColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(sessionIcon, size: 16, color: sessionColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sessionTitle.tr(),
                      style: TextStyle(
                        color: sessionColor,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line2,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Visual Timeline Track & Markers ───────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1.5),
                child: Text(
                  dayName,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    const gap = 3.5;
                    const totalGaps = 4 * gap;
                    final netW = (w - totalGaps).clamp(0.0, double.infinity);

                    // Proportional segment widths (sum of minutes = 1440):
                    // 1. Overnight: 240m
                    // 2. Pre-market: 330m
                    // 3. Regular: 390m
                    // 4. Post-market: 240m
                    // 5. Overnight: 240m
                    final w1 = (240.0 / 1440.0) * netW;
                    final w2 = (330.0 / 1440.0) * netW;
                    final w3 = (390.0 / 1440.0) * netW;
                    final w4 = (240.0 / 1440.0) * netW;
                    final w5 = (240.0 / 1440.0) * netW;

                    // Exact divider centers:
                    final x0400 = w1 + (gap / 2);
                    final x0930 = w1 + gap + w2 + (gap / 2);

                    // Exact needle X position:
                    final double needleX;
                    if (minuteOfDay <= 240) {
                      needleX = (minuteOfDay / 240.0) * w1;
                    } else if (minuteOfDay <= 570) {
                      needleX = w1 + gap + ((minuteOfDay - 240) / 330.0) * w2;
                    } else if (minuteOfDay <= 960) {
                      needleX = w1 + gap + w2 + gap + ((minuteOfDay - 570) / 390.0) * w3;
                    } else if (minuteOfDay <= 1200) {
                      needleX = w1 + gap + w2 + gap + w3 + gap + ((minuteOfDay - 960) / 240.0) * w4;
                    } else {
                      needleX = w1 + gap + w2 + gap + w3 + gap + w4 + gap + ((minuteOfDay - 1200) / 240.0) * w5;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 16,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            clipBehavior: Clip.none,
                            children: [
                              // Colored Pill Segments
                              Row(
                                children: [
                                  // 1. Overnight (00:00 - 04:00)
                                  SizedBox(
                                    width: w1,
                                    height: 7,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFBA68C8),
                                        borderRadius: BorderRadius.circular(3.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: gap),
                                  // 2. Pre-market (04:00 - 09:30)
                                  SizedBox(
                                    width: w2,
                                    height: 7,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF9800),
                                        borderRadius: BorderRadius.circular(3.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: gap),
                                  // 3. Regular (09:30 - 16:00)
                                  SizedBox(
                                    width: w3,
                                    height: 7,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF26A69A),
                                        borderRadius: BorderRadius.circular(3.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: gap),
                                  // 4. Post-market (16:00 - 20:00)
                                  SizedBox(
                                    width: w4,
                                    height: 7,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF42A5F5),
                                        borderRadius: BorderRadius.circular(3.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: gap),
                                  // 5. Overnight (20:00 - 24:00)
                                  SizedBox(
                                    width: w5,
                                    height: 7,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFBA68C8),
                                        borderRadius: BorderRadius.circular(3.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Vertical Current Time Needle
                              Positioned(
                                left: (needleX - 0.75).clamp(0.0, w - 1.5),
                                child: Container(
                                  width: 1.5,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Time Markers: 04:00 and 09:30 directly under their divider gaps
                        SizedBox(
                          height: 14,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: (x0400 - 14).clamp(0.0, w - 28),
                                child: Text(
                                  '04:00',
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: (x0930 - 14).clamp(0.0, w - 28),
                                child: Text(
                                  '09:30',
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Footer Timezone Notice ────────────────────────────────────────
          Center(
            child: Text(
              _isDaylightSaving()
                  ? 'Exchange timezone: New York (UTC-4)'.tr()
                  : 'Exchange timezone: New York (UTC-5)'.tr(),
              style: TextStyle(
                color: textMuted.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _getWeekdayShort(int day) {
    switch (day) {
      case DateTime.monday:
        return 'MON';
      case DateTime.tuesday:
        return 'TUE';
      case DateTime.wednesday:
        return 'WED';
      case DateTime.thursday:
        return 'THU';
      case DateTime.friday:
        return 'FRI';
      case DateTime.saturday:
        return 'SAT';
      case DateTime.sunday:
        return 'SUN';
      default:
        return 'DAY';
    }
  }
}
