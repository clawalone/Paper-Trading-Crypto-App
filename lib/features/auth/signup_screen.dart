import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/auth_provider.dart';
import '../home/home_shell.dart';
import '../profile/privacy_policy_screen.dart';
import '../profile/terms_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  final _emailFocus = FocusNode();
  final _pwdFocus = FocusNode();

  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;
  bool _isEmailFocused = false;
  bool _isPwdFocused = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      setState(() => _isEmailFocused = _emailFocus.hasFocus);
    });
    _pwdFocus.addListener(() {
      setState(() => _isPwdFocused = _pwdFocus.hasFocus);
    });
    _pwd.addListener(() {
      if (mounted) setState(() {});
    });
  }

  String _cleanAuthErrorMessage(dynamic e) {
    final str = e.toString().toLowerCase();
    if (str.contains('email-already-in-use')) {
      return 'An account already exists with this email. Please log in.';
    } else if (str.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (str.contains('weak-password')) {
      return 'Password must be at least 8 characters and include uppercase, lowercase, and numbers.';
    } else if (str.contains('network-request-failed')) {
      return 'Network connection error. Please check your internet connection.';
    }
    return e.toString().replaceAll(RegExp(r'\[.*?\]\s*'), '');
  }

  @override
  void dispose() {
    _email.dispose();
    _pwd.dispose();
    _emailFocus.dispose();
    _pwdFocus.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message, bool isDark) {
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
                message.replaceAll(RegExp(r'\[.*?\]\s*'), ''),
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

  Future<void> _submit(bool isDark) async {
    final email = _email.text.trim();
    final pwd = _pwd.text;

    if (email.isEmpty) {
      _showErrorSnackBar('Please enter your email address', isDark);
      _emailFocus.requestFocus();
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      _showErrorSnackBar('Please enter a valid email address format', isDark);
      _emailFocus.requestFocus();
      return;
    }
    if (pwd.length < 8) {
      _showErrorSnackBar('Password must be at least 8 characters long', isDark);
      _pwdFocus.requestFocus();
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(pwd)) {
      _showErrorSnackBar('Password must contain at least one uppercase letter (A-Z)', isDark);
      _pwdFocus.requestFocus();
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(pwd)) {
      _showErrorSnackBar('Password must contain at least one lowercase letter (a-z)', isDark);
      _pwdFocus.requestFocus();
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(pwd)) {
      _showErrorSnackBar('Password must contain at least one number (0-9)', isDark);
      _pwdFocus.requestFocus();
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      await AuthController.signUp(email, pwd);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (r) => false,
        );
      }
    } catch (e) {
      _showErrorSnackBar(_cleanAuthErrorMessage(e), isDark);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle(bool isDark) async {
    HapticFeedback.lightImpact();
    setState(() => _googleLoading = true);
    try {
      await AuthController.signInWithGoogle();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (r) => false,
        );
      }
    } catch (e) {
      _showErrorSnackBar(e.toString(), isDark);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Widget _buildRequirementItem(String text, bool isMet, Color activeColor, Color mutedColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: isMet ? activeColor.withValues(alpha: 0.18) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isMet ? activeColor : mutedColor.withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: isMet ? Icon(Icons.check, size: 10, color: activeColor) : null,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: isMet ? activeColor : mutedColor,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color pageBg = isDark ? const Color(0xFF0F1315) : const Color(0xFFF3EFE6);
    final Color titleColor = isDark ? const Color(0xFFEDE9DF) : const Color(0xFF12161A);
    final Color subtitleColor = isDark ? const Color(0xFF8A939A) : const Color(0xFF6C7479);
    final Color labelColor = isDark ? const Color(0xFFEDE9DF) : const Color(0xFF12161A);
    final Color inputBg = isDark ? const Color(0xFF171C1F) : const Color(0xFFFBF9F4);
    final Color borderInactive = isDark ? const Color(0xFF283137) : const Color(0xFFDCD7CC);
    const Color activeBorderColor = Color(0xFF4EA884);
    final Color hintColor = isDark ? const Color(0xFF667177) : const Color(0xFF9CA3AF);
    final Color dividerColor = isDark ? const Color(0xFF22292E) : const Color(0xFFDCD7CC);
    final Color orTextColor = isDark ? const Color(0xFF667177) : const Color(0xFF8A939A);

    final Color buttonBg = isDark ? const Color(0xFFEDE9DF) : const Color(0xFF12161A);
    final Color buttonFg = isDark ? const Color(0xFF0F1315) : Colors.white;

    final isAnyLoading = _loading || _googleLoading;

    final pwdText = _pwd.text;
    final hasMinLength = pwdText.length >= 8;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(pwdText);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(pwdText);
    final hasNumber = RegExp(r'[0-9]').hasMatch(pwdText);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 840;
    final isVeryCompact = screenHeight < 700;

    final heroHeight = isVeryCompact ? 115.0 : (isCompact ? 135.0 : 165.0);
    final heroBottomGap = isVeryCompact ? 8.0 : (isCompact ? 12.0 : 20.0);
    final titleFontSize = isVeryCompact ? 25.0 : (isCompact ? 28.0 : 32.0);
    final titleBottomGap = isCompact ? 4.0 : 6.0;
    final subtitleFontSize = isCompact ? 13.5 : 14.5;
    final subtitleBottomGap = isVeryCompact ? 10.0 : (isCompact ? 12.0 : 18.0);
    final googleBtnHeight = isCompact ? 46.0 : 50.0;
    final dividerGap = isVeryCompact ? 8.0 : (isCompact ? 10.0 : 16.0);
    final fieldLabelGap = isCompact ? 4.0 : 6.0;
    final fieldHeight = isCompact ? 46.0 : 50.0;
    final fieldGap = isVeryCompact ? 8.0 : (isCompact ? 10.0 : 14.0);
    final actionBtnHeight = isCompact ? 48.0 : 52.0;
    final actionBtnBottomGap = isVeryCompact ? 12.0 : (isCompact ? 16.0 : 24.0);
    final footerGap = isVeryCompact ? 6.0 : (isCompact ? 8.0 : 12.0);
    final pageVerticalPadding = isVeryCompact ? 6.0 : (isCompact ? 10.0 : 14.0);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: pageVerticalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Forest Green Card with Practice Mode
                  _PaperTradeSignupCard(height: heroHeight),
                  SizedBox(height: heroBottomGap),

                  // Headline & Subtitle
                  Text(
                    'Create account',
                    style: GoogleFonts.newsreader(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: titleBottomGap),
                  Text(
                    'Get started with your free virtual practice portfolio.',
                    style: GoogleFonts.inter(
                      fontSize: subtitleFontSize,
                      color: subtitleColor,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: subtitleBottomGap),

                  // Continue with Google Button
                  Container(
                    height: googleBtnHeight,
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderInactive, width: 1),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isAnyLoading ? null : () => _submitGoogle(isDark),
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: _googleLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: titleColor, strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CustomPaint(painter: _GoogleVectorPainter()),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Continue with Google',
                                      style: GoogleFonts.inter(
                                        color: titleColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: dividerGap),

                  // "or sign up with email" Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: dividerColor, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'or sign up with email',
                          style: GoogleFonts.inter(
                            color: orTextColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: dividerColor, thickness: 1)),
                    ],
                  ),
                  SizedBox(height: dividerGap),

                  // Email Field
                  Text(
                    'Email',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  SizedBox(height: fieldLabelGap),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: fieldHeight,
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isEmailFocused ? activeBorderColor : borderInactive,
                        width: _isEmailFocused ? 1.5 : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _email,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.inter(color: titleColor, fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.mail_outline_rounded,
                          size: 19,
                          color: _isEmailFocused ? activeBorderColor : hintColor,
                        ),
                        hintText: 'alex.morgan@gmail.com',
                        hintStyle: GoogleFonts.inter(color: hintColor, fontSize: 13.5),
                      ),
                    ),
                  ),
                  SizedBox(height: fieldGap),

                  // Password Field
                  Text(
                    'Password',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  SizedBox(height: fieldLabelGap),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: fieldHeight,
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isPwdFocused ? activeBorderColor : borderInactive,
                        width: _isPwdFocused ? 1.5 : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _pwd,
                      focusNode: _pwdFocus,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(isDark),
                      style: GoogleFonts.inter(color: titleColor, fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          size: 19,
                          color: _isPwdFocused ? activeBorderColor : hintColor,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: hintColor,
                            size: 19,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        hintText: '••••••••••••••',
                        hintStyle: GoogleFonts.inter(color: hintColor, fontSize: 13.5),
                      ),
                    ),
                  ),

                  // Password Policy Live Checklist
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: (_isPwdFocused || pwdText.isNotEmpty)
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderInactive.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildRequirementItem(
                                  '8+ characters',
                                  hasMinLength,
                                  activeBorderColor,
                                  hintColor,
                                ),
                              ),
                              Expanded(
                                child: _buildRequirementItem(
                                  'One number (0-9)',
                                  hasNumber,
                                  activeBorderColor,
                                  hintColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _buildRequirementItem(
                                  'Uppercase (A-Z)',
                                  hasUppercase,
                                  activeBorderColor,
                                  hintColor,
                                ),
                              ),
                              Expanded(
                                child: _buildRequirementItem(
                                  'Lowercase (a-z)',
                                  hasLowercase,
                                  activeBorderColor,
                                  hintColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                  SizedBox(height: fieldGap * 1.5),

                  // Primary "Create account →" Button
                  Container(
                    height: actionBtnHeight,
                    decoration: BoxDecoration(
                      color: buttonBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isAnyLoading ? null : () => _submit(isDark),
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: _loading
                              ? SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(color: buttonFg, strokeWidth: 2.2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Create account',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15.5,
                                        color: buttonFg,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: buttonFg,
                                      size: 18,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: actionBtnBottomGap),

                  // Footer: Already have an account? Log in
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: GoogleFonts.inter(color: subtitleColor, fontSize: 13.5),
                        ),
                        GestureDetector(
                          onTap: isAnyLoading
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  );
                                },
                          child: Text(
                            'Log in',
                            style: GoogleFonts.inter(
                              color: activeBorderColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              decoration: TextDecoration.underline,
                              decorationColor: activeBorderColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: footerGap),

                  // Legal Clickwrap Footer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'By creating an account, you agree to our ',
                            style: GoogleFonts.inter(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF8A939A), fontSize: 10.5),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()));
                            },
                            child: Text(
                              'Terms',
                              style: GoogleFonts.inter(
                                color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1976D2),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(
                            ' & ',
                            style: GoogleFonts.inter(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF8A939A), fontSize: 10.5),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                            },
                            child: Text(
                              'Privacy Policy',
                              style: GoogleFonts.inter(
                                color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1976D2),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: pageVerticalPadding),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaperTradeSignupCard extends StatelessWidget {
  final double height;
  const _PaperTradeSignupCard({this.height = 140});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF133D32),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E5244), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(
                painter: _HeroCardChartPainter(),
              ),
            ),
            Positioned(
              right: 16,
              top: (height * 0.50) - 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9DF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '67,420',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF133D32),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App logo in rounded squircle
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/icon.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'PaperTrade',
                            style: GoogleFonts.newsreader(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF3B6658), width: 1.2),
                    ),
                    child: Text(
                      'PRACTICE MODE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white,
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
}

