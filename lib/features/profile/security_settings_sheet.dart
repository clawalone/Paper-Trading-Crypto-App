import 'package:stock_arena/core/app_material.dart';
import '../../core/app_lock_manager.dart';
import '../../core/app_theme.dart';
import '../auth/app_lock_screen.dart';

class SecuritySettingsSheet extends StatefulWidget {
  const SecuritySettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SecuritySettingsSheet(),
    );
  }

  @override
  State<SecuritySettingsSheet> createState() => _SecuritySettingsSheetState();
}

class _SecuritySettingsSheetState extends State<SecuritySettingsSheet> {
  final AppLockManager _lockManager = AppLockManager.instance;

  @override
  void initState() {
    super.initState();
    _lockManager.addListener(_onLockStateChanged);
    _lockManager.checkBiometricsSupport();
  }

  @override
  void dispose() {
    _lockManager.removeListener(_onLockStateChanged);
    super.dispose();
  }

  void _onLockStateChanged() {
    if (mounted) setState(() {});
  }

  String _formatTimeout(int seconds) {
    if (seconds <= 0) return 'Immediately';
    if (seconds < 60) return '$seconds seconds';
    if (seconds == 60) return '1 minute';
    final mins = seconds ~/ 60;
    return '$mins minutes';
  }

  void _openSetupPin() {
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

  void _openDisablePin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AppLockScreen(
          mode: AppLockMode.disable,
          onSuccess: () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('App Lock turned off.'),
                backgroundColor: AppColors.primary,
              ),
            );
          },
          onCancel: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _openChangePin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AppLockScreen(
          mode: AppLockMode.changePin,
          onSuccess: () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN updated successfully!'),
                backgroundColor: Color(0xFF00C853),
              ),
            );
          },
          onCancel: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      final res = await _lockManager.testBiometricEnrollment(
        reason: 'Verify your biometric identity to enable biometric unlock',
      );
      if (res.success) {
        await _lockManager.setBiometricsEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric unlock enabled!'),
              backgroundColor: Color(0xFF00C853),
            ),
          );
        }
      } else if (res.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.error!),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      await _lockManager.setBiometricsEnabled(false);
    }
  }

  void _showTimeoutPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.outline),
        ),
        title: Text(
          'Lock App After',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimeoutOption(ctx, 'Immediately', 0),
            _buildTimeoutOption(ctx, '1 minute', 60),
            _buildTimeoutOption(ctx, '5 minutes', 300),
            _buildTimeoutOption(ctx, '15 minutes', 900),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutOption(BuildContext ctx, String label, int seconds) {
    final isSelected = _lockManager.timeoutSeconds == seconds;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
          : null,
      onTap: () {
        _lockManager.setTimeoutSeconds(seconds);
        Navigator.pop(ctx);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = _lockManager.isEnabled;
    final supportsBiometrics = _lockManager.deviceSupportsBiometrics;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Sheet Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2B3E) : const Color(0xFFE8F1FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF1D9BF0),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security & Lock',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Protect account with PIN and Biometrics',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Toggle App Lock Card & Switch
            InkWell(
              onTap: () {
                if (isEnabled) {
                  _openDisablePin();
                } else {
                  _openSetupPin();
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141922) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.pin_rounded,
                      color: isEnabled ? AppColors.primary : AppColors.subtle,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'App Lock (4-Digit PIN)',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Require PIN to access trading data',
                            style: TextStyle(
                              color: AppColors.subtle,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: isEnabled,
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: Colors.white,
                      onChanged: (val) {
                        if (val) {
                          _openSetupPin();
                        } else {
                          _openDisablePin();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            if (isEnabled) ...[
              const SizedBox(height: 14),

              // Change PIN option
              InkWell(
                onTap: _openChangePin,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.password_rounded, color: AppColors.subtle, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Change 4-Digit PIN',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
                    ],
                  ),
                ),
              ),

              // Biometric unlock row
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.fingerprint_rounded,
                      color: supportsBiometrics ? const Color(0xFF1D9BF0) : AppColors.subtle,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Biometric Unlock',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            supportsBiometrics
                                ? 'Unlock with Fingerprint or Face'
                                : 'Requires fingerprint/face set up on device',
                            style: TextStyle(
                              color: AppColors.subtle,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (supportsBiometrics)
                      Switch.adaptive(
                        value: _lockManager.isBiometricsEnabled,
                        activeTrackColor: AppColors.primary,
                        activeThumbColor: Colors.white,
                        onChanged: _toggleBiometrics,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.muted),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              title: Row(
                                children: [
                                  const Icon(Icons.fingerprint_rounded, color: Color(0xFF1D9BF0)),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Biometric Setup',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              content: Text(
                                'To use biometric unlock, your device must support biometric sensors and have at least one fingerprint or face enrolled in Android Settings -> Security.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Got it'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              // Auto-lock timeout
              const Divider(height: 1),
              InkWell(
                onTap: _showTimeoutPicker,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, color: AppColors.subtle, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Lock Timer',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Locks when app is in background',
                              style: TextStyle(
                                color: AppColors.subtle,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTimeout(_lockManager.timeoutSeconds),
                        style: const TextStyle(
                          color: AppColors.subtle,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
