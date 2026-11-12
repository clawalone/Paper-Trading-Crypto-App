import 'package:flutter/services.dart';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/market_mode_provider.dart';

class ArenaSwitcher extends ConsumerWidget {
  final bool compact;
  const ArenaSwitcher({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(marketModeProvider);
    final isCrypto = mode == MarketMode.crypto;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Palette calibrated to match the design spec for both Light & Dark modes
    final containerBg = isDark ? const Color(0xFF1A1D23) : const Color(0xFFE9EDF2);
    final containerBorder = isDark ? const Color(0xFF262B33) : const Color(0xFFDDE3EA);

    return Container(
      height: compact ? 34 : 38,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: containerBorder, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Crypto Tab ───────────────────────────────────────────────────────
          _TabPill(
            label: 'Crypto',
            icon: Icons.paid_outlined,
            isSelected: isCrypto,
            isDark: isDark,
            compact: compact,
            onTap: () {
              if (isCrypto) return;
              HapticFeedback.selectionClick();
              ref.read(marketModeProvider.notifier).setMode(MarketMode.crypto);
            },
          ),

          const SizedBox(width: 3),

          // ── Stocks Tab ───────────────────────────────────────────────────────
          _TabPill(
            label: 'Stocks',
            icon: Icons.trending_up_rounded,
            isSelected: !isCrypto,
            isDark: isDark,
            compact: compact,
            onTap: () {
              if (!isCrypto) return;
              HapticFeedback.selectionClick();
              ref.read(marketModeProvider.notifier).setMode(MarketMode.stocks);
            },
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final bool compact;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selected state colors
    final selectedBg = isDark ? const Color(0xFF29303C) : Colors.white;
    final selectedBorder = isDark ? const Color(0xFF384252) : const Color(0xFFE2E8F0);
    final activeIconColor = isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D68F2);
    final activeTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

    // Unselected state colors
    final unselectedIconColor = isDark ? const Color(0xFF7E8A9B) : const Color(0xFF64748B);
    final unselectedTextColor = isDark ? const Color(0xFF8E9BAE) : const Color(0xFF64748B);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 3.5 : 5,
        ),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: selectedBorder, width: 0.8)
              : Border.all(color: Colors.transparent, width: 0.8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 15 : 16.5,
              color: isSelected ? activeIconColor : unselectedIconColor,
            ),
            const SizedBox(width: 5.5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeTextColor : unselectedTextColor,
                fontSize: compact ? 12.5 : 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
