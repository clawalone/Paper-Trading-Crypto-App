import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../core/currency_formatters.dart';
import 'models.dart';

class MarketOnlineNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false; // Orders locked until live exchange prices are verified
  }

  void setOnline(bool value) {
    if (state != value) {
      state = value;
    }
  }
}

final marketOnlineProvider = NotifierProvider<MarketOnlineNotifier, bool>(() {
  return MarketOnlineNotifier();
});

final marketProvider = NotifierProvider<MarketNotifier, List<Stock>>(() {
  return MarketNotifier();
});

class MarketNotifier extends Notifier<List<Stock>> {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _connectivityTimer;
  DateTime _lastLiveUpdate = DateTime.now();
  bool _disposed = false;

  // ── 50 coins across all major categories ─────────────────────────────────
  static const _cryptoAssets = [
    // Layer 1
    ('BTCUSDT',  'Bitcoin',         'Layer 1'),
    ('ETHUSDT',  'Ethereum',        'Layer 1'),
    ('SOLUSDT',  'Solana',          'Layer 1'),
    ('ADAUSDT',  'Cardano',         'Layer 1'),
    ('AVAXUSDT', 'Avalanche',       'Layer 1'),
    ('DOTUSDT',  'Polkadot',        'Layer 1'),
    ('ATOMUSDT', 'Cosmos',          'Layer 1'),
    ('NEARUSDT', 'NEAR Protocol',   'Layer 1'),
    ('APTUSDT',  'Aptos',           'Layer 1'),
    ('SUIUSDT',  'Sui',             'Layer 1'),
    ('ALGOUSDT', 'Algorand',        'Layer 1'),
    ('XLMUSDT',  'Stellar',         'Layer 1'),
    ('TRXUSDT',  'TRON',            'Layer 1'),
    ('HBARUSDT', 'Hedera',          'Layer 1'),

    // Layer 2 / Scaling
    ('MATICUSDT','Polygon',         'Layer 2'),
    ('OPUSDT',   'Optimism',        'Layer 2'),
    ('ARBUSDT',  'Arbitrum',        'Layer 2'),
    ('STXUSDT',  'Stacks',          'Layer 2'),
    ('IMXUSDT',  'ImmutableX',      'Layer 2'),

    // Exchange / Utility
    ('BNBUSDT',  'BNB',             'Exchange'),
    ('FTMUSDT',  'Fantom',          'Layer 1'),
    ('GMXUSDT',  'GMX',             'DeFi'),

    // DeFi
    ('UNIUSDT',  'Uniswap',         'DeFi'),
    ('AAVEUSDT', 'Aave',            'DeFi'),
    ('MKRUSDT',  'Maker',           'DeFi'),
    ('CRVUSDT',  'Curve DAO',       'DeFi'),
    ('COMPUSDT', 'Compound',        'DeFi'),
    ('SNXUSDT',  'Synthetix',       'DeFi'),
    ('LDOUSDT',  'Lido DAO',        'DeFi'),
    ('JUPUSDT',  'Jupiter',         'DeFi'),

    // Infrastructure / Oracle
    ('LINKUSDT', 'Chainlink',       'Infrastructure'),
    ('GRTUSDT',  'The Graph',       'Infrastructure'),
    ('FILUSDT',  'Filecoin',        'Infrastructure'),
    ('RENDERUSDT','Render',         'Infrastructure'),
    ('FETUSDT',  'Fetch.ai',        'Infrastructure'),
    ('INJUSDT',  'Injective',       'Infrastructure'),

    // Payments / Cross-chain
    ('XRPUSDT',  'Ripple',          'Payments'),
    ('LTCUSDT',  'Litecoin',        'Payments'),
    ('BCHUSDT',  'Bitcoin Cash',    'Payments'),

    // Gaming / Metaverse
    ('SANDUSDT', 'The Sandbox',     'Gaming'),
    ('MANAUSDT', 'Decentraland',    'Gaming'),
    ('AXSUSDT',  'Axie Infinity',   'Gaming'),
    ('GALAUSDT', 'Gala',            'Gaming'),

    // AI / Data
    ('WLDUSDT',  'Worldcoin',       'AI'),
    ('TAOUSDT',  'Bittensor',       'AI'),
    ('AGIXUSDT', 'SingularityNET',  'AI'),

    // Meme
    ('DOGEUSDT', 'Dogecoin',        'Meme'),
    ('SHIBUSDT', 'Shiba Inu',       'Meme'),
    ('PEPEUSDT', 'Pepe',            'Meme'),
    ('FLOKIUSDT','Floki',           'Meme'),
    ('WIFUSDT',  'dogwifhat',       'Meme'),
    ('BONKUSDT', 'Bonk',            'Meme'),
    ('BOMEUSDT', 'BOOK OF MEME',    'Meme'),

    // Trending Layer 1 & Modular
    ('TONUSDT',  'Toncoin',         'Layer 1'),
    ('ICPUSDT',  'Internet Computer','Layer 1'),
    ('SEIUSDT',  'Sei',             'Layer 1'),
    ('TIAUSDT',  'Celestia',        'Layer 1'),
    ('ETCUSDT',  'Ethereum Classic','Layer 1'),
    ('VETUSDT',  'VeChain',         'Layer 1'),

    // Modern Layer 2
    ('STRKUSDT', 'Starknet',        'Layer 2'),
    ('ZKUSDT',   'ZKsync',          'Layer 2'),

    // Next-Gen DeFi & RWA
    ('ENAUSDT',  'Ethena',          'DeFi'),
    ('PENDLEUSDT','Pendle',         'DeFi'),
    ('ONDOUSDT', 'Ondo Finance',    'DeFi'),
    ('JTOUSDT',  'Jito',            'DeFi'),
    ('PYTHUSDT', 'Pyth Network',    'DeFi'),

    // AI & Compute
    ('ARKMUSDT', 'Arkham',          'AI'),
    ('IOUSDT',   'io.net',          'AI'),

    // Gaming & Fan Tokens
    ('NOTUSDT',  'Notcoin',         'Gaming'),
    ('CHZUSDT',  'Chiliz',          'Gaming'),
  ];

