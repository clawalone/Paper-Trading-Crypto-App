import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('hi')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'PaperTrading - Crypto & Stocks'**
  String get appTitle;

  /// Home bottom navigation tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Spot trading bottom navigation tab
  ///
  /// In en, this message translates to:
  /// **'Spot'**
  String get navSpot;

  /// Futures trading bottom navigation tab
  ///
  /// In en, this message translates to:
  /// **'Futures'**
  String get navFutures;

  /// Portfolio bottom navigation tab
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get navPortfolio;

  /// Community Hub bottom navigation tab
  ///
  /// In en, this message translates to:
  /// **'Hub'**
  String get navHub;

  /// Buy action
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// Sell action
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// Trade action
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get trade;

  /// Cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirm action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Save action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Done action
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Search input placeholder
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Top up virtual money action
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get topUp;

  /// Settings menu header
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language selector setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Title of language picker dialog
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Currency selector setting
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// App theme selector setting
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Security settings
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// Help and customer support
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// Privacy policy link
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Terms of service link
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Log out action
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// Confirmation message before logging out
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirm;

  /// Portfolio total balance label
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get totalBalance;

  /// Available simulator cash label
  ///
  /// In en, this message translates to:
  /// **'Available Cash'**
  String get availableCash;

  /// Portfolio value label
  ///
  /// In en, this message translates to:
  /// **'Portfolio Value'**
  String get portfolioValue;

  /// 24 hour profit and loss label
  ///
  /// In en, this message translates to:
  /// **'24h P&L'**
  String get pnl24h;

  /// Rank bottom navigation tab
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get leaderboard;

  /// Watchlist section title
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get watchlist;

  /// Market overview section title
  ///
  /// In en, this message translates to:
  /// **'Market Overview'**
  String get marketOverview;

  /// Top gainers title
  ///
  /// In en, this message translates to:
  /// **'Top Gainers'**
  String get gainers;

  /// Top losers title
  ///
  /// In en, this message translates to:
  /// **'Top Losers'**
  String get losers;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
