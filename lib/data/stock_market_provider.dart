import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

class StockAssetMeta {
  final String symbol;
  final String name;
  final String category;
  final String exchange;
  final String currency;
  final double defaultPrice;
  final String about;
  final double sharesOutstanding;

  const StockAssetMeta({
    required this.symbol,
    required this.name,
    required this.category,
    required this.exchange,
    required this.currency,
    required this.defaultPrice,
    required this.about,
    this.sharesOutstanding = 1000000000.0,
  });
}

const List<StockAssetMeta> kStockAssets = [
  // US Tech & Megacaps
  StockAssetMeta(
    symbol: 'AAPL',
    name: 'Apple Inc.',
    category: 'US Tech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 350.0,
    about: 'Apple Inc. designs, manufactures, and markets smartphones, personal computers, tablets, wearables, and accessories, and sells a variety of related services.',
    sharesOutstanding: 15120000000.0,
  ),
  StockAssetMeta(
    symbol: 'NVDA',
    name: 'NVIDIA Corporation',
    category: 'US Tech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 180.0,
    about: 'NVIDIA Corporation provides graphics, compute, and networking solutions powering accelerated computing and AI infrastructure globally.',
    sharesOutstanding: 24530000000.0,
  ),
  StockAssetMeta(
    symbol: 'TSLA',
    name: 'Tesla, Inc.',
    category: 'US Tech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 380.0,
    about: 'Tesla, Inc. designs, develops, manufactures, sells, and leases electric vehicles, energy storage systems, and solar panels.',
    sharesOutstanding: 3210000000.0,
  ),
  StockAssetMeta(
    symbol: 'MSFT',
    name: 'Microsoft Corporation',
    category: 'US Tech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 420.0,
    about: 'Microsoft Corporation develops and supports software, services, devices and solutions including Windows, Azure, Office 365, and Xbox gaming.',
    sharesOutstanding: 7430000000.0,
  ),
  StockAssetMeta(
    symbol: 'AMZN',
    name: 'Amazon.com, Inc.',
    category: 'US Tech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 195.0,
    about: 'Amazon.com, Inc. focuses on retail sale of consumer products, cloud computing via AWS, online advertising, digital streaming, and AI.',
    sharesOutstanding: 10420000000.0,
  ),
  StockAssetMeta(
    symbol: 'GOOGL',
    name: 'Alphabet Inc.',
    category: 'US Tech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 175.0,
    about: 'Alphabet Inc. is a multinational technology conglomerate holding company created through a restructuring of Google.',
    sharesOutstanding: 12280000000.0,
  ),
  StockAssetMeta(
    symbol: 'META',
    name: 'Meta Platforms, Inc.',
    category: 'US Tech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 580.0,
    about: 'Meta Platforms builds technologies that help people connect, find communities, and grow businesses across Facebook, Instagram, WhatsApp, and Quest VR.',
    sharesOutstanding: 2530000000.0,
  ),
  StockAssetMeta(
    symbol: 'NFLX',
    name: 'Netflix, Inc.',
    category: 'US Tech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 650.0,
    about: 'Netflix is one of the world\'s leading entertainment services with paid memberships in over 190 countries enjoying TV series, documentaries, and feature films.',
    sharesOutstanding: 430000000.0,
  ),
  StockAssetMeta(
    symbol: 'AMD',
    name: 'Advanced Micro Devices',
    category: 'US Tech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 145.0,
    about: 'Advanced Micro Devices operates as a semiconductor company producing microprocessors, chipsets, GPUs, and data center accelerators.',
    sharesOutstanding: 1620000000.0,
  ),
  StockAssetMeta(
    symbol: 'SPY',
    name: 'SPDR S&P 500 ETF',
    category: 'ETFs',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 580.0,
    about: 'SPDR S&P 500 ETF Trust seeks to provide investment results that, before expenses, correspond generally to the price and yield performance of the S&P 500 Index.',
  ),
  StockAssetMeta(
    symbol: 'QQQ',
    name: 'Invesco QQQ Trust',
    category: 'ETFs',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 490.0,
    about: 'Invesco QQQ is an exchange-traded fund based on the Nasdaq-100 Index, holding 100 of the largest non-financial companies listed on Nasdaq.',
  ),
  StockAssetMeta(
    symbol: 'COIN',
    name: 'Coinbase Global, Inc.',
    category: 'Crypto & FinTech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 310.0,
    about: 'Coinbase Global, Inc. operates a secure online platform for acquiring, storing, and trading cryptocurrencies and crypto assets.',
  ),
  StockAssetMeta(
    symbol: 'PLTR',
    name: 'Palantir Technologies',
    category: 'US Tech',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 65.0,
    about: 'Palantir Technologies builds software platforms that allow organizations to effectively integrate their data, decisions, and operations for AI and analytics.',
  ),

  // Expanded US Tech & Cloud
  StockAssetMeta(
    symbol: 'ORCL',
    name: 'Oracle Corporation',
    category: 'US Tech',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 190.0,
    about: 'Oracle Corporation offers products and services that address enterprise information technology environments, cloud infrastructure, and database software.',
  ),
  StockAssetMeta(
    symbol: 'CRM',
    name: 'Salesforce, Inc.',
    category: 'US Tech',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 330.0,
    about: 'Salesforce is the global leader in Customer Relationship Management (CRM) technology and enterprise cloud applications.',
  ),
  StockAssetMeta(
    symbol: 'ADBE',
    name: 'Adobe Inc.',
    category: 'US Tech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 510.0,
    about: 'Adobe Inc. is a diversified software company providing creative software solutions including Photoshop, Illustrator, Acrobat, and generative AI tools.',
  ),
  StockAssetMeta(
    symbol: 'UBER',
    name: 'Uber Technologies, Inc.',
    category: 'US Tech',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 75.0,
    about: 'Uber Technologies develops and operates proprietary technology applications supporting mobility ride-sharing, food delivery, and freight shipping.',
  ),

  // Semiconductors & AI Hardware
  StockAssetMeta(
    symbol: 'AVGO',
    name: 'Broadcom Inc.',
    category: 'Semiconductors',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 175.0,
    about: 'Broadcom designs, develops, and supplies a broad range of semiconductor devices and infrastructure software solutions powering AI data centers.',
  ),
  StockAssetMeta(
    symbol: 'TSM',
    name: 'Taiwan Semiconductor (ADR)',
    category: 'Semiconductors',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 195.0,
    about: 'Taiwan Semiconductor Manufacturing Company (TSMC) is the world\'s largest dedicated semiconductor foundry, fabricating leading-edge AI chips.',
  ),
  StockAssetMeta(
    symbol: 'QCOM',
    name: 'Qualcomm Incorporated',
    category: 'Semiconductors',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 165.0,
    about: 'Qualcomm develops foundational wireless technologies and Snapdragon processors powering mobile devices, automotive, and edge AI compute.',
  ),
  StockAssetMeta(
    symbol: 'INTC',
    name: 'Intel Corporation',
    category: 'Semiconductors',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 25.0,
    about: 'Intel Corporation designs and manufactures microprocessors, chipsets, server products, and wafer foundry services for computer systems globally.',
  ),
  StockAssetMeta(
    symbol: 'ARM',
    name: 'Arm Holdings plc',
    category: 'Semiconductors',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 140.0,
    about: 'Arm Holdings architects and licenses energy-efficient CPU architectures and compute platforms used in billions of smart devices and AI servers.',
  ),
  StockAssetMeta(
    symbol: 'MU',
    name: 'Micron Technology, Inc.',
    category: 'Semiconductors',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 105.0,
    about: 'Micron Technology develops high-bandwidth memory (HBM) and NAND storage products essential for AI accelerators and high-performance computing.',
  ),
  StockAssetMeta(
    symbol: 'SMCI',
    name: 'Super Micro Computer, Inc.',
    category: 'Semiconductors',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 35.0,
    about: 'Super Micro Computer provides high-performance server and storage solutions optimized for AI workloads, cloud data centers, and 5G edge computing.',
  ),

  // Crypto & FinTech
  StockAssetMeta(
    symbol: 'MSTR',
    name: 'MicroStrategy Incorporated',
    category: 'Crypto & FinTech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 380.0,
    about: 'MicroStrategy is the premier Bitcoin treasury development company, providing enterprise analytics software and holding substantial Bitcoin assets.',
  ),
  StockAssetMeta(
    symbol: 'HOOD',
    name: 'Robinhood Markets, Inc.',
    category: 'Crypto & FinTech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 35.0,
    about: 'Robinhood Markets operates a modern financial services platform facilitating commission-free trading in stocks, options, ETFs, and cryptocurrencies.',
  ),
  StockAssetMeta(
    symbol: 'MARA',
    name: 'MARA Holdings, Inc.',
    category: 'Crypto & FinTech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 22.0,
    about: 'MARA Holdings (formerly Marathon Digital) is a digital asset technology company focused on Bitcoin mining and blockchain ecosystem security.',
  ),
  StockAssetMeta(
    symbol: 'RIOT',
    name: 'Riot Platforms, Inc.',
    category: 'Crypto & FinTech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 13.0,
    about: 'Riot Platforms is a vertically integrated Bitcoin mining and digital infrastructure company with large-scale operations in North America.',
  ),
  StockAssetMeta(
    symbol: 'CLSK',
    name: 'CleanSpark, Inc.',
    category: 'Crypto & FinTech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 14.0,
    about: 'CleanSpark operates sustainable Bitcoin mining infrastructure powered predominantly by low-carbon and renewable energy sources.',
  ),
  StockAssetMeta(
    symbol: 'SQ',
    name: 'Block, Inc.',
    category: 'Crypto & FinTech',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 85.0,
    about: 'Block, Inc. builds ecosystem commerce solutions including Square point-of-sale hardware and Cash App peer-to-peer financial tools.',
  ),
  StockAssetMeta(
    symbol: 'PYPL',
    name: 'PayPal Holdings, Inc.',
    category: 'Crypto & FinTech',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 85.0,
    about: 'PayPal is a digital payment pioneer enabling digital commerce, electronic transfers, and merchant services across over 200 markets globally.',
  ),
  StockAssetMeta(
    symbol: 'V',
    name: 'Visa Inc.',
    category: 'Finance & Banks',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 310.0,
    about: 'Visa Inc. facilitates global digital payments connecting consumers, merchants, financial institutions, and government entities across 200+ countries.',
  ),
  StockAssetMeta(
    symbol: 'MA',
    name: 'Mastercard Incorporated',
    category: 'Finance & Banks',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 520.0,
    about: 'Mastercard is a technology company in the global payments industry that processes payments across consumer, business, and public sectors.',
  ),

  // Finance & Wall Street Banks
  StockAssetMeta(
    symbol: 'JPM',
    name: 'JPMorgan Chase & Co.',
    category: 'Finance & Banks',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 245.0,
    about: 'JPMorgan Chase is the largest bank in the United States, providing consumer banking, investment banking, asset management, and commercial lending.',
  ),
  StockAssetMeta(
    symbol: 'BAC',
    name: 'Bank of America Corporation',
    category: 'Finance & Banks',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 46.0,
    about: 'Bank of America is a multinational investment bank and financial services company serving individual consumers, small businesses, and institutions.',
  ),
  StockAssetMeta(
    symbol: 'GS',
    name: 'The Goldman Sachs Group, Inc.',
    category: 'Finance & Banks',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 590.0,
    about: 'Goldman Sachs is a leading global investment banking, securities, and investment management firm with institutional clients worldwide.',
  ),
  StockAssetMeta(
    symbol: 'MS',
    name: 'Morgan Stanley',
    category: 'Finance & Banks',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 130.0,
    about: 'Morgan Stanley provides wealth management, investment banking, prime brokerage, and capital market advisory services.',
  ),

  // Consumer & Retail Megacaps
  StockAssetMeta(
    symbol: 'DIS',
    name: 'The Walt Disney Company',
    category: 'Consumer',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 115.0,
    about: 'The Walt Disney Company is a premier family entertainment and media enterprise spanning theme parks, film studios, and Disney+ streaming.',
  ),
  StockAssetMeta(
    symbol: 'WMT',
    name: 'Walmart Inc.',
    category: 'Consumer',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 88.0,
    about: 'Walmart operates a vast chain of hypermarkets, discount department stores, grocery stores, and e-commerce platforms worldwide.',
  ),
  StockAssetMeta(
    symbol: 'COST',
    name: 'Costco Wholesale Corporation',
    category: 'Consumer',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 950.0,
    about: 'Costco Wholesale operates membership-only warehouse retail clubs providing high volume brand-name merchandise at discount pricing.',
  ),
  StockAssetMeta(
    symbol: 'NKE',
    name: 'NIKE, Inc.',
    category: 'Consumer',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 78.0,
    about: 'NIKE designs, develops, markets, and sells athletic footwear, apparel, equipment, and accessories globally.',
  ),
  StockAssetMeta(
    symbol: 'SBUX',
    name: 'Starbucks Corporation',
    category: 'Consumer',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 100.0,
    about: 'Starbucks is the premier roaster, marketer, and retailer of specialty coffee worldwide with tens of thousands of company-operated stores.',
  ),
  StockAssetMeta(
    symbol: 'MCD',
    name: 'McDonald\'s Corporation',
    category: 'Consumer',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 290.0,
    about: 'McDonald\'s operates and franchises fast-food restaurants serving millions of customers daily across more than 100 countries.',
  ),
  StockAssetMeta(
    symbol: 'RIVN',
    name: 'Rivian Automotive, Inc.',
    category: 'Consumer',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 11.0,
    about: 'Rivian designs, develops, and manufactures electric adventure vehicles including the R1T pickup, R1S SUV, and commercial delivery vans.',
  ),
  StockAssetMeta(
    symbol: 'LCID',
    name: 'Lucid Group, Inc.',
    category: 'Consumer',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 2.2,
    about: 'Lucid Group manufactures high-performance luxury electric vehicles powered by proprietary powertrain and battery technologies.',
  ),
  StockAssetMeta(
    symbol: 'NIO',
    name: 'NIO Inc. (ADR)',
    category: 'Consumer',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 4.5,
    about: 'NIO designs and manufactures smart high-end electric vehicles featuring proprietary battery swapping and autonomous driving technologies.',
  ),

  // Aerospace, Industrial & Energy
  StockAssetMeta(
    symbol: 'BA',
    name: 'The Boeing Company',
    category: 'Energy & Industrial',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 150.0,
    about: 'Boeing is a major aerospace manufacturer of commercial jetliners, defense aircraft, satellites, and space exploration systems.',
  ),
  StockAssetMeta(
    symbol: 'LMT',
    name: 'Lockheed Martin Corporation',
    category: 'Energy & Industrial',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 540.0,
    about: 'Lockheed Martin is a premier security and aerospace company engaged in research, design, and manufacturing of advanced defense systems like the F-35.',
  ),
  StockAssetMeta(
    symbol: 'GE',
    name: 'GE Aerospace',
    category: 'Energy & Industrial',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 185.0,
    about: 'GE Aerospace is an aerospace propulsion and systems provider supplying jet engines, components, and integrated systems for commercial and military aircraft.',
  ),
  StockAssetMeta(
    symbol: 'CAT',
    name: 'Caterpillar Inc.',
    category: 'Energy & Industrial',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 400.0,
    about: 'Caterpillar is the world\'s leading manufacturer of construction and mining equipment, diesel and natural gas engines, and industrial gas turbines.',
  ),
  StockAssetMeta(
    symbol: 'XOM',
    name: 'Exxon Mobil Corporation',
    category: 'Energy & Industrial',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 120.0,
    about: 'ExxonMobil is one of the world\'s largest publicly traded energy providers and chemical manufacturers, exploring crude oil and natural gas globally.',
  ),
  StockAssetMeta(
    symbol: 'CVX',
    name: 'Chevron Corporation',
    category: 'Energy & Industrial',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 160.0,
    about: 'Chevron is an integrated energy company engaged in exploration, production, refining, and transportation of crude oil and natural gas.',
  ),

  // Healthcare & Pharmaceuticals
  StockAssetMeta(
    symbol: 'LLY',
    name: 'Eli Lilly and Company',
    category: 'Healthcare',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 820.0,
    about: 'Eli Lilly is a global healthcare leader developing breakthrough medicines for diabetes, obesity (Mounjaro/Zepbound), oncology, and immunology.',
  ),
  StockAssetMeta(
    symbol: 'NVO',
    name: 'Novo Nordisk A/S (ADR)',
    category: 'Healthcare',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 105.0,
    about: 'Novo Nordisk is a global healthcare company specializing in diabetes and weight management therapeutics including Ozempic and Wegovy.',
  ),
  StockAssetMeta(
    symbol: 'JNJ',
    name: 'Johnson & Johnson',
    category: 'Healthcare',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 155.0,
    about: 'Johnson & Johnson researches, develops, and manufactures innovative pharmaceutical treatments and medical technology devices.',
  ),
  StockAssetMeta(
    symbol: 'PFE',
    name: 'Pfizer Inc.',
    category: 'Healthcare',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 26.0,
    about: 'Pfizer is a research-based global biopharmaceutical company discovering and developing therapies, vaccines, and oncology treatments.',
  ),
  StockAssetMeta(
    symbol: 'UNH',
    name: 'UnitedHealth Group Incorporated',
    category: 'Healthcare',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 600.0,
    about: 'UnitedHealth Group is a diversified health care company offering health benefit plans through UnitedHealthcare and health services through Optum.',
  ),

  // Top Index & Leveraged ETFs
  StockAssetMeta(
    symbol: 'VOO',
    name: 'Vanguard S&P 500 ETF',
    category: 'ETFs',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 545.0,
    about: 'Vanguard S&P 500 ETF tracks the S&P 500 Index with an ultra-low expense ratio, representing 500 of the largest US public companies.',
  ),
  StockAssetMeta(
    symbol: 'IWM',
    name: 'iShares Russell 2000 ETF',
    category: 'ETFs',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 235.0,
    about: 'iShares Russell 2000 ETF tracks the small-cap segment of the US equity universe, giving exposure to 2,000 small-cap US equities.',
  ),
  StockAssetMeta(
    symbol: 'DIA',
    name: 'SPDR Dow Jones Industrial Average ETF',
    category: 'ETFs',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 440.0,
    about: 'SPDR Dow Jones Industrial Average ETF Trust seeks to provide investment results that correspond to the price and yield of the Dow Jones Industrial Average.',
  ),
  StockAssetMeta(
    symbol: 'TQQQ',
    name: 'ProShares UltraPro QQQ (3x)',
    category: 'ETFs',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 82.0,
    about: 'ProShares UltraPro QQQ seeks daily investment results that correspond to 3x the daily performance of the Nasdaq-100 Index.',
  ),
  StockAssetMeta(
    symbol: 'SQQQ',
    name: 'ProShares UltraPro Short QQQ (-3x)',
    category: 'ETFs',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 7.5,
    about: 'ProShares UltraPro Short QQQ seeks daily investment results that correspond to -3x (triple inverse) the daily performance of the Nasdaq-100 Index.',
  ),
  StockAssetMeta(
    symbol: 'SOXX',
    name: 'iShares Semiconductor ETF',
    category: 'ETFs',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 220.0,
    about: 'iShares Semiconductor ETF tracks an index composed of US-listed equities in the semiconductor sector.',
  ),
  StockAssetMeta(
    symbol: 'GLD',
    name: 'SPDR Gold Shares',
    category: 'ETFs',
    exchange: 'NYSE',
    currency: 'USD',
    defaultPrice: 245.0,
    about: 'SPDR Gold Shares is the largest physically backed gold exchange-traded fund in the world, tracking the spot price of gold bullion.',
  ),
  StockAssetMeta(
    symbol: 'TLT',
    name: 'iShares 20+ Year Treasury Bond ETF',
    category: 'ETFs',
    exchange: 'NASDAQ',
    currency: 'USD',
    defaultPrice: 90.0,
    about: 'iShares 20+ Year Treasury Bond ETF tracks an index of US Treasury bonds with remaining maturities greater than twenty years.',
  ),
];