  static const _assetDetails = <String, Map<String, Object>>{
    'BTC':    {'about': 'Bitcoin is the first decentralized cryptocurrency, created by Satoshi Nakamoto in 2009.', 'supply': 19700000.0, 'rank': 1},
    'ETH':    {'about': 'Ethereum is a decentralized platform for smart contracts and dApps, created by Vitalik Buterin.', 'supply': 120000000.0, 'rank': 2},
    'SOL':    {'about': 'Solana is a high-performance blockchain supporting fast, low-cost transactions and dApps.', 'supply': 450000000.0, 'rank': 5},
    'ADA':    {'about': 'Cardano is a proof-of-stake blockchain platform focused on security and sustainability.', 'supply': 35000000000.0, 'rank': 10},
    'AVAX':   {'about': 'Avalanche is a smart contract platform designed for DeFi with near-instant transaction finality.', 'supply': 400000000.0, 'rank': 11},
    'DOT':    {'about': 'Polkadot enables cross-blockchain transfers of any data or asset type.', 'supply': 1300000000.0, 'rank': 14},
    'ATOM':   {'about': 'Cosmos is an ecosystem of blockchains connected through IBC protocol.', 'supply': 290000000.0, 'rank': 22},
    'NEAR':   {'about': 'NEAR Protocol is a sharded proof-of-stake blockchain designed for scalability.', 'supply': 1000000000.0, 'rank': 18},
    'APT':    {'about': 'Aptos is a Layer 1 blockchain built on Move language, focused on safety and upgradability.', 'supply': 1000000000.0, 'rank': 30},
    'SUI':    {'about': 'Sui is a Layer 1 blockchain and smart contract platform designed for instant finality.', 'supply': 10000000000.0, 'rank': 27},
    'ALGO':   {'about': 'Algorand is a self-sustaining, decentralized blockchain network supporting a wide range of applications.', 'supply': 10000000000.0, 'rank': 40},
    'XLM':    {'about': 'Stellar is an open blockchain network connecting financial institutions for low-cost transactions.', 'supply': 50000000000.0, 'rank': 28},
    'TRX':    {'about': 'TRON is a blockchain platform focused on content sharing and entertainment.', 'supply': 88000000000.0, 'rank': 12},
    'HBAR':   {'about': 'Hedera is an enterprise-grade public network using hashgraph consensus.', 'supply': 50000000000.0, 'rank': 32},
    'MATIC':  {'about': 'Polygon (MATIC) is a scaling solution for Ethereum, providing faster and cheaper transactions.', 'supply': 10000000000.0, 'rank': 16},
    'OP':     {'about': 'Optimism is an Ethereum Layer 2 optimistic rollup scaling solution.', 'supply': 4294967296.0, 'rank': 38},
    'ARB':    {'about': 'Arbitrum is a leading Ethereum Layer 2 scaling solution using optimistic rollups.', 'supply': 10000000000.0, 'rank': 33},
    'STX':    {'about': 'Stacks is a Layer 2 for Bitcoin, enabling smart contracts and dApps on Bitcoin.', 'supply': 1818000000.0, 'rank': 55},
    'IMX':    {'about': 'ImmutableX is a Layer 2 for NFTs on Ethereum with zero gas fees.', 'supply': 2000000000.0, 'rank': 60},
    'BNB':    {'about': 'BNB powers the BNB Chain ecosystem and is used for transaction fees on Binance.', 'supply': 153000000.0, 'rank': 4},
    'FTM':    {'about': 'Fantom is a highly scalable blockchain platform for DeFi, crypto dApps, and enterprise applications.', 'supply': 2800000000.0, 'rank': 50},
    'GMX':    {'about': 'GMX is a decentralized spot and perpetual exchange that supports low swap fees and zero price impact trades.', 'supply': 9000000.0, 'rank': 65},
    'UNI':    {'about': 'Uniswap is the largest decentralized exchange protocol on Ethereum.', 'supply': 1000000000.0, 'rank': 21},
    'AAVE':   {'about': 'Aave is a decentralized non-custodial liquidity protocol for earning interest.', 'supply': 16000000.0, 'rank': 35},
    'MKR':    {'about': 'Maker is the governance token of the MakerDAO protocol, which issues the DAI stablecoin.', 'supply': 977631.0, 'rank': 42},
    'CRV':    {'about': 'Curve is a decentralized exchange optimized for stablecoin trading with low fees.', 'supply': 3303030299.0, 'rank': 70},
    'COMP':   {'about': 'Compound is an algorithmic, autonomous interest rate protocol for DeFi lending.', 'supply': 10000000.0, 'rank': 80},
    'SNX':    {'about': 'Synthetix is a decentralized protocol for synthetic assets on Ethereum.', 'supply': 300000000.0, 'rank': 75},
    'LDO':    {'about': 'Lido DAO governs the Lido liquid staking protocol for ETH and other assets.', 'supply': 1000000000.0, 'rank': 44},
    'JUP':    {'about': 'Jupiter is the leading DEX aggregator on Solana.', 'supply': 10000000000.0, 'rank': 36},
    'LINK':   {'about': 'Chainlink is a decentralized oracle network providing real-world data to smart contracts.', 'supply': 1000000000.0, 'rank': 15},
    'GRT':    {'about': 'The Graph is an indexing protocol for querying blockchain data.', 'supply': 10000000000.0, 'rank': 62},
    'FIL':    {'about': 'Filecoin is a decentralized storage network to store the world\'s most important information.', 'supply': 2000000000.0, 'rank': 53},
    'RENDER': {'about': 'Render Network is a decentralized GPU rendering platform.', 'supply': 536870912.0, 'rank': 45},
    'FET':    {'about': 'Fetch.ai is an AI-powered blockchain platform for autonomous agents.', 'supply': 1152997575.0, 'rank': 58},
    'INJ':    {'about': 'Injective is a DeFi blockchain optimized for trading applications.', 'supply': 100000000.0, 'rank': 37},
    'XRP':    {'about': 'XRP is the native asset of the XRP Ledger, used for fast and low-cost global payments.', 'supply': 55000000000.0, 'rank': 6},
    'LTC':    {'about': 'Litecoin is a peer-to-peer cryptocurrency based on the Bitcoin protocol.', 'supply': 84000000.0, 'rank': 20},
    'BCH':    {'about': 'Bitcoin Cash is a fork of Bitcoin with larger block sizes for faster transactions.', 'supply': 21000000.0, 'rank': 24},
    'SAND':   {'about': 'The Sandbox is a virtual gaming metaverse powered by blockchain.', 'supply': 3000000000.0, 'rank': 72},
    'MANA':   {'about': 'Decentraland is a virtual world where users can buy, sell, and build on virtual land.', 'supply': 2194000000.0, 'rank': 76},
    'AXS':    {'about': 'Axie Infinity is a blockchain-based trading and battling game.', 'supply': 270000000.0, 'rank': 66},
    'GALA':   {'about': 'Gala Games is a blockchain gaming platform building player-owned games.', 'supply': 50000000000.0, 'rank': 85},
    'WLD':    {'about': 'Worldcoin is a global digital identity and financial network.', 'supply': 10000000000.0, 'rank': 48},
    'TAO':    {'about': 'Bittensor is a decentralized machine learning network.', 'supply': 21000000.0, 'rank': 43},
    'AGIX':   {'about': 'SingularityNET is a decentralized AI marketplace and network.', 'supply': 2000000000.0, 'rank': 78},
    'DOGE':   {'about': 'Dogecoin started as a meme but grew into one of the largest cryptocurrencies by market cap.', 'supply': 144000000000.0, 'rank': 8},
    'SHIB':   {'about': 'Shiba Inu is an Ethereum-based meme token with a large community.', 'supply': 589000000000000.0, 'rank': 13},
    'PEPE':   {'about': 'Pepe is a deflationary memecoin launched on Ethereum as a tribute to the Pepe the Frog meme.', 'supply': 420690000000000.0, 'rank': 25},
    'FLOKI':  {'about': 'Floki is a community-driven cryptocurrency inspired by Elon Musk\'s dog.', 'supply': 9897070000000.0, 'rank': 90},
    'WIF':    {'about': 'dogwifhat is a popular decentralized community meme coin launched on the Solana blockchain.', 'supply': 998900000.0, 'rank': 31},
    'BONK':   {'about': 'Bonk is the first dog-themed social utility token launched on the Solana ecosystem.', 'supply': 75000000000000.0, 'rank': 41},
    'BOME':   {'about': 'BOOK OF MEME is an experimental Web3 meme creation and decentralized storage project.', 'supply': 69000000000.0, 'rank': 92},
    'TON':    {'about': 'Toncoin is the decentralized Layer 1 blockchain developed by Telegram for scalable micro-transactions.', 'supply': 5100000000.0, 'rank': 9},
    'ICP':    {'about': 'Internet Computer is a blockchain network that enables developers to build and host decentralized web applications.', 'supply': 470000000.0, 'rank': 23},
    'SEI':    {'about': 'Sei is the fastest Layer 1 blockchain, specialized for trading and decentralized exchange infrastructure.', 'supply': 10000000000.0, 'rank': 52},
    'TIA':    {'about': 'Celestia is a modular blockchain network that rethinks data availability and consensus architecture.', 'supply': 1080000000.0, 'rank': 46},
    'ETC':    {'about': 'Ethereum Classic is the original, immutable proof-of-work smart contract blockchain.', 'supply': 148000000.0, 'rank': 29},
    'VET':    {'about': 'VeChain is an enterprise blockchain platform enhancing supply chain management and business processes.', 'supply': 86000000000.0, 'rank': 39},
    'STRK':   {'about': 'Starknet is a Permissionless Validity-Rollup Layer 2 for Ethereum scaling using STARK cryptographic proofs.', 'supply': 10000000000.0, 'rank': 68},
    'ZK':     {'about': 'ZKsync is a Layer 2 scaling protocol using zero-knowledge rollups to scale Ethereum securely.', 'supply': 21000000000.0, 'rank': 82},
    'ENA':    {'about': 'Ethena is a synthetic dollar protocol built on Ethereum that provides crypto-native yield through USDe.', 'supply': 15000000000.0, 'rank': 49},
    'PENDLE': {'about': 'Pendle is a permissionless yield-trading protocol enabling tokenization and trading of future yields.', 'supply': 260000000.0, 'rank': 61},
    'ONDO':   {'about': 'Ondo Finance is an institutional-grade protocol bridging traditional finance with decentralized blockchain assets.', 'supply': 10000000000.0, 'rank': 34},
    'JTO':    {'about': 'Jito is a liquid staking protocol and MEV infrastructure platform for the Solana ecosystem.', 'supply': 1000000000.0, 'rank': 88},
    'PYTH':   {'about': 'Pyth Network is a high-frequency financial oracle network delivering sub-second market data.', 'supply': 10000000000.0, 'rank': 51},
    'ARKM':   {'about': 'Arkham is an AI-powered blockchain analysis and intelligence platform revealing transaction origins.', 'supply': 1000000000.0, 'rank': 95},
    'IO':     {'about': 'io.net is a decentralized physical infrastructure network providing on-demand distributed GPU compute.', 'supply': 800000000.0, 'rank': 98},
    'NOT':    {'about': 'Notcoin is a viral Web3 tap-to-earn game and community token launched on the TON blockchain.', 'supply': 102470000000.0, 'rank': 63},
    'CHZ':    {'about': 'Chiliz powers Socios.com, enabling fans to purchase Fan Tokens for top football clubs and sports teams.', 'supply': 8888888888.0, 'rank': 79},
  };

