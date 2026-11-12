import 'dart:async';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/app_lock_manager.dart';
import '../../core/app_theme.dart';
import '../../data/auth_provider.dart';

enum AppLockMode {
  unlock,
  setup,
  changePin,
  disable,
}

class AppLockScreen extends StatefulWidget {
  final AppLockMode mode;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const AppLockScreen({
    super.key,
    this.mode = AppLockMode.unlock,
    this.onSuccess,
    this.onCancel,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  late AppLockMode _mode;
  String _enteredPin = '';
  String? _firstEnteredPin; // Used in setup & changePin modes for confirmation
  int _step = 1; // 1 = enter, 2 = confirm, 3 = verify

  String? _errorMessage;
  bool _isSuccess = false;
  bool _isVerifying = false;

  bool _isForgotPinVisible = false;
  bool _isSignOutConfirmVisible = false;
  bool _isBiometricsModalVisible = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    if (_mode == AppLockMode.unlock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBiometricsIfAvailable();
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometricsIfAvailable() async {
    final lockManager = AppLockManager.instance;
    if (lockManager.isBiometricsEnabled && lockManager.deviceSupportsBiometrics) {
      final success = await lockManager.authenticateWithBiometrics();
      if (success && mounted) {
        setState(() => _isSuccess = true);
        widget.onSuccess?.call();
      }
    }
  }

  String get _title {
    switch (_mode) {
      case AppLockMode.unlock:
        return 'Enter your PIN';
      case AppLockMode.setup:
        final isReset = widget.mode == AppLockMode.unlock;
        if (_step == 1) {
          return isReset ? 'Create New 4-digit PIN' : 'Create 4-digit PIN';
        }
        return isReset ? 'Confirm New PIN' : 'Confirm your PIN';
      case AppLockMode.changePin:
        if (_step == 1) return 'Enter Current PIN';
        if (_step == 2) return 'Enter New PIN';
        return 'Confirm New PIN';
      case AppLockMode.disable:
        return 'Enter Current PIN';
    }
  }

  String get _subtitle {
    switch (_mode) {
      case AppLockMode.unlock:
        return 'Unlock to continue to your paper trading account.';
      case AppLockMode.setup:
        final isReset = widget.mode == AppLockMode.unlock;
        if (_step == 1) {
          return isReset
              ? 'Identity verified. Choose a new 4-digit PIN.'
              : 'Choose a secure 4-digit PIN to protect your app.';
        }
        return isReset
            ? 'Re-enter your new 4-digit PIN to confirm.'
            : 'Re-enter your 4-digit PIN to confirm.';
      case AppLockMode.changePin:
        if (_step == 1) return 'Verify your current PIN before changing.';
        if (_step == 2) return 'Enter your new 4-digit PIN.';
        return 'Re-enter your new 4-digit PIN to confirm.';
      case AppLockMode.disable:
        return 'Enter your PIN to turn off app lock.';
    }
  }

  void _onKeyPress(String digit) {
    if (_isVerifying || _isSuccess || _enteredPin.length >= 4) return;
    HapticFeedback.lightImpact();

    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _processCompletePin(_enteredPin);
    }
  }

  void _onBackspace() {
    if (_isVerifying || _isSuccess || _enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _processCompletePin(String pin) async {
    setState(() => _isVerifying = true);

    switch (_mode) {
      case AppLockMode.unlock:
        final isValid = await AppLockManager.instance.verifyPin(pin);
        if (isValid) {
          _triggerSuccess();
        } else {
          _triggerError('Incorrect PIN. Try again.');
        }
        break;

      case AppLockMode.setup:
        if (_step == 1) {
          _firstEnteredPin = pin;
          setState(() {
            _step = 2;
            _enteredPin = '';
            _isVerifying = false;
          });
        } else {
          if (pin == _firstEnteredPin) {
            await AppLockManager.instance.setPin(pin);
            await AppLockManager.instance.checkBiometricsSupport();

            if (mounted && AppLockManager.instance.deviceSupportsBiometrics) {
              setState(() {
                _isBiometricsModalVisible = true;
              });
            } else {
              _triggerSuccess();
            }
          } else {
            _triggerError('PINs did not match. Please try again.');
            setState(() {
              _step = 1;
              _firstEnteredPin = null;
            });
          }
        }
        break;

      case AppLockMode.changePin:
        if (_step == 1) {
          final isValid = await AppLockManager.instance.verifyPin(pin);
          if (isValid) {
            setState(() {
              _step = 2;
              _enteredPin = '';
              _isVerifying = false;
            });
          } else {
            _triggerError('Current PIN is incorrect.');
          }
        } else if (_step == 2) {
          _firstEnteredPin = pin;
          setState(() {
            _step = 3;
            _enteredPin = '';
            _isVerifying = false;
          });
        } else {
          if (pin == _firstEnteredPin) {
            await AppLockManager.instance.setPin(pin);
            _triggerSuccess();
          } else {
            _triggerError('New PINs did not match.');
            setState(() {
              _step = 2;
              _firstEnteredPin = null;
            });
          }
        }
        break;

      case AppLockMode.disable:
        final isValid = await AppLockManager.instance.verifyPin(pin);
        if (isValid) {
          await AppLockManager.instance.disableAppLock();
          _triggerSuccess();
        } else {
          _triggerError('Incorrect PIN.');
        }
        break;
    }
  }

  Widget _buildBiometricsSetupModalContent(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2B3E) : const Color(0xFFE8F1FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1D9BF0).withValues(alpha: 0.25)
                    : const Color(0xFF1D9BF0).withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.fingerprint_rounded,
                color: Color(0xFF1D9BF0),
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Enable Biometric Unlock?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Unlock PaperTrading instantly using your Fingerprint or Face ID instead of typing your 4-digit PIN every time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Enable button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Enable Biometrics',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              onPressed: () async {
                setState(() => _isBiometricsModalVisible = false);
                final res = await AppLockManager.instance.testBiometricEnrollment(
                  reason: 'Scan your biometric to enable quick unlock',
                );
                if (res.success) {
                  await AppLockManager.instance.setBiometricsEnabled(true);
                } else if (res.error != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res.error!),
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                _triggerSuccess();
              },
            ),
          ),
          const SizedBox(height: 10),

          // Maybe later button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              onPressed: () {
                setState(() => _isBiometricsModalVisible = false);
                _triggerSuccess();
              },
              child: Text(
                'Maybe Later',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _triggerSuccess() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSuccess = true;
      _isVerifying = false;
      _errorMessage = null;
    });

    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_mode == AppLockMode.unlock || widget.mode == AppLockMode.unlock) {
        AppLockManager.instance.unlock();
      }
      widget.onSuccess?.call();
    });
  }

  void _triggerError(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _errorMessage = message;
      _isVerifying = false;
      _enteredPin = '';
    });
    _shakeController.forward(from: 0.0);
  }

  void _showForgotPinSheet() {
    setState(() {
      _isForgotPinVisible = true;
      _isSignOutConfirmVisible = false;
      _isBiometricsModalVisible = false;
    });
  }

  void _onForgotPinIdentityVerified() {
    setState(() {
      _isForgotPinVisible = false;
      _mode = AppLockMode.setup;
      _step = 1;
      _enteredPin = '';
      _firstEnteredPin = null;
      _errorMessage = null;
      _isVerifying = false;
      _isSuccess = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Identity verified! Please set a new 4-digit PIN.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF00C853),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSignOutDialog(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6465D).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFF6465D), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sign Out & Reset Lock?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'This will sign you out of PaperTrading and reset your local device PIN. You can log back in with your account credentials anytime.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _isSignOutConfirmVisible = false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF6465D),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
                onPressed: () async {
                  setState(() => _isSignOutConfirmVisible = false);
                  await AppLockManager.instance.disableAppLock();
                  await AuthController.signOut();
                },
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnlockMode = _mode == AppLockMode.unlock;
    final lockManager = AppLockManager.instance;
    final showBiometricKey = isUnlockMode &&
        lockManager.isBiometricsEnabled &&
        lockManager.deviceSupportsBiometrics;

    final canPopScreen = !isUnlockMode &&
        widget.mode != AppLockMode.unlock &&
        !_isForgotPinVisible &&
        !_isSignOutConfirmVisible &&
        !_isBiometricsModalVisible;

    return PopScope(
      canPop: canPopScreen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isForgotPinVisible) {
          setState(() => _isForgotPinVisible = false);
          return;
        }
        if (_isSignOutConfirmVisible) {
          setState(() => _isSignOutConfirmVisible = false);
          return;
        }
        if (_isBiometricsModalVisible) {
          setState(() => _isBiometricsModalVisible = false);
          _triggerSuccess();
          return;
        }
        widget.onCancel?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: isUnlockMode
            ? null
            : AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () {
                    if (widget.mode == AppLockMode.unlock && _mode == AppLockMode.setup) {
                      setState(() {
                        _mode = AppLockMode.unlock;
                        _step = 1;
                        _enteredPin = '';
                        _firstEnteredPin = null;
                        _errorMessage = null;
                      });
                      return;
                    }
                    widget.onCancel?.call();
                    Navigator.maybePop(context);
                  },
                ),
              ),
        body: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
              return Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Top Icon Badge ──────────────────────────────────────────
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2B3E) : const Color(0xFFE8F1FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1D9BF0).withValues(alpha: 0.2)
                            : const Color(0xFF1D9BF0).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _isSuccess
                            ? Icons.check_circle_rounded
                            : Icons.lock_rounded,
                        color: _isSuccess
                            ? const Color(0xFF00C853)
                            : const Color(0xFF1D9BF0),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Title & Subtitle ────────────────────────────────────────
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Error / Success Message ─────────────────────────────────
                  SizedBox(
                    height: 22,
                    child: Center(
                      child: _errorMessage != null
                          ? Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFFF4D4F),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : _isSuccess
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, color: Color(0xFF00C853), size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Unlocked',
                                      style: TextStyle(
                                        color: Color(0xFF00C853),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 4 PIN Indicator Dots ────────────────────────────────────
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _enteredPin.length;
                        final isError = _errorMessage != null;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled
                                ? (isError
                                    ? const Color(0xFFFF4D4F)
                                    : const Color(0xFF00C853))
                                : Colors.transparent,
                            border: Border.all(
                              color: isFilled
                                  ? (isError
                                      ? const Color(0xFFFF4D4F)
                                      : const Color(0xFF00C853))
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.black.withValues(alpha: 0.25)),
                              width: 1.6,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Custom Numeric Keypad ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildKeyRow(['1', '2', '3'], isDark),
                        const SizedBox(height: 12),
                        _buildKeyRow(['4', '5', '6'], isDark),
                        const SizedBox(height: 12),
                        _buildKeyRow(['7', '8', '9'], isDark),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Biometric button (left)
                            Expanded(
                              child: showBiometricKey
                                  ? _buildSpecialKey(
                                      icon: Icons.fingerprint_rounded,
                                      iconColor: const Color(0xFF1D9BF0),
                                      iconSize: 28,
                                      isDark: isDark,
                                      onTap: _triggerBiometricsIfAvailable,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(width: 16),
                            // '0' button (center)
                            Expanded(
                              child: _buildNumberKey('0', isDark),
                            ),
                            const SizedBox(width: 16),
                            // Backspace button (right)
                            Expanded(
                              child: _buildSpecialKey(
                                icon: Icons.backspace_outlined,
                                iconColor: AppColors.textPrimary.withValues(alpha: 0.85),
                                iconSize: 22,
                                isDark: isDark,
                                onTap: _onBackspace,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Forgot PIN (Unlock mode only) ───────────────────────────
                  if (isUnlockMode) ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showForgotPinSheet,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Text(
                            'Forgot PIN?',
                            style: TextStyle(
                              color: Color(0xFF1D9BF0),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── Footer Security Badge ───────────────────────────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Protected by device encryption',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
              );
            },
          ),
        ),

        // ── Forgot PIN Modal Sheet Overlay ───────────────────────
        if (_isForgotPinVisible) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isForgotPinVisible = false),
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ForgotPinBottomSheet(
              user: FirebaseAuth.instance.currentUser,
              isGoogle: FirebaseAuth.instance.currentUser?.providerData
                      .any((p) => p.providerId == 'google.com') ??
                  false,
              isEmailPassword: FirebaseAuth.instance.currentUser?.providerData
                      .any((p) => p.providerId == 'password') ??
                  false,
              isDark: isDark,
              onClose: () => setState(() => _isForgotPinVisible = false),
              onVerified: () {
                setState(() => _isForgotPinVisible = false);
                _onForgotPinIdentityVerified();
              },
              onSignOutRequested: () {
                setState(() {
                  _isForgotPinVisible = false;
                  _isSignOutConfirmVisible = true;
                });
              },
            ),
          ),
        ],

        // ── Sign Out Confirmation Dialog Overlay ──────────────────
        if (_isSignOutConfirmVisible) ...[
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: _buildSignOutDialog(isDark),
              ),
            ),
          ),
        ],

        // ── Biometrics Setup Modal Overlay ─────────────────────────
        if (_isBiometricsModalVisible) ...[
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              alignment: Alignment.bottomCenter,
              child: _buildBiometricsSetupModalContent(isDark),
            ),
          ),
        ],
      ],
    ),
  ),
);
  }

  Widget _buildKeyRow(List<String> values, bool isDark) {
    return Row(
      children: [
        for (int i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: _buildNumberKey(values[i], isDark)),
        ],
      ],
    );
  }

  Widget _buildNumberKey(String number, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(number),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141922) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141922) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: iconColor,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPinBottomSheet extends StatefulWidget {
  final User? user;
  final bool isGoogle;
  final bool isEmailPassword;
  final bool isDark;
  final VoidCallback onClose;
  final VoidCallback onVerified;
  final VoidCallback onSignOutRequested;

  const _ForgotPinBottomSheet({
    required this.user,
    required this.isGoogle,
    required this.isEmailPassword,
    required this.isDark,
    required this.onClose,
    required this.onVerified,
    required this.onSignOutRequested,
  });

  @override
  State<_ForgotPinBottomSheet> createState() => _ForgotPinBottomSheetState();
}

