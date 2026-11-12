import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_theme.dart';
import '../../../core/currency_formatters.dart';
import '../../../data/community_provider.dart';
import '../../../data/models.dart';
import '../../../data/user_provider.dart';

class TipModal extends ConsumerStatefulWidget {
  final CommunityPost post;

  const TipModal({super.key, required this.post});

  @override
  ConsumerState<TipModal> createState() => _TipModalState();
}

class _TipModalState extends ConsumerState<TipModal> {
  int _selectedAmount = 50;
  final List<int> _tipPresetAmounts = [10, 50, 100, 500];

  void _sendTip() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentUserState = ref.read(userProvider);
    final senderName = currentUserState.profile.name.isNotEmpty
        ? currentUserState.profile.name
        : 'A trader';

    if (widget.post.authorId.isNotEmpty && widget.post.authorId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You cannot tip your own post!',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }

    final success = ref.read(userProvider.notifier).deductVirtualBalanceForTip(
          amount: _selectedAmount.toDouble(),
          recipientName: widget.post.authorName,
        );

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient USD virtual balance to tip! Top up from your profile.',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }

    ref.read(communityProvider.notifier).tipPost(
          postId: widget.post.id,
          amount: _selectedAmount,
          recipientId: widget.post.authorId,
          recipientName: widget.post.authorName,
          senderId: currentUserId,
          senderName: senderName,
        );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.stars_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Successfully tipped \$$_selectedAmount USD to ${widget.post.authorName}! 🪙✨',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
    final availableUsd = inrRate > 0 ? (userState.profile.virtualBalance / inrRate) : userState.profile.virtualBalance;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              color: AppColors.warning,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Tip in USD (\$)',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Show appreciation to ${widget.post.authorName} in USD (\$) virtual cash!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.subtle,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Text(
              'Available: \$${availableUsd.toStringAsFixed(2)} USD',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Preset Amount Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _tipPresetAmounts.map((amount) {
              final isSelected = _selectedAmount == amount;
              return GestureDetector(
                onTap: () => setState(() => _selectedAmount = amount),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.warning.withValues(alpha: 0.2) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.warning : AppColors.outline,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.monetization_on_rounded, color: AppColors.warning, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        '\$$amount',
                        style: GoogleFonts.inter(
                          color: isSelected ? AppColors.warning : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'USD',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Tip Action Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _sendTip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.card_giftcard_rounded, size: 20),
              label: Text(
                'Send \$$_selectedAmount USD Tip',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