  // Fallback for assets without specific details
  static Map<String, Object> _defaultDetails(String sym) => {
    'about': '$sym is a cryptocurrency asset traded on major exchanges.',
    'supply': 1000000000.0,
    'rank': 999,
  };

  /// Fallback baseline prices (USD) to prevent any coin price staying at 0
  static const Map<String, double> _defaultPricesUsd = {
    'BTC': 68500.0,
    'ETH': 2550.0,
    'SOL': 180.0,
    'ADA': 0.35,
    'AVAX': 25.0,
    'DOT': 4.20,
    'ATOM': 4.50,
    'NEAR': 4.80,
    'APT': 8.50,
    'SUI': 1.95,
    'ALGO': 0.12,
    'XLM': 0.10,
    'TRX': 0.16,
    'HBAR': 0.05,
    'MATIC': 0.38,
    'OP': 1.45,
    'ARB': 0.55,
    'STX': 1.75,
    'IMX': 1.35,
    'BNB': 590.0,
    'FTM': 0.65,
    'GMX': 26.0,
    'UNI': 7.80,
    'AAVE': 155.0,
    'MKR': 1250.0,
    'CRV': 0.28,
    'COMP': 42.0,
    'SNX': 1.45,
    'LDO': 1.15,
    'JUP': 0.95,
    'LINK': 11.80,
    'GRT': 0.15,
    'FIL': 3.60,
    'RENDER': 5.40,
    'FET': 1.25,
    'INJ': 19.5,
    'XRP': 0.52,
    'LTC': 68.0,
    'BCH': 340.0,
    'SAND': 0.26,
    'MANA': 0.28,
    'AXS': 4.80,
    'GALA': 0.02,
    'WLD': 1.85,
    'TAO': 510.0,
    'AGIX': 0.45,
    'DOGE': 0.15,
    'SHIB': 0.000017,
    'PEPE': 0.0000095,
    'FLOKI': 0.00014,
    'TON': 4.90,
    'ICP': 8.10,
    'SEI': 0.38,
    'ETC': 18.5,
    'VET': 0.024,
    'STRK': 0.38,
    'ZK': 0.14,
    'ENA': 0.55,
    'PENDLE': 4.60,
    'ONDO': 0.85,
    'JTO': 2.45,
    'ARKM': 1.85,
    'IO': 1.75,
    'WIF': 2.30,
    'BONK': 0.000022,
    'BOME': 0.0085,
    'TIA': 4.80,
    'PYTH': 0.36,
    'NOT': 0.0075,
    'CHZ': 0.065,
  };