const List<StockAssetMeta> kStockIndices = [
  StockAssetMeta(
    symbol: '^GSPC',
    name: 'S&P 500',
    category: 'Indices',
    exchange: 'INDEX',
    currency: 'USD',
    defaultPrice: 5950.0,
    about: 'Standard and Poor\'s 500 is a stock market index tracking the stock performance of 500 leading companies listed on stock exchanges in the United States.',
  ),
  StockAssetMeta(
    symbol: '^IXIC',
    name: 'NASDAQ',
    category: 'Indices',
    exchange: 'INDEX',
    currency: 'USD',
    defaultPrice: 19200.0,
    about: 'The Nasdaq Composite is a stock market index tracking over 2,500 common equities listed on the Nasdaq stock market.',
  ),
  StockAssetMeta(
    symbol: '^DJI',
    name: 'Dow Jones',
    category: 'Indices',
    exchange: 'INDEX',
    currency: 'USD',
    defaultPrice: 43800.0,
    about: 'The Dow Jones Industrial Average is a price-weighted measure of 30 prominent companies listed on stock exchanges in the United States.',
  ),
];

class StockMarketNotifier extends Notifier<List<Stock>> {
  Timer? _pollingTimer;
  bool _isLoading = false;
  bool _disposed = false;

  @override
  List<Stock> build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _pollingTimer?.cancel();
    });

    final initialList = _buildInitialStockList();
    _startPolling();
    return initialList;
  }

  List<Stock> _buildInitialStockList() {
    return kStockAssets.map((meta) {
      final prev = meta.defaultPrice * 0.992;
      return Stock(
        symbol: meta.symbol,
        name: meta.name,
        category: meta.category,
        currentPrice: meta.defaultPrice,
        previousClose: prev,
        dayHigh: meta.defaultPrice * 1.015,
        dayLow: meta.defaultPrice * 0.985,
        volume: 2500000,
        history: _generateSyntheticHistory(meta.defaultPrice, meta.symbol),
        candleHistory: _generateSyntheticCandles(meta.defaultPrice, meta.symbol),
        about: meta.about,
        supply: meta.sharesOutstanding > 0 ? meta.sharesOutstanding : 1000000000,
        rank: 1,
        isLive: false,
        exchange: meta.exchange,
        currency: meta.currency,
        fiftyTwoWeekHigh: meta.defaultPrice * 1.25,
        fiftyTwoWeekLow: meta.defaultPrice * 0.75,
        isStock: true,
        marketState: 'REGULAR',
      );
    }).toList();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Initial fetch deferred to microtask so build() finishes and state is initialized
    Future.microtask(() {
      if (!_disposed) {
        _fetchQuotes();
      }
    });
    // Poll every 12 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!_disposed) {
        _fetchQuotes();
      }
    });
  }

  Future<void> _fetchQuotes() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;

    try {
      if (_disposed) return;
      final allSymbols = kStockAssets.map((e) => e.symbol).toList();
      final updatedList = List<Stock>.from(state);

      final futures = allSymbols.map((sym) async {
        return _fetchSingleQuote(sym);
      });

      final results = await Future.wait(futures);
      if (_disposed) return;

      for (final res in results) {
        if (res == null) continue;
        final idx = updatedList.indexWhere((s) => s.symbol == res.symbol);
        if (idx != -1) {
          updatedList[idx] = res;
        }
      }

      if (_disposed) return;
      state = updatedList;
    } catch (e) {
      debugPrint('[StockMarket] Polling error: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<Stock?> _fetchSingleQuote(String symbol) async {
    try {
      final meta = kStockAssets.firstWhere(
        (e) => e.symbol == symbol,
        orElse: () => StockAssetMeta(
          symbol: symbol,
          name: symbol,
          category: 'Stocks',
          exchange: 'US',
          currency: 'USD',
          defaultPrice: 100.0,
          about: '',
        ),
      );

      String querySymbol = symbol;
      if (querySymbol == 'SQ') {
        querySymbol = 'XYZ';
      }

      final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$querySymbol?interval=15m&range=5d',
      );

      final resp = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = json['chart']?['result'] as List?;
      if (result == null || result.isEmpty) return null;

      final data = result[0] as Map<String, dynamic>;
      final chartMeta = data['meta'] as Map<String, dynamic>? ?? {};

      final priceNum = chartMeta['regularMarketPrice'] as num?;
      final bool hasRealPrice = priceNum != null && priceNum > 0;
      final regularMarketPrice = hasRealPrice ? priceNum.toDouble() : meta.defaultPrice;
      final chartPreviousClose = (chartMeta['chartPreviousClose'] as num?)?.toDouble() ??
          (chartMeta['previousClose'] as num?)?.toDouble() ??
          (regularMarketPrice * 0.995);
      final fiftyTwoWeekHigh = (chartMeta['fiftyTwoWeekHigh'] as num?)?.toDouble() ?? (regularMarketPrice * 1.2);
      final fiftyTwoWeekLow = (chartMeta['fiftyTwoWeekLow'] as num?)?.toDouble() ?? (regularMarketPrice * 0.8);
      final currency = (chartMeta['currency'] as String?) ?? meta.currency;
      final exchange = (chartMeta['fullExchangeName'] as String?) ?? meta.exchange;

      // Parse candles if present
      final timestamps = (data['timestamp'] as List?)?.cast<int>() ?? [];
      final indicators = data['indicators']?['quote'] as List?;
      final quote = (indicators != null && indicators.isNotEmpty) ? indicators[0] as Map<String, dynamic> : null;

      final List<StockCandle> candles = [];
      final List<double> history = [];

      if (quote != null && timestamps.isNotEmpty) {
        final opens = (quote['open'] as List?) ?? [];
        final highs = (quote['high'] as List?) ?? [];
        final lows = (quote['low'] as List?) ?? [];
        final closes = (quote['close'] as List?) ?? [];
        final volumes = (quote['volume'] as List?) ?? [];

        final count = min(timestamps.length, closes.length);
        for (int i = 0; i < count; i++) {
          final c = (closes[i] as num?)?.toDouble();
          if (c == null || c.isNaN) continue;
          final o = (opens.length > i && opens[i] != null) ? (opens[i] as num).toDouble() : c;
          final h = (highs.length > i && highs[i] != null) ? (highs[i] as num).toDouble() : max(o, c);
          final l = (lows.length > i && lows[i] != null) ? (lows[i] as num).toDouble() : min(o, c);
          final v = (volumes.length > i && volumes[i] != null) ? (volumes[i] as num).toDouble() : 100000.0;
          final dt = DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000);

          candles.add(StockCandle(
            date: dt,
            open: o,
            high: h,
            low: l,
            close: c,
            volume: v,
          ));
          history.add(c);
        }
      }

      // Check current market open status based on exchange time
      final marketState = _calculateMarketState(symbol, exchange);

      final regularMarketVolume = (chartMeta['regularMarketVolume'] as num?)?.toInt() ??
          (candles.isNotEmpty ? candles.map((e) => e.volume).reduce((a, b) => a + b).toInt() : 1500000);
      final regularMarketDayHigh = (chartMeta['regularMarketDayHigh'] as num?)?.toDouble() ??
          (candles.isNotEmpty ? candles.map((e) => e.high).reduce(max) : regularMarketPrice * 1.01);
      final regularMarketDayLow = (chartMeta['regularMarketDayLow'] as num?)?.toDouble() ??
          (candles.isNotEmpty ? candles.map((e) => e.low).reduce(min) : regularMarketPrice * 0.99);

      return Stock(
        symbol: symbol,
        name: meta.name,
        category: meta.category,
        currentPrice: regularMarketPrice,
        previousClose: chartPreviousClose,
        dayHigh: regularMarketDayHigh,
        dayLow: regularMarketDayLow,
        volume: regularMarketVolume > 0 ? regularMarketVolume : 1500000,
        history: history.isNotEmpty ? history : _generateSyntheticHistory(regularMarketPrice, symbol),
        candleHistory: candles.isNotEmpty ? candles : _generateSyntheticCandles(regularMarketPrice, symbol),
        about: meta.about,
        supply: meta.sharesOutstanding > 0 ? meta.sharesOutstanding : 1000000000,
        rank: 1,
        isLive: hasRealPrice,
        exchange: exchange,
        currency: currency,
        fiftyTwoWeekHigh: fiftyTwoWeekHigh,
        fiftyTwoWeekLow: fiftyTwoWeekLow,
        isStock: true,
        marketState: marketState,
      );
    } catch (e) {
      return null;
    }
  }

  static String _calculateMarketState(String symbol, String exchange) {
    final nowUtc = DateTime.now().toUtc();
    final weekday = nowUtc.weekday; // 1 = Mon, 7 = Sun

    // If Saturday or Sunday, market is closed
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      return 'CLOSED';
    }

    // US Market (EST/EDT: Regular Trading Hours: 9:30 AM to 4:00 PM EST => 14:30 to 21:00 UTC)
    final minuteOfDayUtc = nowUtc.hour * 60 + nowUtc.minute;
    const openMinuteUtc = 14 * 60 + 30; // 14:30 UTC
    const closeMinuteUtc = 21 * 60;     // 21:00 UTC

    if (minuteOfDayUtc >= openMinuteUtc && minuteOfDayUtc < closeMinuteUtc) {
      return 'REGULAR';
    }
    return 'CLOSED';
  }

  static List<double> _generateSyntheticHistory(double basePrice, [String symbol = '']) {
    final list = <double>[];
    final rand = Random(symbol.hashCode ^ (basePrice * 100).toInt());
    double p = basePrice * (0.97 + (rand.nextDouble() * 0.04));
    for (int i = 0; i < 30; i++) {
      p += (rand.nextDouble() - 0.49) * (basePrice * 0.015);
      list.add(p);
    }
    list.add(basePrice);
    return list;
  }

  static List<StockCandle> _generateSyntheticCandles(double basePrice, [String symbol = '']) {
    final list = <StockCandle>[];
    final rand = Random(symbol.hashCode ^ (basePrice * 100).toInt());
    double p = basePrice * (0.96 + (rand.nextDouble() * 0.04));
    final now = DateTime.now();

    for (int i = 25; i >= 0; i--) {
      final change = (rand.nextDouble() - 0.48) * (basePrice * 0.018);
      final o = p;
      final c = p + change;
      final h = max(o, c) + rand.nextDouble() * (basePrice * 0.006);
      final l = min(o, c) - rand.nextDouble() * (basePrice * 0.006);
      p = c;

      list.add(StockCandle(
        date: now.subtract(Duration(days: i)),
        open: o,
        high: h,
        low: l,
        close: c,
        volume: (200000 + rand.nextInt(500000)).toDouble(),
      ));
    }
    return list;
  }

  Future<void> refresh() async {
    await _fetchQuotes();
  }
}