class _ForgotPinBottomSheetState extends State<_ForgotPinBottomSheet> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyGoogle() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User dismissed
      }

      final registeredEmail = widget.user?.email?.toLowerCase().trim();
      final selectedEmail = googleUser.email.toLowerCase().trim();

      if (registeredEmail != null && registeredEmail.isNotEmpty && selectedEmail != registeredEmail) {
        setState(() {
          _isLoading = false;
          _errorText =
              'Account mismatch: Selected Google account ($selectedEmail) does not match your registered email ($registeredEmail).';
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      if (widget.user != null) {
        await widget.user!.reauthenticateWithCredential(credential);
      }

      widget.onVerified();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = e.message ?? 'Google authentication failed (${e.code}).';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'Authentication failed: $e';
      });
    }
  }

  Future<void> _verifyPassword() async {
    final pwd = _passwordController.text.trim();
    if (pwd.isEmpty) {
      setState(() => _errorText = 'Please enter your account password.');
      return;
    }
    if (widget.user?.email == null) {
      setState(() => _errorText = 'No registered email found for this session.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final credential = EmailAuthProvider.credential(
        email: widget.user!.email!,
        password: pwd,
      );
      await widget.user!.reauthenticateWithCredential(credential);
      widget.onVerified();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _errorText = 'Incorrect password. Please try again.';
        } else if (e.code == 'too-many-requests') {
          _errorText = 'Too many attempts. Please try again in a few minutes.';
        } else {
          _errorText = e.message ?? 'Authentication failed.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'Verification error: $e';
      });
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = widget.user?.email;
    if (email == null) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $email. Please check your inbox.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'Could not send reset email: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isGoogle = widget.isGoogle;
    final isEmail = widget.isEmailPassword;
    final isDark = widget.isDark;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16181D) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar handle & header
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2416) : const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF0B90B).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFF0B90B), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Forgot PIN?',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verify account to reset your 4-digit PIN',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.subtle, size: 20),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Account badge
              if (user != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E232F) : const Color(0xFFF4F6F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: user.photoURL != null
                            ? ClipOval(
                                child: Image.network(
                                  user.photoURL!,
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.person, color: AppColors.primary, size: 18),
                                ),
                              )
                            : const Icon(Icons.person, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName?.isNotEmpty == true
                                  ? user.displayName!
                                  : (user.email ?? 'Trading Account'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (user.email != null)
                              Text(
                                user.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isGoogle
                              ? const Color(0xFF4285F4).withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isGoogle ? 'Google' : 'Email',
                          style: TextStyle(
                            color: isGoogle ? const Color(0xFF4285F4) : AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Error banner if any
              if (_errorText != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6465D).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF6465D).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFF6465D), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorText!,
                          style: const TextStyle(
                            color: Color(0xFFF6465D),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action buttons based on provider
              if (isGoogle) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata_rounded, size: 28),
                    label: Text(
                      _isLoading ? 'Verifying with Google...' : 'Verify with Google Account',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    onPressed: _isLoading ? null : _verifyGoogle,
                  ),
                ),
              ] else if (isEmail) ...[
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Account Password',
                    labelStyle: const TextStyle(color: AppColors.subtle, fontSize: 13),
                    hintText: 'Enter your password to verify',
                    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E232F) : const Color(0xFFF4F6F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isLoading ? null : _verifyPassword,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Verify & Reset PIN',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : _sendPasswordResetEmail,
                    child: const Text(
                      'Forgot Password? Send Reset Link',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF1D9BF0)),
                    ),
                  ),
                ),
              ] else ...[
                // Guest / No credentials
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => widget.onVerified(),
                    child: const Text(
                      'Reset 4-Digit PIN',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],

              const Divider(height: 26),

              // Sign out option
              InkWell(
                onTap: _isLoading ? null : widget.onSignOutRequested,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Color(0xFFF6465D), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign Out of Account',
                              style: TextStyle(
                                color: Color(0xFFF6465D),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Resets PIN lock and returns to login screen',
                              style: TextStyle(
                                color: AppColors.subtle,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