  /// Fallback hosts for Binance REST endpoints (data-api.binance.vision is unblocked globally)
  static const List<String> _binanceHosts = [
    'data-api.binance.vision',
    'api.binance.com',
    'api3.binance.com',
    'api1.binance.com',
  ];

  static List<StockCandle> generateFallbackCandles(double currentPrice) {
    final price = currentPrice > 0 ? currentPrice : 100.0;
    final now = DateTime.now();
    final candles = <StockCandle>[];
    final rand = Random(price.toInt() ^ 0x5A5A);

    // Generate 72 realistic points working backward from current price (3 days of hourly candles)
    double p = price;
    final points = <double>[price];
    for (int i = 0; i < 71; i++) {
      final change = (rand.nextDouble() - 0.5) * 0.012;
      p = p / (1 + change);
      points.insert(0, p);
    }

    for (int i = 0; i < 72; i++) {
      final candleTime = now.subtract(Duration(hours: 71 - i));
      final cPrice = points[i];
      final open = i > 0 ? points[i - 1] : cPrice * 0.998;
      final high = max(open, cPrice) * (1 + rand.nextDouble() * 0.003);
      final low = min(open, cPrice) * (1 - rand.nextDouble() * 0.003);

      candles.add(StockCandle(
        date: candleTime,
        open: open,
        high: high,
        low: low,
        close: cPrice,
        volume: 5000.0 + rand.nextDouble() * 20000.0,
      ));
    }
    return candles;
  }

