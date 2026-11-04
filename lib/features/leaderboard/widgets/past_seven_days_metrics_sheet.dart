import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme.dart';
import '../../community/widgets/user_profile_modal.dart';

class TraderRegistrationEntry {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final DateTime joinDate;
  final double virtualBalance;
  final double netWorth;
  final int xp;
  final bool isBanned;

  const TraderRegistrationEntry({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.joinDate,
    required this.virtualBalance,
    required this.netWorth,
    required this.xp,
    required this.isBanned,
  });
}

class DayRegistrationSummary {
  final DateTime date;
  final String label;
  final List<TraderRegistrationEntry> entries;

  const DayRegistrationSummary({
    required this.date,
    required this.label,
    required this.entries,
  });

  int get count => entries.length;
}

class PastSevenDaysMetricsSheet extends StatefulWidget {
  final int totalTraders;
  final int newTradersToday;
  final int newTradersWeek;
  final List<DayRegistrationSummary> pastSevenDays;
  final String initialMode; // 'total', 'today', 'week'

  const PastSevenDaysMetricsSheet({
    super.key,
    required this.totalTraders,
    required this.newTradersToday,
    required this.newTradersWeek,
    required this.pastSevenDays,
    this.initialMode = 'today',
  });

  @override
  State<PastSevenDaysMetricsSheet> createState() => _PastSevenDaysMetricsSheetState();
}

