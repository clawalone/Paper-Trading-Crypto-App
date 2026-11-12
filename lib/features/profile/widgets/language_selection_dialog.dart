import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_translations.dart';
import '../../../data/user_provider.dart';

class LanguageOption {
  final String code;
  final String title;
  final String? subtitle;

  const LanguageOption({
    required this.code,
    required this.title,
    this.subtitle,
  });
}

class LanguageSelectionDialog extends ConsumerStatefulWidget {
  final String currentLanguage;

  const LanguageSelectionDialog({
    super.key,
    required this.currentLanguage,
  });

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final current = ref.read(userProvider).profile.preferredLanguage;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LanguageSelectionDialog(currentLanguage: current),
    );
  }

  @override
  ConsumerState<LanguageSelectionDialog> createState() => _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends ConsumerState<LanguageSelectionDialog> {
  late String _selectedCode;

  static const List<LanguageOption> _options = [
    LanguageOption(
      code: 'English',
      title: 'English',
      subtitle: null,
    ),
    LanguageOption(
      code: 'Hindi',
      title: 'हिन्दी',
      subtitle: 'Hindi',
    ),
    LanguageOption(
      code: 'Spanish',
      title: 'Español',
      subtitle: 'Spanish',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Palette calibrated directly to the design spec for Light and Dark themes
    final dialogBg = isDark ? const Color(0xFF181B22) : Colors.white;
    final dialogBorder = isDark ? const Color(0xFF282F3B) : const Color(0xFFE2E8F0);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final selectedRowBg = isDark ? const Color(0xFF202A38) : const Color(0xFFEEF4FF);
    final dividerColor = isDark ? const Color(0xFF232832) : const Color(0xFFF1F5F9);

    final cancelBg = isDark ? const Color(0xFF1E232B) : Colors.white;
    final cancelBorder = isDark ? const Color(0xFF333A46) : const Color(0xFFD1D5DB);
    final cancelTextColor = isDark ? Colors.white : const Color(0xFF1F2937);

    final applyBg = isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D68F2);

    return Dialog(
      backgroundColor: dialogBg,
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: dialogBorder, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select language'.tr(),
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 18.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Choose the language used across the app.'.tr(),
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Language Options ────────────────────────────────────────────────
            ..._options.asMap().entries.map((entry) {
              final idx = entry.key;
              final opt = entry.value;
              final isSelected = _selectedCode.toLowerCase() == opt.code.toLowerCase();

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (idx > 0)
                    Divider(height: 1, thickness: 1, color: dividerColor),
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCode = opt.code);
                    },
                    child: Container(
                      color: isSelected ? selectedRowBg : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  opt.title,
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (opt.subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    opt.subtitle!,
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _buildRadioButton(isSelected, isDark),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),

            const SizedBox(height: 6),

            // ── Bottom Action Buttons ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: cancelBg,
                        side: BorderSide(color: cancelBorder, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel'.tr(),
                        style: TextStyle(
                          color: cancelTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Apply Button
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref.read(userProvider.notifier).updateProfileSettings(language: _selectedCode);
                        AppTranslations.setLanguage(_selectedCode);
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: applyBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: Text(
                        'Apply'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioButton(bool isSelected, bool isDark) {
    final activeColor = isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D68F2);
    final inactiveColor = isDark ? const Color(0xFF4B5565) : const Color(0xFFCBD5E1);

    if (isSelected) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: activeColor, width: 2.2),
        ),
        child: Center(
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeColor,
            ),
          ),
        ),
      );
    } else {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: inactiveColor, width: 2),
        ),
      );
    }
  }
}
