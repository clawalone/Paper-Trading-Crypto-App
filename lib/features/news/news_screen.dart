import 'dart:convert';
import 'package:stock_arena/core/app_material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import 'news_detail_screen.dart';

class NewsArticle {
  final String title;
  final String source;
  final String time;
  final String snippet;
  final String fullContent;
  final String url;
  final String? imageUrl;
  final IconData defaultIcon;
  final Color defaultColor;

  const NewsArticle({
    required this.title,
    required this.source,
    required this.time,
    required this.snippet,
    required this.fullContent,
    required this.url,
    this.imageUrl,
    this.defaultIcon = Icons.newspaper_rounded,
    this.defaultColor = const Color(0xFF38BDF8),
  });

  NewsArticle copyWithTime(String newTime) {
    return NewsArticle(
      title: title,
      source: source,
      time: newTime,
      snippet: snippet,
      fullContent: fullContent,
      url: url,
      imageUrl: imageUrl,
      defaultIcon: defaultIcon,
      defaultColor: defaultColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'source': source,
    'time': time,
    'snippet': snippet,
    'fullContent': fullContent,
    'url': url,
    'imageUrl': imageUrl,
  };

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    title: json['title'] as String? ?? '',
    source: json['source'] as String? ?? 'Crypto News',
    time: json['time'] as String? ?? 'Recently',
    snippet: json['snippet'] as String? ?? '',
    fullContent: json['fullContent'] as String? ?? '',
    url: json['url'] as String? ?? '',
    imageUrl: json['imageUrl'] as String?,
    defaultIcon: _iconForSource(json['source'] as String? ?? ''),
    defaultColor: _colorForSource(json['source'] as String? ?? ''),
  );

  static IconData _iconForSource(String source) {
    final s = source.toLowerCase();
    if (s.contains('telegraph')) return Icons.bolt_rounded;
    if (s.contains('desk')) return Icons.newspaper_rounded;
    if (s.contains('decrypt')) return Icons.flash_on_rounded;
    if (s.contains('bitcoin')) return Icons.currency_bitcoin_rounded;
    return Icons.article_rounded;
  }

  static Color _colorForSource(String source) {
    final s = source.toLowerCase();
    if (s.contains('telegraph')) return const Color(0xFFF3BA2F);
    if (s.contains('desk')) return const Color(0xFF38BDF8);
    if (s.contains('decrypt')) return const Color(0xFF14F195);
    if (s.contains('bitcoin')) return const Color(0xFFF59E0B);
    return const Color(0xFF818CF8);
  }
}

class _FeedSource {
  final String name;
  final String url;
  final IconData icon;
  final Color color;

  const _FeedSource(this.name, this.url, this.icon, this.color);
}

class NewsScreen extends StatefulWidget {
  final bool showAppBar;
  const NewsScreen({super.key, this.showAppBar = false});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  bool _isLoading = true;
  String? _error;
  List<NewsArticle> _news = [];

  static const _cacheKey = 'cached_crypto_news_v2';

