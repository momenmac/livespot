import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/news_article.dart';
import '../../../services/news/news_service.dart';
import '../../../constants/theme_constants.dart';
import 'news_detail_page.dart';

class NewsListPage extends StatefulWidget {
  final String title;
  final String? category;

  const NewsListPage({
    super.key,
    this.title = 'Latest News',
    this.category,
  });

  static IconData getSourceIcon(String source) {
    switch (source.toLowerCase()) {
      case 'bbc news':
        return Icons.public;
      case 'cnn':
        return Icons.tv;
      case 'fox news':
        return Icons.live_tv;
      case 'the new york times':
        return Icons.newspaper;
      case 'reuters':
        return Icons.feed;
      case 'associated press':
        return Icons.article;
      case 'the guardian':
        return Icons.shield;
      case 'al jazeera':
        return Icons.language;
      case 'sky news':
        return Icons.cloud;
      case 'hackernews':
        return Icons.code;
      case 'dev.to':
        return Icons.developer_mode;
      case 'reddit worldnews':
        return Icons.forum;
      case 'quotable':
        return Icons.format_quote;
      case 'tech news':
        return Icons.computer;
      case 'sample news':
        return Icons.article_outlined;
      case 'tech feed':
        return Icons.rss_feed;
      case 'business report':
        return Icons.business;
      case 'github':
        return Icons.code_off;
      case 'global news':
        return Icons.public;
      case 'politico':
        return Icons.how_to_vote;
      case 'axios':
        return Icons.trending_up;
      case 'deadline':
        return Icons.access_time;
      case 'usa today':
        return Icons.flag;
      case 'post magazine':
        return Icons.auto_stories;
      case 'washington post':
        return Icons.newspaper;
      case 'npr':
        return Icons.radio;
      default:
        return Icons.article;
    }
  }

  @override
  State<NewsListPage> createState() => _NewsListPageState();
}

class _NewsListPageState extends State<NewsListPage> {
  final List<NewsArticle> _articles = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  bool _hasMoreArticles = true;
  int _currentPage = 1;
  String _selectedCategory = 'featured';

