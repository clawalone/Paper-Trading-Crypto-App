import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import '../features/auth/app_lock_screen.dart';

/// Central manager for App Lock (4-digit PIN and Biometrics: Fingerprint/Face).
/// Handles lock lifecycle, encryption hashing, timeout logic, and hardware biometrics.
class AppLockManager extends ChangeNotifier with WidgetsBindingObserver {
  static final AppLockManager instance = AppLockManager._internal();
  AppLockManager._internal();

  static const String _keyEnabled = 'app_lock_enabled';
  static const String _keyPinHash = 'app_lock_pin_hash';
  static const String _keyPinSalt = 'app_lock_pin_salt';
  static const String _keyBiometrics = 'app_lock_biometrics_enabled';
  static const String _keyTimeout = 'app_lock_timeout_seconds';
  static const String _keyPromptDismissed = 'app_lock_setup_prompt_dismissed';

  static bool _hasPromptedThisSession = false;

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isInitialized = false;
  bool _isLocked = false;
  bool _isEnabled = false;
  bool _isBiometricsEnabled = false;
  bool _deviceSupportsBiometrics = false;
  int _timeoutSeconds = 0; // 0 = Immediately
  DateTime? _pausedAt;

  /// Flag set to true when full-screen system overlays (e.g. Rewarded Video Ads,
  /// Google Play Billing) are active, so the app does NOT lock when returning.
  bool isSystemOverlayActive = false;

  bool get isLocked => _isLocked;
  bool get isEnabled => _isEnabled;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get deviceSupportsBiometrics => _deviceSupportsBiometrics;
  int get timeoutSeconds => _timeoutSeconds;

