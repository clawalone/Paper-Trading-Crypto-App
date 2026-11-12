import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_translations.dart';
import '../../../data/models.dart';
import '../../../data/user_provider.dart';

class EditProfileSheet extends StatefulWidget {
  final UserState userState;
  final WidgetRef ref;

  const EditProfileSheet({
    super.key,
    required this.userState,
    required this.ref,
  });

  static Future<void> show(BuildContext context, WidgetRef ref, UserState userState) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileSheet(userState: userState, ref: ref),
    );
  }

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  String? _selectedBadge;
  String _badgeFilter = 'All'; // 'All', 'Stocks', 'Crypto'

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userState.profile.name);
    _bioController = TextEditingController(text: widget.userState.profile.bio);
    _selectedBadge = widget.userState.profile.featuredBadgeId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-aware palette matching the new modern design system
    final sheetBg = isDark ? const Color(0xFF171A21) : Colors.white;
    final surfaceInputBg = isDark ? const Color(0xFF1D222B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2A323F) : const Color(0xFFE2E8F0);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF8E9BAE) : const Color(0xFF64748B);
    final activeAccent = isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D68F2);

    final unlocked = ALL_BADGES.where((b) => widget.userState.profile.unlockedBadges.contains(b.id)).toList();
    final filteredBadges = unlocked.where((b) {
      if (_badgeFilter == 'Stocks') return b.id.startsWith('b_stock');
      if (_badgeFilter == 'Crypto') return !b.id.startsWith('b_stock');
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Drag Handle ──────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF363E4D) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Title & Close Button ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Profile & Showcase Badge'.tr(),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222834) : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Trader Name Field ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 14, color: secondaryTextColor),
                        const SizedBox(width: 5),
                        Text(
                          'TRADER NAME'.tr(),
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _nameController,
                      builder: (context, value, _) {
                        return Text(
                          '${value.text.length}/12',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: surfaceInputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.0),
                  ),
                  child: TextField(
                    controller: _nameController,
                    maxLength: 12,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter name (e.g. Alex)'.tr(),
                      hintStyle: TextStyle(color: secondaryTextColor.withValues(alpha: 0.6), fontSize: 13.5),
                      counterText: '',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Text(
                    'Max 12 chars • Prevents "..." truncation across headers & leaderboards'.tr(),
                    style: TextStyle(
                      color: secondaryTextColor.withValues(alpha: 0.75),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Trader Bio Field ─────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 16, color: secondaryTextColor),
                        const SizedBox(width: 5),
                        Text(
                          'TRADER BIO'.tr(),
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _bioController,
                      builder: (context, value, _) {
                        return Text(
                          '${value.text.length}/80',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: surfaceInputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.0),
                  ),
                  child: TextField(
                    controller: _bioController,
                    maxLines: 2,
                    maxLength: 80,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Share your trading strategy or favorite assets...'.tr(),
                      hintStyle: TextStyle(color: secondaryTextColor.withValues(alpha: 0.6), fontSize: 12.5),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // ── Featured Showcase Badge Header ───────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.military_tech_outlined, size: 15, color: secondaryTextColor),
                        const SizedBox(width: 5),
                        Text(
                          'FEATURED SHOWCASE BADGE'.tr(),
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedBadge != null)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedBadge = null);
                        },
                        child: Text(
                          'Clear Badge'.tr(),
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Filter Segmented Pill ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14171D) : const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterChip('All', Icons.grid_view_rounded, isDark),
                      const SizedBox(width: 4),
                      _buildFilterChip('Stocks', Icons.trending_up_rounded, isDark),
                      const SizedBox(width: 4),
                      _buildFilterChip('Crypto', Icons.paid_outlined, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Badges List / Empty State ────────────────────────────────────
                if (filteredBadges.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surfaceInputBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 0.8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 24, color: secondaryTextColor),
                        const SizedBox(height: 8),
                        Text(
                          'No unlocked badges in this category yet.'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Earn badges by completing quests in Rewards Hub!'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: secondaryTextColor, fontSize: 11.5),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: filteredBadges.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final b = filteredBadges[index];
                        final isSel = _selectedBadge == b.id;
                        final isStock = b.id.startsWith('b_stock');

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedBadge = b.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 124,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? (isDark ? const Color(0xFF222B38) : const Color(0xFFEEF4FF))
                                  : surfaceInputBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSel ? activeAccent : borderColor,
                                width: isSel ? 1.6 : 0.8,
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: activeAccent.withValues(alpha: isDark ? 0.25 : 0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF14171E) : const Color(0xFFE9EEF4),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(b.icon, style: const TextStyle(fontSize: 20)),
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      b.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSel ? primaryTextColor : secondaryTextColor,
                                        fontSize: 11.5,
                                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      isStock ? 'Stocks' : 'Crypto',
                                      style: TextStyle(
                                        color: isStock ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isSel)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      size: 15,
                                      color: activeAccent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Save Profile Button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      final newName = _nameController.text.trim();
                      final newBio = _bioController.text.trim();
                      if (newName.isNotEmpty) {
                        widget.ref.read(userProvider.notifier).updateProfileSettings(name: newName);
                      }
                      widget.ref.read(userProvider.notifier).updateBioAndBadge(newBio, _selectedBadge);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Profile and showcase badge saved! ✨'.tr()),
                          backgroundColor: activeAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: activeAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Profile'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isDark) {
    final active = _badgeFilter == label;
    final activeBg = isDark ? const Color(0xFF242C38) : Colors.white;
    final activeBorder = isDark ? const Color(0xFF384354) : const Color(0xFFE2E8F0);
    final activeColor = isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D68F2);
    final inactiveColor = isDark ? const Color(0xFF8E9BAE) : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _badgeFilter = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? activeBorder : Colors.transparent, width: 0.8),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 4),
            Text(
              label.tr(),
              style: TextStyle(
                color: active ? (isDark ? Colors.white : const Color(0xFF0F172A)) : inactiveColor,
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