class _HeroCardChartPainter extends CustomPainter {
  const _HeroCardChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, h * 0.50), Offset(w, h * 0.50), linePaint);
    canvas.drawLine(Offset(0, h * 0.68), Offset(w, h * 0.68), linePaint);
    canvas.drawLine(Offset(0, h * 0.86), Offset(w, h * 0.86), linePaint);

    final double targetY = h * 0.50;
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;

    const double dashWidth = 5.0;
    const double dashSpace = 4.0;
    double currentX = 18.0;
    final double endX = w - 85.0;
    while (currentX < endX) {
      canvas.drawLine(Offset(currentX, targetY), Offset(currentX + dashWidth, targetY), dashPaint);
      currentX += dashWidth + dashSpace;
    }

    final mintPaint = Paint()
      ..color = const Color(0xFFD3EBE1)
      ..style = PaintingStyle.fill;
    final coralPaint = Paint()
      ..color = const Color(0xFFDC8474)
      ..style = PaintingStyle.fill;

    const candlesData = [
      (0.85, true),
      (0.83, false),
      (0.79, true),
      (0.76, false),
      (0.72, true),
      (0.70, false),
      (0.66, true),
      (0.64, false),
      (0.60, true),
      (0.57, false),
      (0.54, true),
      (0.48, true),
      (0.46, false),
      (0.40, true),
    ];

    const double candleWidth = 9.0;
    const double chartStartX = 20.0;
    final double chartEndX = w - 90.0;
    final double spacing = (chartEndX - chartStartX) / (candlesData.length - 1);

    for (int i = 0; i < candlesData.length; i++) {
      final item = candlesData[i];
      final double x = chartStartX + i * spacing;
      final double yCenter = h * item.$1;
      final bool isBullish = item.$2;
      final paint = isBullish ? mintPaint : coralPaint;

      const double bodyHeight = 12.0;
      const double wickHeight = 22.0;

      canvas.drawRect(
        Rect.fromLTRB(x + candleWidth / 2 - 0.75, yCenter - wickHeight / 2, x + candleWidth / 2 + 0.75, yCenter + wickHeight / 2),
        paint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x + candleWidth / 2, yCenter), width: candleWidth, height: bodyHeight),
          const Radius.circular(2.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoogleVectorPainter extends CustomPainter {
  const _GoogleVectorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 48.0;
    canvas.save();
    canvas.scale(scale, scale);

    final bluePaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    final greenPaint = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill;
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill;
    final redPaint = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill;

    final bluePath = Path()
      ..moveTo(46.98, 24.55)
      ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20.0)
      ..lineTo(24.0, 20.0)
      ..lineTo(24.0, 29.02)
      ..lineTo(36.94, 29.02)
      ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
      ..lineTo(39.89, 42.2)
      ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    final greenPath = Path()
      ..moveTo(24.0, 48.0)
      ..cubicTo(30.48, 48.0, 35.93, 45.87, 39.89, 42.19)
      ..lineTo(32.16, 36.19)
      ..cubicTo(30.01, 37.64, 27.24, 38.5, 24.0, 38.5)
      ..cubicTo(17.74, 38.5, 12.43, 34.28, 10.53, 28.59)
      ..lineTo(2.56, 34.78)
      ..cubicTo(6.51, 42.62, 14.62, 48.0, 24.0, 48.0)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    final yellowPath = Path()
      ..moveTo(10.53, 28.59)
      ..cubicTo(10.02, 27.09, 9.75, 25.58, 9.75, 24.0)
      ..cubicTo(9.75, 22.42, 10.02, 20.91, 10.53, 19.41)
      ..lineTo(2.56, 13.22)
      ..cubicTo(0.92, 16.48, 0.0, 20.14, 0.0, 24.0)
      ..cubicTo(0.0, 27.86, 0.92, 31.52, 2.56, 34.78)
      ..lineTo(10.53, 28.59)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    final redPath = Path()
      ..moveTo(24.0, 9.5)
      ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
      ..lineTo(40.06, 6.25)
      ..cubicTo(35.9, 2.38, 30.47, 0.0, 24.0, 0.0)
      ..cubicTo(14.62, 0.0, 6.51, 5.38, 2.56, 13.22)
      ..lineTo(10.53, 19.41)
      ..cubicTo(12.43, 13.72, 17.74, 9.5, 24.0, 9.5)
      ..close();
    canvas.drawPath(redPath, redPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
