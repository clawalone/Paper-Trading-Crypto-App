import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'core/championship_prize_manager.dart';
import 'core/fcm_manager.dart';
import 'core/system_notification_manager.dart';
import 'features/home/home_shell.dart';
import 'firebase_options.dart';
import 'core/currency_formatters.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Preload SharedPreferences early so cached user state is available immediately
  unawaited(SharedPreferences.getInstance());

  // Fetch live currency exchange rate in background without blocking startup
  unawaited(CurrencyFormatters.initExchangeRate());

  // Automate weekly championship rewards: checks settlement & schedules next Monday 12:00 AM payout
  unawaited(ChampionshipPrizeManager.checkWeeklySettlementAndSchedule());

  // Initialize OS-level system push notification channels & permissions
  unawaited(SystemNotificationManager.initialize());

  // Initialize Firebase Cloud Messaging (FCM) background/foreground push
  unawaited(FcmManager.initialize());
  
  runApp(
    const ProviderScope(
      child: TradeQuestApp(),
    ),
  );
}

class TradeQuestApp extends StatelessWidget {
  const TradeQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'PaperTrading - Crypto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeShell(),
    );
  }
}