class _PastSevenDaysMetricsSheetState extends State<PastSevenDaysMetricsSheet> {
  late String _selectedMode;
  int _selectedDayIndex = -1; // -1 means "All 7 Days", 0 = Today, 1 = Yesterday, etc.
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    if (_selectedMode == 'today') {
      _selectedDayIndex = 0; // default to Today
    } else {
      _selectedDayIndex = -1; // All 7 Days
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TraderRegistrationEntry> get _filteredEntries {
    List<TraderRegistrationEntry> source;
    if (_selectedDayIndex == -1) {
      source = widget.pastSevenDays.expand((d) => d.entries).toList();
    } else if (_selectedDayIndex >= 0 && _selectedDayIndex < widget.pastSevenDays.length) {
      source = widget.pastSevenDays[_selectedDayIndex].entries;
    } else {
      source = [];
    }

    // Sort newest first
    final sorted = List<TraderRegistrationEntry>.from(source)
      ..sort((a, b) => b.joinDate.compareTo(a.joinDate));

    if (_searchQuery.trim().isEmpty) return sorted;

    final q = _searchQuery.toLowerCase();
    return sorted.where((e) {
      return e.name.toLowerCase().contains(q) ||
          e.email.toLowerCase().contains(q) ||
          e.uid.toLowerCase().contains(q);
    }).toList();
  }

  void _openProfile(TraderRegistrationEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => UserProfileModal(
        userId: entry.uid,
        fallbackName: entry.name.isNotEmpty ? entry.name : 'Trader',
        fallbackAvatar: entry.photoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Calculate maximum daily count to scale graph bars
    int maxDayCount = 1;
    for (final day in widget.pastSevenDays) {
      if (day.count > maxDayCount) maxDayCount = day.count;
    }

    final displayedEntries = _filteredEntries;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121519),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle pill
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0B90B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Color(0xFFF0B90B), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Past 7 Days Analytics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _selectedDayIndex == 0
                              ? "Showing today's new calendar entries"
                              : _selectedDayIndex == -1
                                  ? 'Breakdown of last 7 calendar days'
                                  : 'Filtered for ${widget.pastSevenDays[_selectedDayIndex].label}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // 3 Interactive Metric Selector Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSelectorTile(
                          id: 'total',
                          icon: Icons.people_alt_rounded,
                          iconColor: const Color(0xFF3861FB),
                          label: 'Total Persons',
                          value: '${widget.totalTraders}',
                          subtext: 'Registered',
                          isSelected: _selectedMode == 'total',
                          onTap: () {
                            setState(() {
                              _selectedMode = 'total';
                              _selectedDayIndex = -1; // view all
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSelectorTile(
                          id: 'today',
                          icon: Icons.person_add_alt_1_rounded,
                          iconColor: AppColors.profit,
                          label: 'New Today',
                          value: '+${widget.newTradersToday}',
                          subtext: 'Today',
                          isSelected: _selectedMode == 'today',
                          onTap: () {
                            setState(() {
                              _selectedMode = 'today';
                              _selectedDayIndex = 0; // Today
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSelectorTile(
                          id: 'week',
                          icon: Icons.trending_up_rounded,
                          iconColor: const Color(0xFFF0B90B),
                          label: 'New (7 Days)',
                          value: '+${widget.newTradersWeek}',
                          subtext: 'This week',
                          isSelected: _selectedMode == 'week',
                          onTap: () {
                            setState(() {
                              _selectedMode = 'week';
                              _selectedDayIndex = -1; // all 7 days
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Past 7 Days Visual Bar Chart
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF262D35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'Day-by-Day New Entries (Past 7 Days)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '+${widget.newTradersWeek} total',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 7 Daily Columns / Bars
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(widget.pastSevenDays.length, (idx) {
                            // Reverse order so left-to-right is oldest to today
                            final realIdx = widget.pastSevenDays.length - 1 - idx;
                            final day = widget.pastSevenDays[realIdx];
                            final isToday = realIdx == 0;
                            final isSelected = _selectedDayIndex == realIdx;
                            final ratio = (day.count / maxDayCount).clamp(0.08, 1.0);

                            // Short label for the day
                            final shortLabel = isToday
                                ? 'Today'
                                : realIdx == 1
                                    ? 'Yest'
                                    : DateFormat('E').format(day.date);

                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDayIndex = isSelected ? -1 : realIdx;
                                    if (realIdx == 0) {
                                      _selectedMode = 'today';
                                    } else {
                                      _selectedMode = 'week';
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Value above bar
                                      Text(
                                        '+${day.count}',
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.primary
                                              : (isToday ? AppColors.profit : Colors.white70),
                                          fontSize: 10.5,
                                          fontWeight: isSelected || isToday
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // The Bar
                                      Container(
                                        height: 60 * ratio,
                                        width: 18,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary
                                              : (isToday
                                                  ? AppColors.profit
                                                  : const Color(0xFF2B3139)),
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.primary.withValues(alpha: 0.4),
                                                    blurRadius: 8,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Date Label
                                      Text(
                                        shortLabel,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : (isToday ? AppColors.profit : Colors.white38),
                                          fontSize: 10,
                                          fontWeight: isSelected || isToday
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Filter Chips row (All 7 Days, Today, Yesterday, ...)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All 7 Days (${widget.newTradersWeek})',
                          isSelected: _selectedDayIndex == -1,
                          onTap: () => setState(() => _selectedDayIndex = -1),
                        ),
                        const SizedBox(width: 8),
                        ...List.generate(widget.pastSevenDays.length, (idx) {
                          final day = widget.pastSevenDays[idx];
                          final label = idx == 0
                              ? 'Today (+${day.count})'
                              : idx == 1
                                  ? 'Yesterday (+${day.count})'
                                  : '${DateFormat('E, d MMM').format(day.date)} (+${day.count})';
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildFilterChip(
                              label: label,
                              isSelected: _selectedDayIndex == idx,
                              onTap: () => setState(() => _selectedDayIndex = idx),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Search Field
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF262D35)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: const InputDecoration(
                              hintText: 'Search new traders by name or email...',
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(Icons.clear, color: Colors.white38, size: 16),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Section Title
                  Row(
                    children: [
                      Text(
                        _selectedDayIndex == -1
                            ? 'New Traders (Past 7 Days)'
                            : _selectedDayIndex == 0
                                ? "Today's New Entries"
                                : "Registered on ${widget.pastSevenDays[_selectedDayIndex].label}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262D35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${displayedEntries.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Users List
                  if (displayedEntries.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded, color: Colors.white.withValues(alpha: 0.2), size: 42),
                          const SizedBox(height: 10),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No new traders match "$_searchQuery"'
                                : 'No new registrations found for this day.',
                            style: const TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    ...displayedEntries.map((entry) {
                      return _buildUserRow(entry, currencyFormatter);
                    }),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorTile({
    required String id,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtext,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E242B) : const Color(0xFF14171A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? iconColor : const Color(0xFF2B3139),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: iconColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  color: isSelected ? iconColor : Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFF1E2329),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFF2B3139),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUserRow(TraderRegistrationEntry entry, NumberFormat currencyFormatter) {
    // Formatted time: "Today, 02:45 PM" or "01 Nov, 11:30 AM"
    final now = DateTime.now();
    final isToday = entry.joinDate.year == now.year &&
        entry.joinDate.month == now.month &&
        entry.joinDate.day == now.day;
    final timeStr = isToday
        ? 'Today, ${DateFormat('hh:mm a').format(entry.joinDate)}'
        : DateFormat('dd MMM, hh:mm a').format(entry.joinDate);

    final avatarUrl = entry.photoUrl.isNotEmpty
        ? entry.photoUrl
        : 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Unicorn.png';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161A1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF242B33)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: () => _openProfile(entry),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2329),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outline, width: 1),
          ),
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: Image.network(
              avatarUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  entry.name.isNotEmpty ? entry.name[0].toUpperCase() : 'T',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.name.isNotEmpty ? entry.name : 'Anonymous Trader',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isToday)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.profit.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: AppColors.profit,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            if (entry.email.isNotEmpty)
              Text(
                entry.email,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 11, color: Colors.white38),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
                const Spacer(),
                Text(
                  currencyFormatter.format(entry.virtualBalance),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 12),
      ),
    );
  }
}
