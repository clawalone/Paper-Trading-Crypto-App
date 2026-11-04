import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/app_review_manager.dart';
import '../../core/currency_formatters.dart';
import '../../core/currency_picker.dart';
import '../../data/user_provider.dart';
import '../../data/market_provider.dart';
import '../../data/community_provider.dart';
import '../../data/models.dart';
import 'request_money_screen.dart';
import 'admin_panel_screen.dart';
import 'terms_screen.dart';
import 'how_it_works_screen.dart';
import 'wallet_screen.dart';
import 'feature_request_screen.dart';

const _avatars = [
  'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Cat.png',
  'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Dog%20Face.png',
  'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Fox.png',
  'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Bear.png',
  'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Panda.png',
  'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Rabbit%20Face.png',
  'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Tiger%20Face.png',
  'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Lion.png',
  'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Monkey%20Face.png',
  'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Animals/Unicorn.png'
];

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final marketState = ref.watch(marketProvider);
    final user = FirebaseAuth.instance.currentUser;
    final currentUserId = user?.uid ?? '';
    final isAdmin = (user?.email?.toLowerCase() == 'admin@gmail.com') ||
        userState.profile.email.toLowerCase() == 'admin@gmail.com' ||
        userState.profile.name.toLowerCase().contains('admin');
    final isVerified = isAdmin || ref.watch(isUserVerifiedProvider(currentUserId));
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    double portfolioValue = 0;
    for (var h in userState.holdings) {
      final stock = marketState.firstWhere(
        (c) => c.symbol == h.symbol,
        orElse: () => marketState.first,
      );
      portfolioValue += h.quantity * stock.currentPrice;
    }

    double futuresValue = 0;
    for (final pos in userState.futuresPositions) {
      final s = marketState.firstWhere((m) => m.symbol == pos.symbol,
          orElse: () => marketState.first);
      final isLong = pos.side == OrderSide.buy;
      final diff = s.currentPrice - pos.entryPrice;
      final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
      final currentValue = pos.margin + pnl;
      futuresValue += currentValue > 0 ? currentValue : 0;
    }

    final netWorth = userState.profile.virtualBalance + portfolioValue + futuresValue;

    final uidDisplay = userState.profile.publicUid.isNotEmpty
        ? userState.profile.publicUid
        : (user?.uid != null ? user!.uid.substring(0, 8).toUpperCase() : '84920184');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        // actions removed per user request
      ),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // ── HEADER ────────────────────────────────────────────────────────
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF1E2329),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (context) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Choose Avatar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              alignment: WrapAlignment.center,
                              children: _avatars.map((url) => GestureDetector(
                                onTap: () {
                                  ref.read(userProvider.notifier).updateProfileSettings(photoUrl: url);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2B3139),
                                    shape: BoxShape.circle,
                                    border: userState.profile.photoUrl == url ? Border.all(color: AppColors.primary, width: 2) : null,
                                  ),
                                  child: ClipOval(
                                    child: Image.network(url, fit: BoxFit.cover),
                                  ),
                                ),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
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
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 12, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userState.profile.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFF0095F6),
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'UID: $uidDisplay',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: uidDisplay));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('UID copied to clipboard!'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating),
                              );
                            },
                            child: const Icon(Icons.copy,
                                size: 14, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── STATS CARDS ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _MiniStatCard(
                    title: 'Total XP',
                    value: '${userState.profile.xp}',
                    icon: Icons.star_rounded,
                    iconColor: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatCard(
                    title: 'Streak',
                    value: '${userState.profile.streak} Days',
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.deepOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MiniStatCard(
              title: 'Net Worth',
              value: formatter.format(netWorth),
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppColors.primary,
              fullWidth: true,
            ),
            const SizedBox(height: 32),

            // ── MENU SECTIONS ────────────────────────────────────────────────
            const Text(
              'Account',
              style: TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            if (user?.email == 'admin@gmail.com')
              _MenuTile(
                icon: Icons.admin_panel_settings,
                title: 'Admin Panel',
                subtitle: 'Manage requests & users',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
                },
              ),
            _MenuTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallet',
              subtitle: 'Transaction history & balance',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
              },
            ),
            _MenuTile(
              icon: Icons.add_card_rounded,
              title: 'Buy Virtual Funds',
              subtitle: 'Top-up balance with UPI / Cards',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestMoneyScreen()));
              },
            ),
            _MenuTile(
              icon: Icons.bug_report_outlined,
              title: 'Report a Bug',
              subtitle: 'Email acadrio.official@gmail.com with details/images',
              onTap: () => _handleReportBug(context, userState),
            ),
            const SizedBox(height: 24),
            const Text(
              'Preferences',
              style: TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.language,
              title: 'Language',
              trailingText: userState.profile.preferredLanguage,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    backgroundColor: const Color(0xFF1E2329),
                    title: const Text('Select Language', style: TextStyle(color: Colors.white)),
                    children: ['English', 'Hindi', 'Spanish'].map((lang) {
                      return SimpleDialogOption(
                        onPressed: () {
                          ref.read(userProvider.notifier).updateProfileSettings(language: lang);
                          Navigator.pop(ctx);
                        },
                        child: Text(lang, style: const TextStyle(color: Colors.white70)),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            Builder(
              builder: (ctx) {
                final currInfo = CurrencyFormatters.getInfo(userState.profile.preferredCurrency);
                return _MenuTile(
                  icon: Icons.attach_money,
                  title: 'Currency',
                  trailingText: '${currInfo.flag} ${currInfo.code} (${currInfo.symbol})',
                  onTap: () {
                    CurrencyPicker.show(
                      ctx,
                      currentCode: userState.profile.preferredCurrency,
                      onSelected: (code) {
                        ref.read(userProvider.notifier).updateProfileSettings(currency: code);
                      },
                    );
                  },
                );
              },
            ),
            _MenuTile(
              icon: Icons.dark_mode_outlined,
              title: 'Theme',
              trailingText: userState.profile.themeMode,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    backgroundColor: const Color(0xFF1E2329),
                    title: const Text('Select Theme', style: TextStyle(color: Colors.white)),
                    children: ['Dark', 'Light', 'System'].map((t) {
                      return SimpleDialogOption(
                        onPressed: () {
                          ref.read(userProvider.notifier).updateProfileSettings(themeMode: t);
                          Navigator.pop(ctx);
                        },
                        child: Text(t, style: const TextStyle(color: Colors.white70)),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            const Text(
              'Legal & Help',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFF0B90B),
              title: 'Rate on Google Play',
              subtitle: 'Share your review & claim +\$25 cash bonus',
              trailingWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0B90B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFF0B90B).withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.card_giftcard_rounded, color: Color(0xFFF0B90B), size: 12),
                    SizedBox(width: 4),
                    Text(
                      '+\$25',
                      style: TextStyle(
                        color: Color(0xFFF0B90B),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () {
                AppReviewManager.showReviewDialog(
                  context,
                  ref,
                  isFromProfile: true,
                );
              },
            ),
            _MenuTile(
              icon: Icons.help_outline,
              title: 'How It Works',
              subtitle: 'Feature guide & tutorials',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HowItWorksScreen()));
              },
            ),
            _MenuTile(
              icon: Icons.tips_and_updates_outlined,
              title: 'Request a Feature',
              subtitle: 'Suggest new features for the app',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FeatureRequestScreen()));
              },
            ),
            _MenuTile(
              icon: Icons.gavel,
              title: 'Terms & Conditions',
              subtitle: 'Legal disclaimers & rules',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()));
              },
            ),

            const SizedBox(height: 32),

            // 🛑 LOGOUT BUTTON 🛑────────────────────────────────────────────────
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.loss,
                side: BorderSide(color: AppColors.loss.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.loss,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E2329),
                    title: const Row(
                      children: [
                        Icon(Icons.warning_rounded, color: AppColors.loss),
                        SizedBox(width: 8),
                        Text('Delete Account', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    content: const Text(
                      'Are you sure you want to permanently delete your account? All your stats, balances, and history will be lost. This action cannot be undone.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
                        child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
                      await user.delete();
                    }
                    if (context.mounted) {
                      Navigator.pop(context); 
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please log out and log back in to verify your identity before deleting your account.'),
                          backgroundColor: AppColors.loss,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.loss,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReportBug(BuildContext context, UserState userState) async {
    const recipientEmail = 'acadrio.official@gmail.com';
    final uid = userState.profile.publicUid.isNotEmpty
        ? userState.profile.publicUid
        : (FirebaseAuth.instance.currentUser?.uid ?? 'Unknown');
    final userName = userState.profile.name.isNotEmpty
        ? userState.profile.name
        : 'Trader';

    const subject = '[Bug Report] Paper Trading - Crypto';
    final body =
        'Hi Acadrio Team,\n\n'
        'I would like to report an issue encountered in the app.\n\n'
        '--- Account Details ---\n'
        'Trader Name: $userName\n'
        'User UID: $uid\n'
        'Preferred Currency: ${userState.profile.preferredCurrency}\n\n'
        '--- Bug Details ---\n'
        'Description:\n'
        '[Please describe what happened]\n\n'
        'Steps to reproduce:\n'
        '1. \n'
        '2. \n'
        '3. \n\n'
        'Expected result:\n'
        '[What did you expect to happen]\n\n'
        'Note: Please attach any screenshots or images directly to this email to help us investigate.\n\n'
        'Thank you!';

    final emailUri = Uri(
      scheme: 'mailto',
      path: recipientEmail,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not launch mail application');
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: recipientEmail));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF1E2329),
            content: Text(
              'Could not open mail app. Support email copied: acadrio.official@gmail.com',
              style: TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MINI STAT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool fullWidth;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2B3139)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MENU TILE
// ─────────────────────────────────────────────────────────────────────────────
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailingWidget;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailingWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.03),
      highlightColor: Colors.white.withValues(alpha: 0.01),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? const Color(0xFF6B7280), size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null) ...[
              trailingWidget!,
              const SizedBox(width: 8),
            ] else if (trailingText != null) ...[
              Text(
                trailingText!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: Color(0xFF4B5563), size: 20),
          ],
        ),
      ),
    );
  }
}