  /// Initializes the lock state from SharedPreferences and registers lifecycle observers.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);

    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_keyEnabled) ?? false;
    _isBiometricsEnabled = prefs.getBool(_keyBiometrics) ?? false;
    _timeoutSeconds = prefs.getInt(_keyTimeout) ?? 0;

    await checkBiometricsSupport();

    // If app lock is enabled, start app in locked state
    if (_isEnabled && hasPinConfigured(prefs)) {
      _isLocked = true;
    }

    notifyListeners();
  }

  /// Checks hardware biometric support and enrolled biometrics dynamically.
  Future<bool> checkBiometricsSupport() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final available = await _localAuth.getAvailableBiometrics();
      _deviceSupportsBiometrics = canCheck || isSupported || available.isNotEmpty;
      notifyListeners();
      return _deviceSupportsBiometrics;
    } catch (e) {
      debugPrint('[AppLockManager] Error checking biometrics support: $e');
      _deviceSupportsBiometrics = false;
      return false;
    }
  }

  bool hasPinConfigured([SharedPreferences? prefs]) {
    if (prefs != null) {
      return (prefs.getString(_keyPinHash) ?? '').isNotEmpty;
    }
    // Synchronous best-effort check requires async prefs, but default to true if enabled
    return _isEnabled;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isEnabled) return;

    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      if (!isSystemOverlayActive) {
        _pausedAt = DateTime.now();
        if (_timeoutSeconds == 0 && !_isLocked) {
          lock();
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (isSystemOverlayActive) {
        // Returned from system overlay/ad: reset timestamp and keep unlocked
        _pausedAt = null;
        return;
      }

      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
        _pausedAt = null;
        if (elapsed >= _timeoutSeconds && !_isLocked) {
          lock();
        }
      }
    }
  }

  /// Locks the app and notifies listeners so the lock screen is displayed.
  void lock() {
    if (!_isEnabled) return;
    _isLocked = true;
    notifyListeners();
  }

  /// Unlocks the app after successful PIN or biometric verification.
  void unlock() {
    _isLocked = false;
    _pausedAt = null;
    notifyListeners();
  }

  /// Sets a new 4-digit PIN, generating a cryptographic salt and SHA-256 hash.
  Future<bool> setPin(String pin) async {
    if (pin.length != 4) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final salt = _generateSalt();
      final hash = _hashPin(pin, salt);

      await prefs.setString(_keyPinSalt, salt);
      await prefs.setString(_keyPinHash, hash);
      await prefs.setBool(_keyEnabled, true);

      _isEnabled = true;
      _isLocked = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AppLockManager] Error setting PIN: $e');
      return false;
    }
  }

  /// Verifies if the entered 4-digit PIN matches the stored salted hash.
  Future<bool> verifyPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salt = prefs.getString(_keyPinSalt);
      final storedHash = prefs.getString(_keyPinHash);

      if (salt == null || storedHash == null) return false;
      final inputHash = _hashPin(pin, salt);
      return inputHash == storedHash;
    } catch (e) {
      debugPrint('[AppLockManager] Error verifying PIN: $e');
      return false;
    }
  }

  /// Prompts for biometric authentication to verify eligibility and enable biometrics.
  Future<({bool success, String? error})> testBiometricEnrollment({
    String reason = 'Verify your biometric identity to enable biometric unlock',
  }) async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        return (success: true, error: null);
      }
      return (success: false, error: 'Authentication cancelled');
    } on PlatformException catch (e) {
      debugPrint('[AppLockManager] Biometric verification error: ${e.code} - ${e.message}');
      String msg = 'Biometric authentication failed.';
      if (e.code == 'NotEnrolled') {
        msg = 'No fingerprints or face enrolled on device. Please register one in Android Settings.';
      } else if (e.code == 'PasscodeNotSet') {
        msg = 'Device lock screen (PIN/Pattern) is not set up in device settings.';
      } else if (e.code == 'NotAvailable') {
        msg = 'Biometrics sensor is currently unavailable.';
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        msg = 'Too many attempts. Biometrics temporarily locked.';
      }
      return (success: false, error: msg);
    } catch (e) {
      return (success: false, error: 'Biometric error: $e');
    }
  }

  /// Prompts the OS for biometric authentication (Fingerprint / Face ID).
  Future<bool> authenticateWithBiometrics({String reason = 'Authenticate to unlock PaperTrading'}) async {
    if (!_deviceSupportsBiometrics || !_isBiometricsEnabled) return false;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        unlock();
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      debugPrint('[AppLockManager] Biometric platform error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[AppLockManager] Biometric general error: $e');
      return false;
    }
  }

  /// Enables or disables biometric unlock.
  Future<void> setBiometricsEnabled(bool enabled) async {
    _isBiometricsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometrics, enabled);
    notifyListeners();
  }

  /// Sets auto-lock timeout duration in seconds (0 = immediately, 60 = 1 min, etc.).
  Future<void> setTimeoutSeconds(int seconds) async {
    _timeoutSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTimeout, seconds);
    notifyListeners();
  }

  /// Disables App Lock and clears stored PIN credentials.
  Future<void> disableAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEnabled);
    await prefs.remove(_keyPinHash);
    await prefs.remove(_keyPinSalt);
    _isEnabled = false;
    _isLocked = false;
    notifyListeners();
  }

  // ── Cryptographic Helpers ──────────────────────────────────────────────────
  String _generateSalt([int length = 16]) {
    final rand = Random.secure();
    final values = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64Url.encode(values);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$pin:$salt:paper_trading_crypto_secret');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Checks if App Lock has not been set up and hasn't been dismissed by the user yet.
  /// Shows a clean, non-intrusive one-time dialog recommending account protection.
  static void checkAndPromptSetup(BuildContext context) {
    if (_hasPromptedThisSession) return;
    _hasPromptedThisSession = true;

    final manager = AppLockManager.instance;
    if (manager.isEnabled) return;

    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (!context.mounted) return;
      if (manager.isEnabled) return;

      final prefs = await SharedPreferences.getInstance();
      final isDismissed = prefs.getBool(_keyPromptDismissed) ?? false;
      if (isDismissed) return;
      if (!context.mounted) return;

      _showSetupPromptDialog(context);
    });
  }

  static void _showSetupPromptDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
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
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Icon Badge
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
                child: const Center(
                  child: Icon(
                    Icons.security_rounded,
                    color: Color(0xFF1D9BF0),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Security Pill Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D9BF0).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SECURITY RECOMMENDATION',
                  style: TextStyle(
                    color: Color(0xFF1D9BF0),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title & Subtitle
              Text(
                'Protect Your Account',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enable a 4-digit PIN and Biometric Lock to keep your virtual trading portfolio and stats secure.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // Feature Highlights
              _buildFeatureRow(
                icon: Icons.lock_outline_rounded,
                text: 'Device-encrypted 4-digit PIN',
              ),
              const SizedBox(height: 8),
              _buildFeatureRow(
                icon: Icons.fingerprint_rounded,
                text: 'Fast Fingerprint & Face ID unlock',
              ),
              const SizedBox(height: 8),
              _buildFeatureRow(
                icon: Icons.timer_outlined,
                text: 'Automatic lock when switching apps',
              ),
              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_keyPromptDismissed, true);

                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => AppLockScreen(
                            mode: AppLockMode.setup,
                            onSuccess: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('App Lock enabled successfully!'),
                                  backgroundColor: Color(0xFF00C853),
                                ),
                              );
                            },
                            onCancel: () => Navigator.pop(ctx),
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Set Up PIN Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_keyPromptDismissed, true);
                },
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildFeatureRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF1D9BF0),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
