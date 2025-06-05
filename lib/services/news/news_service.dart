import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';
import '../../models/news_article.dart';

class NewsService {
  static final Logger _logger = Logger('NewsService');

  // Your actual NewsAPI.org API key
  static const String _newsApiKey = 'c194cf692e4f43d39ec5a19b3b1f84e4';
  static const String _newsApiBaseUrl = 'https://newsapi.org/v2';

  static int _currentPage = 1;
  static final List<NewsArticle> _cachedArticles = [];
  static String _lastCategory = '';
  static String _lastUsedSource = '';

  /// Get debug information about last used source
  static String get lastUsedSource => _lastUsedSource;

  /// Fetch news articles from various sources
  static Future<List<NewsArticle>> fetchNews({
    String category = 'general',
    String country = 'us',
    int pageSize = 20,
    bool useBackupSources = false,
    int page = 1,
  }) async {
    _logger.info(
        'Fetching news: category=$category, page=$page, pageSize=$pageSize');

    // Reset cache if category changed
    if (_lastCategory != category) {
      _cachedArticles.clear();
      _currentPage = 1;
      _lastCategory = category;
      _logger.info('Cache reset for new category: $category');
    }

    _currentPage = page;

    // Handle featured category - mix NewsAPI with other sources
    if (category == 'featured') {
      try {
        _logger.info('Featured category: Mixing NewsAPI with other sources...');

        // Get NewsAPI articles
        final newsApiArticles = await _fetchFromNewsAPI(
          category: 'general',
          country: country,
          pageSize: pageSize ~/ 2, // Half from NewsAPI
          page: page,
        );

        // Get articles from other sources
        final mixedArticles = await _fetchFromMixedSources(
          category: 'general',
          page: page,
          pageSize: pageSize ~/ 2, // Half from other sources
        );

        // Combine and shuffle for variety
        final allArticles = [...newsApiArticles, ...mixedArticles];
        allArticles.shuffle();

        _lastUsedSource = 'Featured Mix (NewsAPI + Others)';
        _logger.info('Featured: ${allArticles.length} mixed articles loaded');
        return allArticles.take(pageSize).toList();
      } catch (e) {
        _logger.warning('Featured category failed: $e');
        return _getFallbackArticles(pageSize);
      }
    }

    // For other categories, use mixed sources
    try {
      _logger.info('Category $category: Loading from mixed sources...');
      final mixedArticles = await _fetchFromMixedSources(
          category: category, page: page, pageSize: pageSize);
      _lastUsedSource = 'Mixed Sources ($category)';
      _logger
          .info('Category $category: ${mixedArticles.length} articles loaded');
      return mixedArticles;
    } catch (e) {
      _logger.warning('Mixed sources failed for $category: $e');
      return _getFallbackArticles(pageSize);
    }
  }

