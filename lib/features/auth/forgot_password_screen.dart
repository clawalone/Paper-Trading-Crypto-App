import 'dart:async';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  final FocusNode _emailFocus = FocusNode();

  bool _isEmailFocused = false;
  bool _isLoading = false;
  bool _isEmailSent = false;

  Timer? _timer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
    _emailFocus.addListener(() {
      if (mounted) setState(() => _isEmailFocused = _emailFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _timer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  String _cleanFirebaseError(dynamic e) {
    final str = e.toString().toLowerCase();
    if (str.contains('user-not-found')) {
      return 'No account found with this email address. Please check your spelling or sign up.';
    } else if (str.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (str.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a minute before requesting another reset link.';
    } else if (str.contains('network-request-failed')) {
      return 'Network connection error. Please check your internet and try again.';
    }
    return e.toString().replaceAll(RegExp(r'\[.*?\]\s*'), '');
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
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
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4EA884), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F1A17),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF4EA884), width: 1),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleSendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackBar('Please enter your email address');
      _emailFocus.requestFocus();
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      _showErrorSnackBar('Please enter a valid email address');
      _emailFocus.requestFocus();
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      await AuthController.resetPassword(email);
      if (mounted) {
        setState(() {
          _isEmailSent = true;
          _isLoading = false;
        });
        _startCooldownTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(_cleanFirebaseError(e));
      }
    }
  }

  Future<void> _handleOpenMailApp() async {
    HapticFeedback.lightImpact();
    final mailUri = Uri(scheme: 'mailto');
    try {
      final launched = await launchUrl(mailUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showSuccessSnackBar('Email sent to ${_emailController.text.trim()}. Please check your mailbox app.');
      }
    } catch (_) {
      _showSuccessSnackBar('Email sent to ${_emailController.text.trim()}. Please open your mail app.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color pageBg = isDark ? const Color(0xFF0F1315) : const Color(0xFFF3EFE6);
    final Color titleColor = isDark ? const Color(0xFFEDE9DF) : const Color(0xFF12161A);
    final Color subtitleColor = isDark ? const Color(0xFF8A939A) : const Color(0xFF6C7479);
    final Color inputBg = isDark ? const Color(0xFF171C1F) : const Color(0xFFFBF9F4);
    final Color borderInactive = isDark ? const Color(0xFF283137) : const Color(0xFFDCD7CC);
    const Color activeBorderColor = Color(0xFF4EA884);
    final Color buttonBg = isDark ? const Color(0xFFEDE9DF) : const Color(0xFF12161A);
    final Color buttonFg = isDark ? const Color(0xFF0F1315) : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _isEmailSent
                    ? _buildStep2Confirmation(
                        isDark: isDark,
                        titleColor: titleColor,
                        subtitleColor: subtitleColor,
                        borderInactive: borderInactive,
                        buttonBg: buttonBg,
                        buttonFg: buttonFg,
                      )
                    : _buildStep1InputForm(
                        isDark: isDark,
                        titleColor: titleColor,
                        subtitleColor: subtitleColor,
                        inputBg: inputBg,
                        borderInactive: borderInactive,
                        activeBorderColor: activeBorderColor,
                        buttonBg: buttonBg,
                        buttonFg: buttonFg,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── STEP 1: INPUT FORM ───────────────────────────────────────────────────

  Widget _buildStep1InputForm({
    required bool isDark,
    required Color titleColor,
    required Color subtitleColor,
    required Color inputBg,
    required Color borderInactive,
    required Color activeBorderColor,
    required Color buttonBg,
    required Color buttonFg,
  }) {
    return Column(
      key: const ValueKey('step_1_input_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),

        // Security Key Icon Badge
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF4EA884).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF4EA884).withValues(alpha: 0.35), width: 1.5),
            ),
            child: const Icon(
              Icons.key_rounded,
              color: Color(0xFF4EA884),
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Headline & Description
        Text(
          'Reset password',
          style: GoogleFonts.newsreader(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: titleColor,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the email associated with your account and we will send you a password recovery link.',
          style: GoogleFonts.inter(
            fontSize: 14.5,
            color: subtitleColor,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 28),

        // Email Field Label
        Text(
          'Email address',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 6),

        // Email TextField
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isEmailFocused ? activeBorderColor : borderInactive,
              width: _isEmailFocused ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.mail_outline_rounded,
                size: 20,
                color: _isEmailFocused ? activeBorderColor : subtitleColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleSendResetLink(),
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    color: titleColor,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'alex.morgan@gmail.com',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: subtitleColor.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_emailController.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear_rounded, size: 18, color: subtitleColor),
                  onPressed: () {
                    _emailController.clear();
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Submit Button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSendResetLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: buttonFg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: buttonFg,
                    ),
                  )
                : Text(
                    'Send Reset Link',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Back to Sign In Link
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: subtitleColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text.rich(
              TextSpan(
                text: 'Remember your password? ',
                style: GoogleFonts.inter(fontSize: 13.5, color: subtitleColor),
                children: [
                  TextSpan(
                    text: 'Sign in',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4EA884),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── STEP 2: CONFIRMATION VIEW ────────────────────────────────────────────

  Widget _buildStep2Confirmation({
    required bool isDark,
    required Color titleColor,
    required Color subtitleColor,
    required Color borderInactive,
    required Color buttonBg,
    required Color buttonFg,
  }) {
    final email = _emailController.text.trim();

    return Column(
      key: const ValueKey('step_2_confirmation'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),

        // Mail Sent Icon Badge with Glow
        Center(
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFF4EA884).withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4EA884).withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4EA884).withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: Color(0xFF4EA884),
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Headline
        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: GoogleFonts.newsreader(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: titleColor,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),

        // Subtitle with highlighted email
        Text.rich(
          TextSpan(
            text: 'We have sent password reset instructions to\n',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: subtitleColor,
              height: 1.45,
            ),
            children: [
              TextSpan(
                text: email,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 26),

        // Guidance Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF171C1F) : const Color(0xFFFBF9F4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderInactive),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF4EA884), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Next steps',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '1. Tap the secure link in the email to set a new password.\n'
                '2. If you do not see it in 1 minute, check your Spam or Junk folder.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: subtitleColor,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action 1: Open Email App
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _handleOpenMailApp,
            icon: const Icon(Icons.mail_rounded, size: 18),
            label: Text(
              'Open Email App',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: buttonFg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Action 2: Resend Link (with Countdown)
        Center(
          child: _cooldownSeconds > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: subtitleColor),
                      const SizedBox(width: 6),
                      Text(
                        'Resend reset link in ${_cooldownSeconds}s',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                )
              : TextButton.icon(
                  onPressed: _isLoading ? null : _handleSendResetLink,
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF4EA884)),
                  label: Text(
                    'Resend Reset Link',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4EA884),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
        ),
        const SizedBox(height: 16),

        // Action 3: Back to Sign In
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: subtitleColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              '← Back to Sign in',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