  String _activeHost = 'data-api.binance.vision';

  Future<http.Response?> _getWithFallback(String pathAndQuery) async {
    final hosts = [_activeHost, ..._binanceHosts.where((h) => h != _activeHost)];
    for (final host in hosts) {
      try {
        final uri = Uri.parse('https://$host$pathAndQuery');
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          _activeHost = host;
          return res;
        }
      } catch (_) {
        // Continue to fallback host
      }
    }
    return null;
  }

  Future<List<StockCandle>?> _fetchKlinesWithFallback(String symbol) async {
    // 24 hours of 1-hour candles perfectly matching the 24h market change on Binance
    final path = '/api/v3/klines?symbol=$symbol&interval=1h&limit=24';
    final res = await _getWithFallback(path);
    if (res != null) {
      try {
        final List<dynamic> data = jsonDecode(res.body);
        final candles = data.map((d) => StockCandle(
          date: DateTime.fromMillisecondsSinceEpoch(d[0] as int),
          open:   double.parse(d[1].toString()) * CurrencyFormatters.usdToInr,
          high:   double.parse(d[2].toString()) * CurrencyFormatters.usdToInr,
          low:    double.parse(d[3].toString()) * CurrencyFormatters.usdToInr,
          close:  double.parse(d[4].toString()) * CurrencyFormatters.usdToInr,
          volume: double.parse(d[5].toString()),
        )).toList();
        if (candles.length >= 2) {
          return candles;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  List<Stock> build() {
    _initLiveMarket();
    _startConnectivityCheck();
    ref.onDispose(() {
      _disposed = true;
      _connectivityTimer?.cancel();
      _reconnectTimer?.cancel();
      _flushTimer?.cancel();
      _channel?.sink.close();
    });

    // Populate initial state with baseline prices and synthetic candles
    // so coins never appear at price 0 or with empty history
    return _cryptoAssets.map((c) {
      final sym = c.$1.replaceAll('USDT', '');
      final details = _assetDetails[sym] ?? _defaultDetails(sym);
      final defaultUsd = _defaultPricesUsd[sym] ?? 10.0;
      final defaultPriceInr = defaultUsd * CurrencyFormatters.usdToInr;
      final fallbackCandles = generateFallbackCandles(defaultPriceInr);

      return Stock(
        symbol: sym,
        name: c.$2,
        category: c.$3,
        currentPrice: defaultPriceInr,
        previousClose: defaultPriceInr * 0.99,
        dayHigh: defaultPriceInr * 1.02,
        dayLow: defaultPriceInr * 0.98,
        volume: 150000,
        history: fallbackCandles.map((cand) => cand.close).toList(),
        candleHistory: fallbackCandles,
        about: details['about'] as String,
        supply: (details['supply'] as num).toDouble(),
        rank: details['rank'] as int,
      );
    }).toList();
  }

  Future<void> refresh() async {
    await _initLiveMarket();
  }

  Future<void> _initLiveMarket() async {
    // ── Step 1: Fetch 24h tickers with strict timeout and fallback hosts ──
    try {
      final symbols = '[${_cryptoAssets.map((c) => '"${c.$1}"').join(',')}]';
      var tickerRes = await _getWithFallback(
        '/api/v3/ticker/24hr?symbols=${Uri.encodeComponent(symbols)}',
      );
      // Fallback: If filtered call fails or returns non-200, query the general 24hr endpoint
      tickerRes ??= await _getWithFallback('/api/v3/ticker/24hr');

      final tickerMap = <String, dynamic>{};
      if (tickerRes != null) {
        try {
          final List<dynamic> tickers = jsonDecode(tickerRes.body);
          for (final t in tickers) {
            if (t is Map && t['symbol'] != null) {
              tickerMap[t['symbol'] as String] = t;
            }
          }
        } catch (_) {}
      }

      if (_disposed) return;
      if (tickerMap.isNotEmpty) {
        _lastLiveUpdate = DateTime.now();

        // ── Fast-track: Apply live ticker prices to state IMMEDIATELY ───────
        // This ensures the screen switches to real prices in ~200ms without
        // waiting for kline batch requests to finish.
        final fastUpdated = state.map((old) {
          final rawSym = '${old.symbol}USDT';
          final ticker = tickerMap[rawSym];
          if (ticker == null) return old;

          final livePrice = (double.tryParse(ticker['lastPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr;
          if (livePrice <= 0) return old;

          final openPrice = (double.tryParse(ticker['openPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr;
          final highPrice = (double.tryParse(ticker['highPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr;
          final lowPrice = (double.tryParse(ticker['lowPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr;
          final volume = (double.tryParse(ticker['volume'].toString()) ?? 0.0).toInt();

          return old.copyWith(
            currentPrice: livePrice,
            previousClose: openPrice > 0 ? openPrice : old.previousClose,
            dayHigh: highPrice > 0 ? highPrice : livePrice * 1.01,
            dayLow: lowPrice > 0 ? lowPrice : livePrice * 0.99,
            volume: volume > 0 ? volume : old.volume,
            isLive: true,
          );
        }).toList();

        state = fastUpdated;
        ref.read(marketOnlineProvider.notifier).setOnline(true);
      } else {
        ref.read(marketOnlineProvider.notifier).setOnline(false);
      }

      // ── Step 2: Fetch real 24h klines in parallel batches ─────────────────
      final allHistoryMap = <String, Map<String, dynamic>>{};

      if (tickerMap.isNotEmpty) {
        final batches = <List<(String, String, String)>>[];
        for (var i = 0; i < _cryptoAssets.length; i += 15) {
          batches.add(_cryptoAssets.skip(i).take(15).toList());
        }

        for (final batch in batches) {
          final batchFutures = batch.map((asset) async {
            final symbol = asset.$1;
            try {
              final candles = await _fetchKlinesWithFallback(symbol);
              if (candles != null && candles.isNotEmpty) {
                return MapEntry(symbol, {
                  'candles': candles,
                  'history': candles.map((c) => c.close).toList(),
                });
              }
            } catch (_) {}
            return MapEntry(symbol, <String, dynamic>{});
          }).toList();

          final results = await Future.wait(batchFutures);
          for (final entry in results) {
            if (entry.value.isNotEmpty) {
              allHistoryMap[entry.key] = entry.value;
            }
          }
        }
      }

      // ── Step 3: Build updated state with robust fallbacks ────────────────
      final updatedState = _cryptoAssets.map((c) {
        final sym = c.$1.replaceAll('USDT', '');
        final details = _assetDetails[sym] ?? _defaultDetails(sym);
        final ticker = tickerMap[c.$1];
        final h = allHistoryMap[c.$1];

        final defaultUsd = _defaultPricesUsd[sym] ?? 10.0;
        final defaultPriceInr = defaultUsd * CurrencyFormatters.usdToInr;

        double currentPrice = 0.0;
        if (ticker != null) {
          currentPrice = (double.tryParse(ticker['lastPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr;
        }
        if (currentPrice <= 0) {
          final existingIdx = state.indexWhere((s) => s.symbol == sym);
          if (existingIdx >= 0 && state[existingIdx].currentPrice > 0) {
            currentPrice = state[existingIdx].currentPrice;
          } else {
            currentPrice = defaultPriceInr;
          }
        }

        final openPrice = ticker != null
            ? (double.tryParse(ticker['openPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr
            : 0.0;
        final highPrice = ticker != null
            ? (double.tryParse(ticker['highPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr
            : 0.0;
        final lowPrice = ticker != null
            ? (double.tryParse(ticker['lowPrice'].toString()) ?? 0.0) * CurrencyFormatters.usdToInr
            : 0.0;
        final volume = ticker != null
            ? (double.tryParse(ticker['volume'].toString()) ?? 0.0).toInt()
            : 150000;

        List<StockCandle> candles = (h?['candles'] as List<StockCandle>?) ?? const [];
        List<double> history = (h?['history'] as List<double>?) ?? const [];

        if (candles.length < 2) {
          final existingIdx = state.indexWhere((s) => s.symbol == sym);
          if (existingIdx >= 0 && state[existingIdx].candleHistory.length >= 2) {
            candles = List<StockCandle>.from(state[existingIdx].candleHistory);
            history = List<double>.from(state[existingIdx].history);

            // Scale check: If previous history was generated at a completely different baseline price,
            // scale the historical points proportionally to eliminate artificial cliff drop-offs
            if (history.isNotEmpty && currentPrice > 0) {
              final lastHistPrice = history.last;
              if (lastHistPrice > 0 && (currentPrice - lastHistPrice).abs() / lastHistPrice > 0.05) {
                final ratio = currentPrice / lastHistPrice;
                history = history.map((p) => p * ratio).toList();
                candles = candles.map((c) => StockCandle(
                  date: c.date,
                  open: c.open * ratio,
                  high: c.high * ratio,
                  low: c.low * ratio,
                  close: c.close * ratio,
                  volume: c.volume,
                )).toList();
              }
            }
          } else {
            candles = generateFallbackCandles(currentPrice);
            history = candles.map((cand) => cand.close).toList();
          }
        }

        return Stock(
          symbol: sym,
          name: c.$2,
          category: c.$3,
          currentPrice: currentPrice,
          previousClose: openPrice > 0 ? openPrice : currentPrice * 0.99,
          dayHigh: highPrice > 0 ? highPrice : currentPrice * 1.02,
          dayLow: lowPrice > 0 ? lowPrice : currentPrice * 0.98,
          volume: volume > 0 ? volume : 150000,
          history: history,
          candleHistory: candles,
          about: details['about'] as String,
          supply: (details['supply'] as num).toDouble(),
          rank: details['rank'] as int,
          isLive: ticker != null && currentPrice > 0,
        );
      }).toList();

      state = updatedState;
    } catch (_) {}

    // ── Step 4: WebSocket for live ticker updates ────────────────────────────
    _connectWebSocket();
  }

  Timer? _flushTimer;
  bool _hasPendingUpdates = false;
  int _wsHostIndex = 0;
  static const List<String> _wsHosts = [
    'data-stream.binance.vision:9443',
    'stream.binance.com:9443',
  ];

  bool _wasOnline = true;

  void _startConnectivityCheck() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_disposed) return;
      final now = DateTime.now();
      final silenceDuration = now.difference(_lastLiveUpdate).inSeconds;

      // Only check if we haven't received ANY ticker in 18 seconds (generous buffer for network jitter)
      if (silenceDuration > 18) {
        try {
          // Check general internet connectivity against a reliable host, NOT ISP-blocked api.binance.com
          final result = await InternetAddress.lookup('google.com')
              .timeout(const Duration(seconds: 3));
          if (_disposed) return;

          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            if (!_wasOnline) {
              _wasOnline = true;
              // Transitioned from offline to online: trigger market refresh to fetch real klines
              _initLiveMarket();
            } else if (_channel == null) {
              _connectWebSocket();
            }
            // Only declare market offline if prolonged silence exceeds 25 seconds
            if (silenceDuration > 25) {
              ref.read(marketOnlineProvider.notifier).setOnline(false);
            }
          } else {
            _wasOnline = false;
            ref.read(marketOnlineProvider.notifier).setOnline(false);
          }
        } catch (_) {
          if (!_disposed) {
            _wasOnline = false;
            ref.read(marketOnlineProvider.notifier).setOnline(false);
          }
        }
      }
    });
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    // Debounce offline status: only mark offline if no ticks have arrived for > 15s
    // to prevent banner flickering on brief TCP renegotiations
    if (DateTime.now().difference(_lastLiveUpdate).inSeconds > 15) {
      ref.read(marketOnlineProvider.notifier).setOnline(false);
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed) return;
      _wsHostIndex++;
      _connectWebSocket();
    });
  }

  void _connectWebSocket() {
    try {
      _reconnectTimer?.cancel();
      _channel?.sink.close();
      _flushTimer?.cancel();

      final streams = _cryptoAssets
          .map((c) => '${c.$1.toLowerCase()}@miniTicker')
          .join('/');

      final host = _wsHosts[_wsHostIndex % _wsHosts.length];
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://$host/stream?streams=$streams'),
      );

      _flushTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
        if (_hasPendingUpdates) {
          _hasPendingUpdates = false;
          state = List<Stock>.from(state);
        }
      });

      _channel!.stream.listen(
        (message) {
          try {
            final decoded = jsonDecode(message as String);
            if (decoded['data'] == null) return;
            final data = decoded['data'] as Map<String, dynamic>;

            final wsSymbol = data['s'] as String?;           // e.g. BTCUSDT
            if (wsSymbol == null) return;
            final displaySym = wsSymbol.replaceAll('USDT', '');
            final rawPrice = double.tryParse(data['c']?.toString() ?? '') ?? 0.0;
            if (rawPrice <= 0) return; // Prevent corrupting coin price with 0
            final currentPrice = rawPrice * CurrencyFormatters.usdToInr;

            if (_disposed) return;
            _lastLiveUpdate = DateTime.now();
            ref.read(marketOnlineProvider.notifier).setOnline(true);

            final openPrice    = (double.tryParse(data['o']?.toString() ?? '') ?? 0.0) * CurrencyFormatters.usdToInr;
            final highPrice    = (double.tryParse(data['h']?.toString() ?? '') ?? 0.0) * CurrencyFormatters.usdToInr;
            final lowPrice     = (double.tryParse(data['l']?.toString() ?? '') ?? 0.0) * CurrencyFormatters.usdToInr;
            final volume       = (double.tryParse(data['v']?.toString() ?? '') ?? 0).toInt();

            final idx = state.indexWhere((s) => s.symbol == displaySym);
            if (idx < 0) return;

            final old = state[idx];

            var newCandles = List<StockCandle>.from(old.candleHistory);
            var newHistory = List<double>.from(old.history);

            // Scale check: If previous history was generated at a completely different baseline price (> 5% discrepancy),
            // scale the entire historical series proportionally so that the transition is smooth and does not form a vertical cliff
            if (newHistory.isNotEmpty && currentPrice > 0) {
              final oldLast = newHistory.last;
              if (oldLast > 0 && (currentPrice - oldLast).abs() / oldLast > 0.05) {
                final ratio = currentPrice / oldLast;
                newHistory = newHistory.map((p) => p * ratio).toList();
                newCandles = newCandles.map((c) => StockCandle(
                  date: c.date,
                  open: c.open * ratio,
                  high: c.high * ratio,
                  low: c.low * ratio,
                  close: c.close * ratio,
                  volume: c.volume,
                )).toList();
              }
            }

            // Update last candle with live price
            if (newCandles.isNotEmpty) {
              final last = newCandles.last;
              newCandles[newCandles.length - 1] = StockCandle(
                date:   last.date,
                open:   last.open,
                high:   max(last.high, currentPrice),
                low:    min(last.low, currentPrice),
                close:  currentPrice,
                volume: last.volume,
              );
            }

            if (newHistory.isNotEmpty) {
              newHistory[newHistory.length - 1] = currentPrice;
            }

            state[idx] = Stock(
              symbol:        old.symbol,
              name:          old.name,
              category:      old.category,
              currentPrice:  currentPrice,
              previousClose: openPrice > 0 ? openPrice : old.previousClose,
              dayHigh:       highPrice > 0 ? highPrice : old.dayHigh,
              dayLow:        lowPrice > 0 ? lowPrice : old.dayLow,
              volume:        volume > 0 ? volume : old.volume,
              history:       newHistory,
              candleHistory: newCandles,
              about:         old.about,
              supply:        old.supply,
              rank:          old.rank,
              isLive:        true,
            );
            _hasPendingUpdates = true;
          } catch (_) {}
        },
        onDone: () {
          if (_disposed) return;
          _scheduleReconnect();
        },
        onError: (_) {
          if (_disposed) return;
          _scheduleReconnect();
        },
      );
    } catch (_) {
      if (!_disposed) {
        _scheduleReconnect();
      }
    }
  }
}