  // Dynamic category ordering based on last clicked
  static final List<String> _categoryOrder = [
    'featured',
    'trending',
    'recent',
    'general',
    'business',
    'entertainment',
    'health',
    'science',
    'sports',
    'technology',
    'politics',
    'world',
    'magazine'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category ?? 'general';
    NewsService.resetPagination();
    _loadNews();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreArticles && !_isLoading) {
        _loadMoreNews();
      }
    }
  }

  void _onCategorySelected(String category) {
    debugPrint(
        '🔥 Category selected: $category (currently: $_selectedCategory)');

    if (_selectedCategory == category) {
      // If same category is selected, deselect it and go to 'general'
      debugPrint('🔥 Same category clicked, switching to general');
      setState(() {
        _selectedCategory = 'general';
      });
    } else {
      // Move selected category to front
      _categoryOrder.remove(category);
      _categoryOrder.insert(0, category);

      debugPrint('🔥 New category selected: $category');
      setState(() {
        _selectedCategory = category;
      });
    }

    // Clear articles and reload
    setState(() {
      _articles.clear();
      _currentPage = 1;
      _hasMoreArticles = true;
    });

    debugPrint('🔥 Loading news for category: $_selectedCategory');
    _loadNews();
  }

  Future<void> _loadNews({bool resetPage = true}) async {
    try {
      debugPrint('🔥 _loadNews called for category: $_selectedCategory');

      setState(() {
        if (resetPage) _currentPage = 1;
        _isLoading = true;
        _error = null;
      });

      NewsService.resetPagination();

      // Map UI categories to backend categories and logic
      String backendCategory = 'general';
      bool sortByRecent = false;
      bool sortByTrending = false;

      switch (_selectedCategory) {
        case 'featured':
          backendCategory = 'featured';
          debugPrint('🔥 Using featured category');
          break;
        case 'trending':
          backendCategory = 'general';
          sortByTrending = true;
          debugPrint('🔥 Using trending (general + shuffle)');
          break;
        case 'recent':
          backendCategory = 'general';
          sortByRecent = true;
          debugPrint('🔥 Using recent (general + sort by date)');
          break;
        case 'business':
        case 'entertainment':
        case 'health':
        case 'science':
        case 'sports':
        case 'technology':
          backendCategory = _selectedCategory;
          debugPrint('🔥 Using NewsAPI category: $_selectedCategory');
          break;
        default:
          backendCategory = 'general';
          debugPrint(
              '🔥 Using default general category for: $_selectedCategory');
      }

      debugPrint('🔥 Fetching news with backend category: $backendCategory');

      var articles = await NewsService.fetchNews(
        category: backendCategory,
        pageSize: 20,
        page: _currentPage,
      );

      debugPrint('🔥 Received ${articles.length} articles from NewsService');

      // Simple sort logic for demo: trending = shuffle, recent = sort by date desc
      if (sortByTrending) {
        articles.shuffle();
        debugPrint('🔥 Shuffled articles for trending');
      } else if (sortByRecent) {
        articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        debugPrint('🔥 Sorted articles by date for recent');
      }

      if (mounted) {
        setState(() {
          if (resetPage) {
            _articles.clear();
          }
          _articles.addAll(articles);
          _isLoading = false;
          _hasMoreArticles = articles.isNotEmpty;
        });
        debugPrint('🔥 Updated UI with ${_articles.length} total articles');
      }
    } catch (e) {
      debugPrint('🔥 ERROR in _loadNews: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreNews() async {
    if (_isLoadingMore || !_hasMoreArticles || _isLoading) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      final nextPage = _currentPage + 1;

      String backendCategory = 'general';
      bool sortByRecent = false;
      bool sortByTrending = false;

      switch (_selectedCategory) {
        case 'featured':
          backendCategory = 'featured';
          break;
        case 'trending':
          backendCategory = 'general';
          sortByTrending = true;
          break;
        case 'recent':
          backendCategory = 'general';
          sortByRecent = true;
          break;
        default:
          backendCategory = _selectedCategory;
      }

      var articles = await NewsService.fetchNews(
        category: backendCategory,
        pageSize: 20,
        page: nextPage,
      );

      if (sortByTrending) {
        articles.shuffle();
      } else if (sortByRecent) {
        articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      }

      if (mounted) {
        setState(() {
          _articles.addAll(articles);
          _currentPage = nextPage;
          _hasMoreArticles = articles.isNotEmpty;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadNews();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Column(
        children: [
          _buildCategoryChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading more articles...',
            style: TextStyle(color: ThemeConstants.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_articles.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _articles.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _articles.length) {
            return _buildLoadingMoreIndicator();
          }
          return _buildNewsCard(_articles[index]);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 20,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 16,
              width: 200,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: ThemeConstants.grey),
            const SizedBox(height: 16),
            Text('Failed to load news', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error',
                style: TextStyle(color: ThemeConstants.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadNews(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: ThemeConstants.grey),
            const SizedBox(height: 16),
            const Text('No articles available', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadNews(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(NewsArticle article) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withAlpha(25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      child: InkWell(
        onTap: () => _navigateToDetail(article),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 130,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section (Left)
              Container(
                width: 100,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: article.imageUrl?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: article.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            child: Icon(
                              NewsListPage.getSourceIcon(article.source),
                              size: 30,
                              color: _getSourceColor(article.source),
                            ),
                          ),
                        )
                      : Container(
                          color: _getSourceColor(article.source).withAlpha(26),
                          child: Icon(
                            NewsListPage.getSourceIcon(article.source),
                            size: 30,
                            color: _getSourceColor(article.source),
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // Content Section (Right)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getSourceColor(article.source),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            NewsListPage.getSourceIcon(article.source),
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            article.source,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Title
                    Expanded(
                      child: Text(
                        article.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Time
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          article.timeAgo,
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'bbc news':
        return Colors.red[600] ?? Colors.red;
      case 'cnn':
        return Colors.red[700] ?? Colors.red;
      case 'fox news':
        return Colors.blue[800] ?? Colors.blue;
      case 'the new york times':
        return Colors.black87;
      case 'reuters':
        return Colors.orange[600] ?? Colors.orange;
      case 'associated press':
        return Colors.green[600] ?? Colors.green;
      case 'the guardian':
        return const Color(0xFF052962);
      case 'al jazeera':
        return const Color(0xFFF2AF00);
      case 'sky news':
        return const Color(0xFF0078D4);
      case 'hackernews':
        return const Color(0xFFFF6600);
      case 'dev.to':
        return const Color(0xFF3B49DF);
      case 'reddit worldnews':
        return const Color(0xFFFF4500);
      case 'quotable':
        return const Color(0xFF6C5CE7);
      case 'tech news':
        return const Color(0xFF2D3748);
      case 'sample news':
        return const Color(0xFF718096);
      case 'tech feed':
        return const Color(0xFF00BCD4);
      case 'business report':
        return const Color(0xFFFFC107);
      case 'github':
        return const Color(0xFF24292E);
      case 'global news':
        return const Color(0xFF1976D2);
      case 'politico':
        return const Color(0xFFE14B5A);
      case 'axios':
        return const Color(0xFF0066CC);
      case 'deadline':
        return const Color(0xFFFF6B35);
      case 'usa today':
        return const Color(0xFF1877F2);
      case 'post magazine':
        return const Color(0xFF8B4513);
      default:
        return ThemeConstants.primaryColor;
    }
  }

  Widget _buildCategoryChips() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _getOrderedCategories().map((category) {
          final isSelected = _selectedCategory == category;
          return Container(
            margin: const EdgeInsets.only(right: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FilterChip(
                label: Text(
                  _getCategoryDisplayName(category),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) => _onCategorySelected(category),
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[50],
                selectedColor: ThemeConstants.primaryColor,
                checkmarkColor: Colors.white,
                elevation: isSelected ? 2 : 0,
                pressElevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(
                  color: isSelected
                      ? ThemeConstants.primaryColor
                      : (isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                  width: 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<String> _getOrderedCategories() {
    return _categoryOrder;
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'featured':
        return 'Featured';
      case 'trending':
        return 'Trending';
      case 'recent':
        return 'Most Recent';
      case 'general':
        return 'General';
      case 'business':
        return 'Business';
      case 'entertainment':
        return 'Entertainment';
      case 'health':
        return 'Health';
      case 'science':
        return 'Science';
      case 'sports':
        return 'Sports';
      case 'technology':
        return 'Technology';
      default:
        return category
            .split(' ')
            .map((word) =>
                word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  void _navigateToDetail(NewsArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailPage(article: article),
      ),
    );
  }
}