  static const List<NewsArticle> _fallbackArticles = [
    NewsArticle(
      title: 'Bitcoin Market Structure Shows Strong Resilience Above Key Support Levels',
      source: 'CoinDesk',
      time: '12m ago',
      snippet: 'On-chain analytics reveal steady institutional accumulation across major spot ETFs as network hash rate reaches fresh all-time highs.',
      fullContent: 'On-chain analytics reveal steady institutional accumulation across major spot ETFs as network hash rate reaches fresh all-time highs. Analysts point toward strong market depth and sustained perpetual futures open interest indicating enduring macro conviction.',
      url: 'https://www.coindesk.com',
      defaultIcon: Icons.newspaper_rounded,
      defaultColor: Color(0xFF38BDF8),
    ),
    NewsArticle(
      title: 'Ethereum Layer-2 Networks Process Record Daily Transaction Volume',
      source: 'CoinTelegraph',
      time: '28m ago',
      snippet: 'Blob fee optimizations and Rollup upgrades drive total daily active addresses across leading L2 protocols to unprecedented peaks.',
      fullContent: 'Blob fee optimizations and Rollup upgrades drive total daily active addresses across leading L2 protocols to unprecedented peaks. Gas efficiency improvements have reduced transaction costs to sub-cent levels, spurring renewed decentralized exchange and gaming activity.',
      url: 'https://cointelegraph.com',
      defaultIcon: Icons.bolt_rounded,
      defaultColor: Color(0xFFF3BA2F),
    ),
    NewsArticle(
      title: 'Solana Ecosystem Expands as Decentralized Exchange Volumes Challenge Top CEXs',
      source: 'Decrypt',
      time: '45m ago',
      snippet: 'High-speed automated market makers on Solana record over \$3B in weekly liquidity flow driven by meme coins and institutional cross-chain swaps.',
      fullContent: 'High-speed automated market makers on Solana record over \$3B in weekly liquidity flow driven by meme coins and institutional cross-chain swaps. Network validators report 99.9% uptime with ongoing fee-market adjustments.',
      url: 'https://decrypt.co',
      defaultIcon: Icons.flash_on_rounded,
      defaultColor: Color(0xFF14F195),
    ),
    NewsArticle(
      title: 'Global Regulatory Clarity Accelerates Corporate Treasury Allocations to Digital Assets',
      source: 'Bitcoin.com',
      time: '1h ago',
      snippet: 'Major public corporations continue diversifying reserves into physical Bitcoin, citing inflation hedge characteristics and balance sheet optionality.',
      fullContent: 'Major public corporations continue diversifying reserves into physical Bitcoin, citing inflation hedge characteristics and balance sheet optionality. Legislative updates in Europe and Asia provide regulated banking rails for custody.',
      url: 'https://news.bitcoin.com',
      defaultIcon: Icons.currency_bitcoin_rounded,
      defaultColor: Color(0xFFF59E0B),
    ),
    NewsArticle(
      title: 'Decentralized Derivatives Surge as Traders Seek High Capital Efficiency',
      source: 'CoinTelegraph',
      time: '2h ago',
      snippet: 'Perpetual DEXs and on-chain order books report record daily open interest with advanced cross-margin and automated liquidation engines.',
      fullContent: 'Perpetual DEXs and on-chain order books report record daily open interest with advanced cross-margin and automated liquidation engines. Traders benefit from non-custodial risk management and verifiable price feeds.',
      url: 'https://cointelegraph.com',
      defaultIcon: Icons.bolt_rounded,
      defaultColor: Color(0xFFF3BA2F),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedNewsAndFetch();
  }

  Future<void> _loadCachedNewsAndFetch() async {
    // 1. Immediately populate from cache so user sees content with zero delay
    await _loadCachedNews();
    // 2. Fetch fresh live feeds in background
    await _fetchNews();
  }

  Future<void> _loadCachedNews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final cachedArticles = decoded
            .map((item) => NewsArticle.fromJson(item as Map<String, dynamic>))
            .where((a) => a.title.isNotEmpty)
            .toList();

        if (cachedArticles.isNotEmpty && mounted) {
          setState(() {
            _news = cachedArticles;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // If cache is empty, prime immediately with fallback articles
    if (mounted && _news.isEmpty) {
      setState(() {
        _news = List.from(_fallbackArticles);
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNewsToCache(List<NewsArticle> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.take(30).map((a) => a.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<void> _fetchNews({bool isPullToRefresh = false}) async {
    if (!isPullToRefresh && _news.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      const sources = [
        _FeedSource('CoinTelegraph', 'https://cointelegraph.com/rss', Icons.bolt_rounded, Color(0xFFF3BA2F)),
        _FeedSource('CoinDesk', 'https://www.coindesk.com/arc/outboundfeeds/rss/', Icons.newspaper_rounded, Color(0xFF38BDF8)),
        _FeedSource('Decrypt', 'https://decrypt.co/feed', Icons.flash_on_rounded, Color(0xFF14F195)),
        _FeedSource('Bitcoin.com', 'https://news.bitcoin.com/feed/', Icons.currency_bitcoin_rounded, Color(0xFFF59E0B)),
      ];

      // Fetch all sources concurrently; each handles its own errors so one slow/failing source never breaks the others
      final results = await Future.wait(
        sources.map((src) => _fetchSingleSource(src)),
      );

      final List<NewsArticle> loaded = [];
      for (final list in results) {
        loaded.addAll(list);
      }

      // If direct feeds returned articles, apply them!
      if (loaded.isNotEmpty) {
        loaded.shuffle();
        final displayList = loaded.take(30).toList();

        for (int j = 0; j < displayList.length; j++) {
          final mins = (j * 3) + 2;
          displayList[j] = displayList[j].copyWithTime(mins < 60 ? '${mins}m ago' : '${(mins ~/ 60)}h ago');
        }

        if (mounted) {
          setState(() {
            _news = displayList;
            _isLoading = false;
            _error = null;
          });
        }

        _saveNewsToCache(displayList);
        return;
      }

      // If direct feeds were all empty or blocked, try rss2json proxy as secondary fallback
      final r2j = await _fetchRss2JsonFallback();
      if (r2j.isNotEmpty) {
        if (mounted) {
          setState(() {
            _news = r2j;
            _isLoading = false;
            _error = null;
          });
        }
        _saveNewsToCache(r2j);
        return;
      }
    } catch (_) {}

    // If completely offline or failed: keep cached news or use curated fallback
    if (mounted) {
      if (_news.isEmpty) {
        setState(() {
          _news = List.from(_fallbackArticles);
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() => _isLoading = false);
      }

      if (isPullToRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline: Showing latest cached market news.'),
            backgroundColor: Color(0xFF1E2329),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<List<NewsArticle>> _fetchSingleSource(_FeedSource src) async {
    try {
      final res = await http.get(
        Uri.parse(src.url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) PaperTrade/2.0',
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && res.body.isNotEmpty) {
        return _parseRssXml(res.body, src);
      }
    } catch (_) {}
    return [];
  }

  List<NewsArticle> _parseRssXml(String xml, _FeedSource src) {
    final List<NewsArticle> items = [];
    final itemRegex = RegExp(r'<item[\s\S]*?>([\s\S]*?)<\/item>', caseSensitive: false);
    final matches = itemRegex.allMatches(xml);

    for (final m in matches) {
      final itemXml = m.group(1) ?? '';
      final title = _cleanText(_extractTag(itemXml, 'title'));
      if (title.isEmpty) continue;

      final link = _extractTag(itemXml, 'link');
      final desc = _cleanText(_extractTag(itemXml, 'description'));
      final contentEncoded = _cleanText(_extractTag(itemXml, 'content:encoded'));
      final fullContent = contentEncoded.isNotEmpty ? contentEncoded : desc;

      String snippet = desc;
      if (snippet.length > 150) snippet = '${snippet.substring(0, 150)}...';

      final image = _extractImage(itemXml);

      items.add(NewsArticle(
        title: title,
        source: src.name,
        time: 'Recently',
        snippet: snippet.isNotEmpty ? snippet : title,
        fullContent: fullContent.isNotEmpty ? fullContent : desc,
        url: link,
        imageUrl: image,
        defaultIcon: src.icon,
        defaultColor: src.color,
      ));
    }
    return items;
  }

  Future<List<NewsArticle>> _fetchRss2JsonFallback() async {
    final List<NewsArticle> fallbackList = [];
    try {
      const url = 'https://api.rss2json.com/v1/api.json?rss_url=https://cointelegraph.com/rss';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['items'] is List) {
          final items = data['items'] as List;
          for (final item in items) {
            final title = _cleanText(item['title']?.toString() ?? '');
            if (title.isEmpty) continue;
            final desc = _cleanText(item['description']?.toString() ?? '');
            String snippet = desc;
            if (snippet.length > 150) snippet = '${snippet.substring(0, 150)}...';

            String? img;
            if (item['enclosure'] is Map && item['enclosure']['link'] != null) {
              img = item['enclosure']['link']?.toString();
            } else if (item['thumbnail'] != null && item['thumbnail'].toString().isNotEmpty) {
              img = item['thumbnail']?.toString();
            }

            fallbackList.add(NewsArticle(
              title: title,
              source: 'CoinTelegraph',
              time: 'Recently',
              snippet: snippet.isNotEmpty ? snippet : title,
              fullContent: desc,
              url: item['link']?.toString() ?? '',
              imageUrl: img,
              defaultIcon: Icons.bolt_rounded,
              defaultColor: const Color(0xFFF3BA2F),
            ));
          }
        }
      }
    } catch (_) {}
    return fallbackList;
  }

  static String _extractTag(String xml, String tag) {
    final match = RegExp('<$tag(?:[^>]*)>(?:<!\\[CDATA\\[)?([\\s\\S]*?)(?:\\]\\]>)?<\\/$tag>', caseSensitive: false).firstMatch(xml);
    return match?.group(1)?.trim() ?? '';
  }

  static String? _extractImage(String xml) {
    final enc = RegExp(r'<enclosure[^>]+url=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(xml);
    if (enc != null) return enc.group(1);
    final media = RegExp(r'<media:(?:content|thumbnail)[^>]+url=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(xml);
    if (media != null) return media.group(1);
    final img = RegExp(r'<img[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(xml);
    if (img != null) return img.group(1);
    return null;
  }

  static String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _isLoading && _news.isEmpty
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _error != null && _news.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(_error!, style: GoogleFonts.inter(color: Colors.white70)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _fetchNews(),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Retry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: RefreshIndicator(
                    onRefresh: () => _fetchNews(isPullToRefresh: true),
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    child: Column(
                      children: [
                        if (!widget.showAppBar)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.profit,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'LIVE HEADLINES',
                                  style: GoogleFonts.inter(
                                    color: AppColors.subtle,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                if (_isLoading)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  )
                                else
                                  InkWell(
                                    onTap: () => _fetchNews(),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.refresh_rounded, size: 14, color: AppColors.subtle),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Refresh',
                                            style: GoogleFonts.inter(color: AppColors.subtle, fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth > 800) {
                                return GridView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: 180,
                                  ),
                                  itemCount: _news.length,
                                  itemBuilder: (context, index) => _NewsCard(item: _news[index]),
                                );
                              }
                              return ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                itemCount: _news.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) => _NewsCard(item: _news[index]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text('Live Market News', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          centerTitle: false,
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF848E9C)),
                onPressed: () => _fetchNews(),
              ),
          ],
        ),
        body: bodyContent,
      );
    }

    return Container(
      color: AppColors.background,
      child: bodyContent,
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});
  final NewsArticle item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(article: item)));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.defaultIcon, size: 12, color: item.defaultColor),
                      const SizedBox(width: 6),
                      Text(
                        item.source,
                        style: GoogleFonts.inter(color: const Color(0xFFD1D5DB), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: AppColors.subtle),
                    const SizedBox(width: 4),
                    Text(
                      item.time,
                      style: GoogleFonts.inter(color: AppColors.subtle, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.snippet.replaceAll('&nbsp;', ' '),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9CA3AF),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Center(child: Icon(item.defaultIcon, size: 28, color: item.defaultColor.withValues(alpha: 0.8))),
                          ),
                        )
                      : Center(
                          child: Icon(item.defaultIcon, size: 28, color: item.defaultColor.withValues(alpha: 0.8)),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
