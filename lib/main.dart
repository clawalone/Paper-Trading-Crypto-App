import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'core/app_lock_manager.dart';
import 'core/championship_prize_manager.dart';
import 'core/fcm_manager.dart';
import 'core/rewarded_ad_manager.dart';
import 'core/system_notification_manager.dart';
import 'data/user_provider.dart';
import 'features/auth/app_lock_screen.dart';
import 'features/home/home_shell.dart';
import 'firebase_options.dart';
import 'core/currency_formatters.dart';
import 'l10n/app_localizations.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure image cache for smooth animated avatars without ART GC thrashing
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 150;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Preload SharedPreferences early so cached user state is available immediately
  unawaited(SharedPreferences.getInstance());

  // Initialize App Lock and Biometrics state before first render
  await AppLockManager.instance.initialize();

  // Fetch live currency exchange rate in background without blocking startup
  unawaited(CurrencyFormatters.initExchangeRate());

  // Automate weekly championship rewards: checks settlement & schedules next Monday 12:00 AM payout
  unawaited(ChampionshipPrizeManager.checkWeeklySettlementAndSchedule());

  // Initialize OS-level system push notification channels & permissions
  unawaited(SystemNotificationManager.initialize());

  // Initialize Firebase Cloud Messaging (FCM) background/foreground push
  unawaited(FcmManager.initialize());

  // Initialize Google Mobile Ads SDK with Google UMP Consent & buffer rewarded ad in background
  if (!kIsWeb) {
    unawaited(RewardedAdManager.instance.initializeWithConsent());
  }
  
  runApp(
    const ProviderScope(
      child: TradeQuestApp(),
    ),
  );
}

class TradeQuestApp extends ConsumerWidget {
  const TradeQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeStr = ref.watch(userProvider.select((s) => s.profile.themeMode));
    final preferredLanguage = ref.watch(userProvider.select((s) => s.profile.preferredLanguage));
    AppTranslations.setLanguage(preferredLanguage);

    final Locale activeLocale;
    if (preferredLanguage.toLowerCase().contains('hi')) {
      activeLocale = const Locale('hi');
    } else if (preferredLanguage.toLowerCase().contains('es') || preferredLanguage.toLowerCase().contains('span')) {
      activeLocale = const Locale('es');
    } else {
      activeLocale = const Locale('en');
    }

    final ThemeMode themeMode;
    switch (themeModeStr) {
      case 'Light':
        themeMode = ThemeMode.light;
        break;
      case 'Dark':
        themeMode = ThemeMode.dark;
        break;
      case 'System':
      default:
        themeMode = ThemeMode.system;
        break;
    }

    // Synchronize AppColors active brightness state
    final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = themeMode == ThemeMode.light
        ? false
        : themeMode == ThemeMode.system
            ? platformBrightness == Brightness.dark
            : true;
    AppColors.isDarkMode = isDark;

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'PaperTrading - Crypto & Stocks',
      debugShowCheckedModeBanner: false,
      locale: activeLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final currentBrightness = MediaQuery.platformBrightnessOf(context);
        final isDark = themeMode == ThemeMode.light
            ? false
            : themeMode == ThemeMode.dark
                ? true
                : currentBrightness == Brightness.dark;
        AppColors.isDarkMode = isDark;
        return ListenableBuilder(
          listenable: AppLockManager.instance,
          builder: (context, _) {
            final isLocked = AppLockManager.instance.isLocked;
            return Stack(
              children: [
                if (child != null) child,
                if (isLocked)
                  const Positioned.fill(
                    child: AppLockScreen(
                      mode: AppLockMode.unlock,
                    ),
                  ),
              ],
            );
          },
        );
      },
      home: const HomeShell(),
    );
  }
}
