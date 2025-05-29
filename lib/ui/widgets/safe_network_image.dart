import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';

class SafeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double size;
  final String fallbackText;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.size = 40,
    required this.fallbackText,
  });

  // Helper function to fix localhost URLs
  String _getFixedImageUrl(String url) {
    if (url.isEmpty) return '';

    // Handle localhost URLs
    if (url.startsWith('http://localhost:8000')) {
      return ApiUrls.baseUrl + url.substring('http://localhost:8000'.length);
    }

    // Handle 127.0.0.1 URLs
    if (url.startsWith('http://127.0.0.1:8000')) {
      return ApiUrls.baseUrl + url.substring('http://127.0.0.1:8000'.length);
    }

    // Handle relative paths
    if (url.startsWith('/')) {
      return ApiUrls.baseUrl + url;
    }

    // Return as is if already a valid URL
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final fixedImageUrl = _getFixedImageUrl(imageUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        color: ThemeConstants.primaryColor.withOpacity(0.2),
        child: fixedImageUrl.isEmpty
            ? _buildFallback()
            : Image.network(
                fixedImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // On error, show fallback
                  return _buildFallback();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Text(
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
        style: TextStyle(
          color: ThemeConstants.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.5,
        ),
      ),
    );
  }
}
