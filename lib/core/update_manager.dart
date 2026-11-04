import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';

class InAppUpdateManager {
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.acadriotrade';
  static bool _hasCheckedThisSession = false;

  static Future<void> checkForUpdates(BuildContext context) async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final currentVersion = packageInfo.version;

      final doc = await FirebaseFirestore.instance.collection('app_config').doc('version').get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final latestBuildNumber = (data['latestBuildNumber'] as num?)?.toInt() ?? 0;
      final latestVersion = (data['latestVersion'] as String?) ?? currentVersion;
      final updateMessage = (data['updateMessage'] as String?) ??
          'A new version of Acadrio Trade is available on Google Play Store. Update now for new features and performance improvements!';
      final isForceUpdate = (data['forceUpdate'] as bool?) ?? false;

      // If Play Store version build number is strictly newer than current installed version
      if (latestBuildNumber > currentBuildNumber) {
        if (context.mounted) {
          _showUpdateDialog(
            context,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            updateMessage: updateMessage,
            isForceUpdate: isForceUpdate,
          );
        }
      }
    } catch (_) {}
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required String updateMessage,
    required bool isForceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (dialogContext) {
        return PopScope(
          canPop: !isForceUpdate,
          child: Dialog(
            backgroundColor: const Color(0xFF161A1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF2B3139), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                    ),
                    child: const Icon(
                      Icons.system_update_alt_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title
                  const Text(
                    'NEW UPDATE AVAILABLE!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Version Pill Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2329),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF2B3139)),
                        ),
                        child: Text(
                          'Installed: v$currentVersion',
                          style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.profit.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.profit.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Latest: v$latestVersion',
                          style: const TextStyle(color: AppColors.profit, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Update Message
                  Text(
                    updateMessage,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      if (!isForceUpdate) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF2B3139)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'LATER',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final uri = Uri.parse(playStoreUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'UPDATE NOW',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
