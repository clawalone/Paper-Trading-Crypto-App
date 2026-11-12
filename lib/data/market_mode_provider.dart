import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MarketMode {
  crypto,
  stocks,
}

class MarketModeNotifier extends Notifier<MarketMode> {
  static const String _prefKey = 'active_market_mode';

  @override
  MarketMode build() {
    _loadFromPrefs();
    return MarketMode.crypto;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'stocks') {
        state = MarketMode.stocks;
      } else if (saved == 'crypto') {
        state = MarketMode.crypto;
      }
    } catch (_) {
      // Keep default
    }
  }

  Future<void> setMode(MarketMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode == MarketMode.stocks ? 'stocks' : 'crypto');
    } catch (_) {}
  }

  Future<void> toggleMode() async {
    final next = state == MarketMode.crypto ? MarketMode.stocks : MarketMode.crypto;
    await setMode(next);
  }
}

final marketModeProvider = NotifierProvider<MarketModeNotifier, MarketMode>(() {
  return MarketModeNotifier();
});