  /// Clean text to fix encoding issues with quotes and special characters
  static String _cleanText(String text) {
    return text
        // Fix common encoding issues
        .replaceAll('â€™', "'") // Right single quotation mark
        .replaceAll('â€œ', '"') // Left double quotation mark
        .replaceAll('â€�', '"') // Right double quotation mark
        .replaceAll('â€"', '–') // En dash
        .replaceAll('â€"', '—') // Em dash
        .replaceAll('â€¦', '...') // Horizontal ellipsis
        .replaceAll('Â', '') // Non-breaking space artifacts
        .replaceAll('â€¢', '•') // Bullet point
        .replaceAll('â„¢', '™') // Trademark symbol
        .replaceAll('Â®', '®') // Registered trademark
        .replaceAll('Â©', '©') // Copyright symbol
        // Fix HTML entities
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&hellip;', '...')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rdquo;', '"')
        .replaceAll('&ldquo;', '"')
        // Remove any remaining special characters that might cause issues
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '') // Remove non-ASCII characters
        .trim();
  }

  /// Fetch from multiple sources for variety
  static Future<List<NewsArticle>> _fetchFromMixedSources({
    String category = 'general',
    int page = 1,
    int pageSize = 20,
  }) async {
    _logger.info('Fetching from multiple major news sources for page $page...');

    if (_cachedArticles.isEmpty) {
      final List<NewsArticle> allArticles = [];
      final Set<String> seenIds = {};
      final Set<String> seenLinks = {};
      final Set<String> seenTitleHash = {};

      try {
        final sources = <Future<List<NewsArticle>>>[
          _fetchFromGuardianAPI(limit: 15),
          _fetchFromCNNRSS(limit: 15),
          _fetchFromFoxNewsRSS(limit: 15),
          _fetchFromNPRAPI(limit: 15),
          _fetchFromAxiosRSS(limit: 15),
          _fetchFromPoliticoRSS(limit: 15),
          _fetchFromBBCRSS(limit: 15),
          _fetchFromWashingtonPostRSS(limit: 15),
          _fetchFromDeadlineRSS(limit: 15),
          _fetchFromUSATodayRSS(limit: 15),
          _fetchFromPostMagazineRSS(limit: 15),
          _fetchFromAlJazeeraRSS(limit: 15), // NEW: Al Jazeera
        ];
        final results = await Future.wait(sources);

        for (final articles in results) {
          for (final article in articles) {
            final titleHash = (article.title + article.source)
                .toLowerCase()
                .replaceAll(RegExp(r'\s+'), '');
            if (seenIds.contains(article.id) ||
                (article.url.isNotEmpty && seenLinks.contains(article.url)) ||
                seenTitleHash.contains(titleHash)) {
              continue;
            }
            seenIds.add(article.id);
            if (article.url.isNotEmpty) seenLinks.add(article.url);
            seenTitleHash.add(titleHash);
            allArticles.add(article);
          }
        }

        if (allArticles.isNotEmpty) {
          allArticles.shuffle();
          _cachedArticles.addAll(allArticles);
        }
      } catch (e) {
        _logger.warning('Multiple sources failed: $e');
      }
    }

    final start = (page - 1) * pageSize;
    final end = start + pageSize;
    final limitedArticles = _cachedArticles.length > start
        ? _cachedArticles.sublist(
            start, end > _cachedArticles.length ? _cachedArticles.length : end)
        : <NewsArticle>[];

    _logger.info(
        'Mixed sources page $page: ${limitedArticles.length} unique articles from ${_cachedArticles.length} total');
    return limitedArticles;
  }

  /// Fetch from BBC RSS (real parsing, with image support)
  static Future<List<NewsArticle>> _fetchFromBBCRSS({int limit = 10}) async {
    try {
      _logger.info('Fetching from REAL BBC RSS...');
      final response = await http.get(
        Uri.parse('http://feeds.bbci.co.uk/news/rss.xml'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.body);
        final items = xml.findAllElements('item').take(limit);
        final now = DateTime.now();
        int i = 0;
        final articles = items.map((item) {
          final title =
              _cleanText(item.getElement('title')?.text ?? 'BBC News');
          final link =
              item.getElement('link')?.text ?? 'https://bbc.co.uk/news';
          final desc = _cleanText(
            (item.getElement('description')?.text ?? '')
                .replaceAll(RegExp(r'<[^>]*>'), ''),
          );
          final pubDate = item.getElement('pubDate')?.text;
          final dt = pubDate != null
              ? DateTime.tryParse(pubDate) ?? now.subtract(Duration(hours: i++))
              : now.subtract(Duration(hours: i++));
          String? imageUrl;
          // BBC puts images in <media:thumbnail> or <media:content>
          final mediaThumb = item.getElement('media:thumbnail');
          if (mediaThumb != null && mediaThumb.getAttribute('url') != null) {
            imageUrl = mediaThumb.getAttribute('url');
          } else {
            final mediaContent = item.getElement('media:content');
            if (mediaContent != null &&
                mediaContent.getAttribute('url') != null) {
              imageUrl = mediaContent.getAttribute('url');
            }
          }
          return NewsArticle(
            id: 'bbc_${link.hashCode}',
            title: title,
            description: desc,
            content: desc,
            url: link,
            imageUrl: imageUrl,
            source: 'BBC News',
            author: 'BBC News',
            publishedAt: dt,
            category: 'general',
          );
        }).toList();
        return articles;
      }
    } catch (e) {
      _logger.warning('BBC RSS failed: $e');
    }
    return [];
  }

  /// Fetch from CNN RSS (real parsing, with improved description support)
  static Future<List<NewsArticle>> _fetchFromCNNRSS({int limit = 10}) async {
    try {
      _logger.info('Fetching from REAL CNN RSS...');
      final response = await http.get(
        Uri.parse('http://rss.cnn.com/rss/edition.rss'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.body);
        final items = xml.findAllElements('item').take(limit);
        final now = DateTime.now();
        int i = 0;
        final articles = items.map((item) {
          final title =
              _cleanText(item.getElement('title')?.text ?? 'CNN News');
          final link = item.getElement('link')?.text ?? 'https://cnn.com';
          // Try <description>, then <media:description>, then <media:text>
          String desc = item.getElement('description')?.text ?? '';
          if (desc.trim().isEmpty) {
            final mediaDesc = item.getElement('media:description');
            if (mediaDesc != null && mediaDesc.text.trim().isNotEmpty) {
              desc = mediaDesc.text;
            } else {
              final mediaText = item.getElement('media:text');
              if (mediaText != null && mediaText.text.trim().isNotEmpty) {
                desc = mediaText.text;
              }
            }
          }
          desc = _cleanText(desc.replaceAll(RegExp(r'<[^>]*>'), ''));
          final pubDate = item.getElement('pubDate')?.text;
          final dt = pubDate != null
              ? DateTime.tryParse(pubDate) ?? now.subtract(Duration(hours: i++))
              : now.subtract(Duration(hours: i++));
          String? imageUrl;
          // Try media:content, media:thumbnail, enclosure, media:group
          final mediaContent = item.getElement('media:content');
          if (mediaContent != null &&
              mediaContent.getAttribute('url') != null) {
            imageUrl = mediaContent.getAttribute('url');
          } else {
            final mediaThumb = item.getElement('media:thumbnail');
            if (mediaThumb != null && mediaThumb.getAttribute('url') != null) {
              imageUrl = mediaThumb.getAttribute('url');
            } else {
              final enclosure = item.getElement('enclosure');
              if (enclosure != null && enclosure.getAttribute('url') != null) {
                imageUrl = enclosure.getAttribute('url');
              } else {
                final mediaGroup = item.getElement('media:group');
                if (mediaGroup != null) {
                  final groupContent = mediaGroup.getElement('media:content');
                  if (groupContent != null &&
                      groupContent.getAttribute('url') != null) {
                    imageUrl = groupContent.getAttribute('url');
                  }
                }
              }
            }
          }
          imageUrl ??=
              'https://cdn.cnn.com/cnn/.e1mo/img/4.0/logos/cnn_logo_social.jpg';
          return NewsArticle(
            id: 'cnn_${link.hashCode}',
            title: title,
            description: desc,
            content: desc,
            url: link,
            imageUrl: imageUrl,
            source: 'CNN',
            author: 'CNN',
            publishedAt: dt,
            category: 'general',
          );
        }).toList();
        return articles;
      }
    } catch (e) {
      _logger.warning('CNN RSS failed: $e');
    }
    return [];
  }

  /// Fetch from Fox News RSS (real parsing, with image support)
  static Future<List<NewsArticle>> _fetchFromFoxNewsRSS(
      {int limit = 10}) async {
    try {
      _logger.info('Fetching from REAL Fox News RSS...');
      final response = await http.get(
        Uri.parse('https://feeds.foxnews.com/foxnews/latest'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.body);
        final items = xml.findAllElements('item').take(limit);
        final now = DateTime.now();
        int i = 0;
        final articles = items.map((item) {
          final title =
              _cleanText(item.getElement('title')?.text ?? 'Fox News');
          final link = item.getElement('link')?.text ?? 'https://foxnews.com';
          final desc = _cleanText(
            (item.getElement('description')?.text ?? '')
                .replaceAll(RegExp(r'<[^>]*>'), ''),
          );
          final pubDate = item.getElement('pubDate')?.text;
          final dt = pubDate != null
              ? DateTime.tryParse(pubDate) ?? now.subtract(Duration(hours: i++))
              : now.subtract(Duration(hours: i++));
          String? imageUrl;
          // Try media:content, media:thumbnail, enclosure
          final mediaContent = item.getElement('media:content');
          if (mediaContent != null &&
              mediaContent.getAttribute('url') != null) {
            imageUrl = mediaContent.getAttribute('url');
          } else {
            final mediaThumb = item.getElement('media:thumbnail');
            if (mediaThumb != null && mediaThumb.getAttribute('url') != null) {
              imageUrl = mediaThumb.getAttribute('url');
            } else {
              final enclosure = item.getElement('enclosure');
              if (enclosure != null && enclosure.getAttribute('url') != null) {
                imageUrl = enclosure.getAttribute('url');
              }
            }
          }
          return NewsArticle(
            id: 'fox_${link.hashCode}',
            title: title,
            description: desc,
            content: desc,
            url: link,
            imageUrl: imageUrl,
            source: 'Fox News',
            author: 'Fox News',
            publishedAt: dt,
            category: 'general',
          );
        }).toList();
        return articles;
      }
    } catch (e) {
      _logger.warning('Fox News RSS failed: $e');
    }
    return [];
  }

  /// Fetch from The Washington Post RSS
  static Future<List<NewsArticle>> _fetchFromWashingtonPostRSS(
      {int limit = 10}) async {
    try {
      _logger.info('Fetching from Washington Post RSS...');
      final response = await http.get(
        Uri.parse('https://feeds.washingtonpost.com/rss/national'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.body);
        final items = xml.findAllElements('item').take(limit);
        final now = DateTime.now();
        int i = 0;

        // Helper to extract image from <media:content> or <img ...> in description
        String? extractImageUrl(XmlElement item) {
          // Try <media:content>
          final mediaContent = item.getElement('media:content');
          if (mediaContent != null &&
              mediaContent.getAttribute('url') != null) {
            return mediaContent.getAttribute('url');
          }
          // Try <enclosure>
          final enclosure = item.getElement('enclosure');
          if (enclosure != null && enclosure.getAttribute('url') != null) {
            return enclosure.getAttribute('url');
          }
          // Try <img ...> in description HTML
          final desc = item.getElement('description')?.innerText ?? '';
          final imgMatch = RegExp(r'<img[^>]+src="([^">]+)"').firstMatch(desc);
          if (imgMatch != null && imgMatch.groupCount > 0) {
            return imgMatch.group(1);
          }
          // Try Open Graph from article page (fallback, async)
          return null;
        }

        Future<String?> fetchOgImage(String url) async {
          try {
            final pageResp = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 5));
            if (pageResp.statusCode == 200) {
              final html = pageResp.body;
              final ogImageMatch =
                  RegExp(r'<meta property="og:image" content="([^"]+)"')
                      .firstMatch(html);
              if (ogImageMatch != null && ogImageMatch.groupCount > 0) {
                return ogImageMatch.group(1);
              }
            }
          } catch (_) {}
          return null;
        }

        final articlesFutures = items.map((item) async {
          final title = _cleanText(
              item.getElement('title')?.innerText ?? 'Washington Post');
          final link = item.getElement('link')?.innerText ??
              'https://washingtonpost.com';
          final desc = _cleanText(
              (item.getElement('description')?.innerText ?? '')
                  .replaceAll(RegExp(r'<[^>]*>'), ''));
          final pubDate = item.getElement('pubDate')?.innerText;
          final dt = pubDate != null
              ? DateTime.tryParse(pubDate) ?? now.subtract(Duration(hours: i++))
              : now.subtract(Duration(hours: i++));
          String? imageUrl = extractImageUrl(item);

          // Fallback: Try Open Graph if no image found
          if (imageUrl == null && link.startsWith('http')) {
            imageUrl = await fetchOgImage(link);
          }

          return NewsArticle(
            id: 'wapo_${link.hashCode}',
            title: title,
            description: desc,
            content: desc,
            url: link,
            imageUrl: imageUrl,
            source: 'The Washington Post',
            author: 'The Washington Post',
            publishedAt: dt,
            category: 'general',
          );
        }).toList();

        final articles = await Future.wait(articlesFutures);
        return articles;
      }
    } catch (e) {
      _logger.warning('Washington Post RSS failed: $e');
    }
    return [];
  }

  /// Fetch from Deadline RSS
  static Future<List<NewsArticle>> _fetchFromDeadlineRSS(
      {int limit = 10}) async {
    try {
      _logger.info('Fetching from Deadline RSS...');
      final response = await http.get(
        Uri.parse('https://deadline.com/feed/'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.body);
        final items = xml.findAllElements('item').take(limit);
        final now = DateTime.now();
        int i = 0;
        final articles = items.map((item) {
          final title =
              _cleanText(item.getElement('title')?.innerText ?? 'Deadline');
          final link =
              item.getElement('link')?.innerText ?? 'https://deadline.com';
          final desc = _cleanText(
              (item.getElement('description')?.innerText ?? '')
                  .replaceAll(RegExp(r'<[^>]*>'), ''));
          final pubDate = item.getElement('pubDate')?.innerText;
          final dt = pubDate != null
              ? DateTime.tryParse(pubDate) ?? now.subtract(Duration(hours: i++))
              : now.subtract(Duration(hours: i++));
          String? imageUrl;
          final mediaContent = item.getElement('media:content');
          if (mediaContent != null &&
              mediaContent.getAttribute('url') != null) {
            imageUrl = mediaContent.getAttribute('url');
          }
          return NewsArticle(
            id: 'deadline_${link.hashCode}',
            title: title,
            description: desc,
            content: desc,
            url: link,
            imageUrl: imageUrl,
            source: 'Deadline',
            author: 'Deadline',
            publishedAt: dt,
            category: 'entertainment',
          );
        }).toList();
        return articles;
      }
    } catch (e) {
      _logger.warning('Deadline RSS failed: $e');
    }
    return [];
  }

  /// Fetch from USA Today RSS
  static Future<List<NewsArticle>> _fetchFromUSATodayRSS(
      {int limit = 10}) async {
    try {
      _logger.info('Fetching from USA Today RSS...');
      final response = await http.get(
        Uri.parse('https://rssfeeds.usatoday.com/usatoday-NewsTopStories'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.body);
        final items = xml.findAllElements('item').take(limit);
        final now = DateTime.now();
        int i = 0;
        final articles = items.map((item) {
          final title =
              _cleanText(item.getElement('title')?.innerText ?? 'USA Today');
          final link =
              item.getElement('link')?.innerText ?? 'https://usatoday.com';
          final desc = _cleanText(
              (item.getElement('description')?.innerText ?? '')
                  .replaceAll(RegExp(r'<[^>]*>'), ''));
          final pubDate = item.getElement('pubDate')?.innerText;
          final dt = pubDate != null
              ? DateTime.tryParse(pubDate) ?? now.subtract(Duration(hours: i++))
              : now.subtract(Duration(hours: i++));
          String? imageUrl;
          final mediaContent = item.getElement('media:content');
          if (mediaContent != null &&
              mediaContent.getAttribute('url') != null) {
            imageUrl = mediaContent.getAttribute('url');
          }
          return NewsArticle(
            id: 'usatoday_${link.hashCode}',
            title: title,
            description: desc,
            content: desc,
            url: link,
            imageUrl: imageUrl,
            source: 'USA Today',
            author: 'USA Today',
            publishedAt: dt,
            category: 'general',
          );
        }).toList();
        return articles;
      }
    } catch (e) {
      _logger.warning('USA Today RSS failed: $e');
    }
    return [];
  }

  /// Fetch from Post Magazine RSS (SCMP)
  static Future<List<NewsArticle>> _fetchFromPostMagazineRSS(
      {int limit = 10}) async {
    try {
      _logger.info('Fetching from Post Magazine RSS...');
      final response = await http.get(
        Uri.parse('https://www.scmp.com/rss/91/feed'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.body);
        final items = xml.findAllElements('item').take(limit);
        final now = DateTime.now();
        int i = 0;
        final articles = items.map((item) {
          final title = _cleanText(
              item.getElement('title')?.innerText ?? 'Post Magazine');
          final link = item.getElement('link')?.innerText ??
              'https://scmp.com/magazines/post-magazine';
          final desc = _cleanText(
              (item.getElement('description')?.innerText ?? '')
                  .replaceAll(RegExp(r'<[^>]*>'), ''));
          final pubDate = item.getElement('pubDate')?.innerText;
          final dt = pubDate != null
              ? DateTime.tryParse(pubDate) ?? now.subtract(Duration(hours: i++))
              : now.subtract(Duration(hours: i++));
          String? imageUrl;
          final mediaContent = item.getElement('media:content');
          if (mediaContent != null &&
              mediaContent.getAttribute('url') != null) {
            imageUrl = mediaContent.getAttribute('url');
          }
          return NewsArticle(
            id: 'postmag_${link.hashCode}',
            title: title,
            description: desc,
            content: desc,
            url: link,
            imageUrl: imageUrl,
            source: 'Post Magazine',
            author: 'Post Magazine',
            publishedAt: dt,
            category: 'magazine',
          );
        }).toList();
        return articles;
      }
    } catch (e) {
      _logger.warning('Post Magazine RSS failed: $e');
    }
    return [];
  }

  /// Enhanced Guardian API with better descriptions and correct links (strip HTML from description/content)
  static Future<List<NewsArticle>> _fetchFromGuardianAPI(
      {int limit = 10}) async {
    try {
      _logger.info('Fetching from Guardian...');
      const apiKey = 'test';
      final url = Uri.parse('https://content.guardianapis.com/search?'
          'api-key=$apiKey&'
          'show-fields=headline,byline,thumbnail,short-url,trailText,standfirst,body&'
          'page-size=$limit&'
          'order-by=newest');
      final response = await http.get(url, headers: {
        'User-Agent': 'NewsApp/1.0',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['response']['results'] as List;
        final guardianArticles = results.map((article) {
          // Only use trailText or standfirst for description, never body/headline
          String description = article['fields']?['trailText'] ??
              article['fields']?['standfirst'] ??
              '';
          description = description.replaceAll(RegExp(r'<[^>]*>'), '');
          String content = description;
          return NewsArticle(
            id: 'guardian_${DateTime.now().millisecondsSinceEpoch}_${article['id']}',
            title: _cleanText(article['webTitle'] ?? 'Guardian Article'),
            description: _cleanText(description),
            content: _cleanText(content),
            url: article['webUrl'] ?? 'https://theguardian.com',
            imageUrl: article['fields']?['thumbnail'] ??
                'https://picsum.photos/seed/guardian${article['id']}/800/600',
            source: 'The Guardian',
            author: article['fields']?['byline'] ?? 'Guardian Staff',
            publishedAt: DateTime.tryParse(article['webPublicationDate']) ??
                DateTime.now(),
            category: 'general',
          );
        }).toList();
        return guardianArticles;
      }
    } catch (e) {
      _logger.warning('Guardian API failed: $e');
    }
    return [];
  }

  static int get currentPage => _currentPage;

  /// Fetch more articles for infinite scrolling
  static Future<List<NewsArticle>> fetchMoreNews({
    String category = 'general',
    String country = 'us',
    int pageSize = 20,
  }) async {
    _currentPage++;
    _logger.info('fetchMoreNews called, incrementing to page $_currentPage');
    return await fetchNews(
      category: category,
      country: country,
      pageSize: pageSize,
      page: _currentPage,
    );
  }

  /// Reset pagination
  static void resetPagination() {
    _currentPage = 1;
    _cachedArticles.clear();
    _logger.info('Pagination reset');
  }

  /// Generate fallback articles if all sources fail
  static List<NewsArticle> _getFallbackArticles(int count) {
    // Return empty list instead of local news
    _logger.info('No fallback articles (local news) will be generated.');
    return [];
  }

  /// Fetch news from NewsAPI.org
  static Future<List<NewsArticle>> _fetchFromNewsAPI({
    required String category,
    required String country,
    required int pageSize,
    required int page,
  }) async {
    // NewsAPI allows up to 100 articles per request
    final actualPageSize = pageSize > 100 ? 100 : pageSize;

    final url = Uri.parse(
      '$_newsApiBaseUrl/top-headlines?'
      'country=$country&'
      'category=$category&'
      'pageSize=$actualPageSize&'
      'page=$page&'
      'apiKey=$_newsApiKey',
    );

    _logger.info('NewsAPI Request: $url');

    final response = await http.get(url, headers: {
      'User-Agent': 'NewsApp/1.0',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'error') {
        throw Exception('NewsAPI Error: ${data['message']}');
      }

      final articles = data['articles'] as List;
      final totalResults = data['totalResults'] as int;

      _logger.info(
          'NewsAPI Response: ${articles.length} articles, total: $totalResults');

      final filteredArticles = articles
          .map((article) => NewsArticle.fromNewsAPI(article))
          .where((article) =>
              article.title.isNotEmpty &&
              article.title != '[Removed]' &&
              article.description.isNotEmpty &&
              article.url.isNotEmpty &&
              !article.title.toLowerCase().contains('removed'))
          .map((article) => article.copyWith(
                title: _cleanText(article.title),
                description: _cleanText(article.description),
              ))
          .toList();

      _logger.info('Filtered NewsAPI articles: ${filteredArticles.length}');
      return filteredArticles;
    } else if (response.statusCode == 429) {
      throw Exception('API rate limit exceeded');
    } else if (response.statusCode == 426) {
      throw Exception('NewsAPI subscription required for more requests');
    } else {
      throw Exception('Failed to load news: ${response.statusCode}');
    }
  }

  // CNN Article Templates
  static String _getCNNTitle(int index) {
    final titles = [
      'Breaking: Major developments in international trade talks',
      'CNN Analysis: Economic indicators show mixed signals',
      'Live updates: Congressional hearing on technology regulation',
      'Exclusive: New study reveals climate change impacts',
      'Politics: Bipartisan agreement reached on infrastructure',
      'Health: CDC releases new guidelines for public safety',
      'Business: Tech stocks surge amid market volatility',
      'World: Diplomatic efforts continue in Eastern Europe',
      'Investigation: Corporate accountability under scrutiny',
      'Report: Education reform proposals gain momentum'
    ];
    return titles[index % titles.length];
  }

  static String _getCNNDescription(int index) {
    final descriptions = [
      'Comprehensive coverage of breaking news developments as officials work toward resolution of key issues affecting global markets.',
      'In-depth analysis of economic trends and their potential impact on American families and businesses nationwide.',
      'Live reporting from Capitol Hill as lawmakers debate critical legislation affecting technology and privacy rights.',
      'Exclusive reporting on new research findings that could reshape our understanding of environmental challenges.',
      'Political leaders from both parties find common ground on essential infrastructure investments for the future.',
      'Health officials announce updated recommendations based on latest scientific evidence and data analysis.',
      'Market analysts weigh in on volatile trading session as investors navigate uncertain economic landscape.',
      'International correspondents report on ongoing diplomatic efforts to address regional security concerns.',
      'Investigative team uncovers new details about corporate practices and regulatory oversight challenges.',
      'Education experts discuss proposed reforms and their potential benefits for students and teachers.'
    ];
    return descriptions[index % descriptions.length];
  }

  static String _getCNNContent(int index) {
    return '${_getCNNDescription(index)} This developing story continues to unfold with significant implications for policy makers and citizens alike. CNN will continue to monitor these developments and provide updates as more information becomes available.';
  }

  static String _getCNNAuthor(int index) {
    final authors = [
      'Jim Acosta',
      'Anderson Cooper',
      'Wolf Blitzer',
      'Christiane Amanpour',
      'Jake Tapper'
    ];
    return authors[index % authors.length];
  }

  // Fox News Article Templates
  static String _getFoxTitle(int index) {
    final titles = [
      'EXCLUSIVE: Sources reveal new details in ongoing investigation',
      'America First: Policy changes boost domestic manufacturing',
      'Border Security: New measures implemented to enhance protection',
      'Economy: Small businesses report increased confidence',
      'Freedom Watch: Constitutional rights advocacy gains support',
      'Military: Defense spending priorities under review',
      'Tucker Tonight: Media bias exposed in latest analysis',
      'Hannity Report: Government accountability measures proposed',
      'The Five: Panel discusses current events and cultural trends',
      'Special Report: Transparency in government operations'
    ];
    return titles[index % titles.length];
  }

  static String _getFoxDescription(int index) {
    final descriptions = [
      'Exclusive reporting reveals previously unknown details about ongoing federal investigation into government operations.',
      'New policy initiatives designed to strengthen American manufacturing and create jobs for working families.',
      'Enhanced border security measures aim to protect national sovereignty and ensure orderly immigration processes.',
      'Survey data shows small business owners expressing optimism about economic conditions and growth prospects.',
      'Constitutional advocacy groups report increased engagement in protecting fundamental American freedoms.',
      'Pentagon officials review defense spending priorities to ensure military readiness and fiscal responsibility.',
      'Media analysis reveals concerning patterns of bias in mainstream news coverage of political events.',
      'Proposed legislation would increase transparency and accountability in government operations and spending.',
      'Panel of experts discusses latest developments in politics, culture, and their impact on American values.',
      'In-depth reporting examines government transparency efforts and their effectiveness in serving citizens.'
    ];
    return descriptions[index % descriptions.length];
  }

  static String _getFoxContent(int index) {
    return '${_getFoxDescription(index)} Fox News continues to bring you fair and balanced reporting on the issues that matter most to American families and communities.';
  }

  static String _getFoxAuthor(int index) {
    final authors = [
      'Tucker Carlson',
      'Sean Hannity',
      'Laura Ingraham',
      'Jesse Watters',
      'Greg Gutfeld'
    ];
    return authors[index % authors.length];
  }

  // NPR Article Templates
  static String _getNPRTitle(int index) {
    final titles = [
      'Morning Edition: Community voices on local government reform',
      'All Things Considered: Cultural preservation in modern society',
      'Fresh Air: Interview with acclaimed author on social issues',
      'Planet Money: Understanding economic trends through data',
      'Code Switch: Conversations about race and identity in America',
      'On Point: Public health initiatives in rural communities',
      'Here & Now: Technology access and digital equity efforts',
      'Science Friday: Climate research and environmental solutions',
      'Wait Wait: Weekly news quiz highlights current events',
      'Throughline: Historical context for contemporary challenges'
    ];
    return titles[index % titles.length];
  }

  static String _getNPRDescription(int index) {
    final descriptions = [
      'Community members share perspectives on local governance and civic engagement in their neighborhoods.',
      'Exploring how communities balance preserving cultural traditions with adapting to modern challenges.',
      'Thoughtful conversation about literature, social justice, and the power of storytelling in society.',
      'Economic experts break down complex financial concepts and their real-world impact on families.',
      'Nuanced discussion about race, ethnicity, and identity in contemporary American culture.',
      'Healthcare professionals discuss innovative approaches to serving underserved rural populations.',
      'Examining efforts to bridge the digital divide and ensure equitable access to technology.',
      'Scientists discuss latest research findings and potential solutions to environmental challenges.',
      'Humorous take on current events through engaging quiz format with celebrity guests.',
      'Historical analysis provides valuable context for understanding current political and social issues.'
    ];
    return descriptions[index % descriptions.length];
  }

  static String _getNPRContent(int index) {
    return '${_getNPRDescription(index)} NPR continues to provide thoughtful, in-depth coverage of the stories that shape our communities and our world.';
  }

  static String _getNPRAuthor(int index) {
    final authors = [
      'Terry Gross',
      'Ira Glass',
      'Steve Inskeep',
      'Ailsa Chang',
      'Mary Louise Kelly'
    ];
    return authors[index % authors.length];
  }

  /// Fetch from NPR RSS (real parsing, with robust image extraction and Open Graph fallback)
  static Future<List<NewsArticle>> _fetchFromNPRAPI({int limit = 10}) async {
    try {
      _logger.info('Fetching from REAL NPR...');
      final response = await http.get(
        Uri.parse('https://feeds.npr.org/1001/rss.xml'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.body);
        final items = xml.findAllElements('item').take(limit);
        final now = DateTime.now();
        int i = 0;

        Future<String?> fetchOgImage(String url) async {
          try {
            final pageResp = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 5));
            if (pageResp.statusCode == 200) {
              final html = pageResp.body;
              final ogImageMatch =
                  RegExp(r'<meta property="og:image" content="([^"]+)"')
                      .firstMatch(html);
              if (ogImageMatch != null && ogImageMatch.groupCount > 0) {
                return ogImageMatch.group(1);
              }
            }
          } catch (_) {}
          return null;
        }

        final articlesFutures = items.map((item) async {
          final title =
              _cleanText(item.getElement('title')?.innerText ?? 'NPR News');
          final link = item.getElement('link')?.innerText ?? 'https://npr.org';
          String desc = '';
          final mediaDesc = item.getElement('media:description');
          if (mediaDesc != null && mediaDesc.innerText.trim().isNotEmpty) {
            desc = mediaDesc.innerText;
          } else {
            desc = item.getElement('description')?.innerText ?? '';
          }
          desc = _cleanText(desc.replaceAll(RegExp(r'<[^>]*>'), ''));
          final pubDate = item.getElement('pubDate')?.innerText;
          final dt = pubDate != null
              ? DateTime.tryParse(pubDate) ?? now.subtract(Duration(hours: i++))
              : now.subtract(Duration(hours: i++));
          String? imageUrl;

          final mediaContents = item.findElements('media:content');
          for (final media in mediaContents) {
            final medium = media.getAttribute('medium');
            final url = media.getAttribute('url');
            if ((medium == null || medium == 'image') &&
                url != null &&
                url.isNotEmpty) {
              imageUrl = url;
              break;
            }
          }
          if (imageUrl == null) {
            final enclosure = item.getElement('enclosure');
            if (enclosure != null && enclosure.getAttribute('url') != null) {
              imageUrl = enclosure.getAttribute('url');
            }
          }
          if (imageUrl == null && link.startsWith('http')) {
            imageUrl = await fetchOgImage(link);
          }
          return NewsArticle(
            id: 'npr_${link.hashCode}',
            title: title,
            description: desc,
            content: desc,
            url: link,
            imageUrl: imageUrl,
            source: 'NPR',
            author: 'NPR',
            publishedAt: dt,
            category: 'general',
          );
        }).toList();

        final articles = await Future.wait(articlesFutures);
        return articles;
      }
    } catch (e) {
      _logger.warning('NPR RSS failed: $e');
    }
    return [];
  }

  /// Fetch from Axios RSS (real parsing, with image support)
  static Future<List<NewsArticle>> _fetchFromAxiosRSS({int limit = 10}) async {
    try {
      _logger.info('Fetching from REAL Axios RSS...');
      final response = await http.get(
        Uri.parse('https://www.axios.com/newsletters/axios-am.xml'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.body);
        final items = xml.findAllElements('item').take(limit);
        final now = DateTime.now();
        int i = 0;
        final articles = items.map((item) {
          final title =
              _cleanText(item.getElement('title')?.innerText ?? 'Axios');
          final link =
              item.getElement('link')?.innerText ?? 'https://axios.com';
          final desc = _cleanText(
            (item.getElement('description')?.innerText ?? '')
                .replaceAll(RegExp(r'<[^>]*>'), ''),
          );
          final pubDate = item.getElement('pubDate')?.innerText;
          final dt = pubDate != null
              ? DateTime.tryParse(pubDate) ?? now.subtract(Duration(hours: i++))
              : now.subtract(Duration(hours: i++));
          String? imageUrl;
          final mediaContent = item.getElement('media:content');
          if (mediaContent != null &&
              mediaContent.getAttribute('url') != null) {
            imageUrl = mediaContent.getAttribute('url');
          } else {
            final mediaThumb = item.getElement('media:thumbnail');
            if (mediaThumb != null && mediaThumb.getAttribute('url') != null) {
              imageUrl = mediaThumb.getAttribute('url');
            } else {
              final enclosure = item.getElement('enclosure');
              if (enclosure != null && enclosure.getAttribute('url') != null) {
                imageUrl = enclosure.getAttribute('url');
              }
            }
          }
          return NewsArticle(
            id: 'axios_${link.hashCode}',
            title: title,
            description: desc,
            content: desc,
            url: link,
            imageUrl: imageUrl,
            source: 'Axios',
            author: 'Axios',
            publishedAt: dt,
            category: 'general',
          );
        }).toList();
        return articles;
      }
    } catch (e) {
      _logger.warning('Axios RSS failed: $e');
    }
    return [];
  }

  /// Fetch from Politico RSS (real parsing, with image support)
  static Future<List<NewsArticle>> _fetchFromPoliticoRSS(
      {int limit = 10}) async {
    try {
      _logger.info('Fetching from REAL Politico RSS...');
      final response = await http.get(
        Uri.parse('https://www.politico.com/rss/politicopicks.xml'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.body);
        final items = xml.findAllElements('item').take(limit);
        final now = DateTime.now();
        int i = 0;
        final articles = items.map((item) {
          final title =
              _cleanText(item.getElement('title')?.innerText ?? 'Politico');
          final link =
              item.getElement('link')?.innerText ?? 'https://politico.com';
          final desc = _cleanText(
            (item.getElement('description')?.innerText ?? '')
                .replaceAll(RegExp(r'<[^>]*>'), ''),
          );
          final pubDate = item.getElement('pubDate')?.innerText;
          final dt = pubDate != null
              ? DateTime.tryParse(pubDate) ?? now.subtract(Duration(hours: i++))
              : now.subtract(Duration(hours: i++));
          String? imageUrl;
          final mediaContent = item.getElement('media:content');
          if (mediaContent != null &&
              mediaContent.getAttribute('url') != null) {
            imageUrl = mediaContent.getAttribute('url');
          } else {
            final mediaThumb = item.getElement('media:thumbnail');
            if (mediaThumb != null && mediaThumb.getAttribute('url') != null) {
              imageUrl = mediaThumb.getAttribute('url');
            } else {
              final enclosure = item.getElement('enclosure');
              if (enclosure != null && enclosure.getAttribute('url') != null) {
                imageUrl = enclosure.getAttribute('url');
              }
            }
          }
          return NewsArticle(
            id: 'politico_${link.hashCode}',
            title: title,
            description: desc,
            content: desc,
            url: link,
            imageUrl: imageUrl,
            source: 'Politico',
            author: 'Politico',
            publishedAt: dt,
            category: 'general',
          );
        }).toList();
        return articles;
      }
    } catch (e) {
      _logger.warning('Politico RSS failed: $e');
    }
    return [];
  }

  /// Fetch from Al Jazeera RSS (real parsing, with robust image extraction)
  static Future<List<NewsArticle>> _fetchFromAlJazeeraRSS(
      {int limit = 10}) async {
    try {
      _logger.info('Fetching from Al Jazeera RSS...');
      final response = await http.get(
        Uri.parse('https://www.aljazeera.com/xml/rss/all.xml'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.body);
        final items = xml.findAllElements('item').take(limit);
        final now = DateTime.now();
        int i = 0;

        // Helper to extract image from <media:content>, <enclosure>, or from HTML in description
        Future<String?> extractImageUrl(XmlElement item, String link) async {
          // Try <media:content>
          final mediaContent = item.getElement('media:content');
          if (mediaContent != null &&
              mediaContent.getAttribute('url') != null) {
            return mediaContent.getAttribute('url');
          }
          // Try <enclosure>
          final enclosure = item.getElement('enclosure');
          if (enclosure != null && enclosure.getAttribute('url') != null) {
            return enclosure.getAttribute('url');
          }
          // Try <img ...> in description HTML
          final desc = item.getElement('description')?.innerText ?? '';
          final imgMatch = RegExp(r'<img[^>]+src="([^">]+)"').firstMatch(desc);
          if (imgMatch != null && imgMatch.groupCount > 0) {
            var src = imgMatch.group(1)!;
            if (src.startsWith('/')) {
              // Relative path, prepend domain
              src = 'https://www.aljazeera.com$src';
            }
            return src;
          }
          // Try Open Graph from article page (fallback, async)
          try {
            final pageResp = await http
                .get(Uri.parse(link))
                .timeout(const Duration(seconds: 5));
            if (pageResp.statusCode == 200) {
              final html = pageResp.body;
              // Try <figure class="article-featured-image"> <img src="...">
              final figureMatch = RegExp(
                      r'<figure[^>]*class="article-featured-image"[^>]*>.*?<img[^>]+src="([^">]+)"',
                      dotAll: true)
                  .firstMatch(html);
              if (figureMatch != null && figureMatch.groupCount > 0) {
                var src = figureMatch.group(1)!;
                if (src.startsWith('/')) {
                  src = 'https://www.aljazeera.com$src';
                }
                return src;
              }
              // Try Open Graph
              final ogImageMatch =
                  RegExp(r'<meta property="og:image" content="([^"]+)"')
                      .firstMatch(html);
              if (ogImageMatch != null && ogImageMatch.groupCount > 0) {
                return ogImageMatch.group(1);
              }
            }
          } catch (_) {}
          return null;
        }

        final articlesFutures = items.map((item) async {
          final title =
              _cleanText(item.getElement('title')?.innerText ?? 'Al Jazeera');
          final link =
              item.getElement('link')?.innerText ?? 'https://aljazeera.com';
          final desc = _cleanText(
              (item.getElement('description')?.innerText ?? '')
                  .replaceAll(RegExp(r'<[^>]*>'), ''));
          final pubDate = item.getElement('pubDate')?.innerText;
          final dt = pubDate != null
              ? DateTime.tryParse(pubDate) ?? now.subtract(Duration(hours: i++))
              : now.subtract(Duration(hours: i++));
          final imageUrl = await extractImageUrl(item, link);

          return NewsArticle(
            id: 'aljazeera_${link.hashCode}',
            title: title,
            description: desc,
            content: desc,
            url: link,
            imageUrl: imageUrl,
            source: 'Al Jazeera',
            author: 'Al Jazeera',
            publishedAt: dt,
            category: 'general',
          );
        }).toList();
        final articles = await Future.wait(articlesFutures);
        return articles;
      }
    } catch (e) {
      _logger.warning('Al Jazeera RSS failed: $e');
    }
    return [];
  }
}
