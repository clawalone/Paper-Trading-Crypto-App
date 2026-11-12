import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../core/avatar_helper.dart';
import '../../core/currency_formatters.dart';
import '../../core/currency_picker.dart';
import '../../data/user_provider.dart';
import '../../data/market_mode_provider.dart';

const List<String> _avatars = AppAvatarHelper.localAvatars;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _experience = 'Beginner';
  String _currency = 'USD';
  String _selectedArena = 'crypto';
  String _photoUrl = _avatars[0];
  bool _acceptedTerms = false;
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();

  final List<String> _experienceTiers = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _acceptedTerms = false;
    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _showAvatarPicker(_OnboardingColors c) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Animated Avatar',
                        style: GoogleFonts.inter(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select an animated mascot for your trading profile',
                        style: GoogleFonts.inter(
                          color: c.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 18, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: _avatars.map((url) {
                  final isSelected = _photoUrl == url;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _photoUrl = url);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: c.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? c.borderActive : c.borderSubtle,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: ClipOval(
                        child: AppAvatar(
                          avatarUrl: url,
                          size: 54,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a trader name.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.loss,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _nameFocusNode.requestFocus();
      return;
    }
    if (!_acceptedTerms) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_box_outline_blank_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please click and check the simulator acknowledgment box to continue.',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1418),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFF6465D), width: 1),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final experienceLevel = _experience == 'Advanced' ? 'Pro' : _experience;
    ref.read(marketModeProvider.notifier).setMode(
          _selectedArena == 'stocks' ? MarketMode.stocks : MarketMode.crypto,
        );
    ref.read(userProvider.notifier).onboardUser(
          _nameController.text.trim(),
          experienceLevel,
          _currency,
          _photoUrl,
        );
  }

  Widget _buildAvatarItem(String url, _OnboardingColors c) {
    final isSelected = _photoUrl == url;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _photoUrl = url);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? c.surfaceElevated : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? c.borderActive : c.borderSubtle,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ClipOval(
            child: AppAvatar(
              avatarUrl: url,
              size: 42,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _OnboardingColors.of(context);
    final currencyInfo = CurrencyFormatters.getInfo(_currency);
    final currencySymbol = CurrencyFormatters.getSymbol(_currency);
    final isReady = _acceptedTerms && _nameController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: c.surfaceBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation / Brand Row ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.borderSubtle),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(
                            'assets/icon.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Paper Trading',
                        style: GoogleFonts.inter(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.surfaceCard,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: c.borderActive,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SIMULATOR',
                          style: GoogleFonts.inter(
                            color: c.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Main Content Area ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Title & Description
                    Text(
                      'Create Profile',
                      style: GoogleFonts.inter(
                        color: c.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Set up your trader identity and preferences to begin simulated market execution.',
                      style: GoogleFonts.inter(
                        color: c.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Animated Avatar Hero Display
                    Center(
                      child: GestureDetector(
                        onTap: () => _showAvatarPicker(c),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.surfaceElevated,
                                border: Border.all(
                                  color: c.borderSubtle,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: AppAvatar(
                                  avatarUrl: _photoUrl,
                                  size: 84,
                                ),
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: c.surfaceCard,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.borderSubtle, width: 1.5),
                                ),
                                child: Icon(
                                  Icons.sync_rounded,
                                  size: 14,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // All 10 Animated Avatars (Symmetric 2 Rows of 5, No Scroll Needed)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _avatars.sublist(0, 5).map((url) => _buildAvatarItem(url, c)).toList(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _avatars.sublist(5, 10).map((url) => _buildAvatarItem(url, c)).toList(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Inset Grouped Settings Card ──────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: c.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.borderSubtle),
                        boxShadow: c.isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Field 1: Trader Name Input
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TRADER NAME',
                                      style: GoogleFonts.inter(
                                        color: c.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      '${_nameController.text.length}/25',
                                      style: GoogleFonts.inter(
                                        color: c.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _nameController,
                                  focusNode: _nameFocusNode,
                                  maxLength: 25,
                                  style: GoogleFonts.inter(
                                    color: c.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  cursorColor: c.borderActive,
                                  decoration: InputDecoration(
                                    filled: false,
                                    fillColor: Colors.transparent,
                                    counterText: '',
                                    hintText: 'e.g. Satoshi',
                                    hintStyle: GoogleFonts.inter(
                                      color: c.textMuted,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Hairline Divider
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            color: c.borderSubtle,
                          ),

                          // Field 2: Experience Level
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EXPERIENCE LEVEL',
                                  style: GoogleFonts.inter(
                                    color: c.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  height: 40,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: c.tierSwitchBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: c.borderSubtle),
                                  ),
                                  child: Row(
                                    children: _experienceTiers.map((tier) {
                                      final isSelected = _experience == tier;
                                      return Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() => _experience = tier);
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? c.tierSwitchSelected
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                              border: isSelected
                                                  ? Border.all(color: c.tierBorderSelected, width: 1)
                                                  : null,
                                              boxShadow: isSelected && !c.isDark
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.06),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 1),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Text(
                                              tier,
                                              style: GoogleFonts.inter(
                                                color: isSelected
                                                    ? (c.isDark ? const Color(0xFF64B5F6) : const Color(0xFF1976D2))
                                                    : c.textSecondary,
                                                fontSize: 13,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Hairline Divider
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            color: c.borderSubtle,
                          ),

                          // Field 3: Settlement Currency
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              CurrencyPicker.show(
                                context,
                                currentCode: _currency,
                                onSelected: (code) => setState(() => _currency = code),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'BASE CURRENCY',
                                          style: GoogleFonts.inter(
                                            color: c.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              currencyInfo.flag,
                                              style: const TextStyle(fontSize: 18),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$_currency ($currencySymbol)',
                                              style: GoogleFonts.inter(
                                                color: c.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                '•  ${currencyInfo.name}',
                                                style: GoogleFonts.inter(
                                                  color: c.textSecondary,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: c.textSecondary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Hairline Divider
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            color: c.borderSubtle,
                          ),

                          // Field 4: Starting Arena Selector
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'STARTING ARENA',
                                      style: GoogleFonts.inter(
                                        color: c.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      'Switch anytime with 1 tap',
                                      style: GoogleFonts.inter(
                                        color: c.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    // Option 1: Crypto Arena
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _selectedArena = 'crypto');
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: _selectedArena == 'crypto'
                                                ? c.tierSwitchSelected
                                                : c.tierSwitchBg,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _selectedArena == 'crypto'
                                                  ? c.tierBorderSelected
                                                  : c.borderSubtle,
                                              width: _selectedArena == 'crypto' ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text('🪙', style: TextStyle(fontSize: 18)),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      'Crypto Arena',
                                                      style: GoogleFonts.inter(
                                                        color: c.textPrimary,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '24/7 Binance • Up to 20x',
                                                style: GoogleFonts.inter(
                                                  color: c.textSecondary,
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Option 2: Stock Arena
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _selectedArena = 'stocks');
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: _selectedArena == 'stocks'
                                                ? c.tierSwitchSelected
                                                : c.tierSwitchBg,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _selectedArena == 'stocks'
                                                  ? c.tierBorderSelected
                                                  : c.borderSubtle,
                                              width: _selectedArena == 'stocks' ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text('📈', style: TextStyle(fontSize: 18)),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      'Stock Arena',
                                                      style: GoogleFonts.inter(
                                                        color: c.textPrimary,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'US & India • Up to 5x',
                                                style: GoogleFonts.inter(
                                                  color: c.textSecondary,
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                            ],
                                          ),
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

                    const SizedBox(height: 24),

                    // ── Terms / Regulatory Checkbox ──────────────────────────
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _acceptedTerms = !_acceptedTerms);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _acceptedTerms
                              ? c.borderActive.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _acceptedTerms
                                ? c.borderActive.withValues(alpha: 0.35)
                                : c.borderSubtle,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: _acceptedTerms ? c.borderActive : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _acceptedTerms ? c.borderActive : c.textMuted,
                                  width: 1.8,
                                ),
                              ),
                              child: _acceptedTerms
                                  ? Icon(Icons.check_rounded, size: 14, color: c.isDark ? Colors.black : Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'By entering, you acknowledge that this is a paper-trading simulator for educational purposes. No real money is traded, and this app does not provide financial advice.',
                                style: GoogleFonts.inter(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Pinned Bottom CTA ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                color: c.surfaceBg,
                border: Border(
                  top: BorderSide(color: c.borderSubtle, width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReady ? c.activeCtaBg : c.inactiveCtaBg,
                    foregroundColor: isReady ? c.activeCtaFg : c.inactiveCtaText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isReady ? c.activeCtaBg : c.borderSubtle,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    'Create Account',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isReady ? c.activeCtaFg : c.inactiveCtaText,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic, design-calibrated token theme for OnboardingScreen.
class _OnboardingColors {
  final bool isDark;
  final Color surfaceBg;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color tierSwitchBg;
  final Color tierSwitchSelected;
  final Color tierBorderSelected;
  final Color borderSubtle;
  final Color borderActive;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color inactiveCtaBg;
  final Color inactiveCtaText;
  final Color activeCtaBg;
  final Color activeCtaFg;

  const _OnboardingColors({
    required this.isDark,
    required this.surfaceBg,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.tierSwitchBg,
    required this.tierSwitchSelected,
    required this.tierBorderSelected,
    required this.borderSubtle,
    required this.borderActive,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.inactiveCtaBg,
    required this.inactiveCtaText,
    required this.activeCtaBg,
    required this.activeCtaFg,
  });

  factory _OnboardingColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _OnboardingColors(
        isDark: true,
        surfaceBg: Color(0xFF090A0C),
        surfaceCard: Color(0xFF111419),
        surfaceElevated: Color(0xFF181C23),
        tierSwitchBg: Color(0xFF14171E),
        tierSwitchSelected: Color(0xFF14243B),
        tierBorderSelected: Color(0xFF2196F3),
        borderSubtle: Color(0xFF1F242D),
        borderActive: Color(0xFF2196F3),
        textPrimary: Color(0xFFF2F4F7),
        textSecondary: Color(0xFF8A92A0),
        textMuted: Color(0xFF525966),
        inactiveCtaBg: Color(0xFF111419),
        inactiveCtaText: Color(0xFF525966),
        activeCtaBg: Color(0xFF2196F3),
        activeCtaFg: Colors.white,
      );
    } else {
      return const _OnboardingColors(
        isDark: false,
        surfaceBg: Color(0xFFF3EFE6),
        surfaceCard: Colors.white,
        surfaceElevated: Color(0xFFEBE5D9),
        tierSwitchBg: Color(0xFFEFEAE0),
        tierSwitchSelected: Colors.white,
        tierBorderSelected: Color(0xFF2196F3),
        borderSubtle: Color(0xFFE2DDD2),
        borderActive: Color(0xFF1976D2),
        textPrimary: Color(0xFF12161A),
        textSecondary: Color(0xFF6C7478),
        textMuted: Color(0xFF9CA3AF),
        inactiveCtaBg: Color(0xFFE2DDD2),
        inactiveCtaText: Color(0xFF9CA3AF),
        activeCtaBg: Color(0xFF1976D2),
        activeCtaFg: Colors.white,
      );
    }
  }
}
