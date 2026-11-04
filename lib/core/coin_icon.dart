import 'package:flutter/material.dart';

class CoinIcon extends StatelessWidget {
  final String symbol;
  final double size;

  const CoinIcon({required this.symbol, this.size = 32, super.key});

  /// Sanitizes raw symbols (e.g. 'BTCUSDT', 'SOL-PERP', 'ETH/USDT' -> 'BTC', 'SOL', 'ETH')
  static String cleanSymbol(String raw) {
    var s = raw.trim().toUpperCase();
    s = s.replaceAll('-PERP', '').replaceAll('PERP', '');
    s = s.replaceAll('/USDT', '').replaceAll('/USD', '').replaceAll('USDT', '').replaceAll('USDC', '');
    return s;
  }

  /// Tokens with dark/black silhouettes on transparent backgrounds that need a white circular
  /// badge behind them so they remain sharp and visible in dark mode
  static const Set<String> _whiteBgCoins = {
    'DOT',
    'ALGO',
    'JTO',
    'ONDO',
    'GALA',
  };

  /// High-resolution verified direct logo URLs for tokens not covered by generic CDNs
  static const Map<String, String> _customIcons = {
    'JTO': 'https://coin-images.coingecko.com/coins/images/33228/large/jto.png',
    'ARKM': 'https://coin-images.coingecko.com/coins/images/30929/large/Arkham_Logo_CG.png',
    'IO': 'https://coin-images.coingecko.com/coins/images/37754/large/io_blackbg.png',
    'BOME': 'https://coin-images.coingecko.com/coins/images/36071/large/bome.png',
    'POPCAT': 'https://coin-images.coingecko.com/coins/images/33760/large/image.jpg',
    'GMX': 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/arbitrum/assets/0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a/logo.png',
  };

  @override
  Widget build(BuildContext context) {
    final clean = cleanSymbol(symbol);
    final lower = clean.toLowerCase();
    final needsWhiteBg = _whiteBgCoins.contains(clean);

    final primaryUrl = _customIcons[clean] ?? 'https://assets.coincap.io/assets/icons/$lower@2x.png';
    final fallbackUrl = 'https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@1a63530be6e374711a8554f31b17e4cb92c25fa5/128/color/$lower.png';

    final imageWidget = Image.network(
      primaryUrl,
      width: needsWhiteBg ? size * 0.74 : size,
      height: needsWhiteBg ? size * 0.74 : size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.network(
          fallbackUrl,
          width: needsWhiteBg ? size * 0.74 : size,
          height: needsWhiteBg ? size * 0.74 : size,
          fit: BoxFit.contain,
          errorBuilder: (context, error2, stackTrace2) {
            return _buildFallbackBadge(clean);
          },
        );
      },
    );

    if (needsWhiteBg) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: imageWidget,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: imageWidget,
    );
  }

  Widget _buildFallbackBadge(String clean) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2B3139), width: 0.8),
      ),
      alignment: Alignment.center,
      child: Text(
        clean.length >= 2 ? clean.substring(0, 2).toUpperCase() : clean.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.35,
        ),
      ),
    );
  }
}
