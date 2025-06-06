import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/news/news_service.dart';
import 'package:flutter_application_2/models/news_article.dart';
import 'package:flutter_application_2/ui/pages/news/news_detail_page.dart';
import 'package:flutter_application_2/ui/pages/news/news_list_page.dart';

class ExternalNewsSection extends StatefulWidget {
  final DateTime selectedDate;

  const ExternalNewsSection({
    super.key,
    required this.selectedDate,
  });

  @override
  State<ExternalNewsSection> createState() => _ExternalNewsSectionState();
}

class _ExternalNewsSectionState extends State<ExternalNewsSection> {
  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Use debugPrint instead of print
      debugPrint('🏠 Loading NewsAPI articles for home page...');

      NewsService.resetPagination();
      final articles = await NewsService.fetchNews(
        category: 'general',
        pageSize: 10,
        page: 1,
      );

      debugPrint('🏠 Received ${articles.length} NewsAPI articles for home');

      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading NewsAPI articles: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ThemeConstants.primaryColorLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.public,
                      size: 16,
                      color: ThemeConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    TextStrings.externalNews,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NewsListPage(
                        title: 'From Around the Web',
                        category: null,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      TextStrings.viewAll,
                      style: TextStyle(
                        color: ThemeConstants.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: ThemeConstants.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Horizontal scrolling news cards
        SizedBox(
          height: 200,
          child: _buildNewsContent(),
        ),
      ],
    );
  }

  Widget _buildNewsContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_articles.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _articles.length,
      itemBuilder: (context, index) {
        final article = _articles[index];
        return _buildExternalNewsCard(context, article);
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return _buildShimmerCard();
      },
    );
  }

  Widget _buildShimmerCard() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDarkMode ? Colors.black : Colors.black).withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shimmer image placeholder
          Container(
            height: 105,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDarkMode ? theme.canvasColor : ThemeConstants.greyLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: ThemeConstants.primaryColor,
                strokeWidth: 2,
              ),
            ),
          ),
          // Shimmer content placeholder
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? theme.canvasColor
                        : ThemeConstants.greyLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 200,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? theme.canvasColor
                        : ThemeConstants.greyLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? theme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isDarkMode ? Colors.black : Colors.black).withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load news',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadNews,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConstants.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? theme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isDarkMode ? Colors.black : Colors.black).withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 48,
              color: ThemeConstants.grey,
            ),
            const SizedBox(height: 12),
            Text(
              'No news available',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try again later',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalNewsCard(BuildContext context, NewsArticle article) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Card background color based on theme
    final cardBackgroundColor = isDarkMode ? theme.cardColor : Colors.white;

    // Shadow color based on theme
    final shadowColor =
        isDarkMode ? Colors.black.withAlpha(38) : Colors.black.withAlpha(20);

    // Text colors based on theme
    final titleTextColor = isDarkMode
        ? theme.textTheme.bodyLarge?.color
        : null; // Use default for light mode

    final descriptionTextColor = isDarkMode
        ? theme.textTheme.bodyMedium?.color
        : ThemeConstants.black.withAlpha(204);

    final secondaryTextColor =
        isDarkMode ? theme.textTheme.bodySmall?.color : ThemeConstants.grey;

    // Get accent color based on source
    final accentColor = _getAccentColorForSource(article.source);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => NewsDetailPage(article: article),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16, bottom: 0),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image section with better error handling
            Stack(
              children: [
                SizedBox(
                  height: 105,
                  width: double.infinity,
                  child: article.imageUrl != null &&
                          article.imageUrl!.isNotEmpty
                      ? Image.network(
                          article.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: isDarkMode
                                  ? theme.canvasColor
                                  : ThemeConstants.greyLight,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: ThemeConstants.primaryColor,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: isDarkMode
                                  ? theme.canvasColor
                                  : ThemeConstants.greyLight,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: isDarkMode
                                      ? theme.disabledColor
                                      : ThemeConstants.grey.withAlpha(128),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: isDarkMode
                              ? theme.canvasColor
                              : ThemeConstants.greyLight,
                          child: Center(
                            child: Icon(
                              Icons.article,
                              size: 48,
                              color: isDarkMode
                                  ? theme.disabledColor
                                  : ThemeConstants.grey.withAlpha(128),
                            ),
                          ),
                        ),
                ),

                // Source badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? const Color.fromRGBO(255, 255, 255, 0.15)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          NewsListPage.getSourceIcon(article.source),
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          article.source,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Content section
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    article.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.1,
                      color: titleTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 2),

                  // Description
                  Text(
                    article.shortDescription,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      color: descriptionTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 3),

                  // Time info and read more button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Time
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: secondaryTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            article.timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),

                      // Read more button - Fixed navigation
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  NewsDetailPage(article: article),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                TextStrings.readMore,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward,
                                size: 12,
                                color: accentColor,
                              ),
                            ],
                          ),
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
    );
  }

  Color _getAccentColorForSource(String source) {
    final sourceColors = {
      'BBC News': Colors.red,
      'Reuters': Colors.orange,
      'CNN': Colors.blue,
      'TechCrunch': ThemeConstants.orange,
      'Financial Times': Colors.pink,
      'Health Journal': Colors.teal,
      'Associated Press': Colors.green,
      'The Guardian': Colors.teal,
      'Bloomberg': Colors.blue,
      'NPR': Colors.purple,
      'Al Jazeera': Colors.purple,
      'Sky News': Colors.indigo,
      'HackerNews': Colors.deepOrange,
      'Dev.to': Colors.purple,
      'Reddit WorldNews': Colors.deepOrange,
    };

    return sourceColors[source] ?? ThemeConstants.primaryColor;
  }
}
