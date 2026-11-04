import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../core/currency_picker.dart';
import '../../data/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _experience = 'Beginner';
  String _currency = 'USD';
  String _photoUrl = _avatars[0];
  bool _acceptedTerms = false;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && ModalRoute.of(context)?.isCurrent == true && FirebaseAuth.instance.currentUser != null) {
        _showAvatarPicker();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showAvatarPicker() {
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
                  setState(() => _photoUrl = url);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B3139),
                    shape: BoxShape.circle,
                    border: _photoUrl == url ? Border.all(color: AppColors.primary, width: 2) : null,
                  ),
                  child: ClipOval(
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.auto_graph, color: AppColors.primary, size: 64),
                const SizedBox(height: 20),
                const Text('Paper Trading', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                const Text('Set up your trading profile.', style: TextStyle(fontSize: 16, color: Colors.white70)),
                const SizedBox(height: 32),
                Center(
                  child: GestureDetector(
                    onTap: _showAvatarPicker,
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2329),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: ClipOval(child: Image.network(_photoUrl, fit: BoxFit.cover)),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 14, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                const Text('Trader Name', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Satoshi',
                    hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                    filled: true,
                    fillColor: const Color(0xFF1E2329),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text('Experience level', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ['Beginner', 'Intermediate', 'Pro'].map((e) {
                    return ChoiceChip(
                      label: Text(e),
                      selected: _experience == e,
                      onSelected: (_) => setState(() => _experience = e),
                      backgroundColor: const Color(0xFF1E2329),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(color: _experience == e ? AppColors.primary : Colors.white70),
                      side: BorderSide(color: _experience == e ? AppColors.primary : Colors.transparent),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                const Text('Preferred Currency', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    CurrencyPicker.show(
                      context,
                      currentCode: _currency,
                      onSelected: (code) => setState(() => _currency = code),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2329),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2B3139)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          CurrencyFormatters.getInfo(_currency).flag,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_currency (${CurrencyFormatters.getSymbol(_currency)})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                CurrencyFormatters.getInfo(_currency).name,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Change',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...['USD', 'INR', 'EUR', 'GBP', 'AED', 'JPY'].map((e) {
                      final isSelected = _currency == e;
                      final info = CurrencyFormatters.getInfo(e);
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(info.flag, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(e),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _currency = e),
                        backgroundColor: const Color(0xFF1E2329),
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(color: isSelected ? AppColors.primary : Colors.transparent),
                      );
                    }),
                    ActionChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public, size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('160+ More', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      backgroundColor: const Color(0xFF1E2329),
                      side: const BorderSide(color: Color(0xFF2B3139)),
                      onPressed: () {
                        CurrencyPicker.show(
                          context,
                          currentCode: _currency,
                          onSelected: (code) => setState(() => _currency = code),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 40),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _acceptedTerms = !_acceptedTerms;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _acceptedTerms ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFF1E2329),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _acceptedTerms ? AppColors.primary.withValues(alpha: 0.5) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _acceptedTerms,
                            onChanged: (val) {
                              setState(() {
                                _acceptedTerms = val ?? false;
                              });
                            },
                            activeColor: AppColors.primary,
                            checkColor: Colors.black,
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'By entering, you acknowledge that this is a paper-trading simulator for educational purposes. No real money is traded, and this app does not provide financial advice.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    if (_nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a Trader Name to continue.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          backgroundColor: AppColors.loss,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    if (!_acceptedTerms) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please check the acknowledgment box above to continue.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    final currencyCode = _currency;
                    ref.read(userProvider.notifier).onboardUser(
                      _nameController.text.trim(),
                      _experience,
                      currencyCode,
                      _photoUrl,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _acceptedTerms ? AppColors.primary : Colors.grey.shade800,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Enter Arena', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _acceptedTerms ? Colors.black : Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

