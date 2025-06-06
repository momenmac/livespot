import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/news_article.dart';
import '../../../constants/theme_constants.dart';
import '../news/news_list_page.dart' show NewsListPage;

class NewsDetailPage extends StatelessWidget {
  final NewsArticle article;

  const NewsDetailPage({
    super.key,
    required this.article,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: _getSourceColor(article.source),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero Image
                  if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                    Image.network(
                      article.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color:
                              isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: ThemeConstants.primaryColor,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                _getSourceColor(article.source).withAlpha(204),
                                _getSourceColor(article.source),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getSourceIcon(article.source),
                                  size: 64,
                                  color: Colors.white.withAlpha(204),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  article.source,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(204),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _getSourceColor(article.source).withAlpha(204),
                            _getSourceColor(article.source),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getSourceIcon(article.source),
                              size: 64,
                              color: Colors.white.withAlpha(204),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              article.source,
                              style: TextStyle(
                                color: Colors.white.withAlpha(204),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(179),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(77),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () => _shareArticle(context),
                  icon: const Icon(Icons.share, color: Colors.white),
                ),
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              color: isDarkMode ? theme.scaffoldBackgroundColor : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Source Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getSourceColor(article.source),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getSourceIcon(article.source),
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                article.source,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Title
                        Text(
                          article.title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            fontSize: 28,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Meta Information - Only show if author exists and is not default
                        if (_shouldShowAuthor(article.author))
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[850]
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      _getSourceColor(article.source),
                                  backgroundImage:
                                      _getAuthorAvatar(article.author),
                                  child: _getAuthorAvatar(article.author) ==
                                          null
                                      ? Text(
                                          _getAuthorInitials(article.author),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        article.author,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.schedule,
                                            size: 14,
                                            color: isDarkMode
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            article.timeAgo,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDarkMode
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
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

                        // If no author, just show time
                        if (!_shouldShowAuthor(article.author))
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[850]
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  article.timeAgo,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Content Section
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getCleanContent(article),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.7,
                            fontSize: 17,
                            color: isDarkMode
                                ? Colors.grey[200]
                                : Colors.grey[800],
                            letterSpacing: 0.3,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openInBrowser(context),
                                icon:
                                    const Icon(Icons.open_in_browser, size: 20),
                                label: const Text('Read Full Article'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _getSourceColor(article.source),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _getSourceColor(article.source),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: () => _copyUrl(context),
                                icon: Icon(
                                  Icons.link,
                                  color: _getSourceColor(article.source),
                                ),
                                iconSize: 24,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCleanContent(NewsArticle article) {
    String content =
        article.content.isNotEmpty ? article.content : article.description;

    // Remove common unwanted patterns
    content = content
        .replaceAll(RegExp(r'\[.*?\]'), '') // Remove [+chars] patterns
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();

    // If content is too short, use description instead
    if (content.length < 50 && article.description.isNotEmpty) {
      content = article.description
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    // Add ellipsis if content is truncated
    if (content.endsWith('...') || content.endsWith('…')) {
      return content;
    }

    // If content seems incomplete, add ellipsis
    if (content.length > 200 &&
        !content.endsWith('.') &&
        !content.endsWith('!') &&
        !content.endsWith('?')) {
      return '$content...';
    }

    return content.isEmpty
        ? 'Click "Read Full Article" to view the complete story.'
        : content;
  }

  Future<void> _openInBrowser(BuildContext context) async {
    try {
      debugPrint('🌐 Attempting to open URL: ${article.url}');

      // Validate URL first
      if (article.url.isEmpty) {
        throw Exception('No URL available for this article');
      }

      final uri = Uri.tryParse(article.url);
      if (uri == null) {
        throw Exception('Invalid URL format');
      }

      // Try different launch modes
      bool launched = false;

      // First try external application
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        debugPrint('✅ Successfully opened URL in external browser');
      } catch (e) {
        debugPrint('❌ External application launch failed: $e');
      }

      // If that fails, try platform default
      if (!launched) {
        try {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
          debugPrint('✅ Successfully opened URL with platform default');
        } catch (e) {
          debugPrint('❌ Platform default launch failed: $e');
        }
      }

      // If still fails, try in-app web view
      if (!launched) {
        try {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
          debugPrint('✅ Successfully opened URL in-app');
        } catch (e) {
          debugPrint('❌ In-app web view launch failed: $e');
        }
      }

      if (!launched) {
        // Final fallback: copy URL and show message
        if (!context.mounted) return;
        await _copyUrl(context);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Unable to open browser. URL copied: ${article.url}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error launching URL: $e');
      if (!context.mounted) return;
      await _copyUrl(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error opening browser: $e. URL copied to clipboard.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: article.url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Article URL copied to clipboard'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error copying to clipboard: $e');
    }
  }

  Future<void> _shareArticle(BuildContext context) async {
    try {
      final shareText = '${article.title}\n\n${article.url}';
      await Clipboard.setData(ClipboardData(text: shareText));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Article copied to clipboard for sharing'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error sharing article: $e');
    }
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'bbc news':
        return const Color(0xFFBB1919);
      case 'cnn':
        return const Color(0xFFCC0000);
      case 'reuters':
        return const Color(0xFFFF6600);
      case 'associated press':
        return const Color(0xFF0066CC);
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
      default:
        return ThemeConstants.primaryColor;
    }
  }

  IconData _getSourceIcon(String source) {
    return NewsListPage.getSourceIcon(source);
  }

  bool _shouldShowAuthor(String author) {
    final invalidAuthors = [
      'unknown',
      'anonymous',
      'news writer',
      'tech reporter',
      'open source community',
      'news reporter',
      'dev.to author',
      'reddit user',
      '',
    ];

    return !invalidAuthors.contains(author.toLowerCase()) &&
        author.trim().isNotEmpty &&
        !author.toLowerCase().contains('reporter') &&
        !author.toLowerCase().contains('writer');
  }

  String _getAuthorInitials(String author) {
    if (author.isEmpty) return '?';

    final words = author.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '?';
  }

  NetworkImage? _getAuthorAvatar(String author) {
    // Generate consistent avatar based on author name
    if (!_shouldShowAuthor(author)) return null;

    // Use a service like UI Avatars or generate based on name
    final encodedName = Uri.encodeComponent(author);
    return NetworkImage(
        'https://ui-avatars.com/api/?name=$encodedName&size=80&background=random&color=fff&bold=true');
  }
}
