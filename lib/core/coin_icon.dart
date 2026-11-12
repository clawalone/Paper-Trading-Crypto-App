import 'package:stock_arena/core/app_material.dart';

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

  /// Tokens/stocks with dark silhouettes on transparent backgrounds that need a white circular
  /// badge behind them so they remain sharp and visible in dark mode
  static const Set<String> _whiteBgCoins = {
    'DOT',
    'ALGO',
    'JTO',
    'ONDO',
    'GALA',
    'AAPL',
    'AMZN',
    'TSLA',
    'AMD',
    'SPY',
    'QQQ',
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

  /// Stock domain map for Google Favicon CDN & Clearbit
  static const Map<String, String> _stockDomains = {
    'AAPL': 'apple.com',
    'NVDA': 'nvidia.com',
    'TSLA': 'tesla.com',
    'MSFT': 'microsoft.com',
    'AMZN': 'amazon.com',
    'GOOGL': 'google.com',
    'GOOG': 'google.com',
    'META': 'meta.com',
    'NFLX': 'netflix.com',
    'AMD': 'amd.com',
    'SPY': 'ssga.com',
    'QQQ': 'invesco.com',
    'COIN': 'coinbase.com',
    'PLTR': 'palantir.com',
    'ORCL': 'oracle.com',
    'CRM': 'salesforce.com',
    'ADBE': 'adobe.com',
    'UBER': 'uber.com',
    'AVGO': 'broadcom.com',
    'TSM': 'tsmc.com',
    'QCOM': 'qualcomm.com',
    'INTC': 'intel.com',
    'ARM': 'arm.com',
    'MU': 'micron.com',
    'SMCI': 'supermicro.com',
    'MSTR': 'microstrategy.com',
    'HOOD': 'robinhood.com',
    'MARA': 'mara.com',
    'RIOT': 'riotplatforms.com',
    'CLSK': 'cleanspark.com',
    'SQ': 'block.xyz',
    'PYPL': 'paypal.com',
    'V': 'visa.com',
    'MA': 'mastercard.com',
    'JPM': 'jpmorganchase.com',
    'BAC': 'bankofamerica.com',
    'GS': 'goldmansachs.com',
    'MS': 'morganstanley.com',
    'DIS': 'disney.com',
    'WMT': 'walmart.com',
    'COST': 'costco.com',
    'NKE': 'nike.com',
    'SBUX': 'starbucks.com',
    'MCD': 'mcdonalds.com',
    'RIVN': 'rivian.com',
    'LCID': 'lucidmotors.com',
    'NIO': 'nio.com',
    'BA': 'boeing.com',
    'LMT': 'lockheedmartin.com',
    'GE': 'ge.com',
    'CAT': 'caterpillar.com',
    'XOM': 'exxonmobil.com',
    'CVX': 'chevron.com',
    'LLY': 'lilly.com',
    'NVO': 'novonordisk.com',
    'JNJ': 'jnj.com',
    'PFE': 'pfizer.com',
    'UNH': 'unitedhealthgroup.com',
    'VOO': 'vanguard.com',
    'IWM': 'ishares.com',
    'DIA': 'ssga.com',
    'TQQQ': 'proshares.com',
    'SQQQ': 'proshares.com',
    'SOXX': 'ishares.com',
    'GLD': 'spdrgoldshares.com',
    'TLT': 'ishares.com',
    '^GSPC': 'spglobal.com',
    '^IXIC': 'nasdaq.com',
    '^DJI': 'spglobal.com',
  };

  /// High-resolution direct logo images for stocks & indices
  static const Map<String, String> _stockLogos = {
    'AAPL': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Apple_logo_black.svg/200px-Apple_logo_black.svg.png',
    'NVDA': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/21/Nvidia_logo.svg/200px-Nvidia_logo.svg.png',
    'TSLA': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e8/Tesla_logo.png/200px-Tesla_logo.png',
    'MSFT': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Microsoft_logo.svg/200px-Microsoft_logo.svg.png',
    'AMZN': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/Amazon_icon.svg/200px-Amazon_icon.svg.png',
    'GOOGL': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/200px-Google_%22G%22_logo.svg.png',
    'GOOG': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/200px-Google_%22G%22_logo.svg.png',
    'META': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Meta_Platforms_Inc._logo.svg/200px-Meta_Platforms_Inc._logo.svg.png',
    'NFLX': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Netflix_2015_logo.svg/200px-Netflix_2015_logo.svg.png',
    'AMD': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7c/AMD_Logo.svg/200px-AMD_Logo.svg.png',
    'SPY': 'https://assets.parqet.com/logos/symbol/SPY?format=png',
    'QQQ': 'https://assets.parqet.com/logos/symbol/QQQ?format=png',
    'RELIANCE': 'https://assets.parqet.com/logos/symbol/RELIANCE.NS?format=png',
    'TCS': 'https://assets.parqet.com/logos/symbol/TCS.NS?format=png',
    'HDFCBANK': 'https://assets.parqet.com/logos/symbol/HDFCBANK.NS?format=png',
    'INFY': 'https://assets.parqet.com/logos/symbol/INFY.NS?format=png',
    'TATAMOTORS': 'https://assets.parqet.com/logos/symbol/TATAMOTORS.NS?format=png',
    'ICICIBANK': 'https://assets.parqet.com/logos/symbol/ICICIBANK.NS?format=png',
    'ITC': 'https://assets.parqet.com/logos/symbol/ITC.NS?format=png',
    'SBIN': 'https://assets.parqet.com/logos/symbol/SBIN.NS?format=png',
    'BHARTIARTL': 'https://assets.parqet.com/logos/symbol/BHARTIARTL.NS?format=png',
  };

  /// Dedicated brand color for fallback tiles
  static const Map<String, Color> _stockBrandColors = {
    'AAPL': Color(0xFF1E2329),
    'NVDA': Color(0xFF76B900),
    'TSLA': Color(0xFFE82127),
    'MSFT': Color(0xFF00A4EF),
    'AMZN': Color(0xFFFF9900),
    'GOOGL': Color(0xFF4285F4),
    'META': Color(0xFF0081FB),
    'NFLX': Color(0xFFE50914),
    'AMD': Color(0xFFED1C24),
    'SPY': Color(0xFF005696),
    'QQQ': Color(0xFF002F6C),
    'RELIANCE': Color(0xFF0F3E75),
    'TCS': Color(0xFF0066B2),
    'HDFCBANK': Color(0xFF004C8F),
    'INFY': Color(0xFF007CC3),
    'TATAMOTORS': Color(0xFF1B4E9B),
    'ICICIBANK': Color(0xFF9C1F2E),
    'ITC': Color(0xFF1B365D),
    'SBIN': Color(0xFF0066B3),
    'BHARTIARTL': Color(0xFFED1B24),
  };

  @override
  Widget build(BuildContext context) {
    final clean = cleanSymbol(symbol);
    final cleanStock = clean.replaceAll('.NS', '');
    final isStock = _stockDomains.containsKey(cleanStock) || _stockLogos.containsKey(cleanStock);
    final lower = clean.toLowerCase();
    final needsWhiteBg = _whiteBgCoins.contains(clean) || _whiteBgCoins.contains(cleanStock);

    if (isStock) {
      final domain = _stockDomains[cleanStock] ?? 'google.com';
      final primaryStockUrl = _stockLogos[cleanStock] ??
          'https://assets.parqet.com/logos/symbol/${clean.contains('.NS') ? clean : cleanStock}?format=png';
      final fallbackStockUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=128';

      final stockImageWidget = Image.network(
        primaryStockUrl,
        width: needsWhiteBg ? size * 0.72 : size,
        height: needsWhiteBg ? size * 0.72 : size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Image.network(
            fallbackStockUrl,
            width: needsWhiteBg ? size * 0.72 : size,
            height: needsWhiteBg ? size * 0.72 : size,
            fit: BoxFit.contain,
            errorBuilder: (context, error2, stackTrace2) {
              return _buildFallbackBadge(cleanStock, brandColor: _stockBrandColors[cleanStock]);
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
          child: stockImageWidget,
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          color: const Color(0xFF1A1F28),
          alignment: Alignment.center,
          child: stockImageWidget,
        ),
      );
    }

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

  Widget _buildFallbackBadge(String clean, {Color? brandColor}) {
    final bgColor = brandColor ?? const Color(0xFF1E2329);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8),
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
