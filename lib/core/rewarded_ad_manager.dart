import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stock_arena/core/app_material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app_lock_manager.dart';

class RewardedAdManager {
  static final RewardedAdManager instance = RewardedAdManager._internal();
  RewardedAdManager._internal();

  RewardedAd? _rewardedAd;
  DateTime? _loadedTimestamp;
  bool _isLoading = false;
  final ValueNotifier<bool> isReadyNotifier = ValueNotifier<bool>(false);
  int? lastLoadErrorCode;
  String? lastLoadErrorMessage;

  // AdMob Rewarded Ad Unit IDs (Automatically uses test unit in debug mode to prevent policy flags)
  static String get adUnitId {
    if (kIsWeb) return '';
    if (kDebugMode) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'ca-app-pub-3940256099942544/5224354917'; // Official Test Unit ID
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'ca-app-pub-3940256099942544/1712485313'; // Official Test Unit ID
      }
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Live Production Rewarded Video Unit ID
      return 'ca-app-pub-1175216465340313/3320570890';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    return '';
  }

  /// Returns true if an unexpired ad is loaded and ready in buffer.
  bool get isReady {
    if (_rewardedAd == null) return false;
    if (_isAdStale()) {
      _disposeStaleAd();
      return false;
    }
    return true;
  }

  bool _isAdStale() {
    if (_loadedTimestamp == null) return false;
    // AdMob rewarded ads expire after 60 minutes. We treat 50+ min as stale.
    return DateTime.now().difference(_loadedTimestamp!) > const Duration(minutes: 50);
  }

  void _disposeStaleAd() {
    debugPrint('[RewardedAdManager] Stale ad (>50m) detected. Disposing from buffer.');
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _loadedTimestamp = null;
    isReadyNotifier.value = false;
  }

  /// Requests European regulations (GDPR) consent via Google UMP SDK.
  /// If the user is in the EEA/UK and consent is required, shows the published consent form.
  /// Otherwise (e.g. users in USA, India, or already consented), skips immediately without prompt.
  /// Once resolved, initializes the MobileAds engine. Preloading is deferred to Just-In-Time triggers.
  Future<void> initializeWithConsent() async {
    if (kIsWeb) return;

    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            debugPrint('[RewardedAdManager] UMP Consent Form warning: ${formError.message}');
          }
          await _initMobileAdsEngine();
        });
      },
      (formError) async {
        debugPrint('[RewardedAdManager] UMP Consent update skipped/failed: ${formError.message}');
        await _initMobileAdsEngine();
      },
    );
  }

  Future<void> _initMobileAdsEngine() async {
    try {
      await MobileAds.instance.initialize();
      debugPrint('[RewardedAdManager] MobileAds initialized. Smart JIT active — ad request deferred until user intent.');
    } catch (e) {
      debugPrint('[RewardedAdManager] Failed to initialize MobileAds: $e');
    }
  }

  /// Smart Just-In-Time preloader. Only loads if buffer is empty or expired.
  Future<void> preload() async {
    if (kIsWeb || _isLoading) return;

    if (_rewardedAd != null) {
      if (_isAdStale()) {
        _disposeStaleAd();
      } else {
        // Unexpired ad is already ready in buffer
        return;
      }
    }

    _isLoading = true;

    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _loadedTimestamp = DateTime.now();
            _isLoading = false;
            lastLoadErrorCode = null;
            lastLoadErrorMessage = null;
            isReadyNotifier.value = true;
            debugPrint('[RewardedAdManager] Smart JIT: Rewarded ad loaded and ready in buffer.');
          },
          onAdFailedToLoad: (error) {
            _rewardedAd = null;
            _loadedTimestamp = null;
            _isLoading = false;
            lastLoadErrorCode = error.code;
            lastLoadErrorMessage = error.message;
            isReadyNotifier.value = false;
            debugPrint('[RewardedAdManager] Failed to load rewarded ad (code: ${error.code}): ${error.message}');
          },
        ),
      );
    } catch (e) {
      _isLoading = false;
      isReadyNotifier.value = false;
      debugPrint('[RewardedAdManager] Error during ad preload: $e');
    }
  }

  /// Plays a sequence of [requiredAds] (1, 2, or 3) with smart buffering transitions.
  /// Calls [onProgress] with the current ad index and total ads.
  /// Resolves true if all ads in the bundle were watched to completion.
  Future<bool> playRewardedSequence({
    required BuildContext context,
    required int requiredAds,
    required void Function(int current, int total) onProgress,
  }) async {
    if (kIsWeb) {
      // Web fallback: simulate sequence
      return _simulateWebSequence(requiredAds, onProgress);
    }

    int completedAds = 0;

    for (int i = 0; i < requiredAds; i++) {
      onProgress(i + 1, requiredAds);

      // Ensure an ad is buffered
      if (_rewardedAd == null) {
        final loaded = await _waitForAdToLoad(timeout: const Duration(seconds: 8));
        if (!loaded) {
          debugPrint('[RewardedAdManager] Timed out waiting for ad ${i + 1}');
          return false;
        }
      }

      final ad = _rewardedAd;
      _rewardedAd = null;
      isReadyNotifier.value = false;

      final completer = Completer<bool>();
      bool userEarnedReward = false;

      ad!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          AppLockManager.instance.isSystemOverlayActive = true;
          debugPrint('[RewardedAdManager] Ad ${i + 1} showing fullscreen');
        },
        onAdDismissedFullScreenContent: (ad) {
          AppLockManager.instance.isSystemOverlayActive = false;
          ad.dispose();
          // Smart JIT: Buffer the next ad only if more ads remain in this sequence
          if (completedAds + 1 < requiredAds) {
            preload();
          }
          completer.complete(userEarnedReward);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          AppLockManager.instance.isSystemOverlayActive = false;
          ad.dispose();
          if (completedAds + 1 < requiredAds) {
            preload();
          }
          completer.complete(false);
        },
      );

      ad.show(
        onUserEarnedReward: (adWithoutView, reward) {
          userEarnedReward = true;
          debugPrint('[RewardedAdManager] User earned reward for ad ${i + 1}/$requiredAds');
        },
      );

      final success = await completer.future;
      if (!success) {
        // User closed or skipped ad before reward callback
        return false;
      }

      completedAds++;

      // If more ads remain in this bundle, wait a brief buffer moment
      if (completedAds < requiredAds) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return completedAds == requiredAds;
  }

  Future<bool> _waitForAdToLoad({Duration timeout = const Duration(seconds: 8)}) async {
    if (_rewardedAd != null) return true;
    if (!_isLoading) {
      preload();
    }

    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (_rewardedAd != null) return true;
      if (!_isLoading) preload();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return _rewardedAd != null;
  }

  Future<bool> _simulateWebSequence(
    int requiredAds,
    void Function(int current, int total) onProgress,
  ) async {
    for (int i = 0; i < requiredAds; i++) {
      onProgress(i + 1, requiredAds);
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    return true;
  }
}