final stockMarketProvider = NotifierProvider<StockMarketNotifier, List<Stock>>(() {
  return StockMarketNotifier();
});

class StockIndicesNotifier extends Notifier<List<Stock>> {
  Timer? _timer;

  @override
  List<Stock> build() {
    ref.onDispose(() => _timer?.cancel());
    final initial = _buildInitialIndices();
    _startPolling();
    return initial;
  }

  List<Stock> _buildInitialIndices() {
    return kStockIndices.map((meta) {
      return Stock(
        symbol: meta.symbol,
        name: meta.name,
        category: meta.category,
        currentPrice: meta.defaultPrice,
        previousClose: meta.defaultPrice * 0.995,
        dayHigh: meta.defaultPrice * 1.01,
        dayLow: meta.defaultPrice * 0.99,
        volume: 10000000,
        history: [meta.defaultPrice * 0.99, meta.defaultPrice],
        candleHistory: const [],
        about: meta.about,
        supply: 1,
        rank: 0,
        exchange: meta.exchange,
        currency: meta.currency,
        isStock: true,
        marketState: 'REGULAR',
      );
    }).toList();
  }

  void _startPolling() {
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final updated = List<Stock>.from(state);
      for (int i = 0; i < kStockIndices.length; i++) {
        final meta = kStockIndices[i];
        final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(meta.symbol)}?interval=1d&range=1d',
        );
        final resp = await http.get(
          uri,
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        ).timeout(const Duration(seconds: 5));

        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body);
          final result = json['chart']?['result']?[0];
          if (result != null) {
            final chartMeta = result['meta'] as Map<String, dynamic>;
            final price = (chartMeta['regularMarketPrice'] as num?)?.toDouble() ?? meta.defaultPrice;
            final prev = (chartMeta['chartPreviousClose'] as num?)?.toDouble() ?? (price * 0.997);
            updated[i] = updated[i].copyWith(
              currentPrice: price,
              previousClose: prev,
            );
          }
        }
      }
      state = updated;
    } catch (_) {}
  }
}

final stockIndicesProvider = NotifierProvider<StockIndicesNotifier, List<Stock>>(() {
  return StockIndicesNotifier();
});
